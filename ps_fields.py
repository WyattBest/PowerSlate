# class Field:
#     def __init__(self, name, nullable, datatype, use_api, use_sql):
#         self.name = name
#         self.nullable = nullable
#         self.datatype = datatype
#         self.use_api = use_api
#         self.use_sql = use_sql


# fields = []
# fields.extend(Field("AdmitDate", True, "generic", False, True))
# fields.extend(Field("Extracurricular", True, "boolean", False, True))

fields = {
    'AdmitDate': {'api_verbatim': False,
                  'sql_verbatim': True,
                  'supply_null': True,
                  'type': str},
    'AppDecision': {'api_verbatim': False,
                    'sql_verbatim': True,
                    'supply_null': True,
                    'type': str},
    'AppDecisionDate': {'api_verbatim': False,
                        'sql_verbatim': True,
                        'supply_null': True,
                        'type': str},
    'AppStatus': {'api_verbatim': False,
                  'sql_verbatim': True,
                  'supply_null': True,
                  'type': str},
    'AppStatusDate': {'api_verbatim': False,
                      'sql_verbatim': True,
                      'supply_null': True,
                      'type': str},
    'BirthDate': {'api_verbatim': True,
                  'sql_verbatim': False,
                  'supply_null': False,
                  'type': str},
    'Campus': {'api_verbatim': True,
               'sql_verbatim': False,
               'supply_null': False,
               'type': str},
    'CitizenshipStatus': {'api_verbatim': True,
                          'sql_verbatim': False,
                          'supply_null': True,
                          'type': str},
    'CollegeAttendStatus': {'api_verbatim': True,
                            'sql_verbatim': False,
                            'supply_null': True,
                            'type': str},
    'Commitment': {'api_verbatim': True,
                   'sql_verbatim': False,
                   'supply_null': True,
                   'type': str},
    'Counselor': {'api_verbatim': False,
                  'sql_verbatim': True,
                  'supply_null': True,
                  'type': str},
    'CountryOfBirth': {'api_verbatim': True,
                       'sql_verbatim': False,
                       'supply_null': True,
                       'type': str},
    'CreateDateTime': {'api_verbatim': True,
                       'sql_verbatim': True,
                       'supply_null': False,
                       'type': str},
    'DemographicsEthnicity': {'api_verbatim': False,
                              'sql_verbatim': True,
                              'supply_null': True,
                              'type': str},
    'Department': {'api_verbatim': False,
                   'sql_verbatim': True,
                   'supply_null': True,
                   'type': str},
    'Disabilities': {'api_verbatim': True,
                     'sql_verbatim': False,
                     'supply_null': True,
                     'type': str},
    'Email': {'api_verbatim': True,
              'sql_verbatim': False,
              'supply_null': False,
              'type': str},
    'Ethnicity': {'api_verbatim': True,
                  'sql_verbatim': True,
                  'supply_null': False,
                  'type': int},
    'Extracurricular': {'api_verbatim': False,
                        'sql_verbatim': True,
                        'supply_null': True,
                        'type': bool},
    'FirstName': {'api_verbatim': True,
                  'sql_verbatim': False,
                  'supply_null': False,
                  'type': str},
    'FormerFirstName': {'api_verbatim': True,
                        'sql_verbatim': False,
                        'supply_null': True,
                        'type': str},
    'FormerLastName': {'api_verbatim': True,
                       'sql_verbatim': False,
                       'supply_null': True,
                       'type': str},
    'Gender': {'api_verbatim': True,
               'sql_verbatim': False,
               'supply_null': False,
               'type': int},
    'GovernmentId': {'api_verbatim': True,
                     'sql_verbatim': True,
                     'supply_null': True,
                     'type': str},
    'IsInterestedInCampusHousing': {'api_verbatim': True,
                                    'sql_verbatim': True,
                                    'supply_null': False,
                                    'type': bool},
    'IsInterestedInFinancialAid': {'api_verbatim': True,
                                   'sql_verbatim': True,
                                   'supply_null': False,
                                   'type': bool},
    'LastName': {'api_verbatim': True,
                 'sql_verbatim': False,
                 'supply_null': False,
                 'type': str},
    'LastNamePrefix': {'api_verbatim': True,
                       'sql_verbatim': False,
                       'supply_null': True,
                       'type': str},
    'LegalName': {'api_verbatim': True,
                  'sql_verbatim': False,
                  'supply_null': True,
                  'type': str},
    'MaritalStatus': {'api_verbatim': True,
                      'sql_verbatim': False,
                      'supply_null': True,
                      'type': str},
    'Matriculated': {'api_verbatim': False,
                     'sql_verbatim': True,
                     'supply_null': True,
                     'type': bool},
    'MiddleName': {'api_verbatim': True,
                   'sql_verbatim': False,
                   'supply_null': True,
                   'type': str},
    'Nickname': {'api_verbatim': True,
                 'sql_verbatim': False,
                 'supply_null': True,
                 'type': str},
    'Nontraditional': {'api_verbatim': False,
                       'sql_verbatim': True,
                       'supply_null': True,
                       'type': str},
    'PEOPLE_CODE_ID': {'api_verbatim': False,
                       'sql_verbatim': True,
                       'supply_null': False,
                       'type': str},
    'Population': {'api_verbatim': False,
                   'sql_verbatim': True,
                   'supply_null': True,
                   'type': str},
    'Prefix': {'api_verbatim': True,
               'sql_verbatim': False,
               'supply_null': True,
               'type': str},
    'PrimaryCitizenship': {'api_verbatim': True,
                           'sql_verbatim': False,
                           'supply_null': True,
                           'type': str},
    'PrimaryLanguage': {'api_verbatim': True,
                        'sql_verbatim': False,
                        'supply_null': True,
                        'type': str},
    'ProposedDecision': {'api_verbatim': True,
                         'sql_verbatim': False,
                         'supply_null': True,
                         'type': str},
    'RaceAfricanAmerican': {'api_verbatim': True,
                            'sql_verbatim': True,
                            'supply_null': False,
                            'type': bool},
    'RaceAmericanIndian': {'api_verbatim': True,
                           'sql_verbatim': True,
                           'supply_null': False,
                           'type': bool},
    'RaceAsian': {'api_verbatim': True,
                  'sql_verbatim': True,
                  'supply_null': False,
                  'type': bool},
    'RaceNativeHawaiian': {'api_verbatim': True,
                           'sql_verbatim': True,
                           'supply_null': False,
                           'type': bool},
    'RaceWhite': {'api_verbatim': True,
                  'sql_verbatim': True,
                  'supply_null': False,
                  'type': bool},
    'Religion': {'api_verbatim': True,
                 'sql_verbatim': False,
                 'supply_null': True,
                 'type': str},
    'SMSOptIn': {'api_verbatim': False,
                 'sql_verbatim': True,
                 'supply_null': False,
                 'type': int},
    'SecondaryCitizenship': {'api_verbatim': True,
                             'sql_verbatim': False,
                             'supply_null': True,
                             'type': str},
    'Status': {'api_verbatim': True,
               'sql_verbatim': False,
               'supply_null': True,
               'type': str},
    'Suffix': {'api_verbatim': True,
               'sql_verbatim': False,
               'supply_null': True,
               'type': str},
    'Veteran': {'api_verbatim': False,
                'sql_verbatim': False,
                'supply_null': True,
                'type': str},
    'Visa': {'api_verbatim': True,
             'sql_verbatim': False,
             'supply_null': True,
             'type': str},
    'YearTerm': {'api_verbatim': True,
                 'sql_verbatim': False,
                 'supply_null': False,
                 'type': str},
    'aid': {'api_verbatim': False,
            'sql_verbatim': True,
            'supply_null': False,
            'type': str}
}