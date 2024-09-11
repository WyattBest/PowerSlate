from copy import deepcopy
from string import ascii_letters, punctuation, whitespace
import ps_models


# Newer data points are implemented as classes. Older ones are implemented in ps_models.py
class Edu_sync_result:
    def __init__(self, sync_result):
        self.pid = sync_result["pid"]
        self.school_guid = sync_result["school_guid"]
        self.org_found = bool(sync_result["org_found"])
        if "compare_org_found" in sync_result:
            self.compare_org_found = format_strtobool(sync_result["compare_org_found"])
        else:
            self.compare_org_found = None

    def dump_to_slate(self):
        return {
            "pid": self.pid,
            "school_guid": self.school_guid,
            "org_found": self.org_found,
        }


class Stop_from_Slate:
    def __init__(self, row):
        self.stop_code = row["StopCode"]
        self.stop_date = row["StopDate"]
        self.cleared = format_strtobool(row["Cleared"])
        if "ClearedDate" in row:
            self.cleared_date = row["ClearedDate"]
        else:
            self.cleared_date = None
        if "Comments" in row:
            self.comments = format_blank_to_null(row["Comments"])
        elif "comments" in row:
            self.comments = format_blank_to_null(row["comments"])
        else:
            self.comments = None


class Scholarship_from_Slate:
    def __init__(self, row):
        yts = row["YearTerm"]
        if yts.count("/") == 1:
            self.year, self.term = yts.split("/")
        elif yts.count("/") == 2:
            self.year, self.term, s = yts.split("/")
        else:
            raise ValueError(
                "Scholarships.YearTerm is not in a valid format. Example 2024/SPRING or 2024/SPRING/01."
            )

        self.scholarship = row["Scholarship"]
        if "Department" in row:
            self.department = row["Department"]
        else:
            self.department = None
        self.level = row["Level"]
        self.status = row["Status"]
        if "StatusDate" in row:
            self.status_date = row["StatusDate"]
        else:
            self.status_date = None
        if "AppliedAmount" in row:
            self.applied_amount = row["AppliedAmount"]
        else:
            self.applied_amount = None
        self.awarded_amount = row["AwardedAmount"]
        if "Notes" in row:
            self.notes = format_blank_to_null(row["Notes"])
        else:
            self.notes = None


class Association_from_Slate:
    def __init__(self, row):
        yts = row["YearTerm"]
        if yts.count("/") == 1:
            self.year, self.term = yts.split("/")
            self.session = ""
        elif yts.count("/") == 2:
            self.year, self.term, self.session = yts.split("/")
        elif yts.isdigit() == True and int(yts) > 1000:
            self.year = yts
            self.term = ""
            self.session = ""
        else:
            raise ValueError(
                "Associations.YearTerm is not in a valid format. Example 2024 or 2024/SPRING or 2024/SPRING/01."
            )
        self.association = row["Association"]
        self.office_held = row["OfficeHeld"]


# Should I perhaps have a class like ApplicationRecord that handles datatype transformations, supplying nulls, etc?


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
    if x == "":
        ret = None
    # Finished scrubbing
    return ret


def format_phone_number(number):
    """Strips anything but digits from a phone number and removes US country code."""
    non_digits = str.maketrans(
        {c: None for c in ascii_letters + punctuation + whitespace}
    )
    number = number.translate(non_digits)

    if len(number) == 11 and number[:1] == "1":
        number = number[1:]

    return number


def format_strtobool(s):
    if type(s) is bool:
        return s
    elif s is not None and s.lower() in ["true", "1", "y", "yes"]:
        return True
    elif s is not None and s.lower() in ["false", "0", "n", "no"]:
        return False
    else:
        return None


def format_str_digits(s):
    """Return only digits from a string."""
    non_digits = str.maketrans(
        {c: None for c in ascii_letters + punctuation + whitespace}
    )
    return s.translate(non_digits)


def format_app_generic(app, cfg_fields):
    """Supply missing fields and correct datatypes. Returns a flat dict."""

    mapped = format_blank_to_null(app)
    mapped["error_flag"] = False
    mapped["error_message"] = None

    fields_null = [k for (k, v) in ps_models.fields.items() if v["supply_null"] == True]
    fields_bool = [k for (k, v) in ps_models.fields.items() if v["type"] == bool]
    fields_int = [k for (k, v) in ps_models.fields.items() if v["type"] == int]
    fields_null.extend(["compare_" + field for field in cfg_fields["fields_string"]])
    fields_null.extend(["compare_" + field for field in cfg_fields["fields_bool"]])
    fields_null.extend(["compare_" + field for field in cfg_fields["fields_int"]])
    fields_bool.extend(["compare_" + field for field in cfg_fields["fields_bool"]])
    fields_int.extend(["compare_" + field for field in cfg_fields["fields_int"]])

    # Copy nullable strings from input to output, then fill in nulls
    mapped.update(
        {k: v for (k, v) in app.items() if k in fields_null and k not in mapped}
    )
    mapped.update({k: None for k in fields_null if k not in app})

    # Convert integers and booleans
    mapped.update({k: int(v) for (k, v) in app.items() if k in fields_int})
    mapped.update(
        {k: format_strtobool(v) for (k, v) in app.items() if k in fields_bool}
    )

    # Probably a stub in the API
    if "GovernmentDateOfEntry" not in app:
        mapped["GovernmentDateOfEntry"] = "0001-01-01T00:00:00"
    else:
        mapped["GovernmentDateOfEntry"] = app["GovernmentDateOfEntry"]

    # Academic program
    # API 9.2.3 still requires two fields for Program and Degree, even though the Swagger schema contains three fields.
    # Done here instead of in format_app_api() because format_app_sql() also needs these fields standardized.
    if "Curriculum" in app:
        mapped["Program"] = app["Program"]
        mapped["Degree"] = app["Degree"] + "/" + app["Curriculum"]
        mapped["Curriculum"] = None
    else:
        mapped["Program"] = app["Program"]
        mapped["Degree"] = app["Degree"]
        mapped["Curriculum"] = None

    # Pass through all other fields
    mapped.update({k: v for (k, v) in app.items() if k not in mapped})

    return mapped


def format_app_api(app, cfg_defaults, Messages):
    """Remap application to Recruiter/Web API format.

    Keyword arguments:
    app -- an application dict
    """

    mapped = {}
    error_flag = False
    error_message = None

    # Error checks
    if "YearTerm" not in app:
        error_message = Messages.error.missing_yt
        error_flag = True

    # Pass through fields
    fields_verbatim = [
        k for (k, v) in ps_models.fields.items() if v["api_verbatim"] == True
    ]
    mapped.update({k: v for (k, v) in app.items() if k in fields_verbatim})

    # Supply empty arrays. Implementing these would require more logic.
    fields_arr = ["Relationships", "Activities", "EmergencyContacts", "Education"]
    mapped.update({k: [] for k in fields_arr})

    # Nest up to ten addresses as a list of dicts
    # "Address1Line1": "123 St" becomes "Addresses": [{"Line1": "123 St"}]
    mapped["Addresses"] = [
        {
            k[8:]: v
            for (k, v) in app.items()
            if k[0:7] == "Address" and int(k[7:8]) - 1 == i and v is not None
        }
        for i in range(10)
    ]

    # Remove empty address dicts
    mapped["Addresses"] = [k for k in mapped["Addresses"] if len(k) > 0]

    # Supply missing keys
    for k in mapped["Addresses"]:
        if "Type" not in k:
            k["Type"] = 0
        # If any of  Line1-4 are missing, insert them with value = None
        k.update(
            {
                "Line" + str(i + 1): None
                for i in range(4)
                if "Line" + str(i + 1) not in k
            }
        )
        if "City" not in k:
            k["City"] = None
        if "StateProvince" not in k:
            k["StateProvince"] = None
        if "PostalCode" not in k:
            k["PostalCode"] = None
        if "Country" not in k:
            k["Country"] = cfg_defaults.address_country

    if len([k for k in app if k[:5] == "Phone"]) > 0:
        has_phones = True
    else:
        has_phones = False

    if has_phones == True:
        # Nest up to 9 phone numbers as a list of dicts.
        # Phones should be passed in as {Phone0Number: '...', Phone0Type: 1, Phone1Number: '...', Phone1Country: '...', Phone1Type: 0}
        # First phone in the list becomes Primary in PowerCampus (I think)
        mapped["PhoneNumbers"] = [
            {
                k[6:]: v
                for (k, v) in app.items()
                if k[:5] == "Phone" and int(k[5:6]) - 1 == i
            }
            for i in range(9)
        ]

        # Remove empty dicts
        mapped["PhoneNumbers"] = [k for k in mapped["PhoneNumbers"] if "Number" in k]

        # Supply missing keys and enforce datatypes
        for i, item in enumerate(mapped["PhoneNumbers"]):
            item["Number"] = format_phone_number(item["Number"])

            if "Type" not in item:
                item["Type"] = cfg_defaults.phone_type
            else:
                item["Type"] = int(item["Type"])

            if "Country" not in item:
                item["Country"] = cfg_defaults.phone_country

    else:
        # PowerCampus WebAPI requires Type -1 instead of a blank or null when not submitting any phones.
        mapped["PhoneNumbers"] = [{"Type": -1, "Country": None, "Number": None}]

    # Suspect Veteran logic was updated in API 9.2.x
    # Changed how this is handled to be less confusing.
    if app["Veteran"] is None:
        mapped["Veteran"] = None
        mapped["VeteranStatus"] = False
    else:
        mapped["Veteran"] = app["Veteran"]
        mapped["VeteranStatus"] = True

    mapped["Programs"] = [
        {
            "Program": app["Program"],
            "Degree": app["Degree"],
            "Curriculum": None,
        }
    ]

    # GUID's
    mapped["ApplicationNumber"] = app["aid"]
    mapped["ProspectId"] = app["pid"]

    return mapped, error_flag, error_message


def format_app_sql(app, mapping, config):
    """Remap application to PowerCampus SQL format.

    Keyword arguments:
    app -- an application dict
    mapping -- a mapping dict derived from recruiterMapping.xml
    config -- Settings class object
    """

    mapped = {}

    # Pass through fields
    fields_verbatim = [
        k for (k, v) in ps_models.fields.items() if v["sql_verbatim"] == True
    ]
    fields_verbatim.extend([n["slate_field"] for n in config.notes])
    fields_verbatim.extend([f["slate_field"] for f in config.user_defined_fields])
    mapped.update({k: v for (k, v) in app.items() if k in fields_verbatim})

    # Gender is hardcoded into the PowerCampus Web API, but [WebServices].[spSetDemographics] has different hardcoded values.
    # API None  =   Error
    # API ''    =   Not tested
    # API 0     =   Application 1   =   GUI Male
    # API 1     =   Application 2   =   GUI Female
    # API 2     =   Application 3   =   GUI Unknown
    # API 3     =   Application 3   =   GUI Unknown
    # spSetDemographics 1 = Male
    # spSetDemographics 2 = Female
    # spSetDemographics 3 = Unknown
    gender_map = {None: 3, 0: 1, 1: 2, 2: 3}
    mapped["GENDER"] = gender_map[app["Gender"]]

    mapped["ACADEMIC_YEAR"] = mapping["AcademicTerm"]["PCYearCodeValue"][
        app["YearTerm"]
    ]
    mapped["ACADEMIC_TERM"] = mapping["AcademicTerm"]["PCTermCodeValue"][
        app["YearTerm"]
    ]
    mapped["ACADEMIC_SESSION"] = mapping["AcademicTerm"]["PCSessionCodeValue"][
        app["YearTerm"]
    ]

    mapped["PROGRAM"] = mapping["AcademicLevel"][app["Program"]]
    mapped["DEGREE"] = mapping["AcademicProgram"]["PCDegreeCodeValue"][app["Degree"]]
    mapped["CURRICULUM"] = mapping["AcademicProgram"]["PCCurriculumCodeValue"][
        app["Degree"]
    ]

    if app["PrimaryCitizenship"] is not None:
        mapped["PRIMARYCITIZENSHIP"] = mapping["CitizenshipStatus"][
            app["PrimaryCitizenship"]
        ]
    else:
        mapped["PRIMARYCITIZENSHIP"] = None

    if app["SecondaryCitizenship"] is not None:
        mapped["SECONDARYCITIZENSHIP"] = mapping["CitizenshipStatus"][
            app["SecondaryCitizenship"]
        ]
    else:
        mapped["SECONDARYCITIZENSHIP"] = None

    if app["CollegeAttendStatus"] is not None:
        mapped["COLLEGE_ATTEND"] = mapping["CollegeAttend"][app["CollegeAttendStatus"]]
    else:
        mapped["COLLEGE_ATTEND"] = None

    if app["Visa"] is not None:
        mapped["VISA"] = mapping["Visa"][app["Visa"]]
    else:
        mapped["VISA"] = None

    if app["MaritalStatus"] is not None:
        mapped["MARITALSTATUS"] = mapping["MaritalStatus"][app["MaritalStatus"]]
    else:
        mapped["MARITALSTATUS"] = None

    if app["Religion"] is not None:
        mapped["Religion"] = mapping["Religion"][app["Religion"]]
    else:
        mapped["Religion"] = None

    if app["PrimaryLanguage"] is not None:
        mapped["PRIMARY_LANGUAGE"] = mapping["Language"][app["PrimaryLanguage"]]
    else:
        mapped["PRIMARY_LANGUAGE"] = None

    if "HomeLanguage" in app:
        mapped["HOME_LANGUAGE"] = mapping["Language"][app["HomeLanguage"]]
    else:
        mapped["HOME_LANGUAGE"] = None

    if "Campus" in app:
        mapped["OrganizationId"] = mapping["Campus"][app["Campus"]]
    else:
        mapped["OrganizationId"] = None

    # Format Education and TestScoresNumeric if present. Newer arrays are implemented as classes.
    # Currently only supplies nulls; no datatype manipulations performed.
    array_models = ps_models.get_arrays()
    array_names = [k for (k, v) in array_models.items() if k in app]

    for array in array_names:
        mapped[array] = deepcopy(app[array])
        fields_null = [
            k for (k, v) in array_models[array].items() if v["supply_null"] == True
        ]

        # Supply nulls
        for item in mapped[array]:
            item.update({k: v for (k, v) in item.items() if k in fields_null})
            item.update({k: None for k in fields_null if k not in item})

    # Pass through arrays implemented as classes
    array_classes = ["Stops", "Scholarships", "Associations"]
    for array in array_classes:
        if array in app:
            mapped[array] = app[array]

    # Look for array names with numbers appended and combine them
    # Example: "Stops1", "Stops2", "Stops3" become "Stops"
    array_numbers = [k for k in app if k[-1].isdigit() and k[:-1] in array_classes]
    for array in array_numbers:
        mapped[array[:-1]].extend(app[array])

    return mapped
