USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-11-11
-- Description:	Get a string description of the most recent ISIR in PowerFAIDS.
--				Used for SlaPowInt (Slate - PowerCampus Integration)
--
--  2019-10-15	Wyatt Best:	Renamed and moved to [custom] schema.
-- =============================================
CREATE PROCEDURE [custom].[PS_selISIR]
	@GovId nvarchar(9)

AS
BEGIN
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT TOP 1
	vsd.doc_name + ' - ' + vsd.doc_status_desc + ' ' + CONVERT(nvarchar(50), vsd.status_effective_dt, 101) [ISIR]
	--,vsd.doc_status_desc [DocStatus]
	--,vsd.award_year_token [DocAcademicYear]
	FROM vmcnypf.PFaids.dbo.v_stu_docs vsd
	WHERE vsd.doc_short_name = 'ISIR'
		AND vsd.student_ssn = @GovId
	ORDER BY vsd.award_year_token DESC

END


GO


