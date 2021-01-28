USE PowerCampusMapper

--
-- Tool for populating RecruiterApplication and Application with just enough data to allow
-- syncing via PowerSlate as if the applications had been inserted organically via the API.
-- I.e. sync your old apps that were manually typed into PowerCampus before you implemented PowerSlate.
--

SELECT DISTINCT aid
INTO #Exclusions
FROM PowerCampusMapper.dbo.Slate_Apps_test
WHERE PEOPLE_CODE_ID IN (
		SELECT PEOPLE_CODE_ID
		FROM [Campus6_odyssey].[dbo].PEOPLE
		)
	AND PEOPLE_CODE_ID NOT IN (
		SELECT PEOPLE_CODE_ID
		FROM [Campus6_odyssey].[dbo].ACADEMIC
		WHERE APPLICATION_FLAG = 'Y'
		)

INSERT INTO #Exclusions
SELECT DISTINCT aid
FROM PowerCampusMapper.dbo.Slate_Apps_test
WHERE PEOPLE_CODE_ID NOT IN (
		SELECT PEOPLE_CODE_ID
		FROM [Campus6_odyssey].[dbo].PEOPLE
		)

INSERT INTO #Exclusions
SELECT DISTINCT aid
FROM PowerCampusMapper.dbo.Slate_Apps_test
WHERE PEOPLE_CODE_ID IS NULL

--Temporary until some mappings are fixed
INSERT INTO #Exclusions
SELECT DISTINCT aid
FROM PowerCampusMapper.dbo.Slate_Apps_test
WHERE yearterm LIKE '%/SEMSUM/MAIN'

PRINT '#Exclusions table built.'

INSERT INTO [Campus6_odyssey].[dbo].[Application] (
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
SELECT getdate()
	,2
	,[Campus6_odyssey].[dbo].fngetpersonid(PEOPLE_CODE_ID)
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
		)
	,0
	,0
	,1
	,aid
FROM PowerCampusMapper.dbo.Slate_Apps_test
WHERE aid NOT IN (
		SELECT aid
		FROM #exclusions
		)
	AND aid NOT IN (
		SELECT applicationnumber
		FROM [Campus6_odyssey].[dbo].[RecruiterApplication]
		)

PRINT 'Insert into [Application] done.'

INSERT INTO [Campus6_odyssey].[dbo].[RecruiterApplication] (
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
		FROM [Campus6_odyssey].[dbo].[Application]
		WHERE othersource = aid
		)
	,getdate()
	,getdate()
	,0
	,pid
FROM PowerCampusMapper.dbo.Slate_Apps_test
WHERE aid NOT IN (
		SELECT aid
		FROM #exclusions
		)
	AND aid NOT IN (
		SELECT applicationnumber
		FROM [Campus6_odyssey].[dbo].[RecruiterApplication]
		)

PRINT 'Insert into [RecruiterApplication] done.'

DROP TABLE #Exclusions
	--SELECT *
	--FROM campus6_odyssey.information_schema.columns
	--WHERE table_name = 'Application'
	--	AND is_nullable = 'no'
	--SELECT DISTINCT yearterm
	--	,(
	--		SELECT sessionperiodid
	--		FROM Campus6.dbo.ACADEMICCALENDAR
	--		WHERE academic_year = (
	--				SELECT value
	--				FROM string_split(yearterm, '/')
	--				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
	--				)
	--			AND academic_term = (
	--				SELECT value
	--				FROM string_split(yearterm, '/')
	--				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
	--				)
	--			AND academic_session = (
	--				SELECT value
	--				FROM string_split(yearterm, '/')
	--				ORDER BY @@rowcount offset 2 rows FETCH NEXT 1 rows ONLY
	--				)
	--		)
	--FROM PowerCampusMapper.dbo.Slate_Apps_test
