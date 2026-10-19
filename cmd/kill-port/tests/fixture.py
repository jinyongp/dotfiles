"""Disposable service and admin APIs for CLI integration tests."""

import argparse
import http.server
import json
import socket
import socketserver

parser = argparse.ArgumentParser()
parser.add_argument("kind", choices=("service", "caddy", "gate"))
parser.add_argument("--socket")
parser.add_argument("--upstream", type=int)
args = parser.parse_args()

listener = socket.socket()
listener.bind(("127.0.0.1", 0))
listener.listen()
port = listener.getsockname()[1]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if args.kind == "caddy" and self.path == "/config/":
            body = {"apps": {"http": {"servers": {"web": {"listen": [":" + str(port)], "routes": [
                {"match": [{"host": ["app.test"]}], "handle": [{"handler": "reverse_proxy",
                 "upstreams": [{"dial": "127.0.0.1:" + str(args.upstream)}]}]}]}}}}}
        elif args.kind == "gate" and self.path == "/routes":
            body = {"routes": [{"domain": "app.test", "upstream": "127.0.0.1:" + str(args.upstream)}]}
        else:
            self.send_error(404)
            return
        payload = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


if args.kind == "service":
    print(json.dumps({"port": port}), flush=True)
    while True:
        connection, _ = listener.accept()
        connection.close()
elif args.kind == "caddy":
    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    print(json.dumps({"port": port, "admin": server.server_port}), flush=True)
    server.serve_forever()
else:
    server = socketserver.UnixStreamServer(args.socket, Handler)
    print(json.dumps({"port": port}), flush=True)
    server.serve_forever()
