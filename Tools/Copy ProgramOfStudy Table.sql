USE Campus6_odyssey

--
-- Tool for copying ProgramOfStudy table from production database back to test database.
--

SELECT *
FROM programofstudy
ORDER BY ProgramOfStudyId

SELECT *
FROM campus6.dbo.programofstudy
ORDER BY ProgramOfStudyId

BEGIN TRAN

SET IDENTITY_INSERT CAMPUS6_ODYSSEY.[dbo].[ProgramOfStudy] ON

DELETE
FROM Campus6_odyssey.[dbo].[ProgramOfStudy]
WHERE ProgramOfStudyId <> 1

INSERT INTO [dbo].[ProgramOfStudy] (
	ProgramOfStudyId
	,[Program]
	,[Degree]
	,[Curriculum]
	)
SELECT ProgramOfStudyId
	,Program
	,degree
	,curriculum
FROM campus6.dbo.programofstudy p2
WHERE 1 = 1
	--AND ProgramOfStudyId NOT IN (
	--	SELECT programofstudyid
	--	FROM programofstudy
	--	)
	AND ProgramOfStudyId <> 1

SET IDENTITY_INSERT CAMPUS6_ODYSSEY.[dbo].[ProgramOfStudy] OFF

SELECT *
FROM ProgramOfStudy P1
LEFT JOIN Campus6.dbo.ProgramOfStudy P2
	ON P1.ProgramOfStudyId = P2.ProgramOfStudyId
WHERE CHECKSUM(P1.ProgramOfStudyId, P1.Program, P1.Degree, P1.Curriculum) <> CHECKSUM(P2.ProgramOfStudyId, P2.Program, P2.Degree, P2.Curriculum)

ROLLBACK TRAN
