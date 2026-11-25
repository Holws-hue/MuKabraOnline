"""Enmarcado Louis31 de KABRA reconstruido desde captura del Main.exe original.

Transporte auténtico observado: wire = ((logical - 1) ^ 0x10) & 0xFF
Invierte TODOS los bytes, incluidos el tipo, el tamaño y el contenido cifrado.
No autentica, no resuelve el intercambio del antihack y no contiene credenciales.
"""

class LouisFrameError(ValueError):
    pass

def unwrap(b: int) -> int:
    return ((b ^ 0x10) + 1) & 0xFF

def wrap(b: int) -> int:
    return ((b - 1) ^ 0x10) & 0xFF

def _frame_length(data: bytes, wire: bool) -> int | None:
    if len(data) < 2:
        return None
    head = unwrap(data[0]) if wire else data[0]
    if head not in (0xC1, 0xC2, 0xC3, 0xC4):
        raise LouisFrameError("Invalid packet family")
    wide = head in (0xC2, 0xC4)
    if wide and len(data) < 3:
        return None
    length = unwrap(data[1]) if wire else data[1]
    if wide:
        length = (length << 8) | (unwrap(data[2]) if wire else data[2])
    if length < (4 if wide else 3) or length > 65535:
        raise LouisFrameError("Invalid packet size")
    return length

def decode_frame(packet: bytes) -> bytes:
    required = _frame_length(packet, True)
    if required != len(packet):
        raise LouisFrameError(f"Expected {required} bytes, received {len(packet)}")
    return bytes(unwrap(b) for b in packet)

def encode_frame(packet: bytes) -> bytes:
    required = _frame_length(packet, False)
    if required != len(packet):
        raise LouisFrameError("Invalid logical packet length")
    return bytes(wrap(b) for b in packet)

def read_one_frame_from_buffer(buffer: bytes) -> tuple[bytes | None, bytes]:
    """TCP es un flujo de bytes y no conserva límites de paquetes."""
    size = _frame_length(buffer, True)
    if size is None or len(buffer) < size:
        return None, buffer
    return decode_frame(buffer[:size]), buffer[size:]
