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
ALTER PROCEDURE [custom].[PS_updEducation] @PCID NVARCHAR(10)
	,@OrgIdentifier NVARCHAR(6)
	,@Degree NVARCHAR(6) = ''
	,@Curriculum NVARCHAR(6) = ''
	,@GPA NUMERIC(7, 4) = 0
	,@GPAUnweighted NUMERIC(8, 4) = 0
	,@GPAUnweightedScale NUMERIC(8, 4) = 0
	,@GPAWeighted NUMERIC(8, 4) = 0
	,@GPAWeightedScale NUMERIC(8, 4) = 0
	,@StartDate DATE = NULL
	,@EndDate DATE = NULL
	,@Honors NVARCHAR(6) = NULL
	,@TranscriptDate DATE = NULL
	,@ClassRank INT = NULL
	,@ClassSize INT = NULL
	,@TransferCredits NUMERIC(8, 3) = 0
	,@FinAidAmount NUMERIC(18, 6) = 0
	,@Quartile NUMERIC(5, 2) = 0
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

	--Set parameter defaults (maybe pyodbc will support named parameters someday, but till then Python will pass NULLs)
	SET @Degree = ISNULL(@Degree, '')
	SET @Curriculum = ISNULL(@Curriculum, '')
	SET @GPA = ISNULL(@GPA, 0)
	SET @GPAUnweighted = ISNULL(@GPAUnweighted, 0)
	SET @GPAUnweightedScale = ISNULL(@GPAUnweightedScale, 0)
	SET @GPAWeighted = ISNULL(@GPAWeighted, 0)
	SET @GPAWeightedScale = ISNULL(@GPAWeightedScale, 0)
	SET @TransferCredits = ISNULL(@TransferCredits, 0)
	SET @FinAidAmount = ISNULL(@FinAidAmount, 0)
	SET @Quartile = ISNULL(@Quartile, 0)

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
		--Update existing record preserving existing values if incoming parameter is NULL/0
		UPDATE EDUCATION
		SET GRADEPOINT_AVERAGE = CASE 
				WHEN @GPA = 0
					THEN GRADEPOINT_AVERAGE
				ELSE @GPA
				END
			,[START_DATE] = COALESCE(@StartDate, [START_DATE])
			,END_DATE = COALESCE(@EndDate, END_DATE)
			,HONORS = COALESCE(@Honors, HONORS)
			,TRANSCRIPT_DATE = COALESCE(@TranscriptDate, TRANSCRIPT_DATE)
			,CLASS_RANK = COALESCE(@ClassRank, CLASS_RANK)
			,CLASS_SIZE = COALESCE(@ClassSize, CLASS_SIZE)
			,TRANSFER_CREDITS = CASE 
				WHEN @TransferCredits = 0
					THEN TRANSFER_CREDITS
				ELSE @TransferCredits
				END
			,FIN_AID_AMOUNT = CASE 
				WHEN @FinAidAmount = 0
					THEN FIN_AID_AMOUNT
				ELSE @FinAidAmount
				END
			,UNWEIGHTED_GPA = CASE 
				WHEN @GPAUnweighted = 0
					THEN UNWEIGHTED_GPA
				ELSE @GPAUnweighted
				END
			,UNWEIGHTED_GPA_SCALE = CASE 
				WHEN @GPAUnweightedScale = 0
					THEN UNWEIGHTED_GPA_SCALE
				ELSE @GPAUnweightedScale
				END
			,WEIGHTED_GPA = CASE 
				WHEN @GPAWeighted = 0
					THEN WEIGHTED_GPA
				ELSE @GPAWeighted
				END
			,WEIGHTED_GPA_SCALE = CASE 
				WHEN @GPAWeightedScale = 0
					THEN WEIGHTED_GPA_SCALE
				ELSE @GPAWeightedScale
				END
			,QUARTILE = CASE 
				WHEN @Quartile = 0
					THEN QUARTILE
				ELSE @Quartile
				END
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
				
				SELECT CASE 
						WHEN @GPA = 0
							THEN GRADEPOINT_AVERAGE
						ELSE @GPA
						END
					,COALESCE(@StartDate, [START_DATE])
					,COALESCE(@EndDate, END_DATE)
					,COALESCE(@Honors, HONORS)
					,COALESCE(@TranscriptDate, TRANSCRIPT_DATE)
					,COALESCE(@ClassRank, CLASS_RANK)
					,COALESCE(@ClassSize, CLASS_SIZE)
					,CASE 
						WHEN @TransferCredits = 0
							THEN TRANSFER_CREDITS
						ELSE @TransferCredits
						END
					,CASE 
						WHEN @FinAidAmount = 0
							THEN FIN_AID_AMOUNT
						ELSE @FinAidAmount
						END
					,CASE 
						WHEN @GPAUnweighted = 0
							THEN UNWEIGHTED_GPA
						ELSE @GPAUnweighted
						END
					,CASE 
						WHEN @GPAUnweightedScale = 0
							THEN UNWEIGHTED_GPA_SCALE
						ELSE @GPAUnweightedScale
						END
					,CASE 
						WHEN @GPAWeighted = 0
							THEN WEIGHTED_GPA
						ELSE @GPAWeighted
						END
					,CASE 
						WHEN @GPAWeightedScale = 0
							THEN WEIGHTED_GPA_SCALE
						ELSE @GPAWeightedScale
						END
					,CASE 
						WHEN @Quartile = 0
							THEN QUARTILE
						ELSE @Quartile
						END
				)
	ELSE
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
END
GO


