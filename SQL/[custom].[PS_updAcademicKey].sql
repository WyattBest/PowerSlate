USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updAcademicAppInfo]    Script Date: 2/18/2021 3:20:41 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-03-17
-- Description:	Updates [custom].AcademicKey with RecruiterApplicationId. See https://github.com/WyattBest/PowerCampus-AcademicKey
-- =============================================
CREATE PROCEDURE [custom].[PS_updAcademicKey] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
	,@Program NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
	,@aid UNIQUEIDENTIFIER NULL
AS
BEGIN
	SET NOCOUNT ON;

	--Update AcademicKey if needed
	IF NOT EXISTS (
			SELECT *
			FROM RecruiterApplication RA
			INNER JOIN [custom].AcademicKey AK
				ON AK.RecruiterApplicationId = RA.RecruiterApplicationId
			WHERE RA.ApplicationNumber = @aid
			)
		UPDATE AK
		SET AK.RecruiterApplicationId = RA.RecruiterApplicationId
		FROM [custom].AcademicKey AK
		INNER JOIN RecruiterApplication RA
			ON RA.ApplicationNumber = @aid
		WHERE PEOPLE_CODE_ID = @PCID
			AND ACADEMIC_YEAR = @Year
			AND ACADEMIC_TERM = @Term
			AND ACADEMIC_SESSION = @Session
			AND PROGRAM = @Program
			AND DEGREE = @Degree
			AND CURRICULUM = @Curriculum
END
GO


