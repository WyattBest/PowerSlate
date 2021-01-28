import sys
import requests
import json
import copy
import datetime
import pyodbc
import xml.etree.ElementTree as ET
import traceback
import smtplib
from email.mime.text import MIMEText
import pscore


# Attempt a sync; send failure email with traceback if error.
try:
    print('Start sync at ' + str(datetime.datetime.now()))
    # Name of configuration file passed via command-line
    smtp_config = pscore.init_config(sys.argv[1])
    # smtp_config = pscore.init_config('config_dev.json') # For debugging
    pscore.main_sync()
    pscore.de_init()
    print('Done at ' + str(datetime.datetime.now()))
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
