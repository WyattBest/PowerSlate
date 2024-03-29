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
--				award_year_token in PowerFAIDS is pulled from FIN_AID_YEAR in ACADEMICCALENDAR.
--
-- 2020-11-12 Wyatt Best:	Added search by TIN/SSN (@GovID) instead of just PEOPLE_CODE_ID (@PCID).
-- 2021-04-02 Wyatt Best:	Changed @GovID datatype from INT to match PFaids column.
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

	DECLARE @FinAidYear NVARCHAR(4) = (
			SELECT FIN_AID_YEAR
			FROM ACADEMICCALENDAR
			WHERE ACADEMIC_YEAR = @AcademicYear
				AND ACADEMIC_TERM = @AcademicTerm
				AND ACADEMIC_SESSION = @AcademicSession
			)

	SELECT srd.doc_token [Code]
		--,d.doc_name
		,doc_status_desc [Status]
		,FORMAT(status_effective_dt, 'yyyy-MM-dd') [Date]
	FROM [PFaids].[dbo].[student] s
	INNER JOIN [PFaids].[dbo].[stu_award_year] say
		ON say.award_year_token = @FinAidYear
			AND s.student_token = say.student_token
	INNER JOIN [PFaids].[dbo].[student_required_documents] srd
		ON say.stu_award_year_token = srd.stu_award_year_token
	INNER JOIN [PFaids].[dbo].[docs] d
		ON d.doc_token = srd.doc_token
	INNER JOIN [PFaids].[dbo].[doc_status_code] dsc
		ON dsc.doc_required_status_code = srd.doc_status
	WHERE s.alternate_id = @PCID
		OR s.student_ssn = @GovID
END
