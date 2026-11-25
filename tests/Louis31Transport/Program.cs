using Client.Main.Networking;
using System.Buffers;
using System.IO.Pipelines;

static class Program
{
    private sealed class TestSocketPipe : IDuplexPipe
    {
        public TestSocketPipe(PipeReader input, PipeWriter output) { Input = input; Output = output; }
        public PipeReader Input { get; }
        public PipeWriter Output { get; }
    }

    static byte[] Hex(string hex) => Convert.FromHexString(hex.Replace(" ", ""));
    static void Check(bool ok, string message)
    {
        if (!ok) throw new Exception("Falló test de protocolo: " + message);
    }

    static void Roundtrip(string data)
    {
        byte[] original = Hex(data);
        byte[] encoded = KabraLouis31Pipe.Encode(original);
        byte[] decoded = KabraLouis31Pipe.Decode(encoded);
        Check(original.SequenceEqual(decoded), "roundtrip " + original[0].ToString("X2"));
    }

    static async Task TestFullDuplexAsync()
    {
        var fromWire = new Pipe();
        var toWire = new Pipe();
        var wrapped = new KabraLouis31Pipe(new TestSocketPipe(fromWire.Reader, toWire.Writer));
        byte[] realHello = Hex("D0 1B E0 EF 10 3A 08 20 3F 23 3F 24");
        // Fragmentar como TCP, que no garantiza límites de paquetes.
        await fromWire.Writer.WriteAsync(realHello[..5]);
        await fromWire.Writer.WriteAsync(realHello[5..]);
        var incoming = await wrapped.Input.ReadAsync().AsTask().WaitAsync(TimeSpan.FromSeconds(5));
        var received = incoming.Buffer.ToArray();
        wrapped.Input.AdvanceTo(incoming.Buffer.End);
        Check(received.AsSpan(0, 4).SequenceEqual(Hex("C1 0C F1 00")), "pipeline servidor → Android");

        byte[] logicalReply = Hex("C3 06 10 20 30 40");
        await wrapped.Output.WriteAsync(logicalReply);
        var outbound = await toWire.Reader.ReadAsync().AsTask().WaitAsync(TimeSpan.FromSeconds(5));
        var encoded = outbound.Buffer.ToArray();
        toWire.Reader.AdvanceTo(outbound.Buffer.End);
        Check(KabraLouis31Pipe.Decode(encoded).SequenceEqual(logicalReply),
            "pipeline Android → servidor");
        await fromWire.Writer.CompleteAsync();
        await wrapped.Output.CompleteAsync();
        await wrapped.Input.CompleteAsync();
        await toWire.Reader.CompleteAsync();
    }

    static async Task<int> Main()
    {
        byte[] welcome = Hex("D0 1B E0 EF 10 3A 08 20 3F 23 3F 24");
        byte[] decoded = KabraLouis31Pipe.Decode(welcome);
        Check(decoded.Length == 12, "longitud de saludo");
        Check(decoded.AsSpan(0, 4).SequenceEqual(Hex("C1 0C F1 00")), "saludo real F1 00");
        Check(KabraLouis31Pipe.Encode(decoded).SequenceEqual(welcome), "recodificación byte a byte");
        Roundtrip("C1 04 F4 06");
        Roundtrip("C3 06 F1 01 01 01");
        Roundtrip("C2 00 06 F3 00 01");
        Roundtrip("C4 00 06 15 20 40");
        bool rejected = false;
        try { KabraLouis31Pipe.Decode(Hex("C1 04 F4 06")); }
        catch (InvalidOperationException) { rejected = true; }
        Check(rejected, "rechaza cabecera desconocida");
        await TestFullDuplexAsync();
        Console.WriteLine("KABRA PASS: codec y pipeline full-duplex Louis31, sin credenciales");
        return 0;
    }
}
