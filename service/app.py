import json
import os
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/healthz':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode('utf-8'))
        elif self.path == '/' or self.path == '':
            app_name = os.environ.get('APP_NAME', 'unknown')
            version = os.environ.get('VERSION', 'unknown')
            pod_hostname = socket.gethostname()
            response = {
                "app": app_name,
                "version": version,
                "pod": pod_hostname
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode('utf-8'))
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": "not found"}).encode('utf-8'))

    def log_message(self, format, *args):
        print(f"{self.address_string()} - [{self.log_date_time_string()}] {format % args}")

def run(port=8080):
    server_address = ('', port)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)
    print(f"Starting service on port {port}...")
    httpd.serve_forever()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8080'))
    run(port=port)
