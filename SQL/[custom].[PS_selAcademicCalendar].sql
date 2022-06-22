USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_selAcademicCalendar]    Script Date: 4/28/2022 11:24:21 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2022-04-28
-- Description:	Return a row from ACADEMICCALENDAR.
--
-- =============================================
CREATE PROCEDURE [custom].[PS_selAcademicCalendar] @Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT [ACADEMIC_YEAR]
		,[ACADEMIC_TERM]
		,[ACADEMIC_SESSION]
		,[START_DATE]
		,[END_DATE]
		,[FISCAL_YEAR]
		,[ACADEMIC_WEEKS]
		,[ACADEMIC_MONTHS]
		,[NUMBER_COURSES]
		,[PRE_REG_DATE]
		,[REG_DATE]
		,[LAST_REG_DATE]
		,[GRADE_WTHDRWL_DATE]
		,[GRADE_PENALTY_DATE]
		,[TRUE_ACADEMIC_YEAR]
		,[FIN_AID_YEAR]
		,[FIN_AID_TERM]
		,[MID_START_DATE]
		,[MID_END_DATE]
		,[FINAL_START_DATE]
		,[FINAL_END_DATE]
		,[SessionPeriodId]
		,[FinAidNonTerm]
	FROM ACADEMICCALENDAR
	WHERE ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
END
GO

