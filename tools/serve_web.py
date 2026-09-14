#!/usr/bin/env python3
"""Serve a Godot web export for local play: `make serve-web` / `make play`.

Usage: serve_web.py <dir> [port] [host] [game_port] [broker_port]

One URL for everything, like production will be:
  http://HOST:PORT/            the web export (index.html, .wasm, .pck)
  ws://HOST:PORT/ws            proxied to the game server's WebSocket on 127.0.0.1:game_port
  ws://HOST:PORT/relay         proxied to the match broker on 127.0.0.1:broker_port (?host, ?join=CODE)

The browser client connects to /ws on whatever address served the page, so
there's no second port to remember or open. (Opening the game server's port
directly in a browser logs "Missing or invalid header 'upgrade'" on the server:
it only speaks WebSocket.)

Also sets the .wasm MIME type and COOP/COEP headers. Those headers are only
*required* for thread-enabled exports (we export without threads), but sending
them keeps local testing identical if we ever flip that switch.
"""
import functools
import http.server
import socket
import sys
import threading


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def __init__(self, *args, game_port=9080, broker_port=9085, **kwargs):
        self.routes = {"/ws": ("game server", game_port, "make server"), "/relay": ("broker", broker_port, "make broker")}
        super().__init__(*args, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        route = self.routes.get(self.path.split("?")[0])
        if route:
            if self.headers.get("Upgrade", "").lower() != "websocket":
                self.send_error(426, f"Upgrade Required: {self.path} is a WebSocket endpoint")
                return
            self._proxy_websocket(*route)
            return
        super().do_GET()

    def _proxy_websocket(self, name, port, how):
        """Replay the handshake upstream, then shovel bytes both ways."""
        try:
            upstream = socket.create_connection(("127.0.0.1", port), timeout=5)
        except OSError:
            self.send_error(502, f"{name} not running on port {port} ({how})")
            return
        upstream.settimeout(None)
        head = f"GET / HTTP/1.1\r\n" + "".join(f"{k}: {v}\r\n" for k, v in self.headers.items()) + "\r\n"
        upstream.sendall(head.encode("latin-1"))
        self.close_connection = True

        def pump(source, destination):
            try:
                while data := source.recv(65536):
                    destination.sendall(data)
            except OSError:
                pass
            finally:
                for sock in (source, destination):
                    try:
                        sock.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass

        downstream = threading.Thread(target=pump, args=(upstream, self.connection), daemon=True)
        downstream.start()
        pump(self.connection, upstream)
        downstream.join()
        upstream.close()

    def log_message(self, fmt, *args):
        if self.path.split("?")[0] in self.routes:
            sys.stderr.write(f"[ws proxy] {self.address_string()} {fmt % args}\n")


def main() -> None:
    directory = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8060
    host = sys.argv[3] if len(sys.argv) > 3 else "127.0.0.1"
    game_port = int(sys.argv[4]) if len(sys.argv) > 4 else 9080
    broker_port = int(sys.argv[5]) if len(sys.argv) > 5 else game_port + 5
    handler = functools.partial(GodotWebHandler, directory=directory, game_port=game_port, broker_port=broker_port)
    with http.server.ThreadingHTTPServer((host, port), handler) as server:
        shown_host = "localhost" if host in ("127.0.0.1", "0.0.0.0") else host
        print(f"Serving {directory}; /ws -> 127.0.0.1:{game_port} (game server), /relay -> 127.0.0.1:{broker_port} (broker)", flush=True)
        print(f"  Play:  http://{shown_host}:{port}/?connect      (Ctrl+C to stop)", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
