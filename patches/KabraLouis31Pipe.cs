using System;
using System.Buffers;
using System.Collections.Generic;
using System.IO.Pipelines;
using System.Threading.Tasks;

namespace Client.Main.Networking
{
    /// <summary>
    /// Adaptador de enmarcado Louis 31 observado en KABRA.
    /// Sólo transforma la envoltura C1/C2/C3/C4 a D0/D1/D2/D3.
    /// No representa la verificación MHP ni sustituye el login legítimo.
    /// </summary>
    internal sealed class KabraLouis31Pipe : IDuplexPipe
    {
        private const int MaxPendingBytes = 1_048_576;
        private readonly IDuplexPipe _physical;
        private readonly Pipe _decodedInput = new Pipe();
        private readonly Pipe _encodedOutput = new Pipe();

        public PipeReader Input => _decodedInput.Reader;
        public PipeWriter Output => _encodedOutput.Writer;

        public KabraLouis31Pipe(IDuplexPipe physical)
        {
            _physical = physical ?? throw new ArgumentNullException(nameof(physical));
            _ = Task.Run(ReadFromGameServerAsync);
            _ = Task.Run(WriteToGameServerAsync);
        }

        // Mapeo auténtico comprobado en la captura Main.exe Louis31:
        // cable = ((MU - 1) XOR 0x10) ; MU = ((cable XOR 0x10) + 1)
        // No es una simple suma de 15/17; esa aproximación alteraba gran parte de los bytes.
        private static byte Unwrap(byte wire) =>
            unchecked((byte)((wire ^ 0x10) + 1));

        private static byte Wrap(byte logical) =>
            unchecked((byte)((logical - 1) ^ 0x10));

        private static bool TryGetFrameSize(List<byte> pending, bool wire, out int length)
        {
            length = 0;
            if (pending.Count < 2) return false;

            byte kind = wire ? Unwrap(pending[0]) : pending[0];
            int headerSize = kind == 0xC1 || kind == 0xC3 ? 2 : 3;
            if (kind != 0xC1 && kind != 0xC2 && kind != 0xC3 && kind != 0xC4)
                throw new InvalidOperationException("Tipo de trama Louis31 no reconocido.");

            if (pending.Count < headerSize) return false;
            byte high = wire ? Unwrap(pending[1]) : pending[1];
            if (headerSize == 2)
                length = high;
            else
                length = (high << 8) | (wire ? Unwrap(pending[2]) : pending[2]);

            if (length < headerSize + 1 || length > 65535)
                throw new InvalidOperationException("Longitud de trama Louis31 inválida.");
            return pending.Count >= length;
        }

        internal static byte[] Decode(byte[] packet)
        {
            if (packet == null || packet.Length < 3)
                throw new ArgumentException("Trama de red incompleta");
            if (!TryGetFrameSize(new List<byte>(packet), true, out int length)
                || length != packet.Length)
                throw new ArgumentException("Tamaño de trama recibida incorrecto");

            var plain = (byte[])packet.Clone();
            for (int i = 0; i < plain.Length; i++)
                plain[i] = Unwrap(plain[i]);
            return plain;
        }

        internal static byte[] Encode(byte[] packet)
        {
            if (packet == null || packet.Length < 3)
                throw new ArgumentException("Trama lógica incompleta");
            if (!TryGetFrameSize(new List<byte>(packet), false, out int length)
                || length != packet.Length)
                throw new ArgumentException("Tamaño de trama de envío incorrecto");

            var wire = (byte[])packet.Clone();
            for (int i = 0; i < wire.Length; i++)
                wire[i] = Wrap(wire[i]);
            return wire;
        }

        private static bool TakeFrame(List<byte> buffer, bool wire, out byte[] frame)
        {
            frame = null;
            if (!TryGetFrameSize(buffer, wire, out int size))
                return false;
            frame = buffer.GetRange(0, size).ToArray();
            buffer.RemoveRange(0, size);
            return true;
        }

        private async Task ReadFromGameServerAsync()
        {
            var waiting = new List<byte>(2048);
            try
            {
                while (true)
                {
                    var result = await _physical.Input.ReadAsync();
                    foreach (ReadOnlyMemory<byte> chunk in result.Buffer)
                        waiting.AddRange(chunk.ToArray());
                    _physical.Input.AdvanceTo(result.Buffer.End);
                    if (waiting.Count > MaxPendingBytes)
                        throw new InvalidOperationException("Tráfico de juego demasiado grande.");

                    while (TakeFrame(waiting, true, out var packet))
                    {
                        byte[] logical = Decode(packet);
                        Memory<byte> dst = _decodedInput.Writer.GetMemory(logical.Length);
                        logical.AsSpan().CopyTo(dst.Span);
                        _decodedInput.Writer.Advance(logical.Length);
                        FlushResult flushed = await _decodedInput.Writer.FlushAsync();
                        if (flushed.IsCompleted || flushed.IsCanceled)
                            return;
                    }
                    if (result.IsCompleted) return;
                }
            }
            catch (Exception)
            {
                // No escribir datos de sesión, paquetes, cuentas ni contraseñas en los registros.
            }
            finally
            {
                await _decodedInput.Writer.CompleteAsync();
            }
        }

        private async Task WriteToGameServerAsync()
        {
            var waiting = new List<byte>(2048);
            try
            {
                while (true)
                {
                    var result = await _encodedOutput.Reader.ReadAsync();
                    foreach (ReadOnlyMemory<byte> chunk in result.Buffer)
                        waiting.AddRange(chunk.ToArray());
                    _encodedOutput.Reader.AdvanceTo(result.Buffer.End);
                    if (waiting.Count > MaxPendingBytes)
                        throw new InvalidOperationException("Cola de envío demasiado grande.");

                    while (TakeFrame(waiting, false, out var packet))
                    {
                        byte[] encoded = Encode(packet);
                        Memory<byte> dst = _physical.Output.GetMemory(encoded.Length);
                        encoded.AsSpan().CopyTo(dst.Span);
                        _physical.Output.Advance(encoded.Length);
                        FlushResult flushed = await _physical.Output.FlushAsync();
                        if (flushed.IsCompleted || flushed.IsCanceled)
                            return;
                    }
                    if (result.IsCompleted) return;
                }
            }
            catch (Exception)
            {
                // La conexión original decide cuándo y cómo mostrar el fallo al usuario.
            }
            finally
            {
                await _encodedOutput.Reader.CompleteAsync();
            }
        }
    }
}
