USE [your_supplementary_database]

SELECT Ref
	,ApplicationNumber
	,ProspectId
	,FirstName
	,LastName
	,ComputedStatus
	,Notes
	,RecruiterApplicationStatus
	,ApplicationStatus
	,PEOPLE_CODE_ID
	,UpdateTime
FROM
	(SELECT Ref
		,ApplicationNumber
		,ProspectId
		,FirstName
		,LastName
		,ComputedStatus
		,Notes
		,RecruiterApplicationStatus
		,ApplicationStatus
		,PEOPLE_CODE_ID
		,UpdateTime
		,RANK() OVER (PARTITION BY ApplicationNumber ORDER BY ID DESC) N
	FROM SlaPowInt_AppStatus_Log) E
WHERE N = 1
