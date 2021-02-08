import sys
import json
import datetime
import traceback
import smtplib
from email.mime.text import MIMEText
import pscore


# Attempt a sync; send failure email with traceback if error.
# Name of configuration is file passed via command-line
try:
    print('Start sync at ' + str(datetime.datetime.now()))
    pscore.init_config(sys.argv[1])
    pscore.main_sync()
    print('Done at ' + str(datetime.datetime.now()))
except Exception as e:
    with open(sys.argv[1]) as config_file:
        smtp_config = json.load(config_file)['smtp']
    print('Exception at ' + str(datetime.datetime.now()) +
          '! Check notification email.')
    msg = MIMEText('Sync failed at ' + str(datetime.datetime.now()) + '\n\nError: '
                   + str(traceback.format_exc())
                   + '\nCurrent Record: ' + str(pscore.CURRENT_RECORD))
    msg['Subject'] = smtp_config['subject']
    msg['From'] = smtp_config['from']
    msg['To'] = smtp_config['to']

    with smtplib.SMTP(smtp_config['server']) as smtp:
        smtp.starttls()
        smtp.login(smtp_config['username'], smtp_config['password'])
        smtp.send_message(msg)
