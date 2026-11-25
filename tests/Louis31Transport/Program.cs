using Client.Main.Networking;

static class Program
{
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

    static int Main()
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
        Console.WriteLine("KABRA PASS: 7 validaciones del transporte Louis31, sin credenciales");
        return 0;
    }
}
