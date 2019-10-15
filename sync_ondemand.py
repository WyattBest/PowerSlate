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


def main_sync():

    # Get applicants from Slate
    r = requests.get(pscore.sq_apps_url, auth = pscore.sq_apps_cred)
    r.raise_for_status()
    slate_dict = json.loads(r.text) # Convert JSON response text to Python dict
    rec_formatted_list = pscore.trans_slate_to_rec(slate_dict) # Transform the data to Recruiter format
    
    # Check each item in rec_formatted_list for status in PowerCampus.
    rec_new_list = []
    rec_existing_list = []

    for k, v in enumerate(rec_formatted_list):
        ra_status, apl_status, computed_status, PEOPLE_CODE_ID = pscore.scan_status(rec_formatted_list[k])

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
            slate_upload_dict.update({rec_new_list[k]['ApplicationNumber']: {'PEOPLE_CODE_ID': PEOPLE_CODE_ID,
                                                                             'credits': 0, 'registered': False,
                                                                             'readmit': None}})
    
    
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
            slate_upload_dict.update({pc_existing_apps_list[k]['ApplicationNumber']: {'PEOPLE_CODE_ID': None}})
        
        registered, credits, readmit = pscore.get_academic(pc_existing_apps_list[k]['PEOPLE_CODE_ID'],
                                                    pc_existing_apps_list[k]['ACADEMIC_YEAR'],
                                                    pc_existing_apps_list[k]['ACADEMIC_TERM'],
                                                    pc_existing_apps_list[k]['ACADEMIC_SESSION'],
                                                    pc_existing_apps_list[k]['PROGRAM'], pc_existing_apps_list[k]['DEGREE'],
                                                    pc_existing_apps_list[k]['CURRICULUM'],)
        # Update slate_upload_dict with registration information
        slate_upload_dict[pc_existing_apps_list[k]['ApplicationNumber']].update({'credits': credits,
                                                                                 'registered': registered,
                                                                                 'readmit': readmit})
    
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
                           actions[k]['actions'][kk]['create_datetime'], # Only the date portion is actually used.
                           actions[k]['ACADEMIC_YEAR'],
                           actions[k]['ACADEMIC_TERM'],
                           actions[k]['ACADEMIC_SESSION'])
            pscore.cnxn.commit()
            
    # Scan PowerCampus status for all apps and log to external db; capture PEOPLE_CODE_ID
    for k, v in enumerate(rec_formatted_list):
        ra_status, apl_status, computed_status, PEOPLE_CODE_ID = pscore.scan_status(rec_formatted_list[k])

        if PEOPLE_CODE_ID is not None and computed_status == 'Active':
            slate_upload_dict[rec_formatted_list[k]['ApplicationNumber']].update({'PEOPLE_CODE_ID': PEOPLE_CODE_ID})
    
    
    # Upload data back to Slate
    # First, slate_upload_dict needs transformation. It was originally designed for a tab-separated file, and updating
    # a dict piecemeal (as done above) is a lot easier that updating a list piecemeal. Room for improvement.
    slate_upload_list = []
    for k, v in slate_upload_dict.items():
            slate_upload_list.append({'aid': k, 'PEOPLE_CODE_ID': slate_upload_dict[k]['PEOPLE_CODE_ID'],
                                      'credits': str(slate_upload_dict[k]['credits']),
                                      'registered': slate_upload_dict[k]['registered'],
                                      'readmit': slate_upload_dict[k]['readmit']})
    

    # Slate requires JSON to be convertable to XML
    slate_upload_dict = {'row': slate_upload_list}
    
    r = requests.post(pscore.s_upload_url, json = slate_upload_dict, auth = pscore.s_upload_cred)
    r.raise_for_status()
    
    pscore.de_init()
        
    print('Done at ' + str(datetime.datetime.now()))

# Attempt a sync; send failure email with traceback if error.
try:
    print('Start sync at ' + str(datetime.datetime.now()))
    smtp_config = pscore.init_config(sys.argv[1]) # Name of configuration file passed via command-line
    # smtp_config = pscore.init_config('config_dev.json') # For debugging
    main_sync()
except Exception as e:
    # Send a failure email with traceback on exceptions
    print('Exception at ' + str(datetime.datetime.now()) + '! Check notification email.')
    msg = MIMEText('Sync failed at ' + str(datetime.datetime.now()) + '\n\nError: '
                    + str(traceback.format_exc()))
    msg['Subject'] = smtp_config['subject']
    msg['From'] = smtp_config['from']
    msg['To'] = smtp_config['to']
    
    with smtplib.SMTP(smtp_config['server']) as smtp:
        smtp.starttls()
        smtp.login(smtp_config['username'], smtp_config['password'])
        smtp.send_message(msg)