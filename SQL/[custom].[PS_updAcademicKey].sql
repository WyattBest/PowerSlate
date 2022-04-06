USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updAcademicKey]    Script Date: 2021-09-03 13:47:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-03-17
-- Description:	Updates [custom].AcademicKey with RecruiterApplicationId. See https://github.com/WyattBest/PowerCampus-AcademicKey
--				Updates PROGRAM, DEGREE, and CURRICULUM rows in ACADEMIC if program change happens in Slate before registration or academic plan assignment.
--
-- 2021-09-01 Wyatt Best:	Clear bad RecruiterApplicationId entries.
-- 2022-04-04 Wyatt Best:	Add ability to update PROGRAM/DEGREE/CURRICULUM in ACADEMIC. Stop clearing bad RecruiterApplicationId entries.
-- =============================================
CREATE PROCEDURE [custom].[PS_updAcademicKey] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
	,@Program NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
	,@SlateAppGuid UNIQUEIDENTIFIER NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @RecruiterApplicationId INT = (
			SELECT RecruiterApplicationId
			FROM RecruiterApplication
			WHERE ApplicationNumber = @SlateAppGuid
				AND ApplicationId IS NOT NULL
			)

	IF @RecruiterApplicationId IS NOT NULL
	BEGIN
		-- Find ACADEMIC row ID
		DECLARE @AcademicGuid UNIQUEIDENTIFIER = (
				SELECT [id]
				FROM [custom].AcademicKey
				WHERE RecruiterApplicationId = @RecruiterApplicationId
				)

		IF @AcademicGuid IS NOT NULL
		BEGIN
			-- Potentially update ACADEMIC row PDC
			UPDATE A
			SET PROGRAM = @Program
				,DEGREE = @Degree
				,CURRICULUM = @Curriculum
			FROM ACADEMIC A
			INNER JOIN [custom].academickey AK
				ON AK.PEOPLE_CODE_ID = A.PEOPLE_CODE_ID
					AND AK.ACADEMIC_YEAR = A.ACADEMIC_YEAR
					AND AK.ACADEMIC_SESSION = A.ACADEMIC_SESSION
					AND AK.ACADEMIC_TERM = A.ACADEMIC_TERM
					AND AK.PROGRAM = A.PROGRAM
					AND AK.DEGREE = A.DEGREE
					AND AK.CURRICULUM = A.CURRICULUM
			WHERE 1 = 1
				AND AK.ID = @AcademicGuid
				AND A.PEOPLE_CODE_ID = @PCID
				AND A.ACADEMIC_YEAR = @Year
				AND A.ACADEMIC_SESSION = @Session
				AND A.ACADEMIC_TERM = @Term
				AND (
					A.PROGRAM <> @Program
					OR A.DEGREE <> @Degree
					OR A.CURRICULUM <> @Curriculum
					)
				AND [STATUS] <> 'N'
				AND APPLICATION_FLAG = 'Y'
				AND CREDITS = 0
				AND REG_VALIDATE = 'N'
				AND PREREG_VALIDATE = 'N'
				AND ACA_PLAN_SETUP = 'N'
		END

		---- Find and clear RecruiterApplicationId from [custom].AcademicKey if not matched
		--UPDATE [custom].AcademicKey
		--SET RecruiterApplicationId = NULL
		--WHERE RecruiterApplicationId = @RecruiterApplicationId
		--	AND (
		--		PEOPLE_CODE_ID <> @PCID
		--		OR ACADEMIC_YEAR <> @Year
		--		OR ACADEMIC_TERM <> @Term
		--		OR ACADEMIC_SESSION <> @Session
		--		OR PROGRAM <> @Program
		--		OR DEGREE <> @Degree
		--		OR CURRICULUM <> @Curriculum
		--		)
		-- Update AcademicKey if needed
		IF NOT EXISTS (
				SELECT *
				FROM RecruiterApplication RA
				INNER JOIN [custom].AcademicKey AK
					ON AK.RecruiterApplicationId = RA.RecruiterApplicationId
				WHERE RA.ApplicationNumber = @SlateAppGuid
				)
			UPDATE AK
			SET AK.RecruiterApplicationId = RA.RecruiterApplicationId
			FROM [custom].AcademicKey AK
			INNER JOIN RecruiterApplication RA
				ON RA.ApplicationNumber = @SlateAppGuid
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = @Session
				AND PROGRAM = @Program
				AND DEGREE = @Degree
				AND CURRICULUM = @Curriculum
	END
END
