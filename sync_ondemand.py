import sys
import json
import datetime
import traceback
from urllib.parse import urlparse
import ps_core

# Additional modules imported below if sending error email becomes necessary

# Attempt a sync; send failure email with traceback if error.
# Name of configuration is file passed via command-line
if __name__ == "__main__":
    try:
        print("Start sync at " + str(datetime.datetime.now()))
        ps_core.init(sys.argv[1])
        ps_core.main_sync()
        print("Done at " + str(datetime.datetime.now()))
    except Exception as e:
        # There's got to be a better way to handle this.
        try:
            current_record = ps_core.CURRENT_RECORD
        except AttributeError:
            current_record = None

        # Close SQL connections
        ps_core.de_init()

        with open(sys.argv[1]) as config_file:
            config = json.load(config_file)
            email_config = config["email"]
            teams_config = config["teams"]
            if current_record:
                slate_domain = urlparse(config["slate_query_apps"]["url"]).netloc
                current_record_link = (
                    "https://"
                    + slate_domain
                    + "/manage/lookup/record?id="
                    + str(current_record)
                )
            else:
                current_record_link = "None"
        print(
            "Exception at "
            + str(datetime.datetime.now())
            + "! Check notification email."
        )
        body = (
            "Sync failed at "
            + str(datetime.datetime.now())
            + "\n\nError: "
            + str(traceback.format_exc())
            + "\nCurrent Record: "
            + current_record_link
        )

        if teams_config["enabled"] == True:
            import pymsteams

            for url in teams_config["webHooksURLs"]:
                teamsMsg = pymsteams.connectorcard(url)
                teamsMsg.title(teams_config["title"])
                teamsMsg.text(body)
                teamsMsg.addLinkButton("Open Slate Record", current_record_link)
                teamsMsg.send()

        if email_config["method"] == "o365":
            from O365 import Account

            credentials = (
                email_config["o365"]["oauth_application"],
                email_config["o365"]["oauth_secret"],
            )
            account = Account(credentials, tenant_id=email_config["o365"]["tenant_id"])
            if not account.is_authenticated:
                # Interactive authentication is required during setup
                account.authenticate(scopes=["basic", "Mail.Send"])

            m = account.new_message()
            for recipient in email_config["to"].split(","):
                m.to.add(recipient.strip())
            m.subject = email_config["subject"]
            m.body = body.replace("\n", "<br>")
            m.send()
        elif email_config["method"] == "smtp":
            import smtplib
            from email.mime.text import MIMEText

            msg = MIMEText(body)
            msg["To"] = email_config["to"]
            msg["From"] = email_config["smtp"]["from"]
            msg["Subject"] = email_config["subject"]

            with smtplib.SMTP(email_config["smtp"]["server"]) as smtp:
                smtp.starttls()
                smtp.login(
                    email_config["smtp"]["username"], email_config["smtp"]["password"]
                )
                smtp.send_message(msg)
