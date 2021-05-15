import requests
import json
from copy import deepcopy
import xml.etree.ElementTree as ET
from ps_format import format_app_generic, format_app_api,  format_app_sql
import ps_powercampus


def init(config_path):
    """Reads config file to global CONFIG dict. Many frequently-used variables are copied to their own globals for convenince."""
    global CONFIG
    global FIELDS
    global RM_MAPPING
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

    # Init PowerCampus API and SQL connections
    ps_powercampus.init(CONFIG)

    # Misc configs
    MSG_STRINGS = CONFIG['msg_strings']

    return CONFIG


def de_init():
    '''Release resources like open SQL connections.'''
    ps_powercampus.de_init()


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


def slate_post_generic(upload_list, config_dict):
    '''Upload a simple list of dicts to Slate with no transformations.'''

    # Slate requires JSON to be convertable to XML
    upload_dict = {'row': upload_list}

    creds = (config_dict['username'], config_dict['password'])
    r = requests.post(config_dict['url'], json=upload_dict, auth=creds)
    r.raise_for_status()


def slate_post_fields_changed(apps, config_dict):
    # Check for changes between Slate and local state
    # Upload changed records back to Slate

    # Build list of flat app dicts with only certain fields included
    upload_list = []
    fields = deepcopy(config_dict['fields_string'])
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


def slate_post_fa_checklist(upload_list):
    '''Upload Financial Aid Checklist to Slate.'''

    if len(upload_list) > 0:
        # Slate's Checklist Import (Financial Aid) requires tab-separated files because it's old and crusty, apparently.
        tab = '\t'
        slate_fa_string = 'AppID' + tab + 'Code' + tab + 'Status' + tab + 'Date'
        for i in upload_list:
            line = i['AppID'] + tab + \
                str(i['Code']) + tab + i['Status'] + tab + i['Date']
            slate_fa_string = slate_fa_string + '\n' + line

        creds = (CONFIG['fa_checklist']['slate_post']['username'],
                 CONFIG['fa_checklist']['slate_post']['password'])
        r = requests.post(CONFIG['fa_checklist']['slate_post']['url'],
                          data=slate_fa_string, auth=creds)
        r.raise_for_status()


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
        apps[k] = format_app_generic(v, CONFIG['slate_upload_active'])

    if CONFIG['autoconfigure_mappings']:
        verbose_print(
            'Automatically update ProgramOfStudy and recruiterMapping.xml')

    verbose_print('Check each app\'s status flags/PCID in PowerCampus')
    for k, v in apps.items():
        CURRENT_RECORD = k
        status_ra, status_app, status_calc, pcid = ps_powercampus.scan_status(
            v)
        apps[k].update({'status_ra': status_ra, 'status_app': status_app,
                        'status_calc': status_calc})
        apps[k]['PEOPLE_CODE_ID'] = pcid

    verbose_print(
        'Post new or repost unprocessed applications to PowerCampus API')
    for k, v in apps.items():
        CURRENT_RECORD = k
        if (v['status_ra'] == None) or (v['status_ra'] in (1, 2) and v['status_app'] is None):
            pcid = ps_powercampus.post_api(format_app_api(
                v, CONFIG['defaults']), MSG_STRINGS)
            apps[k]['PEOPLE_CODE_ID'] = pcid

            # Rescan status
            status_ra, status_app, status_calc, pcid = ps_powercampus.scan_status(
                v)
            apps[k].update({'status_ra': status_ra, 'status_app': status_app,
                            'status_calc': status_calc})
            apps[k]['PEOPLE_CODE_ID'] = pcid

    verbose_print(
        'Update existing applications in PowerCampus and extract information')
    unmatched_schools = []
    for k, v in apps.items():
        CURRENT_RECORD = k
        if v['status_calc'] == 'Active':
            # Transform to PowerCampus format
            app_pc = format_app_sql(v, RM_MAPPING, CONFIG)

            # Execute update sprocs
            ps_powercampus.update_demographics(app_pc)
            ps_powercampus.update_academic(app_pc)
            ps_powercampus.update_smsoptin(app_pc)
            if CONFIG['pc_update_custom_academickey'] == True:
                ps_powercampus.update_academic_key(app_pc)

            # Update PowerCampus Education records
            if 'Education' in app_pc:
                apps[k]['schools_not_found'] = []
                for edu in app_pc['Education']:
                    unmatched_schools.append(ps_powercampus.update_education(
                        app_pc['PEOPLE_CODE_ID'], app_pc['pid'], edu))
            
            # Update PowerCampus Test Score records
            if 'TestScoresNumeric' in app_pc:
                for test in app_pc['TestScoresNumeric']:
                    ps_powercampus.update_test_scores(app_pc['PEOPLE_CODE_ID'], test)

            # Update any PowerCampus Notes defined in config
            for note in CONFIG['pc_notes']:
                if note['slate_field'] in app_pc and len(app_pc[note['slate_field']]) > 0:
                    ps_powercampus.update_note(
                        app_pc, note['slate_field'], note['office'], note['note_type'])

            # Update any PowerCampus User Defined fields defined in config
            for udf in CONFIG['pc_user_defined']:
                if udf['slate_field'] in app_pc and len(app_pc[udf['slate_field']]) > 0:
                    ps_powercampus.update_udf(
                        app_pc, udf['slate_field'], udf['pc_field'])

            # Collect information
            found, registered, reg_date, readmit, withdrawn, credits, campus_email = ps_powercampus.get_profile(
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
            action['app'] = format_app_sql(
                apps[action['aid']], RM_MAPPING, CONFIG)
            ps_powercampus.update_action(action)

    verbose_print('Upload passive fields back to Slate')
    slate_post_fields(apps, CONFIG['slate_upload_passive'])

    verbose_print('Upload active (changed) fields back to Slate')
    verbose_print(slate_post_fields_changed(
        apps, CONFIG['slate_upload_active']))

    if len(unmatched_schools) > 0:
        verbose_print('Upload unmatched school records back to Slate')
        slate_post_generic(unmatched_schools, CONFIG['slate_upload_schools'])

    # Collect Financial Aid checklist and upload to Slate
    if CONFIG['fa_checklist']['enabled'] == True:
        verbose_print('Collect Financial Aid checklist and upload to Slate')
        slate_upload_list = []
        # slate_upload_fields = {'AppID', 'Code', 'Status', 'Date'}

        for k, v in apps.items():
            CURRENT_RECORD = k
            if v['status_calc'] == 'Active':
                # Transform to PowerCampus format
                app_pc = format_app_sql(v, RM_MAPPING, CONFIG)

                fa_checklists = ps_powercampus.pf_get_fachecklist(
                    app_pc['PEOPLE_CODE_ID'], v['GovernmentId'], v['AppID'], app_pc['ACADEMIC_YEAR'], app_pc['ACADEMIC_TERM'], app_pc['ACADEMIC_SESSION'])

                slate_upload_list = slate_upload_list + fa_checklists

        slate_post_fa_checklist(slate_upload_list)

    return MSG_STRINGS['sync_done']
