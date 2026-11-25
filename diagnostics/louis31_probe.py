"""Sondeo de ConnectServer/GameServer Louis 31 sin credenciales.

Ejecutar de forma manual y con permiso del propietario. No intenta autenticarse ni
responder a protecciones del servidor. Limita tiempo, lectura y reconexiones.
"""
import socket
import struct
import os
import sys

HOST = os.getenv("KABRA_HOST", "523.ddns.net")
CS_PORT = int(os.getenv("KABRA_CS_PORT", "44405"))
GS_PORT = int(os.getenv("KABRA_GS_PORT", "55901"))
SOCKET_TIMEOUT = 4
MAX_FRAME = 8192


def recv_exact(sock: socket.socket, amount: int) -> bytes:
    result = bytearray()
    while len(result) < amount:
        piece = sock.recv(amount - len(result))
        if not piece:
            raise EOFError(f"Socket cerrado: faltaban {amount-len(result)} bytes")
        result.extend(piece)
    return bytes(result)


def read_c_frame(sock: socket.socket) -> bytes:
    first = recv_exact(sock, 2)
    if first[0] in (0xC1, 0xC3):
        length = first[1]
        header = first
    elif first[0] in (0xC2, 0xC4):
        header = first + recv_exact(sock, 1)
        length = (header[1] << 8) | header[2]
    else:
        raise ValueError(f"Encabezado desconocido en ConnectServer: {first[:1].hex()}")
    if length < len(header) or length > MAX_FRAME:
        raise ValueError(f"Longitud inesperada: {length}")
    return header + recv_exact(sock, length - len(header))


def describe(frame: bytes) -> str:
    short = frame[:min(len(frame), 32)].hex(" ")
    return f"{len(frame)} bytes: {short}"


def connect_server():
    print("ConnectServer: esperando saludo")
    with socket.create_connection((HOST, CS_PORT), timeout=SOCKET_TIMEOUT) as s:
        s.settimeout(SOCKET_TIMEOUT)
        hello = read_c_frame(s)
        print("Saludo:", describe(hello))
        if hello[0] != 0xC1 or len(hello) < 4:
            print("Saludo desconocido, detengo el sondeo")
            return
        if hello[2:4] != b"\\x00\\x01":
            print("No se reconoce el saludo 00 01, no se envían más paquetes")
            return
        s.sendall(bytes.fromhex("C1 04 F4 06"))
        servers = read_c_frame(s)
        print("Respuesta lista:", describe(servers))
        payload_offset = 3 if servers[0] in (0xC2, 0xC4) else 2
        if servers[payload_offset:payload_offset+2] != bytes.fromhex("F4 06"):
            print("Código de lista distinto de F4 06; no selecciono servidor")
            return
        # Selección exacta del código 9 observada en el Main.exe de KABRA.
        s.sendall(bytes.fromhex("C1 06 F4 03 09 00"))
        address = read_c_frame(s)
        print("Respuesta F4 03:", describe(address))


def game_server():
    print("GameServer: leyendo saludo sin enviar nada")
    with socket.create_connection((HOST, GS_PORT), timeout=SOCKET_TIMEOUT) as s:
        s.settimeout(SOCKET_TIMEOUT)
        first = recv_exact(s, 12)
        print("Saludo GameServer:", describe(first))
        if first[0] == 0xD0:
            print("PROTOCOLO PERSONALIZADO D0: no se envía respuesta D2 sin conocer el algoritmo legítimo")
        else:
            print("Cabecera distinta de D0. No enviar credenciales.")


if __name__ == "__main__":
    if not (1 <= CS_PORT <= 65535 and 1 <= GS_PORT <= 65535):
        sys.exit("Puerto inválido")
    for description, action in [("ConnectServer", connect_server), ("GameServer", game_server)]:
        try:
            action()
        except (OSError, EOFError, ValueError) as ex:
            print(f"{description}: {type(ex).__name__}: {ex}")
