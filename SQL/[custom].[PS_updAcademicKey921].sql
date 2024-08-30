USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-03-17
-- Description:	Updates PROGRAM, DEGREE, and CURRICULUM rows in ACADEMIC if program change happens in Slate before registration or academic plan assignment.
--				Set APPLICATION_FLAG to 'Y' if necessary (fix rows manually entered in Academic Records before application was inserted).
--
-- 2021-09-01 Wyatt Best:	Clear bad RecruiterApplicationId entries.
-- 2022-04-04 Wyatt Best:	Add ability to update PROGRAM/DEGREE/CURRICULUM in ACADEMIC. Stop clearing bad RecruiterApplicationId entries.
-- 2024-03-29 Wyatt Best:	Rewritten to use 9.2.3's built-in Academic.Guid instead of a custom key. Formerly used https://github.com/WyattBest/PowerCampus-AcademicKey.
--							Set APPLICATION_FLAG to 'Y' if necessary.
-- 2024-08-30 Wyatt Best:	Forked from PS_updAcademicKey as part of bringing back support for pre-9.2.1 versions.
-- =============================================
CREATE PROCEDURE [custom].[PS_updAcademicKey921] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
	,@Program NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
	,@AcademicGuid UNIQUEIDENTIFIER NULL
AS
BEGIN
	SET NOCOUNT ON;

	IF @AcademicGuid IS NOT NULL
		--If the GUID is provided, potentially update PDC and APPLICATION_FLAG
		UPDATE A
		SET PROGRAM = @Program
			,DEGREE = @Degree
			,CURRICULUM = @Curriculum
			,APPLICATION_FLAG = 'Y'
		FROM ACADEMIC A
		WHERE 1 = 1
			AND A.[Guid] = @AcademicGuid
			AND (
				A.PROGRAM <> @Program
				OR A.DEGREE <> @Degree
				OR A.CURRICULUM <> @Curriculum
				OR A.APPLICATION_FLAG <> 'Y'
				)
			AND [STATUS] <> 'N'
			AND CREDITS = 0
			AND REG_VALIDATE = 'N'
			AND PREREG_VALIDATE = 'N'
			AND ACA_PLAN_SETUP = 'N'
	ELSE
		--If the GUID is not provided, update APPLICATION_FLAG based on the provided YTSPDC
		UPDATE ACADEMIC
		SET APPLICATION_FLAG = 'Y'
		WHERE 1 = 1
			AND PEOPLE_CODE_ID = @PCID
			AND ACADEMIC_YEAR = @Year
			AND ACADEMIC_SESSION = @Session
			AND ACADEMIC_TERM = @Term
			AND PROGRAM = @Program
			AND DEGREE = @Degree
			AND CURRICULUM = @Curriculum
			AND [STATUS] <> 'N'
			AND APPLICATION_FLAG <> 'Y'
END
