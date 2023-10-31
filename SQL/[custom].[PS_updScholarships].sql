USE [Campus6]

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2023-10-27
-- Description:	Inserts or updates Scholarships data. Existing rows are matched on PCID, Year, Term, and Scholarship.
--				Status and Status Date are inserted initially and only updated later if Department, Level, Applied Amount, or Awarded Amount change.
--				@ValidateScholarshipLevel optionally checks to see if the Scholarship + Level combo exists in SCHOLARSHIPLEVELS.
--				TODO: Check that @ValidateScholarshipLevel is truly optional. Check that automatic requirement inserting works if a non-configured level is used.
-- =============================================
CREATE PROCEDURE [custom].[PS_updScholarships] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Scholarship NVARCHAR(15)
	,@Department NVARCHAR(10) = NULL
	,@Level NVARCHAR(10)
	,@Status NVARCHAR(10)
	,@StatusDate DATE = NULL
	,@AppliedAmount NUMERIC(18, 6) = NULL
	,@AwardedAmount NUMERIC(18, 6)
	,@Notes NVARCHAR(500) = NULL
	,@Opid NVARCHAR(8)
	,@ValidateScholarshipLevel BIT = 1
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(getdate())
		,@StatusDateTime DATETIME = dbo.fnMakeDate(@StatusDate);

	SET @AppliedAmount = COALESCE(@AppliedAmount, @AwardedAmount);

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

	IF (
			NOT EXISTS (
				SELECT *
				FROM SCHOLARSHIP
				WHERE SCHOLARSHIP_ID = @Scholarship
				)
			)
	BEGIN
		RAISERROR (
				'@Scholarship ''%s'' not found in SCHOLARSHIP.'
				,11
				,1
				,@Scholarship
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
				'@Department ''%'' not found in CODE_DEPARTMENT.'
				,11
				,1
				,@Department
				)

		RETURN
	END

	IF (
			NOT EXISTS (
				SELECT *
				FROM CODE_SCHOLARSHIPLEVEL
				WHERE CODE_VALUE_KEY = @Level
				)
			)
	BEGIN
		RAISERROR (
				'@Level ''%'' not found in CODE_SCHOLARSHIPLEVEL.'
				,11
				,1
				,@Level
				)

		RETURN
	END

	--Validate level configuration
	IF (
			@ValidateScholarshipLevel = 1
			AND NOT EXISTS (
				SELECT *
				FROM SCHOLARSHIPLEVELS
				WHERE SCHOLARSHIP_ID = @Scholarship
					AND [LEVEL] = @Level
				)
			)
	BEGIN
		RAISERROR (
				'@Scholarship / @Level combination ''%s/%s'' and not found in SCHOLARSHIPLEVELS.'
				,11
				,1
				,@Scholarship
				,@Level
				)

		RETURN
	END

	--Check for duplicate scholarships. PowerCampus allows this, but most schools don't.
	IF (
			SELECT COUNT(*)
			FROM PEOPLESCHOLARSHIP
			WHERE 1 = 1
				AND PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND SCHOLARSHIP_ID = @Scholarship
			) > 1
	BEGIN
		RAISERROR (
				'More than one PEOPLESCHOLARSHIP row already exists for this PEOPLE_CODE_ID, ACADEMIC_YEAR, ACADEMIC_TERM, and SCHOLARSHIP_ID: %s/%s/%s/%s.'
				,11
				,1
				,@PCID
				,@Year
				,@Term
				,@Scholarship
				)

		RETURN
	END

	--===Insert or update Scholarship row ===
	--Match on existing row
	DECLARE @PeopleScholarshipId INT = (
			SELECT TOP 1 PEOPLESCHOLARSHIP_ID
			FROM PEOPLESCHOLARSHIP
			WHERE 1 = 1
				AND PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND SCHOLARSHIP_ID = @Scholarship
			ORDER BY PEOPLESCHOLARSHIP_ID DESC
			)

	IF @PeopleScholarshipId IS NULL
	BEGIN
		--Insert new Scholarship row if not exists
		INSERT INTO [dbo].[PEOPLESCHOLARSHIP] (
			[PEOPLE_CODE_ID]
			,[ACADEMIC_YEAR]
			,[ACADEMIC_TERM]
			,[SCHOLARSHIP_ID]
			,[DEPARTMENT]
			,[LEVEL]
			,[STATUS]
			,[STATUS_DATE]
			,[APPLIED_AMOUNT]
			,[AWARDED_AMOUNT]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			)
		VALUES (
			@PCID
			,@Year
			,@Term
			,@Scholarship
			,@Department
			,@Level
			,@Status
			,@StatusDate
			,@AppliedAmount
			,@AwardedAmount
			,@Today
			,@Now
			,@Opid
			,'0001'
			,@Today
			,@Now
			,@Opid
			,'0001'
			)
	END
	ELSE
	BEGIN
		-- Update existing PEOPLESCHOLARSHIP row
		UPDATE PEOPLESCHOLARSHIP
		SET DEPARTMENT = @Department
			,[LEVEL] = @Level
			,[STATUS] = @Status
			,STATUS_DATE = @StatusDate
			,APPLIED_AMOUNT = @AppliedAmount
			,AWARDED_AMOUNT = @AwardedAmount
			,REVISION_DATE = @Today
			,REVISION_TIME = @Now
			,REVISION_OPID = @Opid
			,REVISION_TERMINAL = '0001'
		WHERE PEOPLESCHOLARSHIP_ID = @PeopleScholarshipId
			--Only update if certain columns have changed
			AND EXISTS (
				SELECT [LEVEL]
					,DEPARTMENT
					,APPLIED_AMOUNT
					,AWARDED_AMOUNT
				
				EXCEPT
				
				SELECT @Level
					,@Department
					,@AppliedAmount
					,@AwardedAmount
				)
	END

	--===Insert or update Note if present ===
	IF @Notes IS NOT NULL
	BEGIN
		IF NOT EXISTS (
				SELECT *
				FROM PEOPLESCHOLARSHIPNOTES
				WHERE 1 = 1
					AND PEOPLE_CODE_ID = @PCID
					AND ACADEMIC_YEAR = @Year
					AND ACADEMIC_TERM = @Term
					AND SCHOLARSHIP_ID = @Scholarship
				)
		BEGIN
			--Insert new Note
			INSERT INTO [dbo].[PEOPLESCHOLARSHIPNOTES] (
				[PEOPLE_CODE_ID]
				,[ACADEMIC_YEAR]
				,[ACADEMIC_TERM]
				,[SCHOLARSHIP_ID]
				,[NOTES]
				,[CREATE_DATE]
				,[CREATE_TIME]
				,[CREATE_OPID]
				,[CREATE_TERMINAL]
				,[REVISION_DATE]
				,[REVISION_TIME]
				,[REVISION_OPID]
				,[REVISION_TERMINAL]
				)
			VALUES (
				@PCID
				,@Year
				,@Term
				,@Scholarship
				,@Notes
				,@Today
				,@Now
				,@Opid
				,'0001'
				,@Today
				,@Now
				,@Opid
				,'0001'
				)
		END
		ELSE
		BEGIN
			--Update Existing Note
			UPDATE PEOPLESCHOLARSHIPNOTES
			SET [NOTES] = @Notes
				,REVISION_DATE = @Today
				,REVISION_TIME = @Now
				,REVISION_OPID = @Opid
				,REVISION_TERMINAL = '0001'
			--Only update if something has changed
			WHERE EXISTS (
					SELECT NOTES
					
					EXCEPT
					
					SELECT @Notes
					)
		END
	END
END
GO


