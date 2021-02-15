USE [Campus6_odyssey]
GO

/****** Object:  StoredProcedure [custom].[PS_selProfile]    Script Date: 2/5/2021 12:17:22 PM ******/
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
--	2020-04-10	Wyatt Best: Added Withdrawn and CampusEmail.
--	2020-04-21	Wyatt Best: Registration check only considers PROGRAM = CERT instead of full PDC. Allows noncredit programs besides CASAC.
--	2020-05-18	Wyatt Best:	Added REG_VAL_DATE.
--	2020-06-17	Wyatt Best: Coalesce PREREG_VAL_DATE, REG_VAL_DATE.
--	2021-01-27	Wyatt Best: Genericized for MMU.
-- =============================================
CREATE PROCEDURE [custom].[PS_selProfile] @PCID NVARCHAR(10)
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
	DECLARE @Credits NUMERIC(6, 2) = (
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

	--If someone has multiple apps for one YTS with different PDC's but the same transcript sequence, you will not be able to 
	--separate the credits because TRANSCRIPTDETAIL doesn't have PDC. Custom logic is required to sort out things like-zero credit certificate
	--dual enrollment with a for-credit program.
	SELECT CASE 
			WHEN EXISTS (
					SELECT TD.PEOPLE_ID
					FROM TRANSCRIPTDETAIL TD
					INNER JOIN ACADEMIC A
						ON A.PEOPLE_CODE_ID = TD.PEOPLE_CODE_ID
							AND A.ACADEMIC_YEAR = TD.ACADEMIC_YEAR
							AND A.ACADEMIC_TERM = TD.ACADEMIC_TERM
							AND A.ACADEMIC_SESSION = TD.ACADEMIC_SESSION
							AND A.PROGRAM = @Program
							AND A.DEGREE = @Degree
							AND A.CURRICULUM = @Curriculum
							AND A.TRANSCRIPT_SEQ = TD.TRANSCRIPT_SEQ
							--AND A.ACADEMIC_FLAG = 'Y' --Can mask some issues of registrations w/out acceptance, but needed for someone who applies for CASAC and undergrad and only registers for undergrad.
							AND A.APPLICATION_FLAG = 'Y'
					WHERE TD.PEOPLE_CODE_ID = @PCID
						AND TD.ACADEMIC_YEAR = @Year
						AND TD.ACADEMIC_TERM = @Term
						AND TD.ACADEMIC_SESSION = @Session
						AND TD.ADD_DROP_WAIT = 'A'
					)
				THEN 'Y'
			ELSE 'N'
			END AS 'Registered'
		,CAST(COALESCE(PREREG_VAL_DATE, REG_VAL_DATE) AS DATE) [REG_VAL_DATE]
		,cast(@Credits AS VARCHAR(6)) AS CREDITS
		,A.COLLEGE_ATTEND
		,(
			SELECT REQUIRE_SEPDATE
			FROM CODE_ENROLLMENT
			WHERE CODE_VALUE_KEY = A.ENROLL_SEPARATION
			) AS Withdrawn
		,oE.Email AS CampusEmail
	FROM ACADEMIC A
	OUTER APPLY (
		SELECT TOP 1 Email
		FROM EmailAddress E
		WHERE E.PeopleOrgCodeId = A.PEOPLE_CODE_ID
			AND E.EmailType = 'STUDENT'
			AND E.IsActive = 1
		ORDER BY E.REVISION_DATE DESC
			,REVISION_TIME DESC
		) oE
	WHERE PEOPLE_CODE_ID = @PCID
		AND ACADEMIC_YEAR = @Year
		AND ACADEMIC_TERM = @Term
		AND ACADEMIC_SESSION = @Session
		AND PROGRAM = @Program
		AND DEGREE = @Degree
		AND CURRICULUM = @Curriculum
		AND APPLICATION_FLAG = 'Y' --Ought to be an application, or there's a problem somewhere.
END
