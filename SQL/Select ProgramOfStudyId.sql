USE [Campus6_train]

--Sample of how to obtain ProgramOfStudyId
select ProgramOfStudyId
from ProgramOfStudy pos
	inner join dbo.CODE_PROGRAM cp
		on cp.ProgramId = pos.PROGRAM
		and cp.CODE_VALUE = 'UNDER'
	inner join dbo.CODE_DEGREE cd
		on cd.DegreeId = pos.DEGREE
		and cd.CODE_VALUE = 'AA'
	inner join dbo.CODE_CURRICULUM cc
		on cc.CurriculumId = pos.CURRICULUM
		and cc.CODE_VALUE = 'HS2010'