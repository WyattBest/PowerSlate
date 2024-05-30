function insertChecklist(docs, status_xml) {
    docs.forEach(function (doc) {
        values = {
            "active": "1",
            "folder_type": "lookup.checklist",
            "folder_level": "0",
            "folder_0": "",
            "scope": "",
            "group": doc[2],
            "section": "Financial Aid",
            "subject": doc[1],
            "href": doc[3],
            "key": doc[0],
            "order": "",
            "material": "",
            "material2": "",
            "material3": "",
            "material4": "",
            "material5": "",
            "rank": "",
            "test": "",
            "test2": "",
            "test3": "",
            "form_fulfillment": "",
            "sql": "",
            "xml": status_xml,
            "internal": "0",
            "optional": "0",
            "optional_internal": "0",
            "right": "",
            "right_update": "",
            "export": "",
            "cmd": "update"

        }
        $.ajax({
            url: "/manage/database/admin?cmd=edit&id=lookup.checklist",
            type: "POST",
            data: values
        }).done(function () {
            console.log('Successfully inserted ' + doc[0]);
        })
            .fail(function () {
                console.log('Failed to insert ' + doc[0]);
                return;
            });

    });
}

// Standard PF doc statuses and suggested mappings
status_xml = '<p><k>status</k><v><t>Received</t><t>Waived</t><t>Waived</t><t icon="Waived">Not Reviewed</t><t icon="Received">Approved</t><t icon="Awaiting">Incomplete</t><t icon="Awaiting">Not Received</t><t icon="Awaiting">Not Signed</t></v></p>'

// Array of docs: key, subject, group, url
// Replace with doc list from  Tools\Get FA Docs List.sql
docs = [
    ['1234', '2021 Student Signed Tax Return', '2023', 'https://www.irs.gov/individuals/get-transcript'],
]

// insertChecklist(docs, status_xml);
