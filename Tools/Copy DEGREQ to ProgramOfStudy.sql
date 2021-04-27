USE campus6

BEGIN TRAN

INSERT INTO [dbo].[ProgramOfStudy] (
	[Program]
	,[Degree]
	,[Curriculum]
	)
SELECT DISTINCT CP.ProgramId
	,CD.DegreeId
	,CC.CurriculumId
FROM DEGREQ D
INNER JOIN CODE_PROGRAM CP
	ON CP.CODE_VALUE_KEY = D.PROGRAM
INNER JOIN CODE_DEGREE CD
	ON CD.CODE_VALUE_KEY = D.DEGREE
INNER JOIN CODE_CURRICULUM CC
	ON CC.CODE_VALUE_KEY = D.CURRICULUM
WHERE 1 = 1
	AND MATRIC_YEAR = '2021'
	AND NOT EXISTS (
		SELECT *
		FROM ProgramOfStudy PS2
		WHERE PS2.Program = CP.ProgramId
			AND PS2.Degree = CD.DegreeId
			AND PS2.Curriculum = CC.CurriculumId
		)
	--Exclude some degree types as needed
	-- AND DegreeId NOT IN (
		-- 5
		-- ,6
		-- ,13
		-- ,16
		-- )

ROLLBACK TRAN
