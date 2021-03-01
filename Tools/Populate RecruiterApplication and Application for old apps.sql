USE PowerCampusMapper

--
-- Tool for populating RecruiterApplication and Application with just enough data to allow
-- syncing via PowerSlate as if the applications had been inserted organically via the API.
-- I.e. sync your old apps that were manually typed into PowerCampus before you implemented PowerSlate.
--
SELECT DISTINCT aid
INTO #Exclusions
FROM PowerCampusMapper.dbo.Slate_Apps
WHERE PEOPLE_CODE_ID IN (
		SELECT PEOPLE_CODE_ID
		FROM [Campus6].[dbo].PEOPLE
		)
	AND PEOPLE_CODE_ID NOT IN (
		SELECT PEOPLE_CODE_ID
		FROM [Campus6].[dbo].ACADEMIC
		WHERE APPLICATION_FLAG = 'Y'
		)

INSERT INTO #Exclusions
SELECT DISTINCT aid
FROM PowerCampusMapper.dbo.Slate_Apps
WHERE PEOPLE_CODE_ID NOT IN (
		SELECT PEOPLE_CODE_ID
		FROM [Campus6].[dbo].PEOPLE
		)

INSERT INTO #Exclusions
SELECT DISTINCT aid
FROM PowerCampusMapper.dbo.Slate_Apps
WHERE PEOPLE_CODE_ID IS NULL

PRINT '#Exclusions table built.'

BEGIN TRAN

INSERT INTO [Campus6].[dbo].[Application] (
	[CreateDatetime]
	,[Status]
	,[PersonId]
	,[FirstName]
	,[LastName]
	,[SessionPeriodId]
	,[FoodPlanInterest]
	,[DormPlanInterest]
	,[ApplicationFormSettingId]
	,[OtherSource]
	)
SELECT getdate() [CreateDatetime]
	,2 [Status]
	,[Campus6].[dbo].fngetpersonid(PEOPLE_CODE_ID) [PersonId]
	,FirstName
	,LastName
	,(
		SELECT sessionperiodid
		FROM Campus6.dbo.ACADEMICCALENDAR
		WHERE academic_year = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND academic_term = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
			AND academic_session = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 2 rows FETCH NEXT 1 rows ONLY
				)
		) [SessionPeriodId]
	,0 [FoodPlanInterest]
	,0 [DormPlanInterest]
	,1 [ApplicationFormSettingId]
	,aid [OtherSource]
FROM PowerCampusMapper.dbo.Slate_Apps
WHERE aid NOT IN (
		SELECT aid
		FROM #Exclusions
		)
	AND aid NOT IN (
		SELECT applicationnumber
		FROM [Campus6].[dbo].[RecruiterApplication]
		WHERE ApplicationId IS NOT NULL
		)
	AND aid NOT IN (
		SELECT othersource
		FROM [Campus6].[dbo].[Application]
		)

PRINT 'Insert into [Application] done.'

INSERT INTO [Campus6].[dbo].[RecruiterApplication] (
	[ApplicationNumber]
	,[JsonText]
	,[ErrorMessage]
	,[ApplicationId]
	,[CreateDatetime]
	,[RevisionDatetime]
	,[Status]
	,[ProspectId]
	)
SELECT aid
	,'{}'
	,''
	,(
		SELECT applicationid
		FROM [Campus6].[dbo].[Application]
		WHERE othersource = aid
		)
	,getdate()
	,getdate()
	,0
	,pid
FROM PowerCampusMapper.dbo.Slate_Apps
WHERE aid NOT IN (
		SELECT aid
		FROM #exclusions
		)
	AND aid NOT IN (
		SELECT applicationnumber
		FROM [Campus6].[dbo].[RecruiterApplication]
		)

PRINT 'Insert into [RecruiterApplication] done.'

ROLLBACK TRAN

DROP TABLE #Exclusions
