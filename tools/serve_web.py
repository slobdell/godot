#!/usr/bin/env python3
"""Serve a Godot web export for local testing: `make serve-web`.

Usage: serve_web.py <dir> [port] [host]

Sets the .wasm MIME type and the COOP/COEP headers. Those headers are only
*required* for thread-enabled exports (we export without threads), but sending
them keeps local testing identical if we ever flip that switch.
"""
import functools
import http.server
import sys


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    directory = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8060
    host = sys.argv[3] if len(sys.argv) > 3 else "127.0.0.1"
    handler = functools.partial(GodotWebHandler, directory=directory)
    with http.server.ThreadingHTTPServer((host, port), handler) as server:
        print(f"Serving {directory} at http://{host}:{port}  (Ctrl+C to stop)")
        server.serve_forever()


if __name__ == "__main__":
    main()
