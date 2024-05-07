USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2020-09-30
-- Description:	Selects a list of missing documents from PowerFAIDS.
--				PowerFAIDS server/db names may need edited during deployment. @UseFINAIDMAPPING may need toggled.
--
-- 2020-11-12 Wyatt Best:	Added search by TIN/SSN (@GovID) instead of just PEOPLE_CODE_ID (@PCID).
-- 2021-04-02 Wyatt Best:	Changed @GovID datatype from INT to match PFaids column.
-- 2024-05-07 Wyatt Best:	Option to use FINAIDMAPPING instead of ACADEMICCALENDAR for POE mappings.
-- =============================================
CREATE PROCEDURE [custom].[PS_selPFChecklist]
	@PCID NVARCHAR(10)
	,@GovID VARCHAR(9)
	,@AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@AcademicSession NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	--Switch for whether to use ACADEMICCALENDAR (default) or FINAIDMAPPING as the POE source
	DECLARE @UseFINAIDMAPPING BIT = 0
		,@FinAidYear INT
	DECLARE @POEs TABLE (
		POE INT
		,ACADEMIC_SESSION NVARCHAR(10)
		,award_year INT
		)

	IF @UseFINAIDMAPPING = 1
	BEGIN
		--Get POEs from FINAIDMAPPING
		INSERT INTO @POEs
		SELECT POE
			,ACADEMIC_SESSION
			,NULL
		FROM FINAIDMAPPING
		WHERE 1 = 1
			AND ACADEMIC_YEAR = @AcademicYear
			AND ACADEMIC_TERM = @AcademicTerm
			AND (
				ACADEMIC_SESSION = @AcademicSession
				OR ACADEMIC_SESSION = ''
				)
			AND [STATUS] = 'A'

		--If POE's are mapped by Session, delete POE's with blank session
		DELETE
		FROM @POEs
		WHERE ACADEMIC_SESSION = ''
			AND EXISTS (
				SELECT *
				FROM @POEs
				WHERE ACADEMIC_SESSION > ''
				)

		--Get Aid Year by POE from PowerFAIDS
		UPDATE p_local
		SET award_year = p_remote.award_year_token
		FROM @POEs p_local
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[poe] p_remote
			ON p_local.POE = p_remote.poe_token
	END
	ELSE
	BEGIN
		--Get single POE from ACADEMICCALENDAR
		SET @FinAidYear = (
				SELECT FIN_AID_YEAR
				FROM ACADEMICCALENDAR
				WHERE ACADEMIC_YEAR = @AcademicYear
					AND ACADEMIC_TERM = @AcademicTerm
					AND ACADEMIC_SESSION = @AcademicSession
				)
	END

	SELECT srd.doc_token [Code]
		--,d.doc_name
		,doc_status_desc [Status]
		,FORMAT(status_effective_dt, 'yyyy-MM-dd') [Date]
	FROM [POWERFAIDS].[PFaids].[dbo].[student] s
	INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award_year] say
		ON (
				@UseFINAIDMAPPING = 0
				AND say.award_year_token = @FinAidYear
				)
			OR (
				@UseFINAIDMAPPING = 1
				AND say.award_year_token IN (
					SELECT award_year
					FROM @POEs
					)
				)
			AND s.student_token = say.student_token
	INNER JOIN [POWERFAIDS].[PFaids].[dbo].[student_required_documents] srd
		ON say.stu_award_year_token = srd.stu_award_year_token
	INNER JOIN [POWERFAIDS].[PFaids].[dbo].[docs] d
		ON d.doc_token = srd.doc_token
	INNER JOIN [POWERFAIDS].[PFaids].[dbo].[doc_status_code] dsc
		ON dsc.doc_required_status_code = srd.doc_status
	WHERE s.alternate_id = @PCID
		OR s.student_ssn = @GovID
END
