import requests
import json
import pyodbc


def init(config):
    global PC_API_URL
    global PC_API_CRED
    global CNXN
    global CURSOR
    global CONFIG

    CONFIG = config

    # PowerCampus Web API connection
    PC_API_URL = config['pc_api']['url']
    PC_API_CRED = (config['pc_api']['username'], config['pc_api']['password'])

    # PowerCampus Web API connection
    PC_API_URL = config['pc_api']['url']
    PC_API_CRED = (config['pc_api']['username'], config['pc_api']['password'])

    # Microsoft SQL Server connection.
    CNXN = pyodbc.connect(config['pc_database_string'])
    CURSOR = CNXN.cursor()

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


def post_api(x, cfg_strings):
    """Post an application to PowerCampus.
    Return  PEOPLE_CODE_ID if application was automatically accepted or None for all other conditions.

    Keyword arguments:
    x -- an application dict
    """

    # Expose error text response from API, replace useless error message(s).
    try:
        r = requests.post(PC_API_URL + 'api/applications',
                          json=x, auth=PC_API_CRED)
        r.raise_for_status()
        # The API returns 202 for mapping errors. Technically 202 is appropriate, but it should bubble up to the user.
        if r.status_code == 202:
            raise requests.HTTPError
    except requests.HTTPError as e:
        # Change newline handling so response text prints nicely in emails.
        rtext = r.text.replace('\r\n', '\n')

        if 'BadRequest Object reference not set to an instance of an object.' in rtext and 'ApplicationsController.cs:line 183' in rtext:
            raise ValueError(cfg_strings['error_no_phones'], e)
        elif r.status_code == 202 or r.status_code == 400:
            raise ValueError(rtext)
        else:
            raise requests.HTTPError(rtext)

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


def scan_status(x):
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


def get_profile(app):
    """Fetch ACADEMIC row data and email address from PowerCampus.

     Returns:
     found -- True/False (row exists or not)
     registered -- True/False
     reg_date -- Date
     readmit -- True/False
     withdrawn -- True/False
     credits -- string
     campus_email -- string (None of not registered)
    """

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


def update_demographics(app):
    CURSOR.execute('execute [custom].[PS_updDemographics] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?',
                   app['PEOPLE_CODE_ID'],
                   'SLATE',
                   app['GENDER'],
                   app['Ethnicity'],
                   app['DemographicsEthnicity'],
                   app['MARITALSTATUS'],
                   app['VETERAN'],
                   app['PRIMARYCITIZENSHIP'],
                   app['SECONDARYCITIZENSHIP'],
                   app['VISA'],
                   app['RaceAfricanAmerican'],
                   app['RaceAmericanIndian'],
                   app['RaceAsian'],
                   app['RaceNativeHawaiian'],
                   app['RaceWhite'],
                   app['PRIMARY_LANGUAGE'],
                   app['HOME_LANGUAGE'],
                   app['GovernmentId'])
    CNXN.commit()


def update_academic(app):
    CURSOR.execute('exec [custom].[PS_updAcademicAppInfo] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?',
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
                   app['AdmitDate'],
                   app['Matriculated'],
                   app['AppStatus'],
                   app['AppStatusDate'],
                   app['AppDecision'],
                   app['AppDecisionDate'],
                   app['Counselor'],
                   app['COLLEGE_ATTEND'],
                   app['Extracurricular'],
                   app['CreateDateTime'])
    CNXN.commit()


def update_academic_key(app):
    CURSOR.execute('exec [custom].[PS_updAcademicKey] ?, ?, ?, ?, ?, ?, ?, ?',
                   app['PEOPLE_CODE_ID'],
                   app['ACADEMIC_YEAR'],
                   app['ACADEMIC_TERM'],
                   app['ACADEMIC_SESSION'],
                   app['PROGRAM'],
                   app['DEGREE'],
                   app['CURRICULUM'],
                   app['aid'])
    CNXN.commit()


def update_action(action):
    """Update a Scheduled Action in PowerCampus. Expects an action dict with 'app' key containing SQL formatted app
    {'aid': GUID, 'item': 'Transcript', 'app': {'PEOPLE_CODE_ID':...}}
    """
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


def update_smsoptin(app):
    if 'SMSOptIn' in app:
        CURSOR.execute('exec [custom].[PS_updSMSOptIn] ?, ?, ?',
                       app['PEOPLE_CODE_ID'], 'SLATE', app['SMSOptIn'])
        CNXN.commit()


def update_note(app, field, office, note_type):
    CURSOR.execute('exec [custom].[PS_insNote] ?, ?, ?, ?',
                   app['PEOPLE_CODE_ID'], office, note_type, app[field])
    CNXN.commit()


def update_udf(app, slate_field, pc_field):
    CURSOR.execute('exec [custom].[PS_updUserDefined] ?, ?, ?',
                   app['PEOPLE_CODE_ID'], pc_field, app[slate_field])
    CNXN.commit()


def update_education(pcid, education):
    CURSOR.execute('exec [custom].[PS_updEducation] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?',
                   pcid,
                   education['OrgIdentifier'],
                   education['Degree'],
                   education['Curriculum'],
                   education['GPA'],
                   education['GPAUnweighted'],
                   education['GPAUnweightedScale'],
                   education['GPAWeighted'],
                   education['GPAWeightedScale'],
                   education['StartDate'],
                   education['EndDate'],
                   education['Honors'],
                   education['TranscriptDate'],
                   education['ClassRank'],
                   education['ClassSize'],
                   education['TransferCredits'],
                   education['FinAidAmount'],
                   education['Quartile'])
    row = CURSOR.fetchone()
    errorflag = not row[0]

    return errorflag


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
