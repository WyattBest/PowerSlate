import sys
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib
import ps_core
import socket


CONFIG = ps_core.init(sys.argv[1])


def emit_traceback():
    message = (
        "Technical error. Please notify support with the following message: <br /><br />"
        + str(traceback.format_exc())
    )
    return message


class HTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Send response status code
        self.send_response(200)

        # Send headers
        self.send_header("Content-type", "text/html")
        self.end_headers()

        # Send message back to client
        q = urllib.parse.parse_qs(self.path[2:])
        print(q)  # Debug

        # Check for expected HTTP parameter, then sync that particular person record
        try:
            if "pid" in q:
                message = ps_core.main_sync(q["pid"][0])
            else:
                message = "Error: Record not found."
        except Exception as ex:
            # Re-initialize and try one more time before returning an error to the user
            print("Attempting to recover from error:", emit_traceback())
            try:
                ps_core.de_init()
                CONFIG = ps_core.init(sys.argv[1])
                message = ps_core.main_sync(q["pid"][0])
            except Exception:
                message = emit_traceback()
                ps_core.de_init()
                CONFIG = ps_core.init(sys.argv[1])

        # Sent message back to client after replacing newlines with HTML line breaks
        message = message.replace("\n", "<br />")
        self.wfile.write(message.encode("utf8"))
        return


def run_server():
    # Run the web server and idle indefinitely, listening for requests.
    print("starting server...")

    # Server settings
    # Choose port 8080, for port 80, which is normally used for a http server, you need root access
    # Use IP address from config file, if present, otherwise fall back to DNS lookup
    if "http_ip" in CONFIG and CONFIG["http_ip"] is not None:
        local_ip = CONFIG["http_ip"]
    else:
        local_ip = socket.gethostbyname(socket.gethostname())
    server_address = (local_ip, CONFIG["http_port"])
    httpd = HTTPServer(server_address, HTTPRequestHandler)
    print("running server...")
    httpd.serve_forever()


run_server()
