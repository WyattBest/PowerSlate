USE [Campus6]
GO

/****** Object:  StoredProcedure [dbo].[MCNY_SlaPowInt_UpdAction]   ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-12-07
-- Description:	Inserts or updates a scheduled action. For simplicity, SCHEDULED_TIME is not supported.
--				
-- 2017-10-11 Wyatt Best:		Changed WAIVED_REASON from SLATE to ADMIS.
--								Fixed the 'updated waived after inserting new' section.
-- 2019-10-15	Wyatt Best:		Renamed and moved to [custom] schema.
-- 2021-06-21	Wyatt Best:		Rewrite to remove dependency on MCNY_SP_insert_action. New parameters @Responsible (optional) and @CompletedDate.
-- =============================================
CREATE PROCEDURE [custom].[PS_updAction] @PCID NVARCHAR(10)
	,@Opid NVARCHAR(8)
	,@ActionID NVARCHAR(8)
	,@ActionName NVARCHAR(50)
	,@Responsible NVARCHAR(10) = NULL
	,@ScheduledDate DATE --Slate effective date or application creation date
	,@Completed NVARCHAR(1) --Y, N, W (waived)
	,@CompletedDate DATE --Slate activity date
	,@AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@AcademicSession NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @getdate DATETIME = GETDATE()
	DECLARE @Today DATETIME = dbo.fnMakeDate(@getdate)
		,@Now DATETIME = dbo.fnMakeTime(@getdate)
		,@Waived NVARCHAR(1) = 'N'
		,@Actionschedule_Id INT

	IF @Completed = 'W'
	BEGIN
		SET @Waived = 'Y'
		SET @Completed = 'N'
	END

	DECLARE @WaivedReason NVARCHAR(6) = CASE 
			WHEN @Waived = 'Y'
				THEN 'ADMIS'
			ELSE NULL
			END

	SET @ScheduledDate = dbo.fnMakeDate(@ScheduledDate)
	SET @CompletedDate = COALESCE(dbo.fnMakeDate(@CompletedDate), @Today)
	SET @Responsible = COALESCE(@Responsible, @PCID)

	--Find existing action by PCID, Action ID, Action Name, YTS, and CREATE_OPID
	SELECT TOP 1 @Actionschedule_Id = ACTIONSCHEDULE_ID
	FROM ACTIONSCHEDULE
	WHERE PEOPLE_ORG_CODE_ID = @PCID
		AND ACTION_ID = @ActionID
		AND ACTION_NAME = @ActionName
		AND ACADEMIC_YEAR = @AcademicYear
		AND ACADEMIC_TERM = @AcademicTerm
		AND ACADEMIC_SESSION = @AcademicSession
		AND CREATE_OPID = @Opid
	ORDER BY ACTIONSCHEDULE_ID DESC

	--If match found, update various columns
	IF (@Actionschedule_Id IS NOT NULL)
		UPDATE ACTIONSCHEDULE
		SET SCHEDULED_DATE = @ScheduledDate
			,SCHEDULED_TIME = '1900-01-01 00:00:01.000'
			,RESP_STAFF = @Responsible
			,EXECUTION_DATE = CASE 
				WHEN COMPLETED <> 'Y'
					AND @Completed = 'Y'
					THEN @Today
				ELSE NULL
				END
			,COMPLETED = @Completed
			,COMPLETED_BY = CASE 
				WHEN COMPLETED_BY IS NULL
					AND @Completed = 'Y'
					THEN RESP_STAFF
				ELSE COMPLETED_BY
				END
			,WAIVED = @Waived
			,WAIVED_REASON = @WaivedReason
			,REVISION_OPID = @Opid
			,REVISION_DATE = @Today
			,REVISION_TIME = @Now
		WHERE ACTIONSCHEDULE_ID = @Actionschedule_Id
			AND EXISTS (
				SELECT SCHEDULED_DATE
					,SCHEDULED_TIME
					,RESP_STAFF
					,CASE 
						WHEN COMPLETED <> 'Y'
							AND @Completed = 'Y'
							THEN @Today
						ELSE NULL
						END [EXECUTION_DATE]
					,COMPLETED
					,WAIVED
					,WAIVED_REASON
				
				EXCEPT
				
				SELECT @ScheduledDate
					,'1900-01-01 00:00:01.000'
					,@Responsible
					,CASE 
						WHEN COMPLETED <> 'Y'
							AND @Completed = 'Y'
							THEN @Today
						ELSE NULL
						END [EXECUTION_DATE]
					,@Completed
					,@Waived
					,@WaivedReason
				)
	ELSE
	BEGIN
		--Insert the scheduled action
		INSERT INTO ACTIONSCHEDULE (
			ACTION_ID
			,PEOPLE_ORG_CODE
			,PEOPLE_ORG_ID
			,PEOPLE_ORG_CODE_ID
			,REQUEST_DATE
			,REQUEST_TIME
			,SCHEDULED_DATE
			,EXECUTION_DATE
			,CREATE_DATE
			,CREATE_TIME
			,CREATE_OPID
			,CREATE_TERMINAL
			,REVISION_DATE
			,REVISION_TIME
			,REVISION_OPID
			,REVISION_TERMINAL
			,ABT_JOIN
			,ACTION_NAME
			,OFFICE
			,[TYPE]
			,RESP_STAFF
			,COMPLETED_BY
			,[REQUIRED]
			,[PRIORITY]
			,RATING
			,RESPONSE
			,CONTACT
			,SCHEDULED_TIME
			,NOTE
			,UNIQUE_KEY
			,COMPLETED
			,WAIVED
			,WAIVED_REASON
			,CANCELED
			,CANCELED_REASON
			,NUM_OF_REMINDERS
			,ACADEMIC_YEAR
			,ACADEMIC_TERM
			,ACADEMIC_SESSION
			,RULE_ID
			,SEQ_NUM
			,DURATION
			,DOCUMENT
			,Instruction
			)
		SELECT @ActionID [ACTION_ID]
			,'P' [PEOPLE_ORG_CODE]
			,RIGHT(@PCID, 9) [PEOPLE_ORG_ID]
			,@PCID [PEOPLE_ORG_CODE_ID]
			,@Today [REQUEST_DATE]
			,@Now [REQUEST_TIME]
			,@ScheduledDate [SCHEDULED_DATE]
			,CASE 
				WHEN @Completed = 'Y'
					THEN @Today
				ELSE NULL
				END AS [EXECUTION_DATE]
			,@Today [CREATE_DATE]
			,@Now [CREATE_TIME]
			,@Opid [CREATE_OPID]
			,'0001' [CREATE_TERMINAL]
			,@Today [REVISION_DATE]
			,@Now [REVISION_TIME]
			,@Opid [REVISION_OPID]
			,'0001' [REVISION_TERMINAL]
			,'*' [ABT_JOIN]
			,coalesce(@ActionName, A.ACTION_NAME) [ACTION_NAME]
			,OFFICE
			,[TYPE]
			,@Responsible [RESP_STAFF]
			,CASE 
				WHEN @Completed = 'Y'
					THEN RESP_STAFF
				ELSE NULL
				END AS [COMPLETED_BY]
			,[REQUIRED]
			,[PRIORITY]
			,NULL [RATING]
			,NULL [RESPONSE]
			,NULL [CONTACT]
			,'1900-01-01 00:00:01.000' [SCHEDULED_TIME]
			,[NOTE]
			,@ActionId + convert(NVARCHAR(4), datepart(yy, @getdate)) + convert(NVARCHAR(2), datepart(mm, @getdate)) + convert(NVARCHAR(2), datepart(dd, @getdate)) + convert(NVARCHAR(2), datepart(hh, @getdate)) + convert(NVARCHAR(2), datepart(mi, @getdate)) + convert(NVARCHAR(4), datepart(ms, @getdate)) [UNIQUE_KEY]
			,@Completed [COMPLETED]
			,@Waived [WAIVED]
			,@WaivedReason [WAIVED_REASON]
			,'N' [CANCELED]
			,NULL [CANCELED_REASON]
			,0 [NUM_OF_REMINDERS]
			,@AcademicYear [ACADEMIC_YEAR]
			,@AcademicTerm [ACADEMIC_TERM]
			,@AcademicSession [ACADEMIC_SESSION]
			,0 [RULE_ID]
			,0 [SEQ_NUM]
			,'' [Duration]
			,NULL [DOCUMENT]
			,[Instruction]
		FROM [ACTION] A
		WHERE ACTION_ID = @ActionID
	END
END
GO


