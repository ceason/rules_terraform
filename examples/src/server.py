import BaseHTTPServer
import os

SERVER_MESSAGE = os.environ.get("CUSTOM_SERVER_MESSAGE", "<no CUSTOM_SERVER_MESSAGE specified>")

PORT_NUMBER = 8080


class MyHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    def do_GET(s):
        print("Received HTTP request")
        s.send_response(200)
        s.send_header("Content-type", "text/plain")
        s.end_headers()
        s.wfile.write(SERVER_MESSAGE)


if __name__ == '__main__':
    server_class = BaseHTTPServer.HTTPServer
    print("Starting HTTP server on port %d" % PORT_NUMBER)
    httpd = server_class(("0.0.0.0", PORT_NUMBER), MyHandler)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
