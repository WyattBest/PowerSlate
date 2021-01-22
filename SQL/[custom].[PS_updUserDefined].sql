USE [Campus6_odyssey]

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-01-20
-- Description:	Inserts or updates data in User Defined fields. Here be dragons!
-- =============================================
ALTER PROCEDURE [custom].[PS_updUserDefined] @PCID NVARCHAR(10)
	,@Column NVARCHAR(18)
	,@Value NVARCHAR(max)
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
				FROM INFORMATION_SCHEMA.COLUMNS
				WHERE TABLE_NAME = 'USERDEFINEDIND'
					AND COLUMN_NAME = @Column
				)
			)
	BEGIN
		RAISERROR (
				'@Column not found in USERDEFINEDIND. This error indicates that the User Defined Field does not exist in PowerCampus, or that you do not have VIEW DEFINITION rights on dbo.USERDEFINEDIND.'
				,11
				,1
				)

		RETURN
	END

	IF (
			SELECT CHARACTER_MAXIMUM_LENGTH
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE TABLE_NAME = 'USERDEFINEDIND'
				AND COLUMN_NAME = @Column
			) < LEN(@Value)
	BEGIN
		RAISERROR (
				'@Value exceeds the maximum length of user defined column. String would be truncated.'
				,11
				,1
				)

		RETURN
	END

	--Insert new User Defined row if not exists
	IF (
			SELECT COUNT(*)
			FROM USERDEFINEDIND
			WHERE PEOPLE_CODE_ID = @PCID
			) = 0
	BEGIN
		INSERT INTO [dbo].[USERDEFINEDIND] (
			[PEOPLE_CODE]
			,[PEOPLE_ID]
			,[PEOPLE_CODE_ID]
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
			,@Today
			,@Now
			,'SLATE'
			,'0001'
			,@Today
			,@Now
			,'SLATE'
			,'0001'
			,'*'
			)
	END
	ELSE IF (
			SELECT count(*)
			FROM USERDEFINEDIND
			WHERE PEOPLE_CODE_ID = @PCID
			) > 1
	BEGIN
		RAISERROR (
				'More than one USERDEFINEDIND row already exists for this PEOPLE_CODE_ID.'
				,11
				,1
				)

		RETURN
	END

	--Update User Defined row if needed
	DECLARE @sql NVARCHAR(1000) = N'SELECT @Result = 1 FROM USERDEFINEDIND WHERE PEOPLE_CODE_ID = @PCID AND ' + @Column + ' = @Value'
		,@Exists BIT = 0

	EXECUTE sp_executesql @stmt = @sql
		,@params = N'@Result bit OUT, @PCID nvarchar(10), @Value nvarchar(max)'
		,@PCID = @PCID
		,@Value = @Value
		,@Result = @Exists OUTPUT

	IF @Exists = 0
	BEGIN
		SET @sql = 'UPDATE USERDEFINEDIND SET ' + @Column + ' = @Value WHERE PEOPLE_CODE_ID = @PCID'

		EXECUTE sp_executesql @stmt = @sql
			,@params = N'@Value nvarchar(max), @PCID nvarchar(10)'
			,@Value = @Value
			,@PCID = @PCID

		UPDATE USERDEFINEDIND
		SET REVISION_DATE = @Today
			,REVISION_TIME = @Now
			,REVISION_OPID = 'SLATE'
		WHERE PEOPLE_CODE_ID = @PCID
	END
END
GO


