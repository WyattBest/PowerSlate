USE Pfaids

SELECT '[''' + cast(doc_token AS VARCHAR(50)) + ''',''' + replace(doc_name, '''', '\''') + ''',''' + cast(award_year_token AS NVARCHAR(4)) + ''',''' + iif(use_hyperlink = 1, hyperlink_url, '') + '''],' AS [js_array]
FROM docs
WHERE 1 = 1
	AND award_year_token IN (
		2023
		,2024
		)
--AND doc_token IN (
--	SELECT doc_token
--	FROM [student_required_documents] srd
--	INNER JOIN stu_award_year sar
--		ON sar.stu_award_year_token = srd.stu_award_year_token
--	WHERE award_year_token = 2023
--	)
ORDER BY doc_token
