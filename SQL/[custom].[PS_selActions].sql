USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updSMSOptIn]    Script Date: 2021-06-10 16:41:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-06-10
-- Description:	Select scheduled actions by person, CREATE_OPID, and YTS.
--
-- =============================================
CREATE PROCEDURE [custom].[PS_selActions] @PCID NVARCHAR(10)
	,@Opid NVARCHAR(8)
	,@AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@AcademicSession NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT ACTION_ID [action_id]
		,ACTION_NAME [item]
		,ACTIONSCHEDULE_ID
	FROM ACTIONSCHEDULE
	WHERE PEOPLE_ORG_CODE_ID = @PCID
		AND CREATE_OPID = @Opid
		AND ACADEMIC_YEAR = @AcademicYear
		AND ACADEMIC_TERM = @AcademicTerm
		AND ACADEMIC_SESSION = @AcademicSession
END
GO


