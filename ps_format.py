from copy import deepcopy
from string import ascii_letters, punctuation, whitespace
import ps_models


def format_blank_to_null(x):
    # Converts empty string to None. Accepts dicts, lists, and tuples.
    # This function derived from radtek @ http://stackoverflow.com/a/37079737/4109658
    # CC Attribution-ShareAlike 3.0 https://creativecommons.org/licenses/by-sa/3.0/
    ret = deepcopy(x)
    # Handle dictionaries, lists, and tuples. Scrub all values
    if isinstance(x, dict):
        for k, v in ret.items():
            ret[k] = format_blank_to_null(v)
    if isinstance(x, (list, tuple)):
        for k, v in enumerate(ret):
            ret[k] = format_blank_to_null(v)
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


def format_strtobool(s):
    if s is not None and s.lower() in ['true', '1', 'y', 'yes']:
        return True
    elif s is not None and s.lower() in ['false', '0', 'n', 'no']:
        return False
    else:
        return None


def format_str_digits(s):
    """Return only digits from a string."""
    non_digits = str.maketrans(
        {c: None for c in ascii_letters + punctuation + whitespace})
    return s.translate(non_digits)


def format_app_generic(app, cfg_fields):
    """Supply missing fields and correct datatypes. Returns a flat dict."""

    mapped = format_blank_to_null(app)

    fields_null = [k for (k, v) in ps_models.fields.items()
                   if v['supply_null'] == True]
    fields_bool = [k for (k, v) in ps_models.fields.items()
                   if v['type'] == bool]
    fields_int = [k for (k, v) in ps_models.fields.items()
                  if v['type'] == int]
    fields_null.extend(
        ['compare_' + field for field in cfg_fields['fields_string']])
    fields_null.extend(
        ['compare_' + field for field in cfg_fields['fields_bool']])
    fields_null.extend(
        ['compare_' + field for field in cfg_fields['fields_int']])
    fields_bool.extend(
        ['compare_' + field for field in cfg_fields['fields_bool']])
    fields_int.extend(
        ['compare_' + field for field in cfg_fields['fields_int']])

    # Copy nullable strings from input to output, then fill in nulls
    mapped.update({k: v for (k, v) in app.items() if k in fields_null})
    mapped.update({k: None for k in fields_null if k not in app})

    # Convert integers and booleans
    mapped.update({k: int(v) for (k, v) in app.items() if k in fields_int})
    mapped.update({k: format_strtobool(v)
                   for (k, v) in app.items() if k in fields_bool})

    # Probably a stub in the API
    if 'GovernmentDateOfEntry' not in app:
        mapped['GovernmentDateOfEntry'] = '0001-01-01T00:00:00'
    else:
        mapped['GovernmentDateOfEntry'] = app['GovernmentDateOfEntry']

    # Pass through all other fields
    mapped.update({k: v for (k, v) in app.items() if k not in mapped})

    return mapped


def format_app_api(app, cfg_defaults):
    """Remap application to Recruiter/Web API format.

    Keyword arguments:
    app -- an application dict
    """

    mapped = {}

    # Pass through fields
    fields_verbatim = [k for (k, v) in ps_models.fields.items()
                       if v['api_verbatim'] == True]
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
            k['County'] = cfg_defaults['address_country']

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
                item['Type'] = cfg_defaults['phone_type']
            else:
                item['Type'] = int(item['Type'])

            if 'Country' not in item:
                item['Country'] = cfg_defaults['phone_country']

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


def format_app_sql(app, mapping, config):
    """Remap application to PowerCampus SQL format.

    Keyword arguments:
    app -- an application dict
    """

    mapped = {}

    # Pass through fields
    fields_verbatim = [
        k for (k, v) in ps_models.fields.items() if v['sql_verbatim'] == True]
    fields_verbatim.extend([n['slate_field'] for n in config['pc_notes']])
    fields_verbatim.extend([f['slate_field']
                            for f in config['pc_user_defined']])
    mapped.update({k: v for (k, v) in app.items() if k in fields_verbatim})

    # Gender is hardcoded into the PowerCampus Web API, but [WebServices].[spSetDemographics] has different hardcoded values.
    gender_map = {None: 3, 0: 1, 1: 2, 2: 3}
    mapped['GENDER'] = gender_map[app['Gender']]

    mapped['ACADEMIC_YEAR'] = mapping['AcademicTerm']['PCYearCodeValue'][app['YearTerm']]
    mapped['ACADEMIC_TERM'] = mapping['AcademicTerm']['PCTermCodeValue'][app['YearTerm']]
    mapped['ACADEMIC_SESSION'] = mapping['AcademicTerm']['PCSessionCodeValue'][app['YearTerm']]
    # Todo: Fix inconsistency of 1-field vs 2-field mappings
    mapped['PROGRAM'] = mapping['AcademicLevel'][app['Program']]
    mapped['DEGREE'] = mapping['AcademicProgram']['PCDegreeCodeValue'][app['Degree']]
    mapped['CURRICULUM'] = mapping['AcademicProgram']['PCCurriculumCodeValue'][app['Degree']]

    if app['CitizenshipStatus'] is not None:
        mapped['PRIMARYCITIZENSHIP'] = mapping['CitizenshipStatus'][app['CitizenshipStatus']]
    else:
        mapped['PRIMARYCITIZENSHIP'] = None

    if app['CollegeAttendStatus'] is not None:
        mapped['COLLEGE_ATTEND'] = mapping['CollegeAttend'][app['CollegeAttendStatus']]
    else:
        mapped['COLLEGE_ATTEND'] = None

    if app['Visa'] is not None:
        mapped['VISA'] = mapping['Visa'][app['Visa']]
    else:
        mapped['VISA'] = None

    if app['Veteran'] is not None:
        mapped['VETERAN'] = mapping['Veteran'][str(app['Veteran'])]
    else:
        mapped['VETERAN'] = None

    if app['SecondaryCitizenship'] is not None:
        mapped['SECONDARYCITIZENSHIP'] = mapping['CitizenshipStatus'][app['SecondaryCitizenship']]
    else:
        mapped['SECONDARYCITIZENSHIP'] = None

    if app['MaritalStatus'] is not None:
        mapped['MARITALSTATUS'] = mapping['MaritalStatus'][app['MaritalStatus']]
    else:
        mapped['MARITALSTATUS'] = None

    if app['PrimaryLanguage'] is not None:
        mapped['PRIMARY_LANGUAGE'] = mapping['Language'][app['PrimaryLanguage']]
    else:
        mapped['PRIMARY_LANGUAGE'] = None

    if 'HomeLanguage' in app:
        mapped['HOME_LANGUAGE'] = mapping['Language'][app['HomeLanguage']]
    else:
        mapped['HOME_LANGUAGE'] = None

    # Format arrays if present.
    # Currently only supplies nulls; no other datatype manipulation.
    arrays = [k for (k, v) in ps_models.arrays.items() if k in app]

    for array in arrays:
        mapped[array] = deepcopy(app[array])
        fields_null = [
            k for (k, v) in ps_models.arrays[array].items() if v['supply_null'] == True]

        # Supply nulls
        for item in mapped[array]:
            item.update({k: v for (k, v) in item.items() if k in fields_null})
            item.update({k: None for k in fields_null if k not in item})

    return mapped
