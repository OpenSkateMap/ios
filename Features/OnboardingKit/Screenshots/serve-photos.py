#!/usr/bin/env python3
"""Serves the screenshot photos the way the photos domain serves variants, for the simulator's -OSMImagesBaseURL:
GET /cdn-cgi/image/<options>/screenshots/<file> answers with Screenshots/photos/<file> as stored (the app sizes it).
  python3 serve-photos.py [port]   (default 8788)
"""
import http.server
import pathlib
import sys

PHOTOS = pathlib.Path(__file__).resolve().parent / "photos"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.split("?")[0].split("/")
        # ["", "cdn-cgi", "image", "<options>", "screenshots", "<file>"]
        name = parts[-1] if len(parts) == 6 and parts[1:3] == ["cdn-cgi", "image"] and parts[4] == "screenshots" else ""
        photo = PHOTOS / name
        if not name or photo.parent != PHOTOS or not photo.is_file():
            self.send_error(404)
            return
        body = photo.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8788
print(f"Serving {PHOTOS} on http://localhost:{port}")
http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
