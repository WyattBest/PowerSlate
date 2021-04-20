USE PowerCampusMapper

--
-- If you pass values from Slate in PDC format, like DEGREE/CURRICULUM or similar, you can automatically generate
-- the XML for recruiterMapping.xml without having to use the GUI tool.
--
-- === List of Output Sections
-- 1. Programs likely missing from Datatel_academicprogramExtensionBase. See Control Switch.
-- 2. XML to paste into AcademicProgram section of recruiterMapping.xml
-- 3. Programs for which XML couldn't be generated. Likely exists in Datatel_academicprogramExtensionBase but not ProgramOfStudy.
--
-- === Control Switch
-- Should this script automatically insert new items from ProgramOfStudy into Datatel_academicprogramExtensionBase?
-- Default is 0 (off).
DECLARE @PopulateDatatel_academicprogramExtensionBase BIT = 0

SELECT DISTINCT --CP.LONG_DESC [CP.LONG_DESC]
	CD.LONG_DESC [CD.LONG_DESC]
	,CC.LONG_DESC [CC.LONG_DESC] --Can be used to populate Datatel_academicprogramExtensionBase.Datatel_name
	--,CP.CODE_VALUE_KEY [PROGRAM]
	,CD.CODE_VALUE_KEY [DEGREE]
	,CC.CODE_VALUE_KEY [CURRICULUM]
	--,ProgramOfStudyId
	,CD.CODE_VALUE_KEY + '/' + CC.CODE_VALUE_KEY [Datatel_abbreviation] --Can be used to populate Datatel_academicprogramExtensionBase.Datatel_abbreviation
INTO #POS
FROM Campus6.dbo.ProgramOfStudy POS
--LEFT JOIN Campus6.dbo.CODE_PROGRAM CP
--	ON CP.ProgramId = POS.Program
LEFT JOIN Campus6.dbo.CODE_DEGREE CD
	ON CD.DegreeId = POS.Degree
LEFT JOIN Campus6.dbo.CODE_CURRICULUM CC
	ON CC.CurriculumId = POS.Curriculum

--Programs likely missing from Datatel_academicprogramExtensionBase
SELECT *
FROM #POS
WHERE Datatel_abbreviation NOT IN (
		SELECT Datatel_abbreviation
		FROM Datatel_academicprogramExtensionBase
		)

IF @PopulateDatatel_academicprogramExtensionBase = 1
BEGIN
	INSERT INTO [dbo].[Datatel_academicprogramExtensionBase] (
		[Datatel_abbreviation]
		,[Datatel_name]
		)
	SELECT POS.Datatel_abbreviation
		,POS.[CC.LONG_DESC]
	FROM #POS POS
	WHERE Datatel_abbreviation NOT IN (
			SELECT Datatel_abbreviation
			FROM Datatel_academicprogramExtensionBase
			)
END

SELECT *
	,'<row RCCodeValue="' + Datatel_abbreviation + '" RCDesc="' + Datatel_name + '" PCDegreeCodeValue="' + (
		SELECT [DEGREE]
		FROM #POS
		WHERE [DEGREE] = (
				SELECT value
				FROM string_split(D.Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND [CURRICULUM] = (
				SELECT value
				FROM string_split(D.Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
		) + '" PCDegreeDesc="' + (
		SELECT [CD.LONG_DESC]
		FROM #POS
		WHERE [DEGREE] = (
				SELECT value
				FROM string_split(D.Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND [CURRICULUM] = (
				SELECT value
				FROM string_split(D.Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
		) + '" PCCurriculumCodeValue="' + (
		SELECT value
		FROM string_split(D.Datatel_abbreviation, '/')
		ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
		) + '" PCCurriculumDesc="' + (
		SELECT [CC.LONG_DESC]
		FROM #POS
		WHERE [DEGREE] = (
				SELECT value
				FROM string_split(D.Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND [CURRICULUM] = (
				SELECT value
				FROM string_split(D.Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
		) + '" />' [xml]
INTO #XML
FROM Datatel_academicprogramExtensionBase D

SELECT [xml]
FROM #XML
WHERE [xml] IS NOT NULL

SELECT *
FROM #XML
WHERE [xml] IS NULL

DROP TABLE #POS
	,#XML
