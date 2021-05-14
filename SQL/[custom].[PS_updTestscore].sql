USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updEducation]    Script Date: 5/6/2021 7:06:28 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-05-06
-- Description:	Inserts or updates a test score. Scores are converted unless supplied pre-converted.
--				Defaults are loaded from code tables if not supplied. Transcript Print will be left as-is unless supplied.
--
-- 2021-04-28 Wyatt Best:	
-- =============================================
CREATE PROCEDURE [custom].[PS_updTestscore] @PCID NVARCHAR(10)
	,@TestId NVARCHAR(6)
	,@TestType NVARCHAR(8)
	,@TestDate DATE
	,@RawScore NUMERIC(6, 2) = 0
	,@ConverstionFactor NUMERIC(8, 4) = NULL
	,@ConvertedScore NUMERIC(8, 4) = 0
	,@TranscriptPrint BIT = NULL
	,@AlphaScore NVARCHAR(5) = NULL
	,@AlphaScore1 NVARCHAR(5) = NULL
	,@AlphaScore2 NVARCHAR(5) = NULL
	,@AlphaScore3 NVARCHAR(5) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @TranscriptPrintFlag NVARCHAR(1) = CASE @TranscriptPrint
			WHEN 1
				THEN 'Y'
			WHEN 0
				THEN 'N'
			ELSE NULL
			END

	--== Initial Error Checking ==
	--Verify code values
	IF (
			NOT EXISTS (
				SELECT *
				FROM PEOPLE
				WHERE PEOPLE_CODE_ID = @PCID
				)
			)
	BEGIN
		RAISERROR (
				'@PCID ''%s'' not found in PEOPLE.'
				,11
				,1
				,@PCID
				)

		RETURN
	END

	IF NOT EXISTS (
			SELECT *
			FROM CODE_TEST
			WHERE CODE_VALUE_KEY = @TestId
			)
	BEGIN
		RAISERROR (
				'@TestId ''%s'' not found in CODE_TEST.'
				,11
				,1
				,@TestId
				)

		RETURN
	END

	IF NOT EXISTS (
			SELECT *
			FROM CODE_TESTTYPE
			WHERE CODE_VALUE_KEY = @TestType
			)
	BEGIN
		RAISERROR (
				'@TestType ''%s'' not found in CODE_TESTTYPE.'
				,11
				,1
				,@TestType
				)

		RETURN
	END

	IF NOT EXISTS (
			SELECT *
			FROM CODE_TESTLINK
			WHERE TEST = @TestId
				AND [TYPE] = @TestType
			)
	BEGIN
		RAISERROR (
				'@TestType ''%s'' not associated with @TestId ''%s'' in CODE_TESTTYPE.'
				,11
				,1
				,@TestType
				,@TestId
				)

		RETURN
	END

	--=== Load Defaults ===
	DECLARE @TypeAlphaNumeric NVARCHAR(1) = (
			SELECT NUMERIC_ALPHA
			FROM CODE_TEST
			WHERE CODE_VALUE_KEY = @TestId
			)

	--RawScore is 0 for Alpha score rows
	SET @RawScore = COALESCE(@RawScore, 0)

	--Default ConversionFactor from CODE_TESTTYPE
	IF @ConverstionFactor IS NULL
		SET @ConverstionFactor = (
				SELECT CONVERSION_FACTOR
				FROM CODE_TESTTYPE
				WHERE CODE_VALUE_KEY = @TestType
				)

	--Convert score if not already converted
	IF (
			@ConvertedScore IS NULL
			AND @TypeAlphaNumeric = 'N'
			)
		SET @ConvertedScore = CAST((@RawScore * @ConverstionFactor) AS NUMERIC(8, 4))

	--=== More Error Checking ===
	--Enforce Numeric vs Alpha test types
	IF (
			@RawScore <> 0.00
			OR @ConverstionFactor <> 1.0000
			OR @AlphaScore IS NOT NULL
			)
		AND @TypeAlphaNumeric = 'A'
	BEGIN
		RAISERROR (
				'Test ''%s'' is configured as type Alpha but Numeric scores were supplied.'
				,11
				,1
				,@TestId
				)

		RETURN
	END

	IF (
			@AlphaScore1 IS NOT NULL
			OR @AlphaScore2 IS NOT NULL
			OR @AlphaScore3 IS NOT NULL
			)
		AND @TypeAlphaNumeric = 'N'
	BEGIN
		RAISERROR (
				'Test ''%s'' is configured as type Numeric but numeric scores were supplied.'
				,11
				,1
				,@TestId
				)

		RETURN
	END

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(GETDATE())

	--Check whether record already exists by clustered primary key. Test date is compared by month only.
	IF EXISTS (
			SELECT *
			FROM TESTSCORES
			WHERE PEOPLE_CODE_ID = @PCID
				AND TEST_ID = @TestId
				AND TEST_TYPE = @TestType
				AND DATEFROMPARTS(DATEPART(YEAR, TEST_DATE), DATEPART(MONTH, TEST_DATE), 1) = DATEFROMPARTS(DATEPART(YEAR, @TestDate), DATEPART(MONTH, @TestDate), 1)
			)
	BEGIN
		--Update existing record preserving existing values if incoming parameter is NULL
		UPDATE TESTSCORES
		SET [TEST_DATE] = @TestDate
			,[RAW_SCORE] = @RawScore
			,[CONVERSION_FACTOR] = @ConverstionFactor
			,[CONVERTED_SCORE] = @ConvertedScore
			,[TRANSCRIPT_PRINT] = COALESCE(@TranscriptPrintFlag, TRANSCRIPT_PRINT)
			,[ALPHA_SCORE] = @AlphaScore
			,[ALPHA_SCORE_1] = @AlphaScore1
			,[ALPHA_SCORE_2] = @AlphaScore2
			,[ALPHA_SCORE_3] = @AlphaScore3
			,REVISION_DATE = @Today
			,REVISION_TIME = @Now
			,REVISION_OPID = 'SLATE'
			,REVISION_TERMINAL = '0001'
		WHERE PEOPLE_CODE_ID = @PCID
			AND TEST_ID = @TestId
			AND TEST_TYPE = @TestType
			AND DATEFROMPARTS(DATEPART(YEAR, TEST_DATE), DATEPART(MONTH, TEST_DATE), 1) = DATEFROMPARTS(DATEPART(YEAR, @TestDate), DATEPART(MONTH, @TestDate), 1)
			--Only update if something has changed
			AND EXISTS (
				SELECT TEST_DATE
					,RAW_SCORE
					,CONVERSION_FACTOR
					,CONVERTED_SCORE
					,TRANSCRIPT_PRINT
					,ALPHA_SCORE
					,ALPHA_SCORE_1
					,ALPHA_SCORE_2
					,ALPHA_SCORE_3
				
				EXCEPT
				
				SELECT @TestDate
					,@RawScore
					,@ConverstionFactor
					,@ConvertedScore
					,COALESCE(@TranscriptPrintFlag, TRANSCRIPT_PRINT)
					,@AlphaScore
					,@AlphaScore1
					,@AlphaScore2
					,@AlphaScore3
				)
	END
	ELSE
	BEGIN
		--Default TranscriptPrintFlag from CODE_TEST
		IF @TranscriptPrintFlag IS NULL
			SET @TranscriptPrintFlag = (
					SELECT TRANSCRIPT_PRINT
					FROM CODE_TEST
					WHERE CODE_VALUE_KEY = @TestId
					)

		--Insert new record
		INSERT INTO [dbo].[TESTSCORES] (
			[PEOPLE_CODE]
			,[PEOPLE_ID]
			,[PEOPLE_CODE_ID]
			,[TEST_ID]
			,[TEST_TYPE]
			,[TEST_DATE]
			,[RAW_SCORE]
			,[CONVERSION_FACTOR]
			,[CONVERTED_SCORE]
			,[TRANSCRIPT_PRINT]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			,[ABT_JOIN]
			,[ALPHA_SCORE]
			,[ALPHA_SCORE_1]
			,[ALPHA_SCORE_2]
			,[ALPHA_SCORE_3]
			)
		SELECT 'P' [PEOPLE_CODE]
			,RIGHT(@PCID, 9) [PEOPLE_ID]
			,@PCID [PEOPLE_CODE_ID]
			,@TestId [TEST_ID]
			,@TestType [TEST_TYPE]
			,@TestDate [TEST_DATE]
			,@RawScore [RAW_SCORE]
			,@ConverstionFactor [CONVERSION_FACTOR]
			,@ConvertedScore [CONVERTED_SCORE]
			,@TranscriptPrintFlag [TRANSCRIPT_PRINT]
			,@Today [CREATE_DATE]
			,@Now [CREATE_TIME]
			,'SLATE' [CREATE_OPID]
			,'0001' [CREATE_TERMINAL]
			,@Today [REVISION_DATE]
			,@Now [REVISION_TIME]
			,'SLATE' [REVISION_OPID]
			,'0001' [REVISION_TERMINAL]
			,'*' [ABT_JOIN]
			,@AlphaScore [ALPHA_SCORE]
			,@AlphaScore1 [ALPHA_SCORE_1]
			,@AlphaScore2 [ALPHA_SCORE_2]
			,@AlphaScore3 [ALPHA_SCORE_3]
	END
END
GO


