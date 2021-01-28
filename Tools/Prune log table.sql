WITH RankedIDs_CTE AS
(
	SELECT
		ID
		,RANK() OVER (PARTITION BY ApplicationNumber ORDER BY ID DESC) [RankDesc]
		,NULL AS [RankAsc]
		,ApplicationNumber
	FROM [PowerSlate_AppStatus_Log]
)
DELETE TOP (9000)
FROM RankedIDs_CTE
WHERE [RankDesc] >= 6
	AND ID <> (SELECT MIN(ID) FROM [PowerSlate_AppStatus_Log] L2 WHERE L2.ApplicationNumber = RankedIDs_CTE.ApplicationNumber);
