import requests
import json
from copy import deepcopy
from ps_format import (
    format_app_generic,
    format_app_api,
    format_app_sql,
    Edu_sync_result,
    Stop_from_Slate,
    Scholarship_from_Slate,
)
import ps_powercampus

# The Settings class should replace the CONFIG global in all new code.
class Settings:
    def __init__(self, config):
        self.fa_awards = self.FlatDict(config["fa_awards"])
        self.powercampus = self.PowerCampus(config["powercampus"])
        self.console_verbose = config["console_verbose"]
        self.msg_strings = self.FlatDict(config["msg_strings"])
        self.validate_scholarship_levels = bool(
            self.PowerCampus(config["validate_scholarship_levels"])
        )

    class PowerCampus:
        def __init__(self, config):
            dicts = [k for k in config if type(config[k]) == dict]
            for field in config:
                if field not in dicts:
                    setattr(self, field, config[field])

            for d in dicts:
                setattr(self, d, Settings.FlatDict(config[d]))

    class FlatDict:
        def __init__(self, contents):
            for field in contents:
                setattr(self, field, contents[field])


def init(config_path):
    """Reads config file to global CONFIG dict. Many frequently-used variables are copied to their own globals for convenince."""
    global CONFIG
    global CONFIG_PATH
    global FIELDS
    global RM_MAPPING
    global MSG_STRINGS
    global SETTINGS  # New global for Settings class

    CONFIG_PATH = config_path
    with open(CONFIG_PATH) as file:
        CONFIG = json.loads(file.read())
    SETTINGS = Settings(CONFIG)

    RM_MAPPING = ps_powercampus.get_recruiter_mapping(
        SETTINGS.powercampus.mapping_file_location
    )
    MSG_STRINGS = CONFIG["msg_strings"]

    # Init PowerCampus API and SQL connections
    ps_powercampus.init(
        SETTINGS.powercampus, SETTINGS.console_verbose, SETTINGS.msg_strings
    )

    return CONFIG


def de_init():
    """Release resources like open SQL connections."""
    ps_powercampus.de_init()


def verbose_print(x):
    """Attempt to print JSON without altering it, serializable objects as JSON, and anything else as default."""
    if CONFIG["console_verbose"] and len(x) > 0:
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
    http_session.auth = (
        CONFIG["scheduled_actions"]["slate_get"]["username"],
        CONFIG["scheduled_actions"]["slate_get"]["password"],
    )

    actions_list = []

    while apps_list:
        counter = 0
        ql = []  # Queue list
        qs = ""  # Queue string
        al = []  # Temporary actions list

        # Pop up to 48 app GUID's and append to queue list.
        while apps_list and counter < 48:
            ql.append(apps_list.pop())
            counter += 1

        # Stuff them into a comma-separated string.
        qs = ",".join(str(item) for item in ql)

        r = http_session.get(
            CONFIG["scheduled_actions"]["slate_get"]["url"], params={"aids": qs}
        )
        r.raise_for_status()
        al = json.loads(r.text)
        actions_list.extend(al["row"])
        # if len(al['row']) > 1: # Delete. I don't think an application could ever have zero actions.

    http_session.close()

    return actions_list


def slate_post_generic(upload_list, config_dict):
    """Upload a simple list of dicts to Slate."""

    # Dedup list
    upload_list = [dict(t) for t in {tuple(sorted(d.items())) for d in upload_list}]

    # Slate requires JSON to be convertable to XML
    upload_dict = {"row": upload_list}

    creds = (config_dict["username"], config_dict["password"])
    r = requests.post(config_dict["url"], json=upload_dict, auth=creds)
    r.raise_for_status()


def slate_post_apps_changed(apps, config_dict):
    # Check for changes between Slate and local state
    # Upload changed records back to Slate

    # Build list of flat app dicts with only certain fields included
    upload_list = []
    fields = deepcopy(config_dict["fields_string"])
    fields.extend(config_dict["fields_bool"])
    fields.extend(config_dict["fields_int"])

    if len(fields) == 1:
        return

    for app in apps.values():
        CURRENT_RECORD = app["aid"]
        upload_list.append(
            {k: v for (k, v) in app.items() if k in fields and v != app["compare_" + k]}
            | {"aid": app["aid"]}
        )

    # Apps with no changes will only contain {'aid': 'xxx'}
    # Only retain items that have more than one field
    upload_list[:] = [app for app in upload_list if len(app) > 1]

    if len(upload_list) > 0:
        # Slate requires JSON to be convertable to XML
        upload_dict = {"row": upload_list}

        creds = (config_dict["username"], config_dict["password"])
        r = requests.post(config_dict["url"], json=upload_dict, auth=creds)
        r.raise_for_status()

    msg = (
        "\t"
        + str(len(upload_list))
        + " of "
        + str(len(apps))
        + " apps had changed fields"
    )
    return msg


def slate_post_fields(apps, config_dict):
    # Build list of flat app dicts with only certain fields included
    upload_list = []
    fields = ["aid"]
    fields.extend(config_dict["fields"])

    for app in apps.values():
        CURRENT_RECORD = app["aid"]
        upload_list.append({k: v for (k, v) in app.items() if k in fields})

    # Slate requires JSON to be convertable to XML
    upload_dict = {"row": upload_list}

    creds = (config_dict["username"], config_dict["password"])
    r = requests.post(config_dict["url"], json=upload_dict, auth=creds)
    r.raise_for_status()


def slate_post_fa_checklist(upload_list):
    """Upload Financial Aid Checklist to Slate."""

    if len(upload_list) > 0:
        # Slate's Checklist Import (Financial Aid) requires tab-separated files because it's old and crusty, apparently.
        tab = "\t"
        slate_fa_string = "AppID" + tab + "Code" + tab + "Status" + tab + "Date"
        for i in upload_list:
            line = (
                i["AppID"] + tab + str(i["Code"]) + tab + i["Status"] + tab + i["Date"]
            )
            slate_fa_string = slate_fa_string + "\n" + line

        creds = (
            CONFIG["fa_checklist"]["slate_post"]["username"],
            CONFIG["fa_checklist"]["slate_post"]["password"],
        )
        r = requests.post(
            CONFIG["fa_checklist"]["slate_post"]["url"],
            data=slate_fa_string,
            auth=creds,
        )
        r.raise_for_status()


def slate_post_education_changed(edu_list, config_dict):
    """Upload changed School records back to Slate."""

    upload_list = []

    for e in edu_list:
        e = Edu_sync_result(e)
        if e.org_found != e.compare_org_found:
            upload_list.append(e.dump_to_slate())

    if len(upload_list) > 0:
        slate_post_generic(upload_list, config_dict)

    msg = (
        "\t"
        + str(len(upload_list))
        + " of "
        + str(len(edu_list))
        + " education records had changed fields"
    )
    return msg


def learn_actions(actions_list):
    global CONFIG
    action_ids = []
    admissions_action_codes = CONFIG["scheduled_actions"]["admissions_action_codes"]

    for action_id in actions_list:
        for k, v in action_id.items():
            if k == "action_id":
                action_ids.append(v)
    learned_actions = [k for k in action_ids if k not in admissions_action_codes]

    # Dedupe
    learned_actions = list(set(learned_actions))

    # Sanity check against PowerCampus
    for action_id in learned_actions:
        action_def = ps_powercampus.get_action_definition(action_id)
        if action_def is None:
            learned_actions.remove(action_id)

    admissions_action_codes += learned_actions

    # Write new config
    with open(CONFIG_PATH, mode="w") as file:
        json.dump(CONFIG, file, indent="\t")


def main_sync(pid=None):
    """Main body of the program.

    Keyword arguments:
    pid -- specific application GUID to sync (default None)
    """
    global CURRENT_RECORD
    global RM_MAPPING
    sync_errors = False

    verbose_print("Get applicants from Slate...")
    creds = (
        CONFIG["slate_query_apps"]["username"],
        CONFIG["slate_query_apps"]["password"],
    )
    if pid is not None:
        r = requests.get(
            CONFIG["slate_query_apps"]["url"], auth=creds, params={"pid": pid}
        )
    else:
        r = requests.get(CONFIG["slate_query_apps"]["url"], auth=creds)
    r.raise_for_status()
    apps = json.loads(r.text)["row"]
    verbose_print("\tFetched " + str(len(apps)) + " apps")

    # Make a dict of apps with application GUID as the key
    # {AppGUID: { JSON from Slate }
    apps = {k["aid"]: k for k in apps}
    if len(apps) == 0 and pid is not None:
        # Assuming we're running in interactive (HTTP) mode if pid param exists
        raise EOFError(MSG_STRINGS["error_no_apps"])
    elif len(apps) == 0:
        # Don't raise an error for scheduled mode
        return None

    verbose_print("Clean up app data from Slate (datatypes, supply nulls, etc.)")
    for k, v in apps.items():
        CURRENT_RECORD = k
        apps[k] = format_app_generic(v, CONFIG["slate_upload_active"])

    if SETTINGS.powercampus.autoconfigure_mappings.enabled:
        verbose_print("Auto-configure ProgramOfStudy and recruiterMapping.xml")
        CURRENT_RECORD = None
        mfl = SETTINGS.powercampus.mapping_file_location
        vd = SETTINGS.powercampus.autoconfigure_mappings.validate_degreq
        mdy = SETTINGS.powercampus.autoconfigure_mappings.minimum_degreq_year
        dp_list = [
            (apps[app]["Program"], apps[app]["Degree"])
            for app in apps
            if "Degree" in apps[app]
        ]
        yt_list = [apps[app]["YearTerm"] for app in apps if "YearTerm" in apps[app]]

        if ps_powercampus.autoconfigure_mappings(dp_list, yt_list, vd, mdy, mfl):
            RM_MAPPING = ps_powercampus.get_recruiter_mapping(mfl)

    verbose_print("Check each app's status flags/PCID in PowerCampus")
    for k, v in apps.items():
        CURRENT_RECORD = k
        status_ra, status_app, status_calc, pcid = ps_powercampus.scan_status(v)
        apps[k].update(
            {
                "status_ra": status_ra,
                "status_app": status_app,
                "status_calc": status_calc,
            }
        )
        apps[k]["PEOPLE_CODE_ID"] = pcid

    verbose_print("Post new or repost unprocessed applications to PowerCampus API")
    for k, v in apps.items():
        CURRENT_RECORD = k
        if (v["status_ra"] == None) or (
            v["status_ra"] in (1, 2) and v["status_app"] is None
        ):
            pcid = ps_powercampus.post_api(
                format_app_api(v, CONFIG["defaults"]),
                MSG_STRINGS,
                SETTINGS.powercampus.app_form_setting_id,
            )
            apps[k]["PEOPLE_CODE_ID"] = pcid

            # Rescan status
            status_ra, status_app, status_calc, pcid = ps_powercampus.scan_status(v)
            apps[k].update(
                {
                    "status_ra": status_ra,
                    "status_app": status_app,
                    "status_calc": status_calc,
                }
            )
            apps[k]["PEOPLE_CODE_ID"] = pcid

    verbose_print("Get scheduled actions from Slate")
    if CONFIG["scheduled_actions"]["enabled"] == True:
        CURRENT_RECORD = None
        # Send list of app GUID's to Slate; get back checklist items
        actions_list = slate_get_actions(
            [k for (k, v) in apps.items() if v["status_calc"] == "Active"]
        )

        if CONFIG["scheduled_actions"]["autolearn_action_codes"] == True:
            learn_actions(actions_list)

    verbose_print("Update existing applications in PowerCampus and extract information")
    edu_sync_results = []
    for k, v in apps.items():
        CURRENT_RECORD = k
        if v["status_calc"] == "Active":
            # Transform to PowerCampus format
            app_pc = format_app_sql(v, RM_MAPPING, SETTINGS.powercampus)
            pcid = app_pc["PEOPLE_CODE_ID"]
            academic_year = app_pc["ACADEMIC_YEAR"]
            academic_term = app_pc["ACADEMIC_TERM"]
            academic_session = app_pc["ACADEMIC_SESSION"]

            # Single-row updates
            if SETTINGS.powercampus.update_academic_key:
                ps_powercampus.update_academic_key(app_pc)
            ps_powercampus.update_demographics(app_pc)
            ps_powercampus.update_academic(app_pc)
            ps_powercampus.update_smsoptin(app_pc)

            # Update PowerCampus Scheduled Actions
            if CONFIG["scheduled_actions"]["enabled"] == True:
                app_actions = [
                    k for k in actions_list if k["aid"] == v["aid"] and "action_id" in k
                ]

                for action in app_actions:
                    ps_powercampus.update_action(
                        action, pcid, academic_year, academic_term, academic_session
                    )

                ps_powercampus.cleanup_actions(
                    CONFIG["scheduled_actions"]["admissions_action_codes"],
                    app_actions,
                    pcid,
                    academic_year,
                    academic_term,
                    academic_session,
                )

            # Update PowerCampus Education records
            if "Education" in app_pc:
                apps[k]["schools_not_found"] = []
                for edu in app_pc["Education"]:
                    edu_sync_results.append(
                        ps_powercampus.update_education(pcid, app_pc["pid"], edu)
                        | {k: v for (k, v) in edu.items() if k == "compare_org_found"}
                    )

            # Update PowerCampus Test Score records
            if "TestScoresNumeric" in app_pc:
                for test in app_pc["TestScoresNumeric"]:
                    ps_powercampus.update_test_scores(pcid, test)

            # Update any PowerCampus Notes defined in config
            for note in SETTINGS.powercampus.notes:
                if (
                    note["slate_field"] in app_pc
                    and len(app_pc[note["slate_field"]]) > 0
                ):
                    ps_powercampus.update_note(
                        app_pc, note["slate_field"], note["office"], note["note_type"]
                    )

            # Update any PowerCampus User Defined fields defined in config
            for udf in SETTINGS.powercampus.user_defined_fields:
                if udf["slate_field"] in app_pc and len(app_pc[udf["slate_field"]]) > 0:
                    ps_powercampus.update_udf(
                        app_pc, udf["slate_field"], udf["pc_field"]
                    )

            # Update PowerCampus Stops
            if "Stops" in app_pc:
                for stop in app_pc["Stops"]:
                    stop = Stop_from_Slate(stop)
                    ps_powercampus.update_stop(pcid, stop)

            # Update PowerCampus Scholarships
            if "Scholarships" in app_pc:
                for scholarship in app_pc["Scholarships"]:
                    scholarship = Scholarship_from_Slate(scholarship)
                    ps_powercampus.update_scholarship(
                        pcid,
                        scholarship,
                        SETTINGS.validate_scholarship_levels,
                    )

            # Collect information
            (
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
                custom_1,
                custom_2,
                custom_3,
                custom_4,
                custom_5,
            ) = ps_powercampus.get_profile(
                app_pc, SETTINGS.powercampus.campus_emailtype
            )
            apps[k].update(
                {
                    "error_flag": error_flag,
                    "error_message": error_message,
                    "registered": registered,
                    "reg_date": reg_date,
                    "readmit": readmit,
                    "withdrawn": withdrawn,
                    "credits": credits,
                    "campus_email": campus_email,
                    "advisor": advisor,
                    "sso_id": sso_id,
                    "custom_1": custom_1,
                    "custom_2": custom_2,
                    "custom_3": custom_3,
                    "custom_4": custom_4,
                    "custom_5": custom_5,
                }
            )
            if error_flag == True:
                sync_errors == True

            # Get PowerFAIDS awards and tracking status
            if SETTINGS.fa_awards.enabled:
                fa_awards, fa_status = ps_powercampus.pf_get_awards(
                    pcid,
                    v["GovernmentId"],
                    academic_year,
                    academic_term,
                    academic_session,
                )
                apps[k].update({"fa_awards": fa_awards, "fa_status": fa_status})

    verbose_print("Upload passive fields back to Slate")
    slate_post_fields(apps, CONFIG["slate_upload_passive"])

    verbose_print("Upload active (changed) fields back to Slate")
    verbose_print(slate_post_apps_changed(apps, CONFIG["slate_upload_active"]))

    if len(edu_sync_results) > 0 and edu_sync_results[0] is not None:
        verbose_print("Upload education records sync status back to Slate")
        verbose_print(
            slate_post_education_changed(
                edu_sync_results, CONFIG["slate_upload_schools"]
            )
        )

    # Collect Financial Aid checklist and upload to Slate
    if CONFIG["fa_checklist"]["enabled"] == True:
        verbose_print("Collect Financial Aid checklist and upload to Slate")
        slate_upload_list = []
        # slate_upload_fields = {'AppID', 'Code', 'Status', 'Date'}

        for k, v in apps.items():
            CURRENT_RECORD = k
            if v["status_calc"] == "Active":
                # Transform to PowerCampus format
                app_pc = format_app_sql(v, RM_MAPPING, SETTINGS.powercampus)

                fa_checklists = ps_powercampus.pf_get_fachecklist(
                    app_pc["PEOPLE_CODE_ID"],
                    v["GovernmentId"],
                    v["AppID"],
                    app_pc["ACADEMIC_YEAR"],
                    app_pc["ACADEMIC_TERM"],
                    app_pc["ACADEMIC_SESSION"],
                )

                slate_upload_list = slate_upload_list + fa_checklists

        slate_post_fa_checklist(slate_upload_list)

    # Warn if any apps returned an error flag from ps_powercampus.get_profile()
    if sync_errors == True:
        output_msg = MSG_STRINGS["sync_done_not_found"]
    else:
        output_msg = MSG_STRINGS["sync_done"]
    verbose_print(output_msg)

    return output_msg
