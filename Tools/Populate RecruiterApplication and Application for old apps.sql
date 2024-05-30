USE PowerCampusMapper

DECLARE @ApplicationFormSettingId INT = 1

--
-- Tool for populating RecruiterApplication and Application with just enough data to allow
-- syncing via PowerSlate as if the applications had been inserted organically via the API.
-- I.e. sync your old apps that were already in PowerCampus before you implemented PowerSlate.
--
-- Recommend using string_split()'s enable_ordinal parameter when available (SQL Server 2022+)
--
-- Exclude apps without APPLICATION_FLAG = Y
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

--Exclude apps with invalid PCID's
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

--Exclude apps within invalid SessionPeriodId
INSERT INTO #Exclusions
SELECT DISTINCT aid
FROM PowerCampusMapper.dbo.Slate_Apps
WHERE NOT EXISTS (
		SELECT SessionPeriodId
		FROM Campus6.dbo.ACADEMICCALENDAR
		WHERE ACADEMIC_YEAR = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND ACADEMIC_TERM = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
			AND ACADEMIC_SESSION = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 2 rows FETCH NEXT 1 rows ONLY
				)
		)

PRINT '#Exclusions table built.'

SELECT *
FROM #Exclusions

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
	,P.PersonId [PersonId]
	,FirstName
	,LastName
	,(
		SELECT SessionPeriodId
		FROM Campus6.dbo.ACADEMICCALENDAR
		WHERE ACADEMIC_YEAR = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND ACADEMIC_TERM = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
			AND ACADEMIC_SESSION = (
				SELECT value
				FROM string_split(yearterm, '/')
				ORDER BY @@rowcount offset 2 rows FETCH NEXT 1 rows ONLY
				)
		) [SessionPeriodId]
	,0 [FoodPlanInterest]
	,0 [DormPlanInterest]
	,@ApplicationFormSettingId [ApplicationFormSettingId]
	,aid [OtherSource]
FROM PowerCampusMapper.dbo.Slate_Apps SA
LEFT JOIN Campus6.dbo.PEOPLE P
	ON P.PEOPLE_CODE_ID = SA.PEOPLE_CODE_ID
WHERE 1 = 1
	AND NOT EXISTS (
		SELECT E.aid
		FROM #Exclusions E
		WHERE E.aid = SA.aid
		)
	AND NOT EXISTS (
		SELECT ApplicationNumber
		FROM [Campus6].[dbo].[RecruiterApplication]
		WHERE ApplicationId IS NOT NULL
			AND ApplicationNumber = SA.aid
		)
	AND NOT EXISTS (
		SELECT *
		FROM [Campus6].[dbo].[Application]
		WHERE OtherSource = SA.aid
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
	,app.applicationid
	,getdate()
	,getdate()
	,0
	,pid
FROM PowerCampusMapper.dbo.Slate_Apps SA
INNER JOIN [Campus6].[dbo].[Application] APP
	ON app.othersource = sa.aid
WHERE aid NOT IN (
		SELECT aid
		FROM #exclusions
		)
	AND aid NOT IN (
		SELECT ApplicationNumber
		FROM [Campus6].[dbo].[RecruiterApplication]
		)

PRINT 'Insert into [RecruiterApplication] done.'

ROLLBACK TRAN

DROP TABLE #Exclusions
