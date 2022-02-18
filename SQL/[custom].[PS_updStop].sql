USE [Campus6_odyssey]
GO

/****** Object:  StoredProcedure [custom].[PS_updStop]    Script Date: 2022-02-18 10:09:55 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2022-02-18
-- Description:	Insert or update a row in STOPLIST.
--				If StopReason and StopDate match an existing row, update the row. Otherwise, insert a new row.
--
-- =============================================
CREATE PROCEDURE [custom].[PS_updStop] @PCID NVARCHAR(10)
	,@StopReason NVARCHAR(8)
	,@StopDate DATE
	,@ClearedBit BIT
	,@ClearedDate DATE = NULL
	,@Comments NVARCHAR(max) = NULL
	,@Opid NVARCHAR(8)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @getdate DATETIME = getdate();
	DECLARE @Today DATETIME = dbo.fnMakeDate(@getdate)
		,@Now DATETIME = dbo.fnMakeTime(@getdate)
		,@Cleared NVARCHAR(1) = (
			SELECT CASE @ClearedBit WHEN 1 THEN 'Y' WHEN 0 THEN 'N' END
			);

	IF @ClearedBit = 0
		SET @ClearedDate = NULL

	--Error checks
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
			FROM CODE_STOPLIST
			WHERE CODE_VALUE_KEY = @StopReason
			)
	BEGIN
		RAISERROR (
				'@StopReason ''%s'' not found in CODE_STOPLIST.'
				,11
				,1
				,@StopReason
				)

		RETURN
	END

	IF EXISTS (
			SELECT *
			FROM [STOPLIST]
			WHERE PEOPLE_CODE_ID = @PCID
				AND STOP_REASON = @StopReason
				AND CAST(STOP_DATE AS DATE) = @StopDate
			)
	BEGIN
		--Update existing stop
		UPDATE [STOPLIST]
		SET CLEARED = @Cleared
			,CLEARED_DATE = @ClearedDate
			,COMMENTS = @Comments
			,REVISION_OPID = @Opid
			,REVISION_DATE = @Today
			,REVISION_TIME = @Now
	END
	ELSE
	BEGIN
		--Insert a new Stop
		INSERT INTO [dbo].[STOPLIST] (
			[PEOPLE_CODE]
			,[PEOPLE_ID]
			,[PEOPLE_CODE_ID]
			,[STOP_REASON]
			,[STOP_DATE]
			,[CLEARED]
			,[CLEARED_DATE]
			,[COMMENTS]
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
		SELECT 'P' AS [PEOPLE_CODE]
			,RIGHT(@PCID, 9) AS [PEOPLE_ID]
			,@PCID AS [PEOPLE_CODE_ID]
			,@StopReason AS [STOP_REASON]
			,@StopDate AS [STOP_DATE]
			,@Cleared AS [CLEARED]
			,@ClearedDate AS [CLEARED_DATE]
			,@Comments AS [COMMENTS]
			,@Today AS [CREATE_DATE]
			,@Now AS [CREATE_TIME]
			,@Opid AS [CREATE_OPID]
			,'0001' AS [CREATE_TERMINAL]
			,@Comments AS [REVISION_DATE]
			,@Today AS [REVISION_TIME]
			,@Now AS [REVISION_OPID]
			,@Opid AS [REVISION_TERMINAL]
			,'*' AS [ABT_JOIN]
	END
END
GO

