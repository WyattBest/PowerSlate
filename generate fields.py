import pprint
# This was a quick script used to refactor a bunch of separate lists into one big dict.
# Delete after everything is running smoothly.

def merge(current, new):
    '''Union nested dicts one level deep.'''
    for k, v in new.items():
        if k in current:
            current[k] = current[k] | new[k]
        else:
            current[k] = new[k]
    return current


fields_null = ['Prefix',
               'MiddleName',
               'LastNamePrefix',
               'Suffix',
               'Nickname',
               'GovernmentId',
               'LegalName',
               'Visa',
               'CitizenshipStatus',
               'PrimaryCitizenship',
               'SecondaryCitizenship',
               'DemographicsEthnicity',
               'MaritalStatus',
               'ProposedDecision',
               'AppStatus', 'AppStatusDate',
               'AppDecision',
               'AppDecisionDate',
               'Religion',
               'FormerLastName',
               'FormerFirstName',
               'PrimaryLanguage',
               'CountryOfBirth',
               'Disabilities',
               'CollegeAttendStatus',
               'Commitment',
               'Status',
               'Veteran',
               'Counselor',
               'Department',
               'Nontraditional',
               'Population',
               'Matriculated',
               'AdmitDate',
               'Extracurricular']

fields_bool = ['RaceAmericanIndian',
               'RaceAsian',
               'RaceAfricanAmerican',
               'RaceNativeHawaiian',
               'RaceWhite',
               'IsInterestedInCampusHousing',
               'IsInterestedInFinancialAid',
               'Matriculated',
               'Extracurricular']
fields_int = ['Ethnicity',
              'Gender',
              'SMSOptIn']

fields_api_verbatim = ['FirstName',
                       'LastName',
                       'Email',
                       'Campus',
                       'BirthDate',
                       'CreateDateTime',
                       'Prefix',
                       'MiddleName',
                       'LastNamePrefix',
                       'Suffix',
                       'Nickname',
                       'GovernmentId',
                       'LegalName',
                       'Visa',
                       'CitizenshipStatus',
                       'PrimaryCitizenship',
                       'SecondaryCitizenship',
                       'MaritalStatus',
                       'ProposedDecision',
                       'Religion',
                       'FormerLastName',
                       'FormerFirstName',
                       'PrimaryLanguage',
                       'CountryOfBirth',
                       'Disabilities',
                       'CollegeAttendStatus',
                       'Commitment', 'Status',
                       'RaceAmericanIndian',
                       'RaceAsian',
                       'RaceAfricanAmerican',
                       'RaceNativeHawaiian',
                       'RaceWhite',
                       'IsInterestedInCampusHousing',
                       'IsInterestedInFinancialAid',
                       'PrimaryLanguage',
                       'Ethnicity',
                       'Gender',
                       'YearTerm']
fields_sql_verbatim = ['aid',
                       'PEOPLE_CODE_ID',
                       'GovernmentId',
                       'RaceAmericanIndian',
                       'RaceAsian',
                       'RaceAfricanAmerican',
                       'RaceNativeHawaiian',
                       'RaceWhite',
                       'IsInterestedInCampusHousing',
                       'IsInterestedInFinancialAid',
                       'RaceWhite',
                       'Ethnicity',
                       'DemographicsEthnicity',
                       'AdmitDate',
                       'AppStatus',
                       'AppStatusDate',
                       'AppDecision',
                       'AppDecisionDate',
                       'Counselor',
                       'CreateDateTime',
                       'SMSOptIn',
                       'Department',
                       'Extracurricular',
                       'Nontraditional',
                       'Population',
                       'Matriculated']

fields = {k: {"supply": True} for k in fields_null}

new = {k: {"type": bool} for k in fields_bool}
fields = merge(fields, new)

new = {k: {"type": int} for k in fields_int}
fields = merge(fields, new)

new = {k: {"api_verbatim": True} for k in fields_api_verbatim}
fields = merge(fields, new)

new = {k: {"sql_verbatim": True} for k in fields_sql_verbatim}
fields = merge(fields, new)

for f in fields:
    if 'supply' not in fields[f]:
        fields[f]['supply'] = False
    if 'type' not in fields[f]:
        fields[f]['type'] = str
    if 'api_verbatim' not in fields[f]:
        fields[f]['api_verbatim'] = False
    if 'sql_verbatim' not in fields[f]:
        fields[f]['sql_verbatim'] = False

pp = pprint.PrettyPrinter(indent=4)
pp.pprint(fields)
