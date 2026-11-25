import unittest
from louis31_codec import decode_frame, read_one_frame_from_buffer, LouisFrameError


class LouisWireCodecTest(unittest.TestCase):
    def test_server_hello(self):
        wire = bytes.fromhex("D0 1B E0 EF 10 3A 08 20 3F 23 3F 24")
        decoded = decode_frame(wire)
        self.assertEqual(decoded[:4], bytes.fromhex("C1 0C F1 00"))
        self.assertEqual(len(decoded), 12)

    def test_client_prelogin_observed(self):
        wire = bytes.fromhex(
            "D2 07 FF 9E 37 C4 4E CE 30 1C F8 2C 17 84 C9 0E 22 C6 D2 62 BD 47 E3 D9"
        )
        decoded = decode_frame(wire)
        self.assertEqual(decoded[:3], bytes.fromhex("C3 18 10"))
        self.assertEqual(len(decoded), 24)

    def test_fragmented_tcp(self):
        packet = bytes.fromhex("D0 1B E0 EF 10 3A 08 20 3F 23 3F 24")
        out, remainder = read_one_frame_from_buffer(packet[:5])
        self.assertIsNone(out)
        out, remainder = read_one_frame_from_buffer(remainder + packet[5:] + packet)
        self.assertEqual(out[:4], bytes.fromhex("C1 0C F1 00"))
        self.assertEqual(remainder, packet)

    def test_reject_unverified_type(self):
        with self.assertRaises(LouisFrameError):
            decode_frame(bytes.fromhex("D1 03 00"))


if __name__ == "__main__":
    unittest.main()
