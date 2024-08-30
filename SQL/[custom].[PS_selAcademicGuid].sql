USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2024-08-30
-- Description:	Return ACADEMIC.Guid or validate that known Guid matches known YTSPDC.
--
-- 2024-08-30 Wyatt Best:	Forked from PS_selProfile as part of bringing back support for pre-9.2.1 versions.
-- =============================================
CREATE PROCEDURE [custom].[PS_selAcademicGuid] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
	,@Program NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
	,@EmailType NVARCHAR(10)
	,@AcademicGuid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;

	--Writing a simple method for handling non-fatal errors because differentiating real
	--errors in Python is hard and varies based on the ODBC driver used.
	DECLARE @ErrorFlag BIT = 0
		,@ErrorMessage NVARCHAR(max)

	--Search for @AcademicGuid if NULL
	IF @AcademicGuid IS NULL
		SELECT @AcademicGuid = [Guid]
		FROM ACADEMIC
		WHERE PEOPLE_CODE_ID = @PCID
			AND ACADEMIC_YEAR = @Year
			AND ACADEMIC_TERM = @Term
			AND ACADEMIC_SESSION = @Session
			AND PROGRAM = @Program
			AND DEGREE = @Degree
			AND CURRICULUM = @Curriculum
	ELSE
	BEGIN
		--Verify that YTSPDC match existing @AcademicGuid
		DECLARE @TempYear NVARCHAR(4)
			,@TempTerm NVARCHAR(10)
			,@TempSession NVARCHAR(10)
			,@TempProgram NVARCHAR(6)
			,@TempDegree NVARCHAR(6)
			,@TempCurriculum NVARCHAR(6)
			,@TempPCID NVARCHAR(10)

		SELECT @TempPCID = PEOPLE_CODE_ID
			,@TempYear = ACADEMIC_YEAR
			,@TempTerm = ACADEMIC_TERM
			,@TempSession = ACADEMIC_SESSION
			,@TempProgram = PROGRAM
			,@TempDegree = DEGREE
			,@TempCurriculum = CURRICULUM
		FROM [ACADEMIC]
		WHERE [Guid] = @AcademicGuid

		IF @TempYear <> @Year
			OR @TempTerm <> @Term
			OR @TempSession <> @Session
			OR @TempProgram <> @Program
			OR @TempDegree <> @Degree
			OR @TempCurriculum <> @Curriculum
			SELECT @ErrorFlag = 1
				,@ErrorMessage = 'The Application in PowerCampus has a different YTS + PDC than the Slate application.<br />
				Expected: ' + @Year + '/' + @Term + '/' + @Session + '/' + @Program + '/' + @Degree + '/' + @Curriculum + '<br />
				Found: ' + @TempYear + '/' + @TempTerm + '/' + @TempSession + '/' + @TempProgram + '/' + @TempDegree + '/' + @TempCurriculum

		IF @TempPCID <> @PCID
			SELECT @ErrorFlag = 1
				,@ErrorMessage = 'The Application in PowerCampus has a different PEOPLE_CODE_ID than the Slate application.<br />
                Expected: ' + @PCID + '<br />
                Found: ' + @TempPCID
	END

	SELECT @ErrorFlag [ErrorFlag]
		,@ErrorMessage [ErrorMessage]
		,@AcademicGuid [AcademicGuid]
END
