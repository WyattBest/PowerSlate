USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-11-17
-- Description:	Updates Status and Decision code for application from Slate.
--				Sets ACADEMIC_FLAG if needed (an API defect).
--				Sets PRIMARY_FLAG
--
--	2016-12-15	Wyatt Best: Added 'Defer' ProposedDecision type.
--	2016-12-28	Wyatt Best:	Changed translation CODE_APPDECISION for Waiver from 'ACCP' to 'WAIV'
--	2017-01-09	Wyatt Best: Added code to set PRIMARY_FLAG. Assuming that a current admissions application should be the primary activity.
--	2017-01-10	Wyatt Best: Added 'Withdraw' ProposedDecision type.
--	2017-08-16	Wyatt Best:	Added 'Deny' ProposedDecision type.
--  2019-10-15	Wyatt Best:	Renamed and moved to [custom] schema.
--	2019-12-09	Wyatt Best: Added UPDATE for APPLICATION_DATE
-- =============================================

CREATE PROCEDURE [custom].[PS_updAcademicAppInfo]
	@PCID nvarchar(10)
	,@Year nvarchar(4)
	,@Term nvarchar(10)
	,@Session nvarchar(10)
	,@Program nvarchar(6)
	,@Degree nvarchar(6)
	,@Curriculum nvarchar(6)
	,@ProposedDecision nvarchar(max) --Slate data field; translation will happen in this sp
	,@CreateDateTime datetime --Application creation date

AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ProgramOfStudyId int
	DECLARE @SessionPeriodId int
	DECLARE @AppStatusId int
	DECLARE @AppDecisionId int
	DECLARE @Status nvarchar(4)
	DECLARE @Decision nvarchar(4)

	SELECT @ProgramOfStudyId = ProgramOfStudyId
    FROM ProgramOfStudy pos
        INNER JOIN dbo.CODE_PROGRAM cp
            ON cp.ProgramId = pos.PROGRAM
            AND cp.CODE_VALUE = @Program
        INNER JOIN dbo.CODE_DEGREE cd
            ON cd.DegreeId = pos.DEGREE
            AND cd.CODE_VALUE = @Degree
        INNER JOIN dbo.CODE_CURRICULUM cc
            ON cc.CurriculumId = pos.CURRICULUM
            AND cc.CODE_VALUE = @Curriculum

	SELECT @SessionPeriodId = SessionPeriodId
	FROM ACADEMICCALENDAR
	WHERE ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
	
	SELECT @AppStatusId = ApplicationStatusId
	FROM CODE_APPSTATUS
	WHERE STATUS = 'A' AND CODE_VALUE_KEY =
		CASE @ProposedDecision
			WHEN 'Accept' THEN 'COMP'
			WHEN 'Waiver' THEN 'WAVI'
			WHEN 'Defer' THEN 'CANC'
			WHEN 'Withdraw' THEN 'CANC'
			WHEN 'Deny' THEN 'CANC'
		ELSE 'INCP'
		END

	SELECT @AppDecisionId = ApplicationDecisionId
	FROM CODE_APPDECISION
	WHERE STATUS = 'A' AND CODE_VALUE_KEY =
		CASE @ProposedDecision
			WHEN 'Accept' THEN 'ACCP'
			WHEN 'Waiver' THEN 'WAIV'
			WHEN 'Defer' THEN 'DEFR'
			WHEN 'Withdraw' THEN 'WITH'
			WHEN 'Deny' THEN 'DECL'
		ELSE 'PEND'
		END

	SELECT @Status = (SELECT CODE_VALUE_KEY FROM dbo.CODE_APPSTATUS WHERE ApplicationStatusId = @AppStatusId)
	SELECT @Decision = (SELECT CODE_VALUE_KEY FROM dbo.CODE_APPDECISION WHERE ApplicationDecisionId = @AppDecisionId)

	BEGIN TRANSACTION
		
		--Update Status and Decision if needed
		IF NOT EXISTS (SELECT * FROM ACADEMIC
						WHERE PEOPLE_CODE_ID = @PCID
						AND ACADEMIC_YEAR = @Year
						AND ACADEMIC_TERM = @Term
						AND ACADEMIC_SESSION = @Session
						AND PROGRAM = @Program
						AND DEGREE = @Degree
						AND CURRICULUM = @Curriculum
						AND APPLICATION_FLAG = 'Y'
						AND APP_STATUS = @Status
						AND APP_DECISION = @Decision)

			EXEC [WebServices].[spUpdAcademicAppInfo] @PCID, @SessionPeriodId, @ProgramOfStudyId, @AppStatusId, @AppDecisionId;

		-- Set PRIMARY_FLAG if needed
		IF NOT EXISTS (SELECT * FROM ACADEMIC WHERE PEOPLE_CODE_ID = @PCID AND ACADEMIC_YEAR = @Year AND ACADEMIC_TERM = @Term AND ACADEMIC_SESSION = @Session AND APPLICATION_FLAG = 'Y' AND PRIMARY_FLAG = 'Y')

			UPDATE dbo.ACADEMIC
			SET PRIMARY_FLAG = 'Y'
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = @Session
				AND APPLICATION_FLAG = 'Y';

		-- Set ACADEMIC_FLAG if needed
		IF EXISTS (SELECT * FROM CODE_APPSTATUS WHERE ApplicationStatusId = @AppStatusId AND STATUS = 'A' AND CONFIRMED_STATUS = 'Y')
			AND EXISTS (SELECT * FROM CODE_APPDECISION WHERE ApplicationDecisionId = @AppDecisionId AND STATUS = 'A' AND ACCEPTED_DECISION = 'Y')
			AND NOT EXISTS (SELECT * FROM ACADEMIC WHERE PEOPLE_CODE_ID = @PCID AND ACADEMIC_YEAR = @Year AND ACADEMIC_TERM = @Term AND ACADEMIC_SESSION = @Session AND APPLICATION_FLAG = 'Y' AND ACADEMIC_FLAG = 'Y')

			UPDATE dbo.ACADEMIC
			SET ACADEMIC_FLAG = 'Y'
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = @Session
				AND APPLICATION_FLAG = 'Y';

		--Set APPLICATION_DATE if needed
		UPDATE ACADEMIC
		SET APPLICATION_DATE = dbo.fnMakeDate(@CreateDateTime)
		WHERE PEOPLE_CODE_ID = @PCID
			AND ACADEMIC_YEAR = @Year
			AND ACADEMIC_TERM = @Term
			AND ACADEMIC_SESSION = @Session
			AND APPLICATION_FLAG = 'Y'
			AND APPLICATION_DATE <> dbo.fnMakeDate(@CreateDateTime);

	COMMIT
	
END


GO


