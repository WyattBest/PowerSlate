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
-- Description:	Inserts or updates a scheduled action.
--				
-- Dependencies:	MCNY_SP_insert_action
--
--	2017-10-11 Wyatt Best:	Changed WAIVED_REASON from SLATE to ADMIS.
--							Fixed the 'updated waived after inserting new' section.
--  2019-10-15	Wyatt Best:	Renamed and moved to [custom] schema.
-- =============================================

CREATE PROCEDURE [custom].[PS_updAction]
	@PCID nvarchar(10)
	,@Opid nvarchar(8)
	,@action_id nvarchar(8)
	,@action_name nvarchar(50)
	,@completed nvarchar(1) --Y, N, W (waived)
	,@sched_date datetime --Slate checklist item added date
	,@year nvarchar(4)
	,@term nvarchar(10)
	,@session nvarchar(10)

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRANSACTION
		
		--DECLARE @PersonId int = dbo.fnGetPersonId(@PCID)
		DECLARE @getdate datetime = getdate()
		DECLARE @Today datetime = dbo.fnMakeDate(@getdate)
		DECLARE @Now datetime = dbo.fnMakeTime(@getdate)
		DECLARE @Waived nvarchar(1) = 'N'
		DECLARE @Actionschedule_id int

		--Just in case
		SET @sched_date = dbo.fnMakeDate(@sched_date)

		IF @completed = 'W'
			BEGIN
				SET @Waived = 'Y'
				SET @completed = 'N'
			END

		--Find closest existing action
		SELECT TOP 1 @Actionschedule_id = ACTIONSCHEDULE_ID
		FROM ACTIONSCHEDULE
		WHERE PEOPLE_ORG_CODE_ID = @PCID
			AND ACTION_ID = @action_id
			AND ACTION_NAME = @action_name
			AND ACADEMIC_YEAR = @year
			AND ACADEMIC_TERM = @term
			AND ACADEMIC_SESSION = @session
		ORDER BY ACTIONSCHEDULE_ID DESC

		--If a match found
		IF (@Actionschedule_id IS NOT NULL)
			--Update various columns
			BEGIN
				--Update completed
				IF NOT EXISTS (SELECT * FROM ACTIONSCHEDULE WHERE ACTIONSCHEDULE_ID = @Actionschedule_id AND COMPLETED = @completed)
					UPDATE ACTIONSCHEDULE
						SET COMPLETED = @completed
						,EXECUTION_DATE = @Today
						,REVISION_OPID = @Opid
						,REVISION_DATE = @Today
						,REVISION_TIME = @Now
						WHERE ACTIONSCHEDULE_ID = @Actionschedule_id
				--Update waived
				IF NOT EXISTS (SELECT * FROM ACTIONSCHEDULE WHERE ACTIONSCHEDULE_ID = @Actionschedule_id AND WAIVED = @Waived)
					UPDATE ACTIONSCHEDULE
						SET WAIVED = @Waived
						,WAIVED_REASON = 'ADMIS'
						,REVISION_OPID = @Opid
						,REVISION_DATE = @Today
						,REVISION_TIME = @Now
						WHERE ACTIONSCHEDULE_ID = @Actionschedule_id
				--Update scheduled_date and time
				IF NOT EXISTS (SELECT * FROM ACTIONSCHEDULE WHERE ACTIONSCHEDULE_ID = @Actionschedule_id AND SCHEDULED_DATE = @sched_date)
					UPDATE ACTIONSCHEDULE
						SET SCHEDULED_DATE = @sched_date
						,SCHEDULED_TIME = '1900-01-01 00:00:01.000'
						,REVISION_OPID = @Opid
						,REVISION_DATE = @Today
						,REVISION_TIME = @Now
						WHERE ACTIONSCHEDULE_ID = @Actionschedule_id
			END
		--If no match found
		ELSE
			BEGIN
				EXEC dbo.MCNY_SP_insert_action @action_id, @PCID, @sched_date, NULL, @Opid, NULL, NULL, 'Y', NULL, @completed, @year, @term, @session, @action_name, 'N'
			END
			--Update waived
			SELECT TOP 1 @Actionschedule_id = ACTIONSCHEDULE_ID
			FROM ACTIONSCHEDULE
			WHERE PEOPLE_ORG_CODE_ID = @PCID
				AND ACTION_ID = @action_id
				AND ACTION_NAME = @action_name
				AND ACADEMIC_YEAR = @year
				AND ACADEMIC_TERM = @term
				AND ACADEMIC_SESSION = @session
			ORDER BY ACTIONSCHEDULE_ID DESC

			IF NOT EXISTS (SELECT * FROM ACTIONSCHEDULE WHERE ACTIONSCHEDULE_ID = @Actionschedule_id AND WAIVED = @Waived)
				UPDATE ACTIONSCHEDULE
					SET WAIVED = @Waived
					,WAIVED_REASON = 'ADMIS'
					,REVISION_OPID = @Opid
					,REVISION_DATE = @Today
					,REVISION_TIME = @Now
					WHERE ACTIONSCHEDULE_ID = @Actionschedule_id
	COMMIT
END


GO


