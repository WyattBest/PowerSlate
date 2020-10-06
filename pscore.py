import requests
import copy
import json
import xml.etree.ElementTree as ET
import pyodbc
import datetime


def init_config(config_path):
    """Reads config file to global 'config' dict. Many frequently-used variables are copied to their own globals for convenince.

    Returns SMTP config dict for crash handling."""
    global config
    global pc_api_url
    global pc_api_cred
    global http_session_sched_acts
    global rm_mapping
    global cnxn
    global cursor
    global app_status_log_table
    global today
    global finaid_config
    global error_strings

    # Read config file and convert to dict
    with open(config_path) as config_path:
        config = json.loads(config_path.read())
        print(config)  # Debug: print config object

    # We will use recruiterMapping.xml to translate Recruiter values to PowerCampus values for direct SQL operations.
    # The file path can be local or remote. Obviously, a remote file must have proper network share and permissions set up.
    # Remote is more convenient, as local requires you to manually copy the file whenever you change it with the
    # PowerCampus Mapping Tool. Note: The tool produces UTF-8 BOM encoded files, so I explicity specify utf-8-sig.

    # Parse XML mapping file into dict rm_mapping
    with open(config['mapping_file_location'], encoding='utf-8-sig') as treeFile:
        tree = ET.parse(treeFile)
        doc = tree.getroot()
    rm_mapping = {}

    for child in doc:
        if child.get('NumberOfPowerCampusFieldsMapped') == '1':
            rm_mapping[child.tag] = {}
            for row in child:
                rm_mapping[child.tag].update(
                    {row.get('RCCodeValue'): row.get('PCCodeValue')})

        if child.get('NumberOfPowerCampusFieldsMapped') == '2' or child.get('NumberOfPowerCampusFieldsMapped') == '3':
            fn1 = 'PC' + str(child.get('PCFirstField')) + 'CodeValue'
            fn2 = 'PC' + str(child.get('PCSecondField')) + 'CodeValue'
            rm_mapping[child.tag] = {fn1: {}, fn2: {}}

            for row in child:
                rm_mapping[child.tag][fn1].update(
                    {row.get('RCCodeValue'): row.get(fn1)})
                rm_mapping[child.tag][fn2].update(
                    {row.get('RCCodeValue'): row.get(fn2)})

    # PowerCampus Web API connection
    pc_api_url = config['pc_api']['url']
    pc_api_cred = (config['pc_api']['username'], config['pc_api']['password'])

    # Set up an HTTP session to be used for updating scheduled actions. It's initialized here because it will be used
    # inside a loop. Other web service calls will use the top-level requests functions (i.e. their own, automatic sessions).
    if config['scheduled_actions']['enabled'] == True:
        http_session_sched_acts = requests.Session()
        http_session_sched_acts.auth = (
            config['scheduled_actions']['slate_get']['username'], config['scheduled_actions']['slate_get']['password'])

    # Microsoft SQL Server connection.
    cnxn = pyodbc.connect(config['pc_database_string'])
    cursor = cnxn.cursor()
    app_status_log_table = config['app_status_log_table']

    today = datetime.datetime.date(datetime.datetime.now())

    # Config dicts
    smtp_config = config['smtp']
    finaid_config = config['finaid']
    error_strings = config['error_strings']

    # Print a test of connections
    r = requests.get(pc_api_url + 'api/version', auth=pc_api_cred)
    print('PowerCampus API Status: ' + str(r.status_code))
    print(r.text)
    r.raise_for_status()
    print(cnxn.getinfo(pyodbc.SQL_DATABASE_NAME))

    return smtp_config


def de_init():
    # Clean up connections.
    cnxn.close()  # SQL

    if config['scheduled_actions']['enabled'] == True:
        http_session_sched_acts.close()  # HTTP session to Slate for scheduled actions


def blank_to_null(x):
    # Converts empty string to None. Accepts dicts, lists, and tuples.
    # This function derived from radtek @ http://stackoverflow.com/a/37079737/4109658
    # CC Attribution-ShareAlike 3.0 https://creativecommons.org/licenses/by-sa/3.0/
    ret = copy.deepcopy(x)
    # Handle dictionaries, lists, and tuples. Scrub all values
    if isinstance(x, dict):
        for k, v in ret.items():
            ret[k] = blank_to_null(v)
    if isinstance(x, (list, tuple)):
        for k, v in enumerate(ret):
            ret[k] = blank_to_null(v)
    # Handle None
    if x == '':
        ret = None
    # Finished scrubbing
    return ret


def trans_slate_to_rec(x):
    # Converts a dict decoded from the Slate JSON response to a list of dicts,
    # each of which is ready to be re-encoded as JSON for the PowerCampus WebAPI (Recruiter API).

    # Slate exports blanks where PowerCampus expects nulls.
    x2 = blank_to_null(x)
    # Since the initial Slate response is a dict with a single key, isolate the single value, which is a list.
    x2 = x2['row']

    for k, v in enumerate(x2):

        if 'Suffix' not in x2[k]:
            x2[k]['Suffix'] = None

        # International Addresses can be pretty crazy
        if 'AddressStateProvince' not in x2[k]:
            x2[k]['AddressStateProvince'] = None
        if 'AddressPostalCode' not in x2[k]:
            x2[k]['AddressPostalCode'] = None
        if 'AddressCity' not in x2[k]:
            x2[k]['AddressCity'] = None

        # This unused key provides an opportunity to create the structure.
        x2[k]['Addresses'] = [{'Line4': None}]
        x2[k]['Addresses'][0]['Type'] = 0
        x2[k]['Addresses'][0]['Line1'] = x2[k].pop('AddressLine1')
        x2[k]['Addresses'][0]['Line2'] = x2[k].pop('AddressLine2', None)
        x2[k]['Addresses'][0]['Line3'] = x2[k].pop('AddressLine3', None)
        x2[k]['Addresses'][0]['City'] = x2[k].pop('AddressCity')
        x2[k]['Addresses'][0]['StateProvince'] = x2[k].pop(
            'AddressStateProvince')
        x2[k]['Addresses'][0]['PostalCode'] = x2[k].pop('AddressPostalCode')
        x2[k]['Addresses'][0]['County'] = x2[k].pop('AddressCounty', None)
        x2[k]['Addresses'][0]['Country'] = x2[k].pop('AddressCountry')

        # Note that PhoneNumbers is a dict key whose value is a list of dicts containing the actual data.
        # Slate stores phones as formatted strings (!), which is why string.digits is used.
        # Surely there's a better way to write this!
        if 'Phone0' in x2[k] or 'Phone1' in x2[k] or 'Phone2' in x2[k]:
            x2[k].update({'PhoneNumbers': []})
        # PowerCampus WebAPI requires Type -1 instead of a blank or null when not submitting any phones.
        else:
            x2[k]['PhoneNumbers'] = [
                {'Type': -1, 'Country': None, 'Number': None}]

        if 'Phone0' in x2[k]:
            x2[k]['PhoneNumbers'].append(
                {'Type': 0, 'Country': None, 'Number': str_digits(x2[k].pop('Phone0'))})
        if 'Phone1' in x2[k]:
            x2[k]['PhoneNumbers'].append(
                {'Type': 1, 'Country': None, 'Number': str_digits(x2[k].pop('Phone1'))})
        if 'Phone2' in x2[k]:
            x2[k]['PhoneNumbers'].append(
                {'Type': 2, 'Country': None, 'Number': str_digits(x2[k].pop('Phone2'))})
        # If US number, remove leading 1. Otherwise, add Country from Address, or else PowerCampus will complain.
        for kk, vv in enumerate(x2[k]['PhoneNumbers']):
            if x2[k]['PhoneNumbers'][kk]['Number'][:1] == '1':
                x2[k]['PhoneNumbers'][kk]['Number'] = x2[k]['PhoneNumbers'][kk]['Number'][1:]
            else:
                x2[k]['PhoneNumbers'][kk]['Country'] = x2[k]['Addresses'][0]['Country']

        if 'Visa' not in x2[k]:
            x2[k]['Visa'] = None

        if 'SecondaryCitizenship' not in x2[k]:
            x2[k]['SecondaryCitizenship'] = None

        # Temporarily null these. Should work in PowerCampus Web API version 8.8.0 and above.
        #x2[k]['PrimaryCitizenship'] = None
        #x2[k]['SecondaryCitizenship'] = None

        # This seems to only deal with Hispanic
        x2[k]['Ethnicity'] = int(x2[k]['Ethnicity'])

        # Convert string literals into boolean types.
        # TODO: Find a less expensive solution.
        x3 = copy.deepcopy(x2[k])
        for kk, vv in x3.items():
            if kk in ('RaceAmericanIndian', 'RaceAsian', 'RaceAfricanAmerican',
                      'RaceNativeHawaiian', 'RaceWhite') and vv == 'true':
                x2[k][kk] = True
            elif kk in ('RaceAmericanIndian', 'RaceAsian', 'RaceAfricanAmerican',
                        'RaceNativeHawaiian', 'RaceWhite') and vv == 'false':
                x2[k][kk] = False
        del(x3, kk, vv)

        # Slate's translation keys don't seem able to change data type.
        x2[k]['Gender'] = int(x2[k]['Gender'])

        if 'MaritalStatus' not in x2[k]:
            x2[k]['MaritalStatus'] = None

        if 'Veteran' not in x2[k]:
            x2[k]['Veteran'] = 0
            x2[k]['VeteranStatus'] = False
        else:
            x2[k]['Veteran'] = int(x2[k]['Veteran'])
            x2[k]['VeteranStatus'] = True

        # PowerCampus Web API expects empty arrays, not nulls
        # PDC is converted from three top-level keys to a nested dict
        x2[k]['Relationships'] = []
        x2[k]['Activities'] = []
        x2[k]['EmergencyContacts'] = []
        x2[k]['Programs'] = [{'Program': x2[k].pop(
            'Program'), 'Degree': x2[k].pop('Degree'), 'Curriculum': None}]
        x2[k]['Education'] = []

        if 'ProposedDecision' not in x2[k]:
            x2[k]['ProposedDecision'] = None

        # GUID's
        x2[k]['ApplicationNumber'] = x2[k].pop('aid')
        x2[k]['ProspectId'] = x2[k].pop('pid')

        # These are currently not collected in Slate.
        x2[k]['IsInterestedInCampusHousing'] = False
        x2[k]['IsInterestedInFinancialAid'] = False
    return x2


def post_to_pc(x):
    """Post an application to PowerCampus.
    Return  PEOPLE_CODE_ID if application was automatically accepted or None for all other conditions.

    Keyword arguments:
    x -- an application dict
    """

    r = requests.post(pc_api_url + 'api/applications',
                      json=x, auth=pc_api_cred)
    r.raise_for_status()

    # Catch 202 errors, like ApplicationSettings.config not configured.
    # Not sure if this is the most Pythonic way.
    if r.status_code == 202:
        raise ValueError(r.text)

    if (r.text[-25:-12] == 'New People Id'):
        try:
            people_code = r.text[-11:-2]
            # Error check. After slice because leading zeros need preserved.
            int(people_code)
            PEOPLE_CODE_ID = 'P' + people_code
            return PEOPLE_CODE_ID
        except:
            return None
    else:
        return None


def str_digits(s):
    # Returns only digits from a string.
    from string import ascii_letters, punctuation, whitespace
    non_digits = str.maketrans(
        {c: None for c in ascii_letters + punctuation + whitespace})
    return s.translate(non_digits)


def scan_status(x):
    # Scan the PowerCampus status of a single applicant and return it in three parts plus three ID numbers.
    # Expects a dict that has already been transformed with trans_slate_to_rec()

    r = requests.get(pc_api_url + 'api/applications?applicationNumber=' +
                     x['ApplicationNumber'], auth=pc_api_cred)
    r.raise_for_status()
    r_dict = json.loads(r.text)

    # If application exists in PowerCampus, execute SP to look for existing PCID.
    # Log PCID and status.
    if 'applicationNumber' in r_dict:
        cursor.execute('EXEC [custom].[PS_selRAStatus] \'' +
                       x['ApplicationNumber'] + '\'')
        row = cursor.fetchone()
        if row.PEOPLE_CODE_ID is not None:
            PEOPLE_CODE_ID = row.PEOPLE_CODE_ID
            # people_code = row.PEOPLE_CODE_ID[1:]
            # PersonId = row.PersonId # Delete
        else:
            PEOPLE_CODE_ID = None
            people_code = None

        # Determine status.
        if row.ra_status in (0, 3, 4) and row.apl_status == 2 and PEOPLE_CODE_ID is not None:
            computed_status = 'Active'
        elif row.ra_status in (0, 3, 4) and row.apl_status == 3 and PEOPLE_CODE_ID is None:
            computed_status = 'Declined'
        elif row.ra_status in (0, 3, 4) and row.apl_status == 1 and PEOPLE_CODE_ID is None:
            computed_status = 'Pending'
        elif row.ra_status == 1 and row.apl_status is None and PEOPLE_CODE_ID is None:
            computed_status = 'Required field missing.'
        elif row.ra_status == 2 and row.apl_status is None and PEOPLE_CODE_ID is None:
            computed_status = 'Required field mapping is missing.'
        # elif row is not None:
            #ra_status = row.ra_status
        else:
            computed_status = 'Unrecognized Status: ' + str(row.ra_status)

        # Write errors to external database for end-user presentation via SSRS.
        # Append _dev to table name for # Dev v Production
        cursor.execute('INSERT INTO' + app_status_log_table + """
            ([Ref],[ApplicationNumber],[ProspectId],[FirstName],[LastName],
            [ComputedStatus],[Notes],[RecruiterApplicationStatus],[ApplicationStatus],[PEOPLE_CODE_ID])
        VALUES 
            (?,?,?,?,?,?,?,?,?,?)""",
                       [x['Ref'], x['ApplicationNumber'], x['ProspectId'], x['FirstName'], x['LastName'], computed_status, row.ra_errormessage, row.ra_status, row.apl_status, PEOPLE_CODE_ID])
        cnxn.commit()

        return row.ra_status, row.apl_status, computed_status, PEOPLE_CODE_ID
    else:
        return None, None, None, None


def trans_rec_to_pc(x):
    """Return applications list remapped to PowerCampus format according to recruiterMapping.xml"""
    pl = copy.deepcopy(x)

    # Transform and remap the input list, saving results to local list pl
    # Use all-caps key names to help keep track of what has been mapped
    for k, v in enumerate(x):
        # YTS
        pl[k]['ACADEMIC_YEAR'] = rm_mapping['AcademicTerm']['PCYearCodeValue'][x[k]['YearTerm']]
        pl[k]['ACADEMIC_TERM'] = rm_mapping['AcademicTerm']['PCTermCodeValue'][x[k]['YearTerm']]
        pl[k]['ACADEMIC_SESSION'] = '01'
        del pl[k]['YearTerm']

        # PDC
        pl[k]['PROGRAM'] = rm_mapping['AcademicLevel'][x[k]['Programs'][0]['Program']]
        pl[k]['DEGREE'] = rm_mapping['AcademicProgram']['PCDegreeCodeValue'][x[k]
                                                                             ['Programs'][0]['Degree']]
        pl[k]['CURRICULUM'] = rm_mapping['AcademicProgram']['PCCurriculumCodeValue'][x[k]
                                                                                     ['Programs'][0]['Degree']]
        del pl[k]['Programs']

        # Country, State
        for kk, vv in enumerate(pl[k]['Addresses']):
            pl[k]['Addresses'][kk]['COUNTRY'] = rm_mapping['Country'][pl[k]
                                                                      ['Addresses'][kk]['Country']]
            del pl[k]['Addresses'][kk]['Country']

            if pl[k]['Addresses'][kk]['COUNTRY'] != 'US':
                pl[k]['Addresses'][kk]['STATEPROVINCE'] = pl[k]['Addresses'][kk]['StateProvince']
            else:
                pl[k]['Addresses'][kk]['STATEPROVINCE'] = rm_mapping['State'][pl[k]
                                                                              ['Addresses'][kk]['StateProvince']]
            del pl[k]['Addresses'][kk]['StateProvince']

        # Visa
        if pl[k]['Visa'] is not None:
            pl[k]['VISA'] = rm_mapping['Visa'][x[k]['Visa']]
        else:
            pl[k]['VISA'] = None
        del pl[k]['Visa']

        # Gender is hardcoded into the API. [WebServices].[spSetDemographics] has different hardcoded values.
        if pl[k]['Gender'] is None:
            pl[k]['GENDER'] = 3
        elif pl[k]['Gender'] == 0:
            pl[k]['GENDER'] = 1
        elif pl[k]['Gender'] == 1:
            pl[k]['GENDER'] = 2
        elif pl[k]['Gender'] == 2:
            pl[k]['GENDER'] = 3
        del pl[k]['Gender']

        # VeteranStatus of False indicates null Veteran status
        if pl[k]['VeteranStatus'] == True:
            pl[k]['VETERAN'] = rm_mapping['Veteran'][str(x[k]['Veteran'])]
            # if pl[k]['Veteran'] == 0:
            #pl[k]['VETERAN'] = 'NO'
            # elif pl[k]['Veteran'] == 1:
            #pl[k]['VETERAN'] = 'YES'
        else:
            pl[k]['VETERAN'] = None
        del pl[k]['Veteran'], pl[k]['VeteranStatus']

        # PrimaryCitizenship, SecondaryCitizenship
        # This is called CitizenshipStatus in the API and PowerCampus GUI.
        # CitizenshipStatus is broken in the Web API below version 8.8.0
        pl[k]['PRIMARYCITIZENSHIP'] = rm_mapping['CitizenshipStatus'][x[k]
                                                                      ['CitizenshipStatus']]
        del pl[k]['PrimaryCitizenship']
        del pl[k]['CitizenshipStatus']
        if pl[k]['SecondaryCitizenship'] is not None:
            pl[k]['SECONDARYCITIZENSHIP'] = rm_mapping['CitizenshipStatus'][x[k]
                                                                            ['SecondaryCitizenship']]
        else:
            pl[k]['SECONDARYCITIZENSHIP'] = None
        del pl[k]['SecondaryCitizenship']

        # Marital Status
        if pl[k]['MaritalStatus'] is not None:
            pl[k]['MARITALSTATUS'] = rm_mapping['MaritalStatus'][x[k]['MaritalStatus']]
        else:
            pl[k]['MARITALSTATUS'] = None
        del pl[k]['MaritalStatus']

    return pl


def get_actions(apps_list):
    """Fetch 'Scheduled Actions' (Slate Checklist) for a list of applications.

    Keyword arguments:
    apps_list -- list of ApplicationNumbers to fetch actions for

    Returns:
    app_dict -- list of applications as a dict with nested dicts of actions. Example:
        {'ApplicationNumber': {'ACADEMIC_SESSION': '01',
            'ACADEMIC_TERM': 'SUMMER',
            'ACADEMIC_YEAR': '2019',
            'PEOPLE_CODE_ID': 'P000164949',
            'actions': [{'action_id': 'ADRFLTR',
                'aid': 'ApplicationNumber',
                'completed': 'Y',
                'create_datetime': '2019-01-15T14:17:20',
                'item': 'Gregory Smith, Prinicpal'}]}}

    Uses its own HTTP session to reduce overhead and queries Slate with batches of 48 comma-separated ID's.
    48 was chosen to avoid exceeding max GET request.
    """

    pl = copy.deepcopy(apps_list)
    actions_list = []  # Main list of actions that will be appended to
    # Dict of applications with nested actions that will be returned.
    app_dict = {}

    while pl:
        counter = 0
        ql = []  # Queue list
        qs = ''  # Queue string
        al = []  # Temporary actions list

        # Pop up to 48 ApplicationNumbers and append to queue list.
        while pl and counter < 48:
            ql.append(pl.pop()['ApplicationNumber'])
            counter += 1

        # # Stuff them into a comma-separated string.
        qs = ",".join(str(item) for item in ql)

        r = http_session_sched_acts.get(
            config['scheduled_actions']['slate_get']['url'], params={'aids': qs})
        r.raise_for_status()
        al = json.loads(r.text)
        actions_list.extend(al['row'])
        # if len(al['row']) > 1: # Delete. I don't think an application could ever have zero actions.

    # Rebuild the list of applications with the actions nested
    for k, v in enumerate(apps_list):
        app_dict.update({apps_list[k]['ApplicationNumber']: {'PEOPLE_CODE_ID': apps_list[k]['PEOPLE_CODE_ID'],
                                                             'ACADEMIC_YEAR': apps_list[k]['ACADEMIC_YEAR'],
                                                             'ACADEMIC_TERM': apps_list[k]['ACADEMIC_TERM'],
                                                             'ACADEMIC_SESSION': apps_list[k]['ACADEMIC_SESSION'],
                                                             'actions': []}})

    for k, v in enumerate(actions_list):
        app_dict[actions_list[k]['aid']]['actions'].append(actions_list[k])

    return app_dict


def get_pc_profile(PEOPLE_CODE_ID, year, term, session, program, degree, curriculum):
    '''Fetch ACADEMIC row data and email address from PowerCampus.

     Returns:
     found -- True/False (entire row)
     registered -- True/False
     reg_date -- Date
     readmit -- True/False
     withdrawn -- True/False
     credits -- string
     campus_email -- string (None of not registered)
    '''

    found = False
    registered = False
    reg_date = None
    readmit = False
    withdrawn = False
    credits = 0
    campus_email = None

    cursor.execute('EXEC [custom].[PS_selProfile] ?,?,?,?,?,?,?',
                   PEOPLE_CODE_ID, year, term, session, program, degree, curriculum)
    row = cursor.fetchone()

    if row is not None:
        found = True

        if row.Registered == 'Y':
            registered = True
            reg_date = str(row.REG_VAL_DATE)
            credits = str(row.CREDITS)
            campus_email = row.CampusEmail

        if row.COLLEGE_ATTEND == 'READ':
            readmit = True

        if row.Withdrawn == 'Y':
            withdrawn = True

    return found, registered, reg_date, readmit, withdrawn, credits, campus_email


def pc_update_demographics(app):
    cursor.execute('execute [custom].[PS_updDemographics] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?',
                   app['PEOPLE_CODE_ID'],
                   'SLATE',
                   app['GENDER'],
                   app['Ethnicity'],
                   app['MARITALSTATUS'],
                   app['VETERAN'],
                   app['PRIMARYCITIZENSHIP'],
                   app['SECONDARYCITIZENSHIP'],
                   app['VISA'],
                   app['RaceAfricanAmerican'],
                   app['RaceAmericanIndian'],
                   app['RaceAsian'],
                   app['RaceNativeHawaiian'],
                   app['RaceWhite'])
    cnxn.commit()


def pc_update_statusdecision(app):
    cursor.execute('exec [custom].[PS_updAcademicAppInfo] ?, ?, ?, ?, ?, ?, ?, ?, ?',
                   app['PEOPLE_CODE_ID'],
                   app['ACADEMIC_YEAR'],
                   app['ACADEMIC_TERM'],
                   app['ACADEMIC_SESSION'],
                   app['PROGRAM'],
                   app['DEGREE'],
                   app['CURRICULUM'],
                   app['ProposedDecision'],
                   app['CreateDateTime'])
    cnxn.commit()


def pc_update_smsoptin(app):
    if 'SMSOptIn' in app:
        cursor.execute('exec [custom].[PS_updSMSOptIn] ?, ?, ?',
                       app['PEOPLE_CODE_ID'], 'SLATE', app['SMSOptIn'])
        cnxn.commit()


def pf_get_fachecklist(pcid, year, term, session):
    """Return the PowerFAIDS missing docs list for uploading to Financial Aid Checklist."""
    cursor.execute(
        'exec [custom].[PS_selPFChecklist] ?, ?, ?, ?', pcid, year, term, session)
    rows = cursor.fetchall()

    return rows


def main_sync(pid=None):
    """Main body of the program.

    Keyword arguments:
    pid -- specific application GUID to sync (default None)
    """

    # Get applicants from Slate
    creds = (config['slate_query_apps']['username'],
             config['slate_query_apps']['password'])
    if pid is not None:
        r = requests.get(config['slate_query_apps']['url'],
                         auth=creds, params={'pid': pid})
    else:
        r = requests.get(config['slate_query_apps']['url'], auth=creds)
    r.raise_for_status()
    slate_dict = json.loads(r.text)
    # Transform the data to Recruiter format
    rec_formatted_list = trans_slate_to_rec(slate_dict)

    if not rec_formatted_list:
        raise EOFError(error_strings['no_apps'])

    # Check each item in rec_formatted_list for status in PowerCampus.
    rec_new_list = []
    rec_existing_list = []

    for k, v in enumerate(rec_formatted_list):
        ra_status, apl_status, computed_status, PEOPLE_CODE_ID = scan_status(
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
        PEOPLE_CODE_ID = post_to_pc(rec_new_list[k])

        # Add PEOPLE_CODE_ID to a dict to eventually send back to Slate
        if PEOPLE_CODE_ID is not None:
            slate_upload_dict.update({
                rec_new_list[k]['ApplicationNumber']: {
                    'PEOPLE_CODE_ID': PEOPLE_CODE_ID
                }
            })

    # Update existing PowerCampus applications and get registration information
    # First transform the dict to PowerCampus native format (like Campus6 instead of like Recruiter).
    pc_existing_apps_list = trans_rec_to_pc(rec_existing_list)

    for k, v in enumerate(pc_existing_apps_list):
        # Update Demographics
        pc_update_demographics(pc_existing_apps_list[k])

        # Update SMS Opt-In
        pc_update_smsoptin(pc_existing_apps_list[k])

        # Update Status/Decision
        pc_update_statusdecision(pc_existing_apps_list[k])

        # Get registration information to send back to Slate. (Newly-posted apps won't be registered yet.)
        # First add keys to slate_upload_dict
        if pc_existing_apps_list[k]['ApplicationNumber'] not in slate_upload_dict:
            slate_upload_dict.update(
                {pc_existing_apps_list[k]['ApplicationNumber']: {'PEOPLE_CODE_ID': None}})

        found, registered, reg_date, readmit, withdrawn, credits, campus_email = get_pc_profile(
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
                                                                                 'reg_date': reg_date,
                                                                                 'readmit': readmit,
                                                                                 'withdrawn': withdrawn,
                                                                                 'credits': credits,
                                                                                 'campus_email': campus_email})

    # Update Scheduled Actions for existing PowerCampus applications
    if config['scheduled_actions']['enabled'] == True:
        actions = get_actions(pc_existing_apps_list)

        for k, v in actions.items():
            for kk, vv in enumerate(actions[k]['actions']):
                cursor.execute('EXEC [custom].[PS_updAction] ?, ?, ?, ?, ?, ?, ?, ?, ?',
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
                cnxn.commit()

    # Get Financial Aid checklist for upload to Slate
    if config['fa_checklist']['enabled']:
        fa_upload = [pf_get_fachecklist(k['aid'],
                                        k['PEOPLE_CODE_ID'],
                                        k['ACADEMIC_YEAR'],
                                        k['ACADEMIC_TERM'],
                                        k['ACADEMIC_SESSION']) for k in pc_existing_apps_list]

        for k in fa_upload:
            fa_upload[k]['AppID'] = slate_dict[k['aid']]['AppID']

    # Scan PowerCampus status for all apps and log to external db; capture PEOPLE_CODE_ID
    for k, v in enumerate(rec_formatted_list):
        ra_status, apl_status, computed_status, PEOPLE_CODE_ID = scan_status(
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

    creds = (config['slate_upload']['username'],
             config['slate_upload']['password'])
    r = requests.post(config['slate_upload']['url'],
                      json=slate_upload_dict, auth=creds)
    r.raise_for_status()

    return 'Done. Please check the PowerSlate Sync Report for more details.'
