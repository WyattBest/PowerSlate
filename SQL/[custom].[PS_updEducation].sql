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
-- Description:	Updates or inserts an EDUCATION row. Tried to leave existing values alone if input not specified.
--
-- 2021-04-00 Wyatt Best:	
-- =============================================
CREATE PROCEDURE [custom].[PS_updEducation] @PCID NVARCHAR(10)
	,@OrgIdentifier NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
	,@GPA NUMERIC(7, 4)
	,@GPAUnweighted NUMERIC(8, 4)
	,@GPAUnweightedScale NUMERIC(8, 4)
	,@GPAWeighted NUMERIC(8, 4)
	,@GPAWeightedScale NUMERIC(8, 4)
	,@StartDate DATE
	,@EndDate DATE
	,@Honors NVARCHAR(6)
	,@TranscriptDate DATE
	,@ClassRank INT
	,@ClassSize INT
	,@TransferCredits NUMERIC(8, 3)
	,@FinAidAmount NUMERIC(18, 6)
	,@Quartile NUMERIC(5, 2)
AS
BEGIN
	SET NOCOUNT ON;

	--Attempt to locate the org
	DECLARE @OrgCodeId NVARCHAR(10) = (
			SELECT ORG_CODE_ID
			FROM ORGANIZATION
			WHERE ORG_IDENTIFIER = @OrgIdentifier
			)

	--Send flag and quit if Org not found
	IF @OrgCodeId IS NULL
	BEGIN
		SELECT CAST(0 AS BIT) AS 'OrgFound'

		RETURN
	END

	--Set defaults. Other parameters have defaults that might be set later, but these are never useful as NULL
	SET @Degree = ISNULL(@Degree, '')
	SET @Curriculum = ISNULL(@Curriculum, '')

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
			@Degree <> ''
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
			@Curriculum <> ''
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

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(GETDATE())

	--Check whether record already exists by clustered primary key
	IF EXISTS (
			SELECT *
			FROM EDUCATION
			WHERE PEOPLE_CODE_ID = @PCID
				AND ORG_CODE_ID = @OrgCodeId
				AND DEGREE = @Degree
				AND CURRICULUM = @Curriculum
			)
	BEGIN
		--Update existing record preserving existing values if incoming parameter is NULL
		UPDATE EDUCATION
		SET GRADEPOINT_AVERAGE = COALESCE(@GPA, GRADEPOINT_AVERAGE)
			,[START_DATE] = COALESCE(@StartDate, [START_DATE])
			,END_DATE = COALESCE(@EndDate, END_DATE)
			,HONORS = COALESCE(@Honors, HONORS)
			,TRANSCRIPT_DATE = COALESCE(@TranscriptDate, TRANSCRIPT_DATE)
			,CLASS_RANK = COALESCE(@ClassRank, CLASS_RANK)
			,CLASS_SIZE = COALESCE(@ClassSize, CLASS_SIZE)
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
			--Only update if something has changed
			AND EXISTS (
				SELECT GRADEPOINT_AVERAGE
					,[START_DATE]
					,END_DATE
					,HONORS
					,TRANSCRIPT_DATE
					,CLASS_RANK
					,CLASS_SIZE
					,TRANSFER_CREDITS
					,FIN_AID_AMOUNT
					,UNWEIGHTED_GPA
					,UNWEIGHTED_GPA_SCALE
					,WEIGHTED_GPA
					,WEIGHTED_GPA_SCALE
					,QUARTILE
				
				EXCEPT
				
				SELECT GRADEPOINT_AVERAGE = COALESCE(@GPA, GRADEPOINT_AVERAGE)
					,[START_DATE] = COALESCE(@StartDate, [START_DATE])
					,END_DATE = COALESCE(@EndDate, END_DATE)
					,HONORS = COALESCE(@Honors, HONORS)
					,TRANSCRIPT_DATE = COALESCE(@TranscriptDate, TRANSCRIPT_DATE)
					,CLASS_RANK = COALESCE(@ClassRank, CLASS_RANK)
					,CLASS_SIZE = COALESCE(@ClassSize, CLASS_SIZE)
					,TRANSFER_CREDITS = COALESCE(@TransferCredits, TRANSFER_CREDITS)
					,FIN_AID_AMOUNT = COALESCE(@FinAidAmount, FIN_AID_AMOUNT)
					,UNWEIGHTED_GPA = COALESCE(@GPAUnweighted, UNWEIGHTED_GPA)
					,UNWEIGHTED_GPA_SCALE = COALESCE(@GPAUnweightedScale, UNWEIGHTED_GPA_SCALE)
					,WEIGHTED_GPA = COALESCE(@GPAWeighted, WEIGHTED_GPA)
					,WEIGHTED_GPA_SCALE = COALESCE(@GPAWeightedScale, WEIGHTED_GPA_SCALE)
					,QUARTILE = COALESCE(@Quartile, QUARTILE)
				)

		SELECT CAST(1 AS BIT) AS 'OrgFound'
	END
	ELSE
	BEGIN
		--Set defaults
		SET @GPA = ISNULL(@GPA, 0)
		SET @GPAUnweighted = ISNULL(@GPAUnweighted, 0)
		SET @GPAUnweightedScale = ISNULL(@GPAUnweightedScale, 0)
		SET @GPAWeighted = ISNULL(@GPAWeighted, 0)
		SET @GPAWeightedScale = ISNULL(@GPAWeightedScale, 0)
		SET @TransferCredits = ISNULL(@TransferCredits, 0)
		SET @FinAidAmount = ISNULL(@FinAidAmount, 0)
		SET @Quartile = ISNULL(@Quartile, 0)

		--Insert new record
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

		SELECT CAST(1 AS BIT) AS 'OrgFound'
	END
END
GO


