USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updAcademicAppInfo]    Script Date: 2/16/2021 8:57:41 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-11-17
-- Description:	Updates Status and Decision code for application from Slate.
--				Sets ACADEMIC_FLAG if needed (an API defect).
--				Sets PRIMARY_FLAG
--
-- 2016-12-15 Wyatt Best:	Added 'Defer' ProposedDecision type.
-- 2016-12-28 Wyatt Best:	Changed translation CODE_APPDECISION for Waiver from 'ACCP' to 'WAIV'
-- 2017-01-09 Wyatt Best:	Added code to set PRIMARY_FLAG. Assuming that a current admissions application should be the primary activity.
-- 2017-01-10 Wyatt Best:	Added 'Withdraw' ProposedDecision type.
-- 2017-08-16 Wyatt Best:	Added 'Deny' ProposedDecision type.
-- 2019-10-15 Wyatt Best:	Renamed and moved to [custom] schema.
-- 2019-12-09 Wyatt Best:	Added UPDATE for APPLICATION_DATE.
-- 2019-12-28 Wyatt Best:	Added COALESCE() on APPLICATION_DATE update.
-- 2021-01-07 Wyatt Best:	Added NONTRAD_PROGRAM.
-- 2021-01-18 Wyatt Best:	Added COLLEGE_ATTEND, EXTRA_CURRICULAR, and DEPARTMENT.
-- 2021-02-04 Wyatt Best:	Eliminated logic to translate @ProposedDecision into App Status and Decision. Instead, accept code values directly.
-- 2021-02-16 Wyatt Best:	Raise error if @Department is not valid.
--							Added POPULATION.
-- 2021-02-17 Wyatt Best:	Added AppStatusDate and AppDecisionDate. Remove dependency on WebServices.spUpdAcademicAppInfo, which doesn't support these fields.
-- =============================================
CREATE PROCEDURE [custom].[PS_updAcademicAppInfo] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
	,@Program NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
	,@Department NVARCHAR(10) NULL
	,@Nontraditional NVARCHAR(6) NULL
	,@Population NVARCHAR(12) NULL
	,@AppStatus NVARCHAR(8) NULL
	,@AppStatusDate DATE NULL
	,@AppDecision NVARCHAR(8) NULL
	,@AppDecisionDate DATE NULL
	,@CollegeAttend NVARCHAR(4) NULL
	,@Extracurricular BIT NULL
	,@CreateDateTime DATETIME --Application creation date
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(GETDATE())

	--Error check
	IF (
			@AppStatus IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_APPSTATUS
				WHERE CODE_VALUE_KEY = @AppStatus
				)
			)
	BEGIN
		RAISERROR (
				'@AppStatus ''%s'' not found in CODE_APPSTATUS.'
				,11
				,1
				,@AppStatus
				)

		RETURN
	END

	IF (
			@AppDecision IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_APPDECISION
				WHERE CODE_VALUE_KEY = @AppDecision
				)
			)
	BEGIN
		RAISERROR (
				'@AppDecision ''%s'' not found in CODE_APPSTATUS.'
				,11
				,1
				,@AppDecision
				)

		RETURN
	END

	IF (
			@Department IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_DEPARTMENT
				WHERE CODE_VALUE_KEY = @Department
				)
			)
	BEGIN
		RAISERROR (
				'@Department ''%s'' not found in CODE_DEPARTMENT.'
				,11
				,1
				,@Department
				)

		RETURN
	END

	IF (
			@Population IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_POPULATION
				WHERE CODE_VALUE_KEY = @Population
				)
			)
	BEGIN
		RAISERROR (
				'@Population ''%s'' not found in CODE_POPULATION.'
				,11
				,1
				,@Population
				)

		RETURN
	END

	BEGIN TRANSACTION

	--Update Status and Decision if needed
	UPDATE ACADEMIC
	SET APP_STATUS = @AppStatus
		,APP_STATUS_DATE = COALESCE(@AppStatusDate, @Today)
		,APP_DECISION = @AppDecision
		,APP_DECISION_DATE = COALESCE(@AppDecisionDate, @Today)
		,REVISION_DATE = @Today
		,REVISION_TIME = @Now
		,REVISION_OPID = 'SLATE'
		,REVISION_TERMINAL = '0001'
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND (
			COALESCE(APP_STATUS, '') <> @AppStatus
			OR COALESCE(CAST(APP_STATUS_DATE AS DATE), '') <> @AppStatusDate
			OR COALESCE(APP_DECISION, '') <> @AppDecision
			OR COALESCE(CAST(APP_DECISION_DATE AS DATE), '') <> @AppDecisionDate
			)

	--Update DEPARTMENT if needed
	UPDATE ACADEMIC
	SET DEPARTMENT = @Department
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND APPLICATION_FLAG = 'Y'
		AND (
			DEPARTMENT <> @Department
			OR DEPARTMENT IS NULL
			)
		AND @Department IN (
			SELECT CODE_VALUE_KEY
			FROM CODE_DEPARTMENT
			WHERE [STATUS] = 'A'
			)

	-- Set PRIMARY_FLAG if needed
	IF NOT EXISTS (
			SELECT *
			FROM ACADEMIC
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = @Session
				AND APPLICATION_FLAG = 'Y'
				AND PRIMARY_FLAG = 'Y'
			)
		UPDATE dbo.ACADEMIC
		SET PRIMARY_FLAG = 'Y'
		WHERE PEOPLE_CODE_ID = @PCID
			AND ACADEMIC_YEAR = @Year
			AND ACADEMIC_TERM = @Term
			AND ACADEMIC_SESSION = @Session
			AND APPLICATION_FLAG = 'Y';

	-- Set ACADEMIC_FLAG if needed
	IF EXISTS (
			SELECT *
			FROM CODE_APPSTATUS
			WHERE CODE_VALUE_KEY = @AppStatus
				AND STATUS = 'A'
				AND CONFIRMED_STATUS = 'Y'
			)
		AND EXISTS (
			SELECT *
			FROM CODE_APPDECISION
			WHERE CODE_VALUE_KEY = @AppDecision
				AND STATUS = 'A'
				AND ACCEPTED_DECISION = 'Y'
			)
		AND NOT EXISTS (
			SELECT *
			FROM ACADEMIC
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = @Session
				AND APPLICATION_FLAG = 'Y'
				AND ACADEMIC_FLAG = 'Y'
			)
		UPDATE dbo.ACADEMIC
		SET ACADEMIC_FLAG = 'Y'
		WHERE PEOPLE_CODE_ID = @PCID
			AND ACADEMIC_YEAR = @Year
			AND ACADEMIC_TERM = @Term
			AND ACADEMIC_SESSION = @Session
			AND APPLICATION_FLAG = 'Y';

	--Update NONTRAD_PROGRAM if needed
	UPDATE ACADEMIC
	SET NONTRAD_PROGRAM = @Nontraditional
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND APPLICATION_FLAG = 'Y'
		AND (
			NONTRAD_PROGRAM <> @Nontraditional
			OR NONTRAD_PROGRAM IS NULL
			)
		AND @Nontraditional IN (
			SELECT NONTRAD_PROGRAM
			FROM NONTRADITIONAL
			)

	--Update POPULATION if needed
	UPDATE ACADEMIC
	SET [POPULATION] = @Population
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND APPLICATION_FLAG = 'Y'
		AND (
			[POPULATION] <> @Population
			OR [POPULATION] IS NULL
			)

	--Update COLLEGE_ATTEND if needed
	UPDATE ACADEMIC
	SET COLLEGE_ATTEND = @CollegeAttend
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND APPLICATION_FLAG = 'Y'
		AND (
			COLLEGE_ATTEND <> @CollegeAttend
			OR COLLEGE_ATTEND IS NULL
			)
		AND @CollegeAttend IN (
			SELECT CODE_VALUE_KEY
			FROM CODE_COLLEGEATTEND
			WHERE [STATUS] = 'A'
			)

	--Update EXTRA_CURRICULAR if needed
	UPDATE ACADEMIC
	SET EXTRA_CURRICULAR = CASE 
			WHEN @Extracurricular = 1
				THEN 'Y'
			ELSE 'N'
			END
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND APPLICATION_FLAG = 'Y'
		AND CASE EXTRA_CURRICULAR
			WHEN 'Y'
				THEN 1
			WHEN 'N'
				THEN 0
			ELSE NULL
			END <> @Extracurricular

	--Update APPLICATION_DATE if needed
	UPDATE ACADEMIC
	SET APPLICATION_DATE = dbo.fnMakeDate(@CreateDateTime)
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND APPLICATION_FLAG = 'Y'
		AND COALESCE(APPLICATION_DATE, '') <> dbo.fnMakeDate(@CreateDateTime);

	COMMIT
END
