import sys
import json
import datetime
import traceback
import smtplib
from email.mime.text import MIMEText
from urllib.parse import urlparse
import ps_core



# Attempt a sync; send failure email with traceback if error.
# Name of configuration is file passed via command-line
try:
    print('Start sync at ' + str(datetime.datetime.now()))
    ps_core.init(sys.argv[1])
    ps_core.main_sync()
    print('Done at ' + str(datetime.datetime.now()))
except Exception as e:
    # There's got to be a better way to handle this.
    try:
        current_record = ps_core.CURRENT_RECORD
    except AttributeError:
        current_record = None

    with open(sys.argv[1]) as config_file:
        config = json.load(config_file)
        smtp_config = config['smtp']
        if current_record:
            slate_domain = urlparse(config['slate_query_apps']['url']).netloc
            current_record_link = 'https://' + slate_domain + '/manage/lookup/record?id=' + str(current_record)
        else:
            current_record_link = 'None'
    print('Exception at ' + str(datetime.datetime.now()) +
          '! Check notification email.')
    msg = MIMEText('Sync failed at ' + str(datetime.datetime.now()) + '\n\nError: '
                   + str(traceback.format_exc())
                   + '\nCurrent Record: ' + current_record_link)
    msg['Subject'] = smtp_config['subject']
    msg['From'] = smtp_config['from']
    msg['To'] = smtp_config['to']

    with smtplib.SMTP(smtp_config['server']) as smtp:
        smtp.starttls()
        smtp.login(smtp_config['username'], smtp_config['password'])
        smtp.send_message(msg)
