import requests
import copy
import json
import xml.etree.ElementTree as ET
import pyodbc
import datetime


def init_config(x):
    """Opens input filename and inits config variables from it. Returns SMTP config for crash handling."""

    global pc_api_url
    global pc_api_cred
    global sq_apps_url
    global sq_apps_cred
    global sq_actions_url
    global sq_actions_session
    global s_upload_url
    global s_upload_cred
    global rm_mapping
    global cnxn
    global cursor
    global app_status_log_table
    global today

    # Read config file and convert to dict
    with open(x) as config_file:
        config = json.loads(config_file.read())
        # print(json.dumps(config, indent = 4, sort_keys = True)) # Debug: print config object

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

    # The following sections are not strictly necessary. We could just make the config dict a global object
    # and access it directly, but cuts down on repetitive code.
    # I make exception for smtp_config dict - it's rarely used and would require a lot of globals to replace.

    # PowerCampus Web API connection
    pc_api_url = config['pc_api']['url']
    pc_api_cred = (config['pc_api']['username'], config['pc_api']['password'])

    # Slate web service connections
    # At the time of this writing, Slate limits web services to 300 seconds processing time per database
    # in a 5-minute rolling window. Large sync jobs may require sleep timers. (2017-10-10)
    sq_apps_url = config['slate_query_apps']['url']
    sq_apps_cred = (config['slate_query_apps']['username'],
                    config['slate_query_apps']['password'])
    sq_actions_url = config['slate_query_actions']['url']
    s_upload_url = config['slate_upload']['url']
    s_upload_cred = (config['slate_upload']['username'],
                     config['slate_upload']['password'])

    # Set up an HTTP session to be used for updating scheduled actions. It's initialized here because it will be used
    # inside a loop. Other web service calls will use the top-level requests functions (i.e. their own, automatic sessions).
    sq_actions_session = requests.Session()
    sq_actions_session.auth = (
        config['slate_query_actions']['username'], config['slate_query_actions']['password'])

    # Email crash handler notification settings
    smtp_config = config['smtp']

    # Microsoft SQL Server connection. Requires ODBC connection provisioned on the local machine.
    cnxn = pyodbc.connect(config['pc_database_string'])
    cursor = cnxn.cursor()
    app_status_log_table = config['app_status_log_table']

    today = datetime.datetime.date(datetime.datetime.now())

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
    sq_actions_session.close()  # HTTP session to Slate for scheduled actions


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
            # print('You\'ve got phones!')      # Debug
            # print(len(x2[k]['PhoneNumbers'])) # Debug
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

        r = sq_actions_session.post(sq_actions_url, params={'aids': qs})
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
