USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updAcademicAppInfo]    Script Date: 2/18/2021 3:20:41 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-04-20
-- Description:	Updates Status and Decision code for application from Slate.
--				Sets ACADEMIC_FLAG if needed (an API defect).
--				Sets PRIMARY_FLAG
--
-- 2021-04-00 Wyatt Best:	
-- =============================================
CREATE PROCEDURE [custom].[PS_updEducation] @PCID NVARCHAR(10)
	,@OrgIdentifier NVARCHAR(6)
	,@Degree NVARCHAR(6) = ''
	,@Curriculum NVARCHAR(6) = ''
	,@GPA NUMERIC(7, 4) = 0
	,@GPAUnweighted NUMERIC(8, 4) = 0
	,@GPAUnweightedScale NUMERIC(8, 4) = 0
	,@GPAWeighted NUMERIC(8, 4) = 0
	,@GPAWeightedScale NUMERIC(8, 4) = 0
	,@StartDate DATE NULL
	,@EndDate DATE NULL
	,@Honors NVARCHAR(6) = NULL --Code table
	,@TranscriptDate DATE = NULL
	,@ClassRank INT = NULL
	,@ClassSize INT = NULL
	,@TransferCredits NUMERIC(8, 3) = 0
	,@FinAidAmount NUMERIC(18, 6) = 0
	,@Quartile NUMERIC(5, 2) = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(GETDATE())
		--Attempt to locate the org
		,@OrgCodeId NVARCHAR(10) = (
			SELECT ORG_CODE_ID
			FROM ORGANIZATION
			WHERE ORG_IDENTIFIER = @OrgIdentifier
			)
		,@RecordFound BIT = 0

	--Send flag and quit if Org not found
	IF @OrgCodeId IS NULL
	BEGIN
		SELECT CAST(0 AS BIT) AS 'OrgFound'

		RETURN
	END

	--Error check
	IF (
			NOT EXISTS (
				SELECT *
				FROM PEOPLE
				WHERE PEOPLE_CODE_ID = @PCID
				)
			)
	BEGIN
		RAISERROR (
				'@PCID not found in PEOPLE.'
				,11
				,1
				)

		RETURN
	END

	IF (
			@Degree IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_DEGREE
				WHERE CODE_VALUE_KEY = @Degree
				)
			)
	BEGIN
		RAISERROR (
				'@Degree ''%s'' not found in CODE_DEGREE.'
				,11
				,1
				,@Degree
				)

		RETURN
	END

	IF (
			@Curriculum IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_CURRICULUM
				WHERE CODE_VALUE_KEY = @Curriculum
				)
			)
	BEGIN
		RAISERROR (
				'@Curriculum ''%s'' not found in CODE_CURRICULUM.'
				,11
				,1
				,@Curriculum
				)

		RETURN
	END

	IF (
			@Honors IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_HONORS
				WHERE CODE_VALUE_KEY = @Honors
				)
			)
	BEGIN
		RAISERROR (
				'@Honors ''%s'' not found in CODE_HONORS.'
				,11
				,1
				,@Honors
				)

		RETURN
	END

	--Check whether record already exists by clustered primary key
	IF EXISTS (
			SELECT *
			FROM EDUCATION
			WHERE PEOPLE_CODE_ID = @PCID
				AND DEGREE = @Degree
				AND CURRICULUM = @Curriculum
			)
		SET @RecordFound = 1

	--Update existing record preserving existing values if incoming parameter is NULL
	IF @RecordFound = 1
	BEGIN
		UPDATE EDUCATION
		SET GRADEPOINT_AVERAGE = COALESCE(@GPA, GRADEPOINT_AVERAGE)
			,[START_DATE] = COALESCE(@StartDate, [START_DATE])
			,END_DATE = COALESCE(@EndDate, END_DATE)
			,HONORS = COALESCE(@Honors, HONORS)
			,TRANSCRIPT_DATE = COALESCE(@TranscriptDate, TRANSCRIPT_DATE)
			,TRANSFER_CREDITS = COALESCE(@TransferCredits, TRANSFER_CREDITS)
			,FIN_AID_AMOUNT = COALESCE(@FinAidAmount, FIN_AID_AMOUNT)
			,UNWEIGHTED_GPA = COALESCE(@GPAUnweighted, UNWEIGHTED_GPA)
			,UNWEIGHTED_GPA_SCALE = COALESCE(@GPAUnweightedScale, UNWEIGHTED_GPA_SCALE)
			,WEIGHTED_GPA = COALESCE(@GPAWeighted, WEIGHTED_GPA)
			,WEIGHTED_GPA_SCALE = COALESCE(@GPAWeightedScale, WEIGHTED_GPA_SCALE)
			,QUARTILE = COALESCE(@Quartile, QUARTILE)
			,REVISION_DATE = @Today
			,REVISION_TIME = @Now
			,REVISION_OPID = 'SLATE'
			,REVISION_TERMINAL = '0001'
		WHERE PEOPLE_CODE_ID = @PCID
			AND ORG_CODE_ID = @OrgCodeId
			AND DEGREE = @Degree
			AND CURRICULUM = @Curriculum
	END

	--Insert new record
	IF @RecordFound = 0
	BEGIN
		INSERT INTO [dbo].[EDUCATION] (
			[PEOPLE_CODE]
			,[PEOPLE_ID]
			,[PEOPLE_CODE_ID]
			,[ORG_CODE_ID]
			,[DEGREE]
			,[CURRICULUM]
			,[GRADEPOINT_AVERAGE]
			,[START_DATE]
			,[END_DATE]
			,[HONORS]
			,[TRANSCRIPT_DATE]
			,[CLASS_RANK]
			,[CLASS_SIZE]
			,[TRANSFER_CREDITS]
			,[FIN_AID_AMOUNT]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			,[ABT_JOIN]
			,[UNWEIGHTED_GPA]
			,[UNWEIGHTED_GPA_SCALE]
			,[WEIGHTED_GPA]
			,[WEIGHTED_GPA_SCALE]
			,[QUARTILE]
			)
		SELECT 'P' [PEOPLE_CODE]
			,RIGHT(@PCID, 9) [PEOPLE_ID]
			,@PCID [PEOPLE_CODE_ID]
			,@OrgCodeId [ORG_CODE_ID]
			,@Degree [DEGREE]
			,@Curriculum [CURRICULUM]
			,@GPA [GRADEPOINT_AVERAGE]
			,@StartDate [START_DATE]
			,@EndDate [END_DATE]
			,@Honors [HONORS]
			,@TranscriptDate [TRANSCRIPT_DATE]
			,@ClassRank [CLASS_RANK]
			,@ClassSize [CLASS_SIZE]
			,@TransferCredits [TRANSFER_CREDITS]
			,@FinAidAmount [FIN_AID_AMOUNT]
			,@Today [CREATE_DATE]
			,@Now [CREATE_TIME]
			,'SLATE' [CREATE_OPID]
			,'0001' [CREATE_TERMINAL]
			,@Today [REVISION_DATE]
			,@Now [REVISION_TIME]
			,'SLATE' [REVISION_OPID]
			,'0001' [REVISION_TERMINAL]
			,'*' [ABT_JOIN]
			,@GPAUnweighted [UNWEIGHTED_GPA]
			,@GPAUnweightedScale [UNWEIGHTED_GPA_SCALE]
			,@GPAWeighted [WEIGHTED_GPA]
			,@GPAWeightedScale [WEIGHTED_GPA_SCALE]
			,@Quartile [QUARTILE]
	END
END
GO


