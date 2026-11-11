# A denylist server for the blocky VM test: serves list.txt as the mode file
# says, "whole", "404", or "truncate" (Content-Length of the whole body, 40% of
# it sent, then the connection closed mid-read).
import http.server
import sys

body_path, mode_path, port = sys.argv[1], sys.argv[2], int(sys.argv[3])


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with open(mode_path) as f:
            mode = f.read().strip()
        with open(body_path, "rb") as f:
            body = f.read()
        if mode == "404":
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if mode == "truncate":
            self.wfile.write(body[: len(body) * 2 // 5])
            self.wfile.flush()
            self.close_connection = True
            return
        self.wfile.write(body)


http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
