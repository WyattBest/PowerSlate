import sys
import requests
import json
import copy
import datetime
import pyodbc
import xml.etree.ElementTree as ET
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib
import pscore
import socket


def main_sync(x, pid):
    # x is the name of the configuration file to use.
    # pid is the specific application to sync.

    pscore.init_config(x)

    # Get applicants from Slate
    r = requests.get(pscore.sq_apps_url,
                     auth=pscore.sq_apps_cred, params={'pid': pid})
    r.raise_for_status()
    # Convert JSON response text to Python dict
    slate_dict = json.loads(r.text)
    rec_formatted_list = pscore.trans_slate_to_rec(
        slate_dict)  # Transform the data to Recruiter format

    if not rec_formatted_list:
        return "No applications found. Perhaps the application(s) are not submitted or are missing required fields?"

    # Check each item in rec_formatted_list for status in PowerCampus.
    rec_new_list = []
    rec_existing_list = []

    for k, v in enumerate(rec_formatted_list):
        ra_status, apl_status, computed_status, PEOPLE_CODE_ID = pscore.scan_status(
            rec_formatted_list[k])

        if ra_status is not None:

            # If application exist but did not process, try it again.
            if ra_status in (1, 2) and apl_status is None:
                rec_new_list.append(rec_formatted_list[k])

            # If application is in a good status, write to rec_existing_list for updating
            if computed_status == 'Active':
                rec_formatted_list[k]['PEOPLE_CODE_ID'] = PEOPLE_CODE_ID
                rec_existing_list.append(rec_formatted_list[k])

        # If application doesn't exist in PowerCampus, write record to rec_new_list.
        else:
            rec_new_list.append(rec_formatted_list[k])

    # POST any new items to PowerCampus Web API, then record the returned PEOPLE_CODE_ID or None
    slate_upload_dict = {}

    for k, v in enumerate(rec_new_list):
        PEOPLE_CODE_ID = pscore.post_to_pc(rec_new_list[k])

        # Add PEOPLE_CODE_ID to a dict to eventually send back to Slate
        if PEOPLE_CODE_ID is not None:
            slate_upload_dict.update({
                rec_new_list[k]['ApplicationNumber']: {
                    'PEOPLE_CODE_ID': PEOPLE_CODE_ID
                }
            })

    # Update existing PowerCampus applications and get registration information
    # First transform the dict to PowerCampus native format (like Campus6 instead of like Recruiter).
    pc_existing_apps_list = pscore.trans_rec_to_pc(rec_existing_list)

    for k, v in enumerate(pc_existing_apps_list):
        # Update Demographics
        pscore.pc_update_demographics(pc_existing_apps_list[k])

        # Update SMS Opt-In
        pscore.pc_update_smsoptin(pc_existing_apps_list[k])

        # Update Status/Decision
        pscore.pc_update_statusdecision(pc_existing_apps_list[k])

        # Get registration information to send back to Slate. (Newly-posted apps won't be registered yet.)
        # First add keys to slate_upload_dict
        if pc_existing_apps_list[k]['ApplicationNumber'] not in slate_upload_dict:
            slate_upload_dict.update(
                {pc_existing_apps_list[k]['ApplicationNumber']: {'PEOPLE_CODE_ID': None}})

        found, registered, readmit, withdrawn, credits, campus_email = pscore.get_pc_profile(
            pc_existing_apps_list[k]['PEOPLE_CODE_ID'],
            pc_existing_apps_list[k]['ACADEMIC_YEAR'],
            pc_existing_apps_list[k]['ACADEMIC_TERM'],
            pc_existing_apps_list[k]['ACADEMIC_SESSION'],
            pc_existing_apps_list[k]['PROGRAM'],
            pc_existing_apps_list[k]['DEGREE'],
            pc_existing_apps_list[k]['CURRICULUM'],)
            
        # Update slate_upload_dict with registration information
        slate_upload_dict[pc_existing_apps_list[k]['ApplicationNumber']].update({'found': found,
                                                                            'registered': registered,
                                                                            'readmit': readmit,
                                                                            'withdrawn': withdrawn,
                                                                            'credits': credits,
                                                                            'campus_email': campus_email})

    # Update Scheduled Actions for existing PowerCampus applications
    actions = pscore.get_actions(pc_existing_apps_list)

    for k, v in actions.items():
        for kk, vv in enumerate(actions[k]['actions']):
            pscore.cursor.execute('EXEC [custom].[PS_updAction] ?, ?, ?, ?, ?, ?, ?, ?, ?',
                                  actions[k]['PEOPLE_CODE_ID'],
                                  'SLATE',
                                  actions[k]['actions'][kk]['action_id'],
                                  actions[k]['actions'][kk]['item'],
                                  actions[k]['actions'][kk]['completed'],
                                  # Only the date portion is actually used.
                                  actions[k]['actions'][kk]['create_datetime'],
                                  actions[k]['ACADEMIC_YEAR'],
                                  actions[k]['ACADEMIC_TERM'],
                                  actions[k]['ACADEMIC_SESSION'])
            pscore.cnxn.commit()

    # Scan PowerCampus status for all apps and log to external db; capture PEOPLE_CODE_ID
    for k, v in enumerate(rec_formatted_list):
        ra_status, apl_status, computed_status, PEOPLE_CODE_ID = pscore.scan_status(
            rec_formatted_list[k])

        if PEOPLE_CODE_ID is not None and computed_status == 'Active':
            slate_upload_dict[rec_formatted_list[k]['ApplicationNumber']].update(
                {'PEOPLE_CODE_ID': PEOPLE_CODE_ID})

    # Upload data back to Slate
    # slate_upload_dict has app ID's as keys for ease of updating; now transform to a list of flat dicts for Slate to ingest
    slate_upload_list = []
    for k, v in slate_upload_dict.items():
        slate_upload_list.append({**{'aid': k}, **v})

    # Slate requires JSON to be convertable to XML
    slate_upload_dict = {'row': slate_upload_list}

    r = requests.post(pscore.s_upload_url,
                      json=slate_upload_dict, auth=pscore.s_upload_cred)
    r.raise_for_status()

    pscore.de_init()

    print('Done at ' + str(datetime.datetime.now()))
    return 'Done. Please check the SlaPowInt Report for more details.'


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

        # Check for expected HTTP parameter, then sync using first command-line parameter as config file
        try:
            if 'pid' in q:
                message = main_sync(sys.argv[1], q['pid'][0])
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
