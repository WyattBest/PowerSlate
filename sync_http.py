import sys
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib
import pscore
import socket


pscore.init_config(sys.argv[1])


class testHTTPServer_RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Send response status code
        self.send_response(200)

        # Send headers
        self.send_header('Content-type', 'text/html')
        self.end_headers()

        # Send message back to client
        q = urllib.parse.parse_qs(self.path[2:])
        print(q)  # Debug

        # Check for expected HTTP parameter, then sync that particular person record
        try:
            if 'pid' in q:
                message = pscore.main_sync(q['pid'][0])
            else:
                message = 'Error: Record not found.'
        except Exception:
            message = ('Technical error. Please notify support with the following message: <br /><br />'
                       + str(traceback.format_exc()))

        # Write content as utf-8 data
        self.wfile.write(message.encode("utf8"))
        return


def run_server():
    # Run the web server and idle indefinitely, listening for requests.
    print('starting server...')

    # Server settings
    # Choose port 8080, for port 80, which is normally used for a http server, you need root access
    # This is not a static IP. TODO
    local_ip = socket.gethostbyname(socket.gethostname())
    server_address = (local_ip, 8887)
    httpd = HTTPServer(server_address, testHTTPServer_RequestHandler)
    print('running server...')
    httpd.serve_forever()


run_server()
