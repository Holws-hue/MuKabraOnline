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

        private static byte Add(byte value, int delta) =>
            unchecked((byte)(value + delta));

        private static bool TryGetFrameSize(List<byte> pending, bool wire, out int length)
        {
            length = 0;
            if (pending.Count < 2)
                return false;

            byte type = pending[0];
            int headerSize;
            switch (type)
            {
                case 0xD0 when wire:
                    headerSize = 2;
                    length = Add(pending[1], -15);
                    break;
                case 0xD2 when wire:
                    headerSize = 2;
                    length = Add(pending[1], 17);
                    break;
                case 0xD1 when wire:
                case 0xD3 when wire:
                    headerSize = 3;
                    if (pending.Count < 3) return false;
                    length = (Add(pending[1], 17) << 8) | Add(pending[2], 17);
                    break;
                case 0xC1 when !wire:
                case 0xC3 when !wire:
                    headerSize = 2;
                    length = pending[1];
                    break;
                case 0xC2 when !wire:
                case 0xC4 when !wire:
                    headerSize = 3;
                    if (pending.Count < 3) return false;
                    length = (pending[1] << 8) | pending[2];
                    break;
                default:
                    throw new InvalidOperationException("Tipo de trama Louis31 no reconocido.");
            }

            if (length < headerSize + 1 || length > 65535)
                throw new InvalidOperationException("Longitud de trama Louis31 inválida.");
            return pending.Count >= length;
        }

        internal static byte[] Decode(byte[] packet)
        {
            if (packet == null || packet.Length < 3) throw new ArgumentException("Paquete incompleto");
            var list = new List<byte>(packet);
            if (!TryGetFrameSize(list, true, out var size) || size != packet.Length)
                throw new ArgumentException("Trama de red incompleta.");
            var decoded = (byte[])packet.Clone();
            byte kind = decoded[0];
            decoded[0] = Add(kind, -15);
            if (kind == 0xD0)
                decoded[1] = Add(decoded[1], -15);
            else if (kind == 0xD2)
                decoded[1] = Add(decoded[1], 17);
            else
            {
                decoded[1] = Add(decoded[1], 17);
                decoded[2] = Add(decoded[2], 17);
            }

            int header = (kind == 0xD0 || kind == 0xD2) ? 2 : 3;
            for (int i = header; i < decoded.Length; i++)
                decoded[i] = Add(decoded[i], 17);
            return decoded;
        }

        internal static byte[] Encode(byte[] packet)
        {
            if (packet == null || packet.Length < 3) throw new ArgumentException("Paquete incompleto");
            var list = new List<byte>(packet);
            if (!TryGetFrameSize(list, false, out var size) || size != packet.Length)
                throw new ArgumentException("Trama lógica incompleta.");
            var encoded = (byte[])packet.Clone();
            byte kind = encoded[0];
            encoded[0] = Add(kind, 15);
            if (kind == 0xC1)
                encoded[1] = Add(encoded[1], 15);
            else
            {
                encoded[1] = Add(encoded[1], -17);
                if (kind == 0xC2 || kind == 0xC4)
                    encoded[2] = Add(encoded[2], -17);
            }

            int header = (kind == 0xC1 || kind == 0xC3) ? 2 : 3;
            for (int i = header; i < encoded.Length; i++)
                encoded[i] = Add(encoded[i], -17);
            return encoded;
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
