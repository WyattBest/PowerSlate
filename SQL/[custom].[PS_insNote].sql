USE [Campus6_odyssey]

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-01-18
-- Description:	Inserts a note if a matching note doesn't already exist.
-- =============================================
CREATE PROCEDURE [custom].[PS_insNote] @PCID NVARCHAR(10)
	,@Office NVARCHAR(10)
	,@NoteType NVARCHAR(6)
	,@Notes NVARCHAR(max)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATETIME = dbo.fnMakeDate(GETDATE())
		,@Now DATETIME = dbo.fnMakeTime(getdate());

	--Error checking
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
			NOT EXISTS (
				SELECT *
				FROM CODE_OFFICE
				WHERE CODE_VALUE_KEY = @Office
				)
			)
	BEGIN
		RAISERROR (
				'@Office not found in CODE_OFFICE.'
				,11
				,1
				)

		RETURN
	END

	IF (
			NOT EXISTS (
				SELECT *
				FROM CODE_NOTETYPE
				WHERE CODE_VALUE_KEY = @NoteType
				)
			)
	BEGIN
		RAISERROR (
				'@NoteType not found in CODE_NOTETYPE.'
				,11
				,1
				)

		RETURN
	END

	IF NOT EXISTS (
			SELECT *
			FROM NOTES
			WHERE PEOPLE_ORG_CODE_ID = @PCID
				AND OFFICE = @Office
				AND NOTE_TYPE = @NoteType
				AND RTRIM(LTRIM(NOTES)) = RTRIM(LTRIM(@Notes))
			)
		INSERT INTO [dbo].[NOTES] (
			[PEOPLE_ORG_CODE]
			,[PEOPLE_ORG_ID]
			,[PEOPLE_ORG_CODE_ID]
			,[OFFICE]
			,[NOTE_TYPE]
			,[NOTE_DATE]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			,[NOTES]
			,[ABT_JOIN]
			,[PRINT_ON_TRANS]
			)
		VALUES (
			'P'
			,RIGHT(@PCID, 9)
			,@PCID
			,@Office
			,@NoteType
			,@Today
			,@Today
			,@Now
			,'SLATE'
			,'0001'
			,@Today
			,@Now
			,'SLATE'
			,'0001'
			,@Notes
			,'*'
			,'N'
			)
END
GO


