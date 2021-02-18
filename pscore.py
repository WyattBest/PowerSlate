import requests
import copy
import json
import xml.etree.ElementTree as ET
import pyodbc
from string import ascii_letters, punctuation, whitespace


def init_config(config_path):
    """Reads config file to global 'config' dict. Many frequently-used variables are copied to their own globals for convenince."""
    global CONFIG
    global PC_API_URL
    global PC_API_CRED
    global RM_MAPPING
    global CNXN
    global CURSOR
    global MSG_STRINGS

    # Read config file and convert to dict
    with open(config_path) as config_path:
        CONFIG = json.loads(config_path.read())

    # We will use recruiterMapping.xml to translate Recruiter values to PowerCampus values for direct SQL operations.
    # The file path can be local or remote. Obviously, a remote file must have proper network share and permissions set up.
    # Remote is more convenient, as local requires you to manually copy the file whenever you change it with the
    # PowerCampus Mapping Tool. Note: The tool produces UTF-8 BOM encoded files, so I explicity specify utf-8-sig.

    # Parse XML mapping file into dict rm_mapping
    with open(CONFIG['mapping_file_location'], encoding='utf-8-sig') as treeFile:
        tree = ET.parse(treeFile)
        doc = tree.getroot()
    RM_MAPPING = {}

    for child in doc:
        if child.get('NumberOfPowerCampusFieldsMapped') == '1':
            RM_MAPPING[child.tag] = {}
            for row in child:
                RM_MAPPING[child.tag].update(
                    {row.get('RCCodeValue'): row.get('PCCodeValue')})

        if child.get('NumberOfPowerCampusFieldsMapped') == '2':
            fn1 = 'PC' + str(child.get('PCFirstField')) + 'CodeValue'
            fn2 = 'PC' + str(child.get('PCSecondField')) + 'CodeValue'
            RM_MAPPING[child.tag] = {fn1: {}, fn2: {}}

            for row in child:
                RM_MAPPING[child.tag][fn1].update(
                    {row.get('RCCodeValue'): row.get(fn1)})
                RM_MAPPING[child.tag][fn2].update(
                    {row.get('RCCodeValue'): row.get(fn2)})

        if child.get('NumberOfPowerCampusFieldsMapped') == '3':
            fn1 = 'PC' + str(child.get('PCFirstField')) + 'CodeValue'
            fn2 = 'PC' + str(child.get('PCSecondField')) + 'CodeValue'
            fn3 = 'PC' + str(child.get('PCThirdField')) + 'CodeValue'
            RM_MAPPING[child.tag] = {fn1: {}, fn2: {}, fn3: {}}

            for row in child:
                RM_MAPPING[child.tag][fn1].update(
                    {row.get('RCCodeValue'): row.get(fn1)})
                RM_MAPPING[child.tag][fn2].update(
                    {row.get('RCCodeValue'): row.get(fn2)})
                RM_MAPPING[child.tag][fn3].update(
                    {row.get('RCCodeValue'): row.get(fn3)})

    # PowerCampus Web API connection
    PC_API_URL = CONFIG['pc_api']['url']
    PC_API_CRED = (CONFIG['pc_api']['username'], CONFIG['pc_api']['password'])

    # Microsoft SQL Server connection.
    CNXN = pyodbc.connect(CONFIG['pc_database_string'])
    CURSOR = CNXN.cursor()

    # Misc configs
    MSG_STRINGS = CONFIG['msg_strings']

    # Print a test of connections
    r = requests.get(PC_API_URL + 'api/version', auth=PC_API_CRED)
    verbose_print('PowerCampus API Status: ' + str(r.status_code))
    verbose_print(r.text)
    r.raise_for_status()
    verbose_print('Database:' + CNXN.getinfo(pyodbc.SQL_DATABASE_NAME))


def de_init():
    # Clean up connections.
    CNXN.close()  # SQL


def verbose_print(x):
    """Attempt to print JSON without altering it, serializable objects as JSON, and anything else as default."""
    if CONFIG['console_verbose'] and len(x) > 0:
        if isinstance(x, str):
            print(x)
        else:
            try:
                print(json.dumps(x, indent=4))
            except:
                print(x)


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


def format_phone_number(number):
    """Strips anything but digits from a phone number and removes US country code."""
    non_digits = str.maketrans(
        {c: None for c in ascii_letters + punctuation + whitespace})
    number = number.translate(non_digits)

    if len(number) == 11 and number[:1] == '1':
        number = number[1:]

    return number


def strtobool(s):
    if s is not None and s.lower() in ['true', '1', 'y', 'yes']:
        return True
    elif s is not None and s.lower() in ['false', '0', 'n', 'no']:
        return False
    else:
        return None


def format_app_generic(app):
    """Supply missing fields and correct datatypes. Returns a flat dict."""

    mapped = blank_to_null(app)

    fields_null = ['Prefix', 'MiddleName', 'LastNamePrefix', 'Suffix', 'Nickname', 'GovernmentId', 'LegalName',
                   'Visa', 'CitizenshipStatus', 'PrimaryCitizenship', 'SecondaryCitizenship', 'MaritalStatus',
                   'ProposedDecision', 'AppStatus', 'AppDecision', 'Religion', 'FormerLastName', 'FormerFirstName',
                   'PrimaryLanguage', 'CountryOfBirth', 'Disabilities', 'CollegeAttendStatus', 'Commitment',
                   'Status', 'Veteran', 'Department', 'Nontraditional', 'Population', 'Extracurricular']
    fields_bool = ['RaceAmericanIndian', 'RaceAsian', 'RaceAfricanAmerican', 'RaceNativeHawaiian',
                   'RaceWhite', 'IsInterestedInCampusHousing', 'IsInterestedInFinancialAid',
                   'Extracurricular']
    fields_int = ['Ethnicity', 'Gender', 'SMSOptIn']
    fields_null.extend(
        ['compare_' + field for field in CONFIG['slate_upload_active']['fields_string']])
    fields_null.extend(
        ['compare_' + field for field in CONFIG['slate_upload_active']['fields_bool']])
    fields_null.extend(
        ['compare_' + field for field in CONFIG['slate_upload_active']['fields_int']])
    fields_bool.extend(
        ['compare_' + field for field in CONFIG['slate_upload_active']['fields_bool']])
    fields_int.extend(
        ['compare_' + field for field in CONFIG['slate_upload_active']['fields_int']])

    # Copy nullable strings from input to output, then fill in nulls
    mapped.update({k: v for (k, v) in app.items() if k in fields_null})
    mapped.update({k: None for k in fields_null if k not in app})

    # Convert integers and booleans
    mapped.update({k: int(v) for (k, v) in app.items() if k in fields_int})
    mapped.update({k: strtobool(v)
                   for (k, v) in app.items() if k in fields_bool})

    # Probably a stub in the API
    if 'GovernmentDateOfEntry' not in app:
        mapped['GovernmentDateOfEntry'] = '0001-01-01T00:00:00'
    else:
        mapped['GovernmentDateOfEntry'] = app['GovernmentDateOfEntry']

    # Pass through all other fields
    mapped.update({k: v for (k, v) in app.items() if k not in mapped})

    return mapped


def format_app_api(app):
    """Remap application to Recruiter/Web API format.

    Keyword arguments:
    app -- an application dict
    """

    mapped = {}

    # Pass through fields
    fields_verbatim = ['FirstName',  'LastName', 'Email', 'Campus', 'BirthDate', 'CreateDateTime',
                       'Prefix', 'MiddleName', 'LastNamePrefix', 'Suffix', 'Nickname', 'GovernmentId', 'LegalName',
                       'Visa', 'CitizenshipStatus', 'PrimaryCitizenship', 'SecondaryCitizenship', 'MaritalStatus',
                       'ProposedDecision', 'Religion', 'FormerLastName', 'FormerFirstName', 'PrimaryLanguage',
                       'CountryOfBirth', 'Disabilities', 'CollegeAttendStatus', 'Commitment', 'Status',
                       'RaceAmericanIndian', 'RaceAsian', 'RaceAfricanAmerican', 'RaceNativeHawaiian',
                       'RaceWhite', 'IsInterestedInCampusHousing', 'IsInterestedInFinancialAid'
                       'Ethnicity', 'Gender', 'YearTerm']
    mapped.update({k: v for (k, v) in app.items() if k in fields_verbatim})

    # Supply empty arrays. Implementing these would require more logic.
    fields_arr = ['Relationships', 'Activities',
                  'EmergencyContacts', 'Education']
    mapped.update({k: [] for k in fields_arr if k not in app})

    # Nest up to ten addresses as a list of dicts
    # "Address1Line1": "123 St" becomes "Addresses": [{"Line1": "123 St"}]
    mapped['Addresses'] = [{k[8:]: v for (k, v) in app.items()
                            if k[0:7] == 'Address' and int(k[7:8]) - 1 == i} for i in range(10)]

    # Remove empty address dicts
    mapped['Addresses'] = [k for k in mapped['Addresses'] if len(k) > 0]

    # Supply missing keys
    for k in mapped['Addresses']:
        if 'Type' not in k:
            k['Type'] = 0
        # If any of  Line1-4 are missing, insert them with value = None
        k.update({'Line' + str(i+1): None for i in range(4)
                  if 'Line' + str(i+1) not in k})
        if 'City' not in k:
            k['City'] = None
        if 'StateProvince' not in k:
            k['StateProvince'] = None
        if 'PostalCode' not in k:
            k['PostalCode'] = None
        if 'County' not in k:
            k['County'] = CONFIG['defaults']['address_country']

    if len([k for k in app if k[:5] == 'Phone']) > 0:
        has_phones = True
    else:
        has_phones = False

    if has_phones == True:
        # Nest up to 9 phone numbers as a list of dicts.
        # Phones should be passed in as {Phone0Number: '...', Phone0Type: 1, Phone1Number: '...', Phone1Country: '...', Phone1Type: 0}
        # First phone in the list becomes Primary in PowerCampus (I think)
        mapped['PhoneNumbers'] = [{k[6:]: v for (k, v) in app.items(
        ) if k[:5] == 'Phone' and int(k[5:6]) - 1 == i} for i in range(9)]

        # Remove empty dicts
        mapped['PhoneNumbers'] = [
            k for k in mapped['PhoneNumbers'] if 'Number' in k]

        # Supply missing keys and enforce datatypes
        for i, item in enumerate(mapped['PhoneNumbers']):
            item['Number'] = format_phone_number(item['Number'])

            if 'Type' not in item:
                item['Type'] = CONFIG['defaults']['phone_type']
            else:
                item['Type'] = int(item['Type'])

            if 'Country' not in item:
                item['Country'] = CONFIG['defaults']['phone_country']

    else:
        # PowerCampus WebAPI requires Type -1 instead of a blank or null when not submitting any phones.
        mapped['PhoneNumbers'] = [
            {'Type': -1, 'Country': None, 'Number': None}]

    # Veteran has funny logic, and  API 8.8.3 is broken (passing in 1 will write 2 into [Application].[VeteranStatus]).
    # Impact is low because custom SQL routines will fix Veteran field once person has passed Handle Applications.
    if app['Veteran'] is None:
        mapped['Veteran'] = 0
        mapped['VeteranStatus'] = False
    else:
        mapped['Veteran'] = int(app['Veteran'])
        mapped['VeteranStatus'] = True

    # Academic program
    mapped['Programs'] = [{'Program': app['Program'],
                           'Degree': app['Degree'], 'Curriculum': None}]

    # GUID's
    mapped['ApplicationNumber'] = app['aid']
    mapped['ProspectId'] = app['pid']

    return mapped


def format_app_sql(app):
    """Remap application to PowerCampus SQL format.

    Keyword arguments:
    app -- an application dict
    """

    mapped = {}

    # Pass through fields
    fields_verbatim = ['PEOPLE_CODE_ID', 'RaceAmericanIndian', 'RaceAsian', 'RaceAfricanAmerican', 'RaceNativeHawaiian',
                       'RaceWhite', 'IsInterestedInCampusHousing', 'IsInterestedInFinancialAid', 'RaceWhite', 'Ethnicity',
                       'AppStatus', 'AppDecision', 'CreateDateTime', 'SMSOptIn', 'Department', 'Extracurricular',
                       'Nontraditional', 'Population']
    fields_verbatim.extend([n['slate_field'] for n in CONFIG['pc_notes']])
    fields_verbatim.extend([f['slate_field']
                            for f in CONFIG['pc_user_defined']])
    mapped.update({k: v for (k, v) in app.items() if k in fields_verbatim})

    # Gender is hardcoded into the PowerCampus Web API, but [WebServices].[spSetDemographics] has different hardcoded values.
    gender_map = {None: 3, 0: 1, 1: 2, 2: 3}
    mapped['GENDER'] = gender_map[app['Gender']]

    mapped['ACADEMIC_YEAR'] = RM_MAPPING['AcademicTerm']['PCYearCodeValue'][app['YearTerm']]
    mapped['ACADEMIC_TERM'] = RM_MAPPING['AcademicTerm']['PCTermCodeValue'][app['YearTerm']]
    mapped['ACADEMIC_SESSION'] = RM_MAPPING['AcademicTerm']['PCSessionCodeValue'][app['YearTerm']]
    # Todo: Fix inconsistency of 1-field vs 2-field mappings
    mapped['PROGRAM'] = RM_MAPPING['AcademicLevel'][app['Program']]
    mapped['DEGREE'] = RM_MAPPING['AcademicProgram']['PCDegreeCodeValue'][app['Degree']]
    mapped['CURRICULUM'] = RM_MAPPING['AcademicProgram']['PCCurriculumCodeValue'][app['Degree']]

    if app['CitizenshipStatus'] is not None:
        mapped['PRIMARYCITIZENSHIP'] = RM_MAPPING['CitizenshipStatus'][app['CitizenshipStatus']]
    else:
        mapped['PRIMARYCITIZENSHIP'] = None

    if app['CollegeAttendStatus'] is not None:
        mapped['COLLEGE_ATTEND'] = RM_MAPPING['CollegeAttend'][app['CollegeAttendStatus']]
    else:
        mapped['COLLEGE_ATTEND'] = None

    if app['Visa'] is not None:
        mapped['VISA'] = RM_MAPPING['Visa'][app['Visa']]
    else:
        mapped['VISA'] = None

    if 'Veteran' in app:
        mapped['VETERAN'] = RM_MAPPING['Veteran'][str(app['Veteran'])]
    else:
        mapped['VETERAN'] = None

    if app['SecondaryCitizenship'] is not None:
        mapped['SECONDARYCITIZENSHIP'] = RM_MAPPING['CitizenshipStatus'][app['SecondaryCitizenship']]
    else:
        mapped['SECONDARYCITIZENSHIP'] = None

    if app['MaritalStatus'] is not None:
        mapped['MARITALSTATUS'] = RM_MAPPING['MaritalStatus'][app['MaritalStatus']]
    else:
        mapped['MARITALSTATUS'] = None

    return mapped


def str_digits(s):
    """Return only digits from a string."""
    non_digits = str.maketrans(
        {c: None for c in ascii_letters + punctuation + whitespace})
    return s.translate(non_digits)


def slate_get_actions(apps_list):
    """Fetch 'Scheduled Actions' (Slate Checklist) for a list of applications.

    Keyword arguments:
    apps_list -- list of ApplicationNumbers to fetch actions for

    Returns:
    action_list -- list of individual action as dicts

    Uses its own HTTP session to reduce overhead and queries Slate with batches of 48 comma-separated ID's.
    48 was chosen to avoid exceeding max GET request.
    """

    # Set up an HTTP session to use for multiple GET requests.
    http_session = requests.Session()
    http_session.auth = (CONFIG['scheduled_actions']['slate_get']['username'],
                         CONFIG['scheduled_actions']['slate_get']['password'])

    actions_list = []

    while apps_list:
        counter = 0
        ql = []  # Queue list
        qs = ''  # Queue string
        al = []  # Temporary actions list

        # Pop up to 48 app GUID's and append to queue list.
        while apps_list and counter < 48:
            ql.append(apps_list.pop())
            counter += 1

        # Stuff them into a comma-separated string.
        qs = ",".join(str(item) for item in ql)

        r = http_session.get(
            CONFIG['scheduled_actions']['slate_get']['url'], params={'aids': qs})
        r.raise_for_status()
        al = json.loads(r.text)
        actions_list.extend(al['row'])
        # if len(al['row']) > 1: # Delete. I don't think an application could ever have zero actions.

    http_session.close()

    return actions_list


def slate_post_fields_changed(apps, config_dict):
    # Check for changes between Slate and local state
    # Upload changed records back to Slate

    # Build list of flat app dicts with only certain fields included
    upload_list = []
    fields = config_dict['fields_string']
    fields.extend(config_dict['fields_bool'])
    fields.extend(config_dict['fields_int'])

    if len(fields) == 1:
        return

    for app in apps.values():
        CURRENT_RECORD = app['aid']
        upload_list.append({k: v for (k, v) in app.items() if k in fields
                            and v != app["compare_" + k]} | {'aid': app['aid']})

    # Apps with no changes will only contain {'aid': 'xxx'}
    # Only retain items that have more than one field
    upload_list[:] = [app for app in upload_list if len(app) > 1]

    if len(upload_list) > 0:
        # Slate requires JSON to be convertable to XML
        upload_dict = {'row': upload_list}

        creds = (config_dict['username'], config_dict['password'])
        r = requests.post(config_dict['url'], json=upload_dict, auth=creds)
        r.raise_for_status()

    msg = '\t' + str(len(upload_list)) + ' of ' + \
        str(len(apps)) + ' apps had changed fields'
    return msg


def slate_post_fields(apps, config_dict):
    # Build list of flat app dicts with only certain fields included
    upload_list = []
    fields = ['aid']
    fields.extend(config_dict['fields'])

    for app in apps.values():
        CURRENT_RECORD = app['aid']
        upload_list.append({k: v for (k, v) in app.items()
                            if k in fields})

    # Slate requires JSON to be convertable to XML
    upload_dict = {'row': upload_list}

    creds = (config_dict['username'], config_dict['password'])
    r = requests.post(config_dict['url'], json=upload_dict, auth=creds)
    r.raise_for_status()


def pc_post_api(x):
    """Post an application to PowerCampus.
    Return  PEOPLE_CODE_ID if application was automatically accepted or None for all other conditions.

    Keyword arguments:
    x -- an application dict
    """

    r = requests.post(PC_API_URL + 'api/applications',
                      json=x, auth=PC_API_CRED)

    # Catch some errors we know how to handle. Not sure if this is the most Pythonic way.
    # 202 probably means ApplicationSettings.config not configured.
    if r.status_code == 202:
        raise ValueError(r.text)
    elif r.status_code == 400:
        raise ValueError(r.text)

    r.raise_for_status()

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


def pc_scan_status(x):
    """Query the PowerCampus status of a single application and return three status indicators and PowerCampus ID number, if present.

    Keyword arguments:
    x -- an application dict

    Returns:
    ra_status -- RecruiterApplication table status (int)
    apl_status -- Application table status (int)
    computed_status -- Descriptive status (string)
    pcid -- PEOPLE_CODE_ID (string)
    """

    ra_status = None
    apl_status = None
    computed_status = None
    pcid = None

    CURSOR.execute('EXEC [custom].[PS_selRAStatus] ?', x['aid'])
    row = CURSOR.fetchone()

    if row is not None:
        ra_status = row.ra_status
        apl_status = row.apl_status
        pcid = row.PEOPLE_CODE_ID

        # Determine status.
        if row.ra_status in (0, 3, 4) and row.apl_status == 2 and pcid is not None:
            computed_status = 'Active'
        elif row.ra_status in (0, 3, 4) and row.apl_status == 3 and pcid is None:
            computed_status = 'Declined'
        elif row.ra_status in (0, 3, 4) and row.apl_status == 1 and pcid is None:
            computed_status = 'Pending'
        elif row.ra_status == 1 and row.apl_status is None and pcid is None:
            computed_status = 'Required field missing.'
        elif row.ra_status == 2 and row.apl_status is None and pcid is None:
            computed_status = 'Required field mapping is missing.'
        else:
            computed_status = 'Unrecognized Status: ' + str(row.ra_status)

        if CONFIG['logging']['enabled']:
            # Write errors to external database for end-user presentation via SSRS.
            CURSOR.execute('INSERT INTO' + CONFIG['logging']['log_table'] + """
                ([Ref],[ApplicationNumber],[ProspectId],[FirstName],[LastName],
                [ComputedStatus],[Notes],[RecruiterApplicationStatus],[ApplicationStatus],[PEOPLE_CODE_ID])
            VALUES
                (?,?,?,?,?,?,?,?,?,?)""",
                           [x['Ref'], x['aid'], x['pid'], x['FirstName'], x['LastName'], computed_status, row.ra_errormessage, row.ra_status, row.apl_status, pcid])
            CNXN.commit()

    return ra_status, apl_status, computed_status, pcid


def pc_get_profile(app):
    '''Fetch ACADEMIC row data and email address from PowerCampus.

     Returns:
     found -- True/False (row exists or not)
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
    credits = '0.00'
    campus_email = None

    CURSOR.execute('EXEC [custom].[PS_selProfile] ?,?,?,?,?,?,?',
                   app['PEOPLE_CODE_ID'],
                   app['ACADEMIC_YEAR'],
                   app['ACADEMIC_TERM'],
                   app['ACADEMIC_SESSION'],
                   app['PROGRAM'],
                   app['DEGREE'],
                   app['CURRICULUM'])
    row = CURSOR.fetchone()

    if row is not None:
        found = True

        if row.Registered == 'Y':
            registered = True
            reg_date = str(row.REG_VAL_DATE)
            credits = str(row.CREDITS)

        campus_email = row.CampusEmail

        if row.COLLEGE_ATTEND == CONFIG['pc_readmit_code']:
            readmit = True

        if row.Withdrawn == 'Y':
            withdrawn = True

    return found, registered, reg_date, readmit, withdrawn, credits, campus_email


def pc_update_demographics(app):
    CURSOR.execute('execute [custom].[PS_updDemographics] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?',
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
    CNXN.commit()


def pc_update_academic(app):
    CURSOR.execute('exec [custom].[PS_updAcademicAppInfo] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?',
                   app['PEOPLE_CODE_ID'],
                   app['ACADEMIC_YEAR'],
                   app['ACADEMIC_TERM'],
                   app['ACADEMIC_SESSION'],
                   app['PROGRAM'],
                   app['DEGREE'],
                   app['CURRICULUM'],
                   app['Department'],
                   app['Nontraditional'],
                   app['Population'],
                   app['AppStatus'],
                   app['AppDecision'],
                   app['COLLEGE_ATTEND'],
                   app['Extracurricular'],
                   app['CreateDateTime'])
    CNXN.commit()


def pc_update_action(action):
    """Update a Scheduled Action in PowerCampus. Expects an action dict with 'app' key containing SQL formatted app
    {'aid': GUID, 'item': 'Transcript', 'app': {'PEOPLE_CODE_ID':...}}
    """
    try:
        CURSOR.execute('EXEC [custom].[PS_updAction] ?, ?, ?, ?, ?, ?, ?, ?, ?',
                       action['app']['PEOPLE_CODE_ID'],
                       'SLATE',
                       action['action_id'],
                       action['item'],
                       action['completed'],
                       # Only the date portion is actually used.
                       action['create_datetime'],
                       action['app']['ACADEMIC_YEAR'],
                       action['app']['ACADEMIC_TERM'],
                       action['app']['ACADEMIC_SESSION'])
        CNXN.commit()
    except KeyError as e:
        raise KeyError(e, 'aid: ' + action['aid'])


def pc_update_smsoptin(app):
    if 'SMSOptIn' in app:
        CURSOR.execute('exec [custom].[PS_updSMSOptIn] ?, ?, ?',
                       app['PEOPLE_CODE_ID'], 'SLATE', app['SMSOptIn'])
        CNXN.commit()


def pc_update_note(app, field, office, note_type):
    CURSOR.execute('exec [custom].[PS_insNote] ?, ?, ?, ?',
                   app['PEOPLE_CODE_ID'], office, note_type, app[field])
    CNXN.commit()


def pc_update_udf(app, slate_field, pc_field):
    CURSOR.execute('exec [custom].[PS_updUserDefined] ?, ?, ?',
                   app['PEOPLE_CODE_ID'], pc_field, app[slate_field])
    CNXN.commit()


def pf_get_fachecklist(pcid, govid, appid, year, term, session):
    """Return the PowerFAIDS missing docs list for uploading to Financial Aid Checklist."""
    checklist = []
    CURSOR.execute(
        'exec [custom].[PS_selPFChecklist] ?, ?, ?, ?, ?', pcid, govid, year, term, session)

    columns = [column[0] for column in CURSOR.description]
    for row in CURSOR.fetchall():
        checklist.append(dict(zip(columns, row)))

    # Pass through the Slate Application ID
    for doc in checklist:
        doc['AppID'] = appid

    return checklist


def main_sync(pid=None):
    """Main body of the program.

    Keyword arguments:
    pid -- specific application GUID to sync (default None)
    """
    global CURRENT_RECORD

    verbose_print('Get applicants from Slate...')
    creds = (CONFIG['slate_query_apps']['username'],
             CONFIG['slate_query_apps']['password'])
    if pid is not None:
        r = requests.get(CONFIG['slate_query_apps']['url'],
                         auth=creds, params={'pid': pid})
    else:
        r = requests.get(CONFIG['slate_query_apps']['url'], auth=creds)
    r.raise_for_status()
    apps = json.loads(r.text)['row']
    verbose_print('\tFetched ' + str(len(apps)) + ' apps')

    # Make a dict of apps with application GUID as the key
    # {AppGUID: { JSON from Slate }
    apps = {k['aid']: k for k in apps}
    if len(apps) == 0 and pid is not None:
        # Assuming we're running in interactive (HTTP) mode if pid param exists
        raise EOFError(MSG_STRINGS['error_no_apps'])
    elif len(apps) == 0:
        # Don't raise an error for scheduled mode
        return None

    verbose_print(
        'Clean up app data from Slate (datatypes, supply nulls, etc.)')
    for k, v in apps.items():
        CURRENT_RECORD = k
        apps[k] = format_app_generic(v)

    verbose_print('Check each app\'s status flags/PCID in PowerCampus')
    for k, v in apps.items():
        CURRENT_RECORD = k
        status_ra, status_app, status_calc, pcid = pc_scan_status(v)
        apps[k].update({'status_ra': status_ra, 'status_app': status_app,
                        'status_calc': status_calc})
        apps[k]['PEOPLE_CODE_ID'] = pcid

    verbose_print(
        'Post new or repost unprocessed applications to PowerCampus API')
    for k, v in apps.items():
        CURRENT_RECORD = k
        if (v['status_ra'] == None) or (v['status_ra'] in (1, 2) and v['status_app'] is None):
            pcid = pc_post_api(format_app_api(v))
            apps[k]['PEOPLE_CODE_ID'] = pcid

            # Rescan status
            status_ra, status_app, status_calc, pcid = pc_scan_status(v)
            apps[k].update({'status_ra': status_ra, 'status_app': status_app,
                            'status_calc': status_calc})
            apps[k]['PEOPLE_CODE_ID'] = pcid

    # verbose_print('Rescan statuses in PowerCampus')
    # for k, v in apps.items():
    #     status_ra, status_app, status_calc, pcid = pc_scan_status(v)
    #     apps[k].update({'status_ra': status_ra, 'status_app': status_app,
    #                     'status_calc': status_calc})
    #     apps[k]['PEOPLE_CODE_ID'] = pcid

    verbose_print(
        'Update existing applications in PowerCampus and extract information')
    for k, v in apps.items():
        CURRENT_RECORD = k
        if v['status_calc'] == 'Active':
            # Transform to PowerCampus format
            app_pc = format_app_sql(v)

            # Execute update sprocs
            pc_update_demographics(app_pc)
            pc_update_academic(app_pc)
            pc_update_smsoptin(app_pc)

            # Update any PowerCampus Notes defined in config
            for note in CONFIG['pc_notes']:
                if note['slate_field'] in app_pc and len(app_pc[note['slate_field']]) > 0:
                    pc_update_note(
                        app_pc, note['slate_field'], note['office'], note['note_type'])

            # Update any PowerCampus User Defined fields defined in config
            for udf in CONFIG['pc_user_defined']:
                if udf['slate_field'] in app_pc and len(app_pc[udf['slate_field']]) > 0:
                    pc_update_udf(app_pc, udf['slate_field'], udf['pc_field'])

            # Collect information
            found, registered, reg_date, readmit, withdrawn, credits, campus_email = pc_get_profile(
                app_pc)
            apps[k].update({'found': found, 'registered': registered, 'reg_date': reg_date, 'readmit': readmit,
                            'withdrawn': withdrawn, 'credits': credits, 'campus_email': campus_email})

    # Update PowerCampus Scheduled Actions
    # Querying each app individually would introduce significant network overhead, so query Slate in bulk
    if CONFIG['scheduled_actions']['enabled'] == True:
        verbose_print('Update PowerCampus Scheduled Actions')
        # Make a list of App GUID's
        apps_for_sa = [k for (k, v) in apps.items()
                       if v['status_calc'] == 'Active']
        actions_list = slate_get_actions(apps_for_sa)

        for action in actions_list:
            # Lookup the app each action is associated with; we need PCID and YTS
            # Nest SQL version of app underneath action
            action['app'] = format_app_sql(apps[action['aid']])
            pc_update_action(action)

    verbose_print('Upload passive fields back to Slate')
    slate_post_fields(apps, CONFIG['slate_upload_passive'])

    verbose_print('Upload active (changed) fields back to Slate')
    verbose_print(slate_post_fields_changed(
        apps, CONFIG['slate_upload_active']))

    # Collect Financial Aid checklist and upload to Slate
    if CONFIG['fa_checklist']['enabled'] == True:
        verbose_print('Collect Financial Aid checklist and upload to Slate')
        slate_upload_list = []
        slate_upload_fields = {'AppID', 'Code', 'Status', 'Date'}

        for k, v in apps.items():
            CURRENT_RECORD = k
            if v['status_calc'] == 'Active':
                # Transform to PowerCampus format
                app_pc = format_app_sql(v)

                fa_checklists = pf_get_fachecklist(
                    app_pc['PEOPLE_CODE_ID'], v['GovernmentId'], v['AppID'], app_pc['ACADEMIC_YEAR'], app_pc['ACADEMIC_TERM'], app_pc['ACADEMIC_SESSION'])

                slate_upload_list = slate_upload_list + fa_checklists

        if len(slate_upload_list) > 0:
            # Slate's Checklist Import (Financial Aid) requires tab-separated files because it's old and crusty, apparently.
            tab = '\t'
            slate_fa_string = 'AppID' + tab + 'Code' + tab + 'Status' + tab + 'Date'
            for i in slate_upload_list:
                line = i['AppID'] + tab + \
                    str(i['Code']) + tab + i['Status'] + tab + i['Date']
                slate_fa_string = slate_fa_string + '\n' + line

            creds = (CONFIG['fa_checklist']['slate_post']['username'],
                     CONFIG['fa_checklist']['slate_post']['password'])
            r = requests.post(CONFIG['fa_checklist']['slate_post']['url'],
                              data=slate_fa_string, auth=creds)
            r.raise_for_status()

    return MSG_STRINGS['sync_done']
