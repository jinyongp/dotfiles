import http.client
from http.server import BaseHTTPRequestHandler
import threading
import unittest
from unittest.mock import patch

from loopback_http import LoopbackHTTPServer


class LoopbackFixture(unittest.TestCase):
    def test_serves_http_without_reverse_dns(self):
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"ready")

            def log_message(self, *args):
                pass

        with patch("socket.getfqdn", side_effect=AssertionError("ambient reverse DNS was consulted")):
            with LoopbackHTTPServer(("127.0.0.1", 0), Handler) as server:
                server.timeout = 2
                worker = threading.Thread(target=server.handle_request)
                worker.start()
                connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=2)
                try:
                    connection.request("GET", "/")
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    self.assertEqual(response.read(), b"ready")
                finally:
                    connection.close()
                    worker.join(timeout=3)
                self.assertFalse(worker.is_alive())


if __name__ == "__main__":
    unittest.main()
