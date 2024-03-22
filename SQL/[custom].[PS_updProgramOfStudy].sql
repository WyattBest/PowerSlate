USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updProgramOfStudy]    Script Date: 5/17/2021 3:38:27 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-05-17
-- Description:	Inserts a PDC combination into ProgramOfStudy and ApplicationProgramSetting if it doesn't already exist.
--				If @DegReqMinYear is not null, PDC combination will be valided against DEGREQ.
--
-- 2024-03-21 Wyatt Best:	Also insert into ApplicationProgramSetting.
-- =============================================
CREATE PROCEDURE [custom].[PS_updProgramOfStudy] @Program NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
	,@DegReqMinYear NVARCHAR(4) = NULL
	,@AppFormSettingId INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ProgramId INT = (
			SELECT ProgramId
			FROM CODE_PROGRAM
			WHERE CODE_VALUE_KEY = @Program
			)
		,@DegreeId INT = (
			SELECT DegreeId
			FROM CODE_DEGREE
			WHERE CODE_VALUE_KEY = @Degree
			)
		,@CurriculumId INT = (
			SELECT CurriculumId
			FROM CODE_CURRICULUM
			WHERE CODE_VALUE_KEY = @Curriculum
			);

	--Error checks
	IF @ProgramId IS NULL
	BEGIN
		RAISERROR (
				'@Program ''%s'' not found in CODE_PROGRAM.'
				,11
				,1
				,@Program
				)

		RETURN
	END

	IF @DegreeId IS NULL
	BEGIN
		RAISERROR (
				'@Degree ''%s'' not found in CODE_DEGREE.'
				,11
				,1
				,@Degree
				)

		RETURN
	END

	IF @CurriculumId IS NULL
	BEGIN
		RAISERROR (
				'@Curriculum ''%s'' not found in CODE_CURRICULUM.'
				,11
				,1
				,@Curriculum
				)

		RETURN
	END

	IF @DegReqMinYear IS NOT NULL
		AND NOT EXISTS (
			SELECT *
			FROM ACADEMICCALENDAR
			WHERE ACADEMIC_YEAR = @DegReqMinYear
			)
	BEGIN
		RAISERROR (
				'@DegReqMinYear ''%s'' not found in ACADEMICCALENDAR.'
				,11
				,1
				,@DegReqMinYear
				)

		RETURN
	END

	--Get existing ProgramOfStudyId
	DECLARE @ProgramOfStudyId INT = (
			SELECT ProgramOfStudyId
			FROM ProgramOfStudy
			WHERE Program = @ProgramId
				AND Degree = @DegreeId
				AND Curriculum = @CurriculumId
			);

	--If ProgramOfStudyId is null, insert it
	IF @ProgramOfStudyId IS NULL
	BEGIN
		--Optionally check against DEGREQ
		IF @DegReqMinYear IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM DEGREQ
				WHERE MATRIC_YEAR = @DegReqMinYear
					AND PROGRAM = @Program
					AND DEGREE = @Degree
					AND CURRICULUM = @Curriculum
				)
		BEGIN
			RAISERROR (
					'Combination ''%s/%s/%s'' not found in DEGREQ for year ''%s'' or later.'
					,11
					,1
					,@Program
					,@Degree
					,@Curriculum
					,@DegReqMinYear
					)

			RETURN
		END

		--Insert new ProgramOfStudy 
		INSERT INTO ProgramOfStudy (
			Program
			,Degree
			,Curriculum
			)
		VALUES (
			@ProgramId
			,@DegreeId
			,@CurriculumId
			);

		--Get the newly-inserted ProgramOfStudyId
		SET @ProgramOfStudyId = SCOPE_IDENTITY();
	END

	--Check for existing ApplicationProgramSetting row
	IF NOT EXISTS (
			SELECT *
			FROM ApplicationProgramSetting
			WHERE ApplicationFormSettingId = @AppFormSettingId
				AND ProgramOfStudyId = @ProgramOfStudyId
			)
	BEGIN
		--Insert new ProgramOfStudyId
		INSERT INTO ApplicationProgramSetting (
			ApplicationFormSettingId
			,ProgramOfStudyId
			)
		VALUES (
			@AppFormSettingId
			,@ProgramOfStudyId
			);
	END
END
