USE PowerCampusMapper

--
-- If you pass values from Slate in PDC format, like PROGRAM/CURRICULUM or similar, you can automatically generate
-- the XML for recruiterMapping.xml without having to use the GUI tool.
--

SELECT CP.LONG_DESC [CP.LONG_DESC]
	,CD.LONG_DESC [CD.LONG_DESC]
	,CC.LONG_DESC [CC.LONG_DESC]
	,CP.CODE_VALUE_KEY [CP.CODE_VALUE_KEY]
	,CD.CODE_VALUE_KEY [CD.CODE_VALUE_KEY]
	,CC.CODE_VALUE_KEY [CC.CODE_VALUE_KEY]
	,ProgramOfStudyId
INTO #POS
FROM Campus6.dbo.ProgramOfStudy POS
LEFT JOIN Campus6.dbo.CODE_PROGRAM CP
	ON CP.ProgramId = POS.Program
LEFT JOIN Campus6.dbo.CODE_DEGREE CD
	ON CD.DegreeId = POS.Degree
LEFT JOIN Campus6.dbo.CODE_CURRICULUM CC
	ON CC.CurriculumId = POS.Curriculum
--WHERE CP.CODE_VALUE <> 'UNDER2'

SELECT *
FROM #POS

SELECT *
	,'<row RCCodeValue="' + Datatel_abbreviation + '" RCDesc="' + Datatel_name + '" PCDegreeCodeValue="' + (
		SELECT [CD.CODE_VALUE_KEY]
		FROM #POS
		WHERE [CP.CODE_VALUE_KEY] = (
				SELECT value
				FROM string_split(Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND [CC.CODE_VALUE_KEY] = (
				SELECT value
				FROM string_split(Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
		) + '" PCDegreeDesc="' + (
		SELECT [CD.LONG_DESC]
		FROM #POS
		WHERE [CP.CODE_VALUE_KEY] = (
				SELECT value
				FROM string_split(Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND [CC.CODE_VALUE_KEY] = (
				SELECT value
				FROM string_split(Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
		) + '" PCCurriculumCodeValue="' + (
		SELECT value
		FROM string_split(Datatel_abbreviation, '/')
		ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
		) + '" PCCurriculumDesc="' + (
		SELECT [CC.LONG_DESC]
		FROM #POS
		WHERE [CP.CODE_VALUE_KEY] = (
				SELECT value
				FROM string_split(Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 0 rows FETCH NEXT 1 rows ONLY
				)
			AND [CC.CODE_VALUE_KEY] = (
				SELECT value
				FROM string_split(Datatel_abbreviation, '/')
				ORDER BY @@rowcount offset 1 rows FETCH NEXT 1 rows ONLY
				)
		) + '" />' [xml]
FROM Datatel_academicprogramExtensionBase

DROP TABLE #POS
