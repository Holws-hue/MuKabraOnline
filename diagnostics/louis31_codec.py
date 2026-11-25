"""Observational Louis 31 wrapper decoder (lab only, NO login/credential handling).

Known packets in authentic KABRA captures begin with wire D0 and D2.
The opaque body on a D2 packet remains encrypted; parsing its outer frame
DOES NOT derive the server's challenge response or bypass any validation.
"""
from __future__ import annotations


class LouisFrameError(ValueError):
    pass


def decode_frame(packet: bytes) -> bytes:
    if len(packet) < 3:
        raise LouisFrameError("Truncated frame")
    family = packet[0]
    if family == 0xD0:              # observed equivalent to C1
        required = (packet[1] - 15) & 0xFF
        kind = 0xC1
    elif family == 0xD2:            # observed equivalent to C3
        required = (packet[1] + 17) & 0xFF
        kind = 0xC3
    else:
        raise LouisFrameError("Unverified wire framing: do not guess packet type")
    if required != len(packet) or not 3 <= required <= 255:
        raise LouisFrameError(f"Invalid frame size, expected={required}, actual={len(packet)}")
    return bytes((kind, required)) + bytes(((b + 17) & 255 for b in packet[2:]))


def read_one_frame_from_buffer(buffer: bytes) -> tuple[bytes | None, bytes]:
    """TCP is a byte stream: returns (decoded packet or None, unconsumed buffer)."""
    if len(buffer) < 2:
        return None, buffer
    if buffer[0] == 0xD0:
        length = (buffer[1] - 15) & 255
    elif buffer[0] == 0xD2:
        length = (buffer[1] + 17) & 255
    else:
        raise LouisFrameError("Unrecognized leading byte")
    if length < 3:
        raise LouisFrameError("Invalid declared frame length")
    if len(buffer) < length:
        return None, buffer
    return decode_frame(buffer[:length]), buffer[length:]
