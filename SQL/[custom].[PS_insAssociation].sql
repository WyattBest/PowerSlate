USE [Campus6]

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2023-12-01
-- Description:	Inserts Associations data if it does not already exists. Does not updating existing.
--				Existing rows are matched on PCID, Year, Term, Session, Association, and Office Held (same as the clustered primary key).
-- =============================================
CREATE PROCEDURE [custom].[PS_insAssociation] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
	,@Association NVARCHAR(6)
	,@OfficeHeld NVARCHAR(6)
	,@Opid NVARCHAR(8)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(getdate());

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
				FROM CODE_ASSOCIATION
				WHERE CODE_VALUE_KEY = @Association
				)
			)
	BEGIN
		RAISERROR (
				'@Association ''%s'' not found in CODE_ASSOCIATION.'
				,11
				,1
				,@Association
				)

		RETURN
	END

	IF (
			NOT EXISTS (
				SELECT *
				FROM CODE_OFFICEHELD
				WHERE CODE_VALUE_KEY = @OfficeHeld
				)
			)
	BEGIN
		RAISERROR (
				'@OfficeHeld ''%s'' not found in CODE_OFFICEHELD.'
				,11
				,1
				,@OfficeHeld
				)

		RETURN
	END

	--===Insert Assocation row if not exists===
	--Check whether row already exists
	IF NOT EXISTS (
			SELECT *
			FROM ASSOCIATION
			WHERE PEOPLE_ORG_CODE_ID = @PCID
				AND ASSOCIATION = @Association
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = @Session
				AND OFFICE_HELD = @OfficeHeld
			)
	BEGIN
		--Insert new Association row if not exists
		INSERT INTO [dbo].[ASSOCIATION] (
			[PEOPLE_ORG_CODE]
			,[PEOPLE_ORG_ID]
			,[PEOPLE_ORG_CODE_ID]
			,[ASSOCIATION]
			,[ACADEMIC_YEAR]
			,[ACADEMIC_TERM]
			,[ACADEMIC_SESSION]
			,[OFFICE_HELD]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			,[ABT_JOIN]
			)
		VALUES (
			'P'
			,RIGHT(@PCID, 9)
			,@PCID
			,@ASSOCIATION
			,@Year
			,@Term
			,@Session
			,@OfficeHeld
			,@Today
			,@Now
			,@Opid
			,'0001'
			,@Today
			,@Now
			,@Opid
			,'0001'
			,'*'
			)
	END
END
GO


