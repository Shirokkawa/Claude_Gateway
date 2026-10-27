#!/usr/bin/env python3
import http.client
import socket
import socketserver
import ssl

PROXY = ('192.168.50.1', 7897)
DOH_HOST = 'cloudflare-dns.com'
FAIL = b'\x81\x82' + b'\x00' * 8


def resolve(query):
    with socket.create_connection(PROXY, timeout=5) as sock:
        sock.settimeout(5)
        sock.sendall((
            f'CONNECT {DOH_HOST}:443 HTTP/1.1\r\n'
            f'Host: {DOH_HOST}:443\r\n\r\n'
        ).encode('ascii'))
        headers = bytearray()
        while not headers.endswith(b'\r\n\r\n'):
            if len(headers) >= 8192:
                raise ValueError('Proxy response too large')
            byte = sock.recv(1)
            if not byte:
                raise ConnectionError('Proxy closed connection')
            headers.extend(byte)
        if not headers.startswith(b'HTTP/1.1 200 ') and not headers.startswith(b'HTTP/1.0 200 '):
            raise ConnectionError('Proxy rejected CONNECT')

        with ssl.create_default_context().wrap_socket(sock, server_hostname=DOH_HOST) as tls:
            wire_query = b'\x00\x00' + query[2:]
            request = (
                f'POST /dns-query HTTP/1.1\r\n'
                f'Host: {DOH_HOST}\r\n'
                'Content-Type: application/dns-message\r\n'
                'Accept: application/dns-message\r\n'
                f'Content-Length: {len(wire_query)}\r\n'
                'Connection: close\r\n\r\n'
            ).encode('ascii')
            tls.sendall(request + wire_query)
            response = http.client.HTTPResponse(tls)
            response.begin()
            if response.status != 200 or response.getheader('Content-Type', '').split(';')[0] != 'application/dns-message':
                raise ValueError('Invalid DoH response')
            answer = response.read(4097)
            if len(answer) < 12 or len(answer) > 4096:
                raise ValueError('Invalid DNS answer')
            return query[:2] + answer[2:]


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        query, udp = self.request
        if len(query) < 12:
            return
        try:
            answer = resolve(query)
        except (OSError, ValueError, http.client.HTTPException):
            answer = query[:2] + FAIL
        udp.sendto(answer, self.client_address)


class Server(socketserver.ThreadingUDPServer):
    daemon_threads = True
    allow_reuse_address = True


with Server(('127.0.0.1', 5354), Handler) as server:
    server.serve_forever()
