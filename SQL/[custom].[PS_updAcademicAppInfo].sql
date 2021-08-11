USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updAcademicAppInfo]    Script Date: 2021-08-11 10:01:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-11-17
-- Description:	Updates Status and Decision code for application from Slate.
--				Sets ACADEMIC_FLAG, PRIMARY_FLAG, ENROLL_SEPARATION, DEPARTMENT, POPULATION, COUNSELOR, EXTRA_CURRICULAR, COLLEGE_ATTEND, APPLICATION_DATE.
--				Sets ADMIT and MATRIC field groups.
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
-- 2021-03-09 Wyatt Best:	Added Counselor. Raise error for invalid @CollegeAttend instead of silently skipping.
-- 2021-04-02 Wyatt Best:	Added @AdmitDate and @Matriculated. If @Matriculated is true, matric fields will be populated. Matric date will be start date from academic calendar.
--							If @AppDecision is an accepted decision, admit fields will be populated. Admit date will be @AdmitdDate.
-- 2021-04-03 Wyatt Best:	Fix missing PDC filters in some update statements. Could have caused multiple records to be affected if student had multiple applications in same YTS.
--							Change primary flag logic to be more conservative. Rewrote some statements for efficiency.
-- 2021-04-05 Wyatt Best:	Added switch to control whether @Population will overwrite existing values. Used by MCNY.
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
	,@AdmitDate DATE NULL
	,@Matriculated BIT NULL
	,@AppStatus NVARCHAR(8) NULL
	,@AppStatusDate DATE NULL
	,@AppDecision NVARCHAR(8) NULL
	,@AppDecisionDate DATE NULL
	,@Counselor NVARCHAR(10) NULL
	,@CollegeAttend NVARCHAR(4) NULL
	,@Extracurricular BIT NULL
	,@CreateDateTime DATETIME --Application creation date
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(GETDATE())
		,@OverwritePopulation BIT = 1

	--Setup for Matric and Admit field groups
	IF @Matriculated = 1
	BEGIN
		DECLARE @MatricDate DATE = (
				SELECT [START_DATE]
				FROM ACADEMICCALENDAR
				WHERE ACADEMIC_YEAR = @Year
					AND ACADEMIC_TERM = @Term
					AND ACADEMIC_SESSION = @Session
				)
	END

	DECLARE @Admitted BIT = 0

	IF @AppDecision IN (
			SELECT CODE_VALUE_KEY
			FROM CODE_APPDECISION
			WHERE ACCEPTED_DECISION = 'Y'
				AND [STATUS] = 'A'
			)
	BEGIN
		SET @Admitted = 1
	END

	--Error check
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
			@Counselor IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM PEOPLE
				WHERE PEOPLE_CODE_ID = @Counselor
				)
			)
	BEGIN
		RAISERROR (
				'@Counselor ''%s'' not found in PEOPLE.'
				,11
				,1
				,@Counselor
				)

		RETURN
	END

	IF (
			@CollegeAttend IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_COLLEGEATTEND
				WHERE CODE_VALUE_KEY = @CollegeAttend
				)
			)
	BEGIN
		RAISERROR (
				'@CollegeAttend ''%s'' not found in CODE_COLLEGEATTEND.'
				,11
				,1
				,@CollegeAttend
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
		--Don't do anything unless both Status and Decision are present.
		AND @AppStatus IS NOT NULL
		AND @AppDecision IS NOT NULL

	--Update DEPARTMENT if needed
	UPDATE ACADEMIC
	SET DEPARTMENT = @Department
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND (
			DEPARTMENT <> @Department
			OR DEPARTMENT IS NULL
			)

	-- Set PRIMARY_FLAG if no record with primary flag exists in YTS
	IF NOT EXISTS (
			SELECT *
			FROM ACADEMIC
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = @Session
				--AND APPLICATION_FLAG = 'Y'
				AND PRIMARY_FLAG = 'Y'
			)
		UPDATE dbo.ACADEMIC
		SET PRIMARY_FLAG = 'Y'
		WHERE PEOPLE_CODE_ID = @PCID
			AND ACADEMIC_YEAR = @Year
			AND ACADEMIC_TERM = @Term
			AND ACADEMIC_SESSION = @Session
			AND PROGRAM = @Program
			AND DEGREE = @Degree
			AND CURRICULUM = @Curriculum
			AND APPLICATION_FLAG = 'Y';

	--Update ACADEMIC_FLAG if needed
	DECLARE @AcademicFlag NVARCHAR(1) = (
			SELECT CASE 
					WHEN EXISTS (
							SELECT *
							FROM CODE_APPSTATUS
							WHERE CODE_VALUE_KEY = @AppStatus
								AND [STATUS] = 'A'
								AND CONFIRMED_STATUS = 'Y'
							)
						AND EXISTS (
							SELECT *
							FROM CODE_APPDECISION
							WHERE CODE_VALUE_KEY = @AppDecision
								AND [STATUS] = 'A'
								AND ACCEPTED_DECISION = 'Y'
							)
						THEN 'Y'
					ELSE 'N'
					END
			)

	UPDATE dbo.ACADEMIC
	SET ACADEMIC_FLAG = @AcademicFlag
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND (
			ACADEMIC_FLAG <> @AcademicFlag
			OR ACADEMIC_FLAG IS NULL
			)

	--Update ENROLL_SEPARATION if needed
	DECLARE @pdc NVARCHAR(25) = (@program + '/' + @degree + '/' + @curriculum)
		,@pdc1 NVARCHAR(25) = (@program + '/' + @degree + '/')
		,@pdc2 NVARCHAR(25) = (@program + '//')
		,@pdc3 NVARCHAR(25) = ('//')
		,@EnrollSeparation NVARCHAR(4) = NULL

	IF @AcademicFlag = 'Y'
		SET @EnrollSeparation = (
				SELECT TOP 1 LEFT(SETTING, 4)
				FROM ABT_SETTINGS
				WHERE AREA_NAME = 'ACA_RECORDS'
					AND SECTION_NAME = 'STUDENT_CODING_ENROLLED'
					AND LABEL_NAME IN (
						@pdc
						,@pdc1
						,@pdc2
						,@pdc3
						)
				ORDER BY LABEL_NAME DESC
				)

	UPDATE dbo.ACADEMIC
	SET ENROLL_SEPARATION = @EnrollSeparation
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND COALESCE(ENROLL_SEPARATION, '') <> COALESCE(@EnrollSeparation, '')

	--Update NONTRAD_PROGRAM if needed
	UPDATE ACADEMIC
	SET NONTRAD_PROGRAM = @Nontraditional
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
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
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND @Population IS NOT NULL
		AND (
			@OverwritePopulation = 0
			AND (
				[POPULATION] IS NULL
				OR [POPULATION] = ''
				)
			OR (
				@OverwritePopulation = 1
				AND (
					[POPULATION] <> @Population
					OR [POPULATION] IS NULL
					)
				)
			)

	--Update ADMIT fields if needed
	UPDATE ACADEMIC
	SET ADMIT_YEAR = CASE @Admitted
			WHEN 1
				THEN @Year
			ELSE ''
			END
		,ADMIT_TERM = CASE @Admitted
			WHEN 1
				THEN @Term
			ELSE NULL
			END
		,ADMIT_SESSION = CASE @Admitted
			WHEN 1
				THEN @Session
			ELSE NULL
			END
		,ADMIT_DATE = CASE @Admitted
			WHEN 1
				THEN dbo.fnMakeDate(@AdmitDate)
			ELSE NULL
			END
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND (
			(
				@Admitted = 1
				AND (
					ADMIT_DATE <> @AdmitDate
					OR ADMIT_DATE IS NULL
					OR ADMIT_YEAR <> @Year
					OR ADMIT_YEAR IS NULL
					OR ADMIT_TERM <> @Term
					OR ADMIT_TERM IS NULL
					OR ADMIT_SESSION <> @Session
					OR ADMIT_SESSION IS NULL
					)
				)
			OR (
				@Admitted = 0
				AND (
					@AdmitDate IS NOT NULL
					OR ADMIT_YEAR IS NOT NULL
					OR ADMIT_TERM IS NOT NULL
					OR ADMIT_SESSION IS NOT NULL
					)
				)
			)

	--Update MATRIC fields if needed
	UPDATE ACADEMIC
	SET MATRIC = CASE @Matriculated
			WHEN 1
				THEN 'Y'
			ELSE 'N'
			END
		,MATRIC_YEAR = CASE @Matriculated
			WHEN 1
				THEN @Year
			ELSE NULL
			END
		,MATRIC_TERM = CASE @Matriculated
			WHEN 1
				THEN @Term
			ELSE NULL
			END
		,MATRIC_SESSION = CASE @Matriculated
			WHEN 1
				THEN @Session
			ELSE NULL
			END
		,MATRIC_DATE = CASE @Matriculated
			WHEN 1
				THEN dbo.fnMakeDate(@MatricDate)
			ELSE NULL
			END
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND @Matriculated IS NOT NULL
		AND (
			(
				@Matriculated = 1
				AND (
					COALESCE(MATRIC, '') <> 'Y'
					OR MATRIC_DATE <> @MatricDate
					OR MATRIC_DATE IS NULL
					OR MATRIC_YEAR <> @Year
					OR MATRIC_YEAR IS NULL
					OR MATRIC_TERM <> @Term
					OR MATRIC_TERM IS NULL
					OR MATRIC_SESSION <> @Session
					OR MATRIC_SESSION IS NULL
					)
				)
			OR (
				@Matriculated = 0
				AND (
					COALESCE(MATRIC, '') <> 'N'
					OR MATRIC_DATE IS NOT NULL
					OR MATRIC_YEAR IS NOT NULL
					OR MATRIC_TERM IS NOT NULL
					OR MATRIC_SESSION IS NOT NULL
					)
				)
			)

	--Update COUNSELOR if needed
	UPDATE ACADEMIC
	SET COUNSELOR = @Counselor
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND (
			COUNSELOR <> @Counselor
			OR COUNSELOR IS NULL
			)

	--Update COLLEGE_ATTEND if needed
	UPDATE ACADEMIC
	SET COLLEGE_ATTEND = @CollegeAttend
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND (
			COLLEGE_ATTEND <> @CollegeAttend
			OR COLLEGE_ATTEND IS NULL
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
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
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
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y'
		AND COALESCE(APPLICATION_DATE, '') <> dbo.fnMakeDate(@CreateDateTime);

	COMMIT
END
