USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2017-10-16
-- Description:	Returns information for an ACADEMIC row, such as registration and readmit flag.
--				This sp is also used to detect changed primary keys (YTSPDC) and invalid COLLEGE_ATTEND values.
--
--	2017-11-03 Wyatt Best:	Updated to better handle multiple apps. Gave up on a generic method of handling CASAC.
--  2019-10-15	Wyatt Best:	Renamed and moved to [custom] schema.
--	2020-01-13	Wyatt Best: Get credits from rollup record instead of session.
-- =============================================
CREATE PROCEDURE [custom].[PS_selAcademic] @PCID NVARCHAR(10)
	,@Year NVARCHAR(4)
	,@Term NVARCHAR(10)
	,@Session NVARCHAR(10)
	,@Program NVARCHAR(6)
	,@Degree NVARCHAR(6)
	,@Curriculum NVARCHAR(6)
AS
BEGIN
	SET NOCOUNT ON;

	--Select credits from rollup to avoid duplicate hits to table
	DECLARE @Credits numeric(6,2) = (
			SELECT CREDITS
			FROM ACADEMIC A
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = @Year
				AND ACADEMIC_TERM = @Term
				AND ACADEMIC_SESSION = ''
				AND PROGRAM = @Program
				AND DEGREE = @Degree
				AND CURRICULUM = @Curriculum
			)

	--I tried hard to make this not specific to MCNY, but ultimately gave in.
	--If someone has multiple apps for a YTS with different PDC, they will be in the same transcript sequence,
	--and TranscriptDetail doesn't have PDC. I ultimately can't tell which TranscriptDetail goes with with Academic record without custom logic.
	--Filtering by credits would be fine except that we have a non-credit certificate, CASAC. Thus the CASE statement.
	SELECT CASE 
			WHEN PROGRAM = 'CERT'
				AND @Program = 'NON'
				AND @Curriculum = 'CASAC'
				AND EXISTS (
					SELECT TD.PEOPLE_ID
					FROM TRANSCRIPTDETAIL TD
					INNER JOIN ACADEMIC A --No PDC columns in TD.
						ON A.PEOPLE_CODE_ID = TD.PEOPLE_CODE_ID
							AND A.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
							AND A.ACADEMIC_TERM = TD.ACADEMIC_TERM
							AND A.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
							AND A.PROGRAM = @Program
							AND A.DEGREE = @Degree
							AND A.CURRICULUM = @Curriculum
							AND A.TRANSCRIPT_SEQ = TD.TRANSCRIPT_SEQ
							AND A.ACADEMIC_FLAG = 'Y' --Can mask some issues of registrations w/out acceptance, but needed for someone who applies for CASAC and undergrad and only registers for undergrad.
							AND A.APPLICATION_FLAG = 'Y'
					WHERE TD.PEOPLE_CODE_ID = @PCID
						AND TD.ACADEMIC_YEAR = @Year
						AND TD.ACADEMIC_TERM = @Term
						AND TD.ACADEMIC_SESSION = @Session
						AND TD.ADD_DROP_WAIT = 'A'
					)
				THEN 'Y'
			WHEN @Credits > 0
				THEN 'Y'
			ELSE 'N'
			END AS 'Registered'
		,@Credits AS CREDITS
		,A.COLLEGE_ATTEND
	FROM ACADEMIC A
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y' --Ought to be an application, or there's a problem somewhere.
		--AND ACADEMIC_FLAG = 'Y' --We want to expose issues where someone is registered without being accepted.
		AND (
			COLLEGE_ATTEND IS NULL --Returning and continuing students should not have applications.
			OR COLLEGE_ATTEND IN ('NEW', 'READ')
			)
	
	--The older, more generic approach.
	--SELECT
	--	CASE WHEN EXISTS (
	--			SELECT TD.PEOPLE_ID
	--			FROM TRANSCRIPTDETAIL TD
	--			WHERE TD.PEOPLE_CODE_ID = @PCID
	--				AND TD.ACADEMIC_YEAR = @Year
	--				AND TD.ACADEMIC_TERM = @Term
	--				AND TD.ACADEMIC_SESSION = @Session
	--				AND TD.ADD_DROP_WAIT = 'A'
	--			) THEN 'Y' ELSE 'N' END AS 'Registered'
	--	,A.CREDITS
	--	,A.COLLEGE_ATTEND
	--	FROM ACADEMIC A
	--	WHERE PEOPLE_CODE_ID = @PCID
	--		AND ACADEMIC_YEAR = @Year
	--		AND ACADEMIC_TERM = @Term
	--		AND ACADEMIC_SESSION = @Session
	--		AND PROGRAM = @Program
	--		AND DEGREE = @Degree
	--		AND CURRICULUM = @Curriculum
	--		AND APPLICATION_FLAG = 'Y' --Ought to be an application, or there's a problem somewhere.
	--		--AND ACADEMIC_FLAG = 'Y' --We want to expose issues where someone is registered without being accepted.
	--		AND (COLLEGE_ATTEND IS NULL --Returning and continuing students should not have applications.
	--			OR COLLEGE_ATTEND IN ('NEW','READ'))
END
GO


