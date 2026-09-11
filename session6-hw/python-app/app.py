from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(b"<h1>Hello World from Python!</h1>")

server = HTTPServer(("0.0.0.0", 5000), Handler)
print("Server running on port 5000")
server.serve_forever()
