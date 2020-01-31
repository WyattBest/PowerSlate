import sys
import requests
import json
import datetime
import pyodbc
import time
import traceback
import smtplib
from email.mime.text import MIMEText


def init_config(x):
    # Loads configuration file and sets various parameters.
    # Accepts the config file name as input (ex. SlaPowInt_config.json).

    global sq_govid_url
    global sq_govid_cred
    global s_upload_url
    global s_upload_cred
    global smtp_config
    global cnxn
    global cursor
    global today

    # Read config file and convert to dict
    with open(x) as config_file:
        config = json.loads(config_file.read())
        # print(json.dumps(config, indent = 4, sort_keys = True)) # Debug: print config object

    # Slate web service connections
    sq_govid_url = config['slate_query_govid']['url']
    sq_govid_cred = (config['slate_query_govid']['username'],
                     config['slate_query_govid']['password'])
    s_upload_url = config['slate_upload']['url']
    s_upload_cred = (config['slate_upload']['username'],
                     config['slate_upload']['password'])

    # Email crash handler notification settings
    smtp_config = config['smtp']

    # Microsoft SQL Server connection. Requires ODBC connection provisioned on the local machine.
    cnxn = pyodbc.connect(config['pf_database_string'])
    cursor = cnxn.cursor()


def de_init():
    # Clean up connections.
    cnxn.close()  # SQL


def doit(config_file):
    # Main body of the program
    init_config(config_file)

    # Get list of government Id's from Slate
    r = requests.get(sq_govid_url, auth=sq_govid_cred)
    r.raise_for_status()

    # Convert Slate JSON response into Python list.
    # Since the initial Slate response is a dict with a single key, isolate the single value, which is a list.
    x = json.loads(r.text)['row']
    slate_upload_list = []

    # Execute SQL stored precedure for each id and add result to list to be uploaded back to Slate.
    for k, v in enumerate(x):
        cursor.execute('EXEC [custom].[PS_selISIR] ?', x[k]['govid'])
        row = cursor.fetchone()

        # If the stored procedure returns something, append that to new list
        if row is not None:
            slate_upload_list.append({'pid': x[k]['pid'], 'isir': row.ISIR})

    # Slate must have a root element for some reason, so nest the dict inside another dict and list.
    slate_upload_dict = {'row': slate_upload_list}

    # Upload dict back to Slate
    r = requests.post(s_upload_url, json=slate_upload_dict, auth=s_upload_cred)
    r.raise_for_status()

    de_init()


# Attempt a sync; send failure email with traceback if error.
try:
    print('Start sync at ' + str(datetime.datetime.now()))
    doit(sys.argv[1])
except Exception as e:
    # Send a failure email with traceback on exceptions
    print('Exception at ' + str(datetime.datetime.now()) +
          '! Check notification email.')
    msg = MIMEText('Sync failed at ' + str(datetime.datetime.now()) + '\n\nError: '
                    + str(traceback.format_exc()))
    msg['Subject'] = smtp_config['subject']
    msg['From'] = smtp_config['from']
    msg['To'] = smtp_config['to']

    with smtplib.SMTP(smtp_config['server']) as smtp:
        smtp.starttls()
        smtp.login(smtp_config['username'], smtp_config['password'])
        smtp.send_message(msg)
