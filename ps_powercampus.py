import requests
import json
import pyodbc
import xml.etree.ElementTree as ET
import ps_models


def init(config, verbose):
    global CNXN
    global CURSOR
    global CONFIG
    global VERBOSE

    CONFIG = config
    VERBOSE = verbose

    # Microsoft SQL Server connection.
    CNXN = pyodbc.connect(config.database_string)
    CURSOR = CNXN.cursor()

    # Print a test of connections
    r = requests.get(config.api.url + "api/version")
    verbose_print("PowerCampus API Status: " + str(r.status_code))
    verbose_print(r.text)
    r.raise_for_status()
    verbose_print("Database:" + CNXN.getinfo(pyodbc.SQL_DATABASE_NAME))

    # Enable ApplicationFormSetting's ProcessAutomatically in case program exited abnormally last time with setting toggled off.
    update_app_form_autoprocess(config.api.app_form_setting_id, True)


def de_init():
    # Clean up connections.
    if CNXN:
        CNXN.close()  # SQL


def verbose_print(x):
    """Attempt to print JSON without altering it, serializable objects as JSON, and anything else as default."""
    if VERBOSE and len(x) > 0:
        if isinstance(x, str):
            print(x)
        else:
            try:
                print(json.dumps(x, indent=4))
            except:
                print(x)


def autoconfigure_mappings(
    program_list,
    yt_list,
    validate_degreq,
    minimum_degreq_year,
    mapping_file_location,
    app_form_setting_id,
):
    """
    Automatically insert new Program/Degree/Curriculum combinations into ProgramOfStudy and recruiterMapping.xml
    Automatically insert new Year/Term/Session combinations into recruiterMapping.xml
    Assumes Degree values from Slate are concatenated PowerCampus code values like DEGREE/CURRICULUM
    and that YearTerm values are like YEAR/TERM/SESSION.

    Keyword aguments:
    program_list -- list of tuples like [('PROGRAM','DEGREE/CURRICULUM'), (...)]
    yt_list -- list of strings like ['YEAR/TERM/SESSION', ...]
    validate_degreq -- bool. If True, check against DEGREQ for sanity using minimum_degreq_year.
    minimum_degreq_year -- str
    mapping_file_location -- str. Path to recruiterMapping.xml

    Returns True if XML mapping changed.
    """
    program_set = set(program_list)
    yt_set = set(yt_list)
    if validate_degreq == False:
        minimum_degreq_year = None

    # Create set of tuples like {('PROGRAM','DEGREE', 'CURRICULUM'), (...)}
    pdc_set = set()
    for dp in program_set:
        pdc = [dp[0]]
        for dc in dp[1].split("/"):
            pdc.append(dc)
        pdc_set.add(tuple(pdc))

    # Create a set like {'PROGRAM', 'PROGRAM'}
    p_set = set()
    for pdc in pdc_set:
        p_set.add(pdc[0])

    # Create set of tuples like {('DEGREE', 'CURRICULUM'), (...)}
    dc_set = set()
    for pdc in pdc_set:
        if len(pdc) < 3:
            raise ValueError(
                "Expected a value like ('PROGRAM', 'DEGREE', 'CURRICULM') but got "
                + str(pdc)
                + ". Program should be 'PROGRAM' and Degree/Curriculum should be 'DEGREE/CURRICULM'."
            )
        dc = (pdc[1], pdc[2])
        dc_set.add(dc)

    # Create set of tuples like {('YEAR', 'TERM', 'SESSION'), (...)}
    yts_set = set()
    for yt in yt_set:
        yts_set.add(tuple(yt.split("/")))
        # for yts in yt.split("/"):
        #     yts_set.add(tuple(yts))

    # Update ProgramOfStudy table; optionally validate against DEGREQ table
    for pdc in pdc_set:
        CURSOR.execute(
            "execute [custom].[PS_updProgramOfStudy] ?, ?, ?, ?, ?",
            pdc[0],
            pdc[1],
            pdc[2],
            minimum_degreq_year,
            app_form_setting_id,
        )
    CNXN.commit()

    # Validate against ACADEMICCALENDAR table
    for yts in yts_set:
        CURSOR.execute(
            "execute [custom].[PS_selAcademicCalendar] ?, ?, ?", yts[0], yts[1], yts[2]
        )
        row = CURSOR.fetchone()
        if row is None:
            raise Exception(
                "Year/Term/Session '"
                + str(yts)
                + "' not found in ACADEMICCALENDAR table."
            )

    # Update recruiterMapping.xml
    def check_for_duplicates(node):
        """Check for duplicate RCCodeValues and raise error if found."""
        rc_codes = [row.get("RCCodeValue") for row in node.findall("row")]
        if len(rc_codes) != len(set(rc_codes)):
            raise ValueError(
                f"recruiterMapping.xml contains duplicate RCCodeValue keys in node {node}."
            )

    xml_changed = False
    with open(mapping_file_location, encoding="utf-8-sig") as treeFile:
        tree = ET.parse(treeFile)
        root = tree.getroot()

    aca_level = root.find("AcademicLevel")
    check_for_duplicates(aca_level)

    for p in p_set:
        if aca_level.find("./row[@RCCodeValue='" + p + "']") is None:
            xml_changed = True
            attrib = {
                "RCCodeValue": p,
                "RCDesc": "",
                "PCCodeValue": p,
                "PCCodeDesc": "",
            }
            ET.SubElement(aca_level, "row", attrib=attrib)

    aca_prog = root.find("AcademicProgram")
    check_for_duplicates(aca_prog)

    for dc in dc_set:
        rc_code = dc[0] + "/" + dc[1]
        if aca_prog.find("./row[@RCCodeValue='" + rc_code + "']") is None:
            xml_changed = True
            attrib = {
                "RCCodeValue": rc_code,
                "RCDesc": "",
                "PCDegreeCodeValue": dc[0],
                "PCDegreeDesc": "",
                "PCCurriculumCodeValue": dc[1],
                "PCCurriculumDesc": "",
            }
            ET.SubElement(aca_prog, "row", attrib=attrib)

    aca_term = root.find("AcademicTerm")
    check_for_duplicates(aca_term)

    for yts in yts_set:
        rc_code = yts[0] + "/" + yts[1] + "/" + yts[2]
        if aca_term.find("./row[@RCCodeValue='" + rc_code + "']") is None:
            xml_changed = True
            attrib = {
                "RCCodeValue": rc_code,
                "RCDesc": "",
                "PCYearCodeValue": yts[0],
                "PCYearDesc": "",
                "PCTermCodeValue": yts[1],
                "PCTermDesc": "",
                "PCSessionCodeValue": yts[2],
                "PCSessionDesc": "",
            }
            ET.SubElement(aca_term, "row", attrib=attrib)

    if xml_changed:
        tree.write(mapping_file_location, encoding="utf-8", xml_declaration=True)

    return xml_changed


def get_recruiter_mapping(mapping_file_location):
    """
    Return a dict translating Recruiter values to PowerCampus values for direct SQL operations.

    mapping_file_location - Network path to recruiterMapping.xml
    """
    # PowerCampus Mapping Tool produces UTF-8 BOM encoded files.
    with open(mapping_file_location, encoding="utf-8-sig") as treeFile:
        tree = ET.parse(treeFile)
        root = tree.getroot()
    rm_mapping = {}

    for child in root:
        if child.get("NumberOfPowerCampusFieldsMapped") == "1":
            rm_mapping[child.tag] = {}
            for row in child:
                rm_mapping[child.tag].update(
                    {row.get("RCCodeValue"): row.get("PCCodeValue")}
                )

        if child.get("NumberOfPowerCampusFieldsMapped") == "2":
            fn1 = "PC" + str(child.get("PCFirstField")) + "CodeValue"
            fn2 = "PC" + str(child.get("PCSecondField")) + "CodeValue"
            rm_mapping[child.tag] = {fn1: {}, fn2: {}}

            for row in child:
                rm_mapping[child.tag][fn1].update(
                    {row.get("RCCodeValue"): row.get(fn1)}
                )
                rm_mapping[child.tag][fn2].update(
                    {row.get("RCCodeValue"): row.get(fn2)}
                )

        if child.get("NumberOfPowerCampusFieldsMapped") == "3":
            fn1 = "PC" + str(child.get("PCFirstField")) + "CodeValue"
            fn2 = "PC" + str(child.get("PCSecondField")) + "CodeValue"
            fn3 = "PC" + str(child.get("PCThirdField")) + "CodeValue"
            rm_mapping[child.tag] = {fn1: {}, fn2: {}, fn3: {}}

            for row in child:
                rm_mapping[child.tag][fn1].update(
                    {row.get("RCCodeValue"): row.get(fn1)}
                )
                rm_mapping[child.tag][fn2].update(
                    {row.get("RCCodeValue"): row.get(fn2)}
                )
                rm_mapping[child.tag][fn3].update(
                    {row.get("RCCodeValue"): row.get(fn3)}
                )

    return rm_mapping


def post_api(app, config, Messages):
    """Post an application to PowerCampus.
    Return  PEOPLE_CODE_ID if application was automatically accepted or None for all other conditions.

    Keyword arguments:
    x -- an application dict
    """

    creds = None
    headers = None
    if config.auth_method == "basic":
        creds = (config.username, config.password)
    elif config.auth_method == "token":
        headers = {"Authorization": config.token}

    # Check for duplicate person. If found, temporarily toggle auto-process off.
    dup_found = False
    CURSOR.execute("EXEC [custom].[PS_selPersonDuplicate] ?", app["GovernmentId"])
    row = CURSOR.fetchone()
    dup_found = row.DuplicateFound
    if dup_found:
        update_app_form_autoprocess(config.app_form_setting_id, False)

    # Expose error text response from API, replace useless error message(s).
    try:
        r = requests.post(
            config.url + "api/applications", json=app, auth=creds, headers=headers
        )
        r.raise_for_status()
        # The API returns 202 for mapping errors. Technically 202 is appropriate, but it should bubble up to the user.
        if r.status_code == 202:
            raise requests.HTTPError
    except requests.HTTPError as e:
        # Change newline handling so response text prints nicely in emails.
        rtext = r.text.replace("\r\n", "\n")

        if dup_found:
            update_app_form_autoprocess(config.app_form_setting_id, True)

        if (
            "BadRequest Object reference not set to an instance of an object." in rtext
            and "ApplicationsController.cs:line 183" in rtext
        ):
            raise ValueError(Messages.error.no_phones, rtext, e)
        elif (
            "BadRequest Activation error occured while trying to get instance of type Database, key"
            in rtext
            and "ServiceLocatorImplBase.cs:line 53" in rtext
        ):
            raise ValueError(Messages.error.api_missing_database, rtext, e)
        elif (
            r.status_code == 202
            and "was created successfully in PowerCampus" in r.text == False
        ) or r.status_code == 400:
            raise ValueError(rtext)
        elif "was created successfully in PowerCampus" not in r.text == False:
            raise requests.HTTPError(rtext)

    if dup_found:
        update_app_form_autoprocess(config.app_form_setting_id, True)

    if r.text[-25:-12] == "New People Id":
        try:
            people_code = r.text[-11:-2]
            # Error check. After slice because leading zeros need preserved.
            int(people_code)
            PEOPLE_CODE_ID = "P" + people_code
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

    CURSOR.execute("EXEC [custom].[PS_selRAStatus] ?", x["aid"])
    row = CURSOR.fetchone()

    if row is not None:
        ra_status = row.ra_status
        apl_status = row.apl_status
        pcid = row.PEOPLE_CODE_ID

        # Determine status.
        if row.ra_status in (0, 3, 4) and row.apl_status == 2 and pcid is not None:
            computed_status = "Active"
        elif row.ra_status in (0, 3, 4) and row.apl_status == 3 and pcid is None:
            computed_status = "Declined"
        elif row.ra_status in (0, 3, 4) and row.apl_status == 1 and pcid is None:
            computed_status = "Pending"
        elif row.ra_status == 1 and row.apl_status is None and pcid is None:
            computed_status = "Required field missing."
        elif row.ra_status == 2 and row.apl_status is None and pcid is None:
            computed_status = "Required field mapping is missing."
        else:
            computed_status = "Unrecognized Status: " + str(row.ra_status)

    return ra_status, apl_status, computed_status, pcid


def get_profile(app, campus_email_type, Messages):
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

    error_flag = True
    error_message = None
    registered = False
    reg_date = None
    readmit = False
    withdrawn = False
    credits = "0.00"
    campus_email = None
    advisor = None
    sso_id = None
    academic_guid = None
    custom_1 = None
    custom_2 = None
    custom_3 = None
    custom_4 = None
    custom_5 = None

    CURSOR.execute(
        "EXEC [custom].[PS_selProfile] ?, ?, ?, ?, ?, ?, ?, ?, ?",
        app["PEOPLE_CODE_ID"],
        app["ACADEMIC_YEAR"],
        app["ACADEMIC_TERM"],
        app["ACADEMIC_SESSION"],
        app["PROGRAM"],
        app["DEGREE"],
        app["CURRICULUM"],
        campus_email_type,
        app["AcademicGUID"],
    )
    row = CURSOR.fetchone()

    if row is None:
        # ACADEMIC row not found by YTSPDC or GUID.
        error_message = Messages.error.academic_row_not_found
    else:
        if row.ErrorFlag == 1:
            # ACADEMIC row found by GUID but YTSPDC does not match.
            error_message = row.ErrorMessage
        else:
            error_flag = False
            if row.Registered == "Y":
                registered = True
                reg_date = str(row.REG_VAL_DATE)
                credits = str(row.CREDITS)

            campus_email = row.CampusEmail
            advisor = row.AdvisorUsername
            sso_id = row.Username
            academic_guid = row.Guid
            custom_1 = row.custom_1
            custom_2 = row.custom_2
            custom_3 = row.custom_3
            custom_4 = row.custom_4
            custom_5 = row.custom_5

            # College Attend and Readmits
            college_attend = row.COLLEGE_ATTEND
            if college_attend == CONFIG.readmit_code:
                readmit = True
            elif college_attend == "" or college_attend is None:
                college_attend = "blank"

            if college_attend not in CONFIG.valid_college_attend:
                error_flag = True
                error_message = Messages.error.invalid_college_attend.format(
                    college_attend
                )

            if row.Withdrawn == "Y":
                withdrawn = True

    return (
        error_flag,
        error_message,
        registered,
        reg_date,
        readmit,
        withdrawn,
        credits,
        campus_email,
        advisor,
        sso_id,
        academic_guid,
        custom_1,
        custom_2,
        custom_3,
        custom_4,
        custom_5,
    )


def update_demographics(app):
    CURSOR.execute(
        "execute [custom].[PS_updDemographics] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",
        app["PEOPLE_CODE_ID"],
        "SLATE",
        app["GENDER"],
        app["Ethnicity"],
        app["DemographicsEthnicity"],
        app["MARITALSTATUS"],
        app["Religion"],
        app["VETERAN"],
        app["PRIMARYCITIZENSHIP"],
        app["SECONDARYCITIZENSHIP"],
        app["VISA"],
        app["RaceAfricanAmerican"],
        app["RaceAmericanIndian"],
        app["RaceAsian"],
        app["RaceNativeHawaiian"],
        app["RaceWhite"],
        app["PRIMARY_LANGUAGE"],
        app["HOME_LANGUAGE"],
        app["GovernmentId"],
    )
    CNXN.commit()


def update_academic(app):
    """ "
    Update ACADEMIC row data in PowerCampus.
    Work around PowerCampus defect CR-XXXXXXXXX, where the campus passed to the API isn't written to ACADEMIC:
        If ACADEMIC_FLAG isn't yet set to Y, update ACADEMIC.ORG_CODE_ID based on the passed OrganizationId.
    """
    CURSOR.execute(
        "exec [custom].[PS_updAcademicAppInfo] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",
        app["PEOPLE_CODE_ID"],
        app["ACADEMIC_YEAR"],
        app["ACADEMIC_TERM"],
        app["ACADEMIC_SESSION"],
        app["PROGRAM"],
        app["DEGREE"],
        app["CURRICULUM"],
        app["Department"],
        app["Nontraditional"],
        app["Population"],
        app["AdmitDate"],
        app["Matriculated"],
        app["OrganizationId"],
        app["AppStatus"],
        app["AppStatusDate"],
        app["AppDecision"],
        app["AppDecisionDate"],
        app["Counselor"],
        app["COLLEGE_ATTEND"],
        app["Extracurricular"],
        app["CreateDateTime"],
    )
    CNXN.commit()


def update_academic_key(app):
    """Track unique row GUID in custom.AcademicKey table and update PROGRAM/DEGREE/CURRICULUM columns in ACADEMIC table.
    P/C/D will only be updated if application is not registered and does not have an academic plan assigned.
    """
    CURSOR.execute(
        "exec [custom].[PS_updAcademicKey] ?, ?, ?, ?, ?, ?, ?, ?, ?",
        app["PEOPLE_CODE_ID"],
        app["ACADEMIC_YEAR"],
        app["ACADEMIC_TERM"],
        app["ACADEMIC_SESSION"],
        app["PROGRAM"],
        app["DEGREE"],
        app["CURRICULUM"],
        app["aid"],
        app["AcademicGUID"],
    )
    CNXN.commit()


def get_action_definition(action_id):
    CURSOR.execute("exec [custom].[PS_selActionDefinition] ?", action_id)
    row = CURSOR.fetchone()

    return row


def update_action(action, pcid, academic_year, academic_term, academic_session):
    """Update a Scheduled Action in PowerCampus.

    Keyword arguments:
    action -- dict like {'aid': GUID, 'item': 'Transcript', 'action_id': 'ADTRAN', ...}
    pcid -- string
    academic_year -- string
    academic_term -- string
    academic_session -- string
    """

    CURSOR.execute(
        "EXEC [custom].[PS_updAction] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",
        pcid,
        "SLATE",
        action["action_id"],
        action["item"],
        pcid,
        action["scheduled_date"],
        action["completed"],
        action["completed_date"],
        academic_year,
        academic_term,
        academic_session,
    )
    CNXN.commit()


def cleanup_actions(
    admissions_action_codes,
    app_actions,
    pcid,
    academic_year,
    academic_term,
    academic_session,
):
    """
    Delete orphaned Scheduled Actions from PowerCampus.

    admissions_actions -- list of action_id's to consider
    app_actions -- list of dicts from Slate, each representing a scheduled action
    pcid -- string PEOPLE_CODE_ID
    academic_year -- string
    academic_term -- string
    academic_session -- string
    """

    # Only keep keys we care about in app_actions
    keys = ["action_id", "item"]
    app_actions2 = []
    for action in app_actions:
        app_actions2.append({k: v for (k, v) in action.items() if k in keys})

    # Get actions from PowerCampus
    pc_actions = {}
    CURSOR.execute(
        "exec [custom].[PS_selActions] ?, ?, ?, ?, ?",
        pcid,
        "SLATE",
        academic_year,
        academic_term,
        academic_session,
    )
    for row in CURSOR.fetchall():
        pc_actions[row.ACTIONSCHEDULE_ID] = {
            "action_id": row.action_id,
            "item": row.item,
        }

    # Ignore actions types that are not part of admissions_action_codes
    pc_actions = {
        k: v
        for (k, v) in pc_actions.items()
        if v["action_id"] in admissions_action_codes
    }

    # Find actions in pc_actions but not in app_actions
    # This depends on exact matching between the dicts
    orphan_actions = [k for (k, v) in pc_actions.items() if v not in app_actions2]

    # Delete each orphaned action
    for actionschedule_id in orphan_actions:
        CURSOR.execute("exec [custom].[PS_delAction] ?", actionschedule_id)
        CNXN.commit()


def update_smsoptin(app):
    if "SMSOptIn" in app:
        CURSOR.execute(
            "exec [custom].[PS_updSMSOptIn] ?, ?, ?",
            app["PEOPLE_CODE_ID"],
            "SLATE",
            app["SMSOptIn"],
        )
        CNXN.commit()


def update_note(app, field, office, note_type):
    CURSOR.execute(
        "exec [custom].[PS_insNote] ?, ?, ?, ?",
        app["PEOPLE_CODE_ID"],
        office,
        note_type,
        app[field],
    )
    CNXN.commit()


def update_udf(app, slate_field, pc_field):
    CURSOR.execute(
        "exec [custom].[PS_updUserDefined] ?, ?, ?",
        app["PEOPLE_CODE_ID"],
        pc_field,
        app[slate_field],
    )
    CNXN.commit()


def update_education(pcid, pid, education):
    """Insert or update a row in the EDUCATION table. Return whether or not the org identifier was found in PowerCampus."""
    CURSOR.execute(
        "exec [custom].[PS_updEducation] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",
        pcid,
        education["OrgIdentifier"],
        education["Degree"],
        education["Curriculum"],
        education["GPA"],
        education["GPAUnweighted"],
        education["GPAUnweightedScale"],
        education["GPAWeighted"],
        education["GPAWeightedScale"],
        education["StartDate"],
        education["EndDate"],
        education["Honors"],
        education["TranscriptDate"],
        education["ClassRank"],
        education["ClassSize"],
        education["TransferCredits"],
        education["FinAidAmount"],
        education["Quartile"],
    )
    row = CURSOR.fetchone()
    CNXN.commit()
    org_found = row[0]

    output = {
        "pid": pid,
        "school_guid": education["GUID"],
        "org_found": org_found,
    }

    return output


def update_test_scores(pcid, test):
    """Insert or update a Test Scores row in PowerCampus."""
    # Identify which scores are present.
    score_types = [
        k
        for k in ps_models.get_arrays()["TestScoresNumeric"]
        if k[:5] == "Score" and k[-4:] == "Type" and k != "ScoreAlphaType"
    ]

    # Find the ScoreType to attach ScoreAlpha to
    # Error if ScoreAlphaType matches more than one ScoreType
    if test["ScoreAlphaType"] is not None:
        alpha_type_match = [
            k
            for (k, v) in test.items()
            if k in score_types and v == test["ScoreAlphaType"]
        ]
        if len(alpha_type_match) > 1:
            raise ValueError(
                "For numeric test types, AlphaScoreType cannot match more than one ScoreType.",
                alpha_type_match,
            )
    else:
        alpha_type_match = None

    scores_present = [k for k in test if k in score_types if test[k[:-4]] is not None]

    for k in scores_present:
        score_name = k[:-4]
        CURSOR.execute(
            "exec [custom].[PS_updTestscore] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",
            pcid,
            test["TestType"],
            test[k],
            test["TestDate"],
            test[score_name],
            test[score_name + "ConversionFactor"],
            test[score_name + "Converted"],
            test[score_name + "TranscriptPrint"],
            None,
            None,
            None,
            None,
            "SLATE",
        )

    if test["ScoreAlpha"] is not None:
        score_name = alpha_type_match[0]
        CURSOR.execute(
            "exec [custom].[PS_updTestscore] ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",
            pcid,
            test["TestType"],
            k,
            test["TestDate"],
            None,
            None,
            None,
            test[score_name + "TranscriptPrint"],
            test["ScoreAlpha"],
            None,
            None,
            None,
            "SLATE",
        )
    CNXN.commit()


def update_stop(pcid, stop):
    """Insert or update a row in STOPLIST.
    If StopCode and StopDate match an existing row, update the row. Otherwise, insert a new row.
    """
    CURSOR.execute(
        "exec [custom].[PS_updStop] ?, ?, ?, ?, ? ,? ,?",
        pcid,
        stop.stop_code,
        stop.stop_date,
        stop.cleared,
        stop.cleared_date,
        stop.comments,
        "SLATE",
    )
    CNXN.commit()


def update_app_form_autoprocess(app_form_setting_id, autoprocess):
    CURSOR.execute(
        "EXEC [custom].[PS_updApplicationFormSetting] ?,?",
        app_form_setting_id,
        autoprocess,
    )
    CNXN.commit()


def update_scholarship(pcid, scholarship, validate_scholarship_level):
    """Insert or update a row in PEOPLESCHOLARSHIP and PEOPLESCHOLARSHIPNOTES.
    Existing rows are matched on PCID, Year, Term, and Scholarship.
    Status and Status Date are inserted initially and only updated later if Department, Level, Applied Amount, or Awarded Amount change.
    """

    CURSOR.execute(
        "exec [custom].[PS_updScholarships] ?,?,?,?,?,?,?,?,?,?,?,?,?",
        pcid,
        scholarship.year,
        scholarship.term,
        scholarship.scholarship,
        scholarship.department,
        scholarship.level,
        scholarship.status,
        scholarship.status_date,
        scholarship.applied_amount,
        scholarship.awarded_amount,
        scholarship.notes,
        "SLATE",
        validate_scholarship_level,
    )
    CNXN.commit()


def update_association(pcid, association):
    """Insert a rows in ASSOCIATION if not already present.
    Existing rows are matched on PCID, Year, Term, Session, Association, and Office Held.
    """

    CURSOR.execute(
        "exec [custom].[PS_updAssociation] ?,?,?,?,?,?,?",
        pcid,
        association.year,
        association.term,
        association.session,
        association.association,
        association.office_held,
        "SLATE",
    )
    CNXN.commit()


def pf_get_fachecklist(pcid, govid, appid, year, term, session):
    """Return the PowerFAIDS missing docs list for uploading to Financial Aid Checklist."""
    checklist = []
    CURSOR.execute(
        "exec [custom].[PS_selPFChecklist] ?, ?, ?, ?, ?",
        pcid,
        govid,
        year,
        term,
        session,
    )

    columns = [column[0] for column in CURSOR.description]
    for row in CURSOR.fetchall():
        checklist.append(dict(zip(columns, row)))

    # Pass through the Slate Application ID
    for doc in checklist:
        doc["AppID"] = appid

    return checklist


def pf_get_awards(pcid, govid, year, term, session):
    """Return the PowerFAIDS awards list as XML and the Tracking Status."""
    awards = None
    tracking_status = None

    CURSOR.execute(
        "exec [custom].[PS_selPFAwardsXML] ?, ?, ?, ?, ?",
        pcid,
        govid,
        year,
        term,
        session,
    )
    row = CURSOR.fetchone()

    if row is not None:
        awards = row.XML
        tracking_status = row.tracking_status

    return awards, tracking_status
