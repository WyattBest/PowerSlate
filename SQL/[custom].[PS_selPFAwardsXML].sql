USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_selPFAwardsXML]    Script Date: 04/19/2022 10:12:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2022-03-15
-- Description:	Return XML of award data from PowerFAIDS for the award year associated with a YTS and the tracking status.
--				Award data is aggregated and intended for display on Slate dashboards.
--				The XML structure mimics Slate's own Dictionary subquery export types for compatibility with Liquid looping.
--				@UseFINAIDMAPPING toggles between selecting a single POE from ACADEMICCALENDAR or selecting multiple POE's from FINAIDMAPPING.
--				PowerFAIDS server/db names may need edited during deployment.
--
-- 2022-04-19 Wyatt Best:		Removed gross amounts and added total line.
-- 2024-05-07 Wyatt Best:		Option to use FINAIDMAPPING instead of ACADEMICCALENDAR for POE mappings.
--								Fixed @GovID datatype.
--								Restructured for efficiency.
-- =============================================
CREATE PROCEDURE [custom].[PS_selPFAwardsXML] @PCID NVARCHAR(10)
	,@GovID VARCHAR(9)
	,@AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@AcademicSession NVARCHAR(10)
	,@UseFINAIDMAPPING BIT = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @student_token INT
		,@FinAidYear INT
		,@TrackStat VARCHAR(2)
	DECLARE @POEs TABLE (
		POE INT
		,ACADEMIC_SESSION NVARCHAR(10)
		,award_year INT
		)
	DECLARE @AwardsRaw TABLE (
		[fund_long_name] VARCHAR(40)
		,[amount] NUMERIC(8, 2)
		,[attend_desc] VARCHAR(30)
		)

	--Find student
	SELECT @student_token = student_token
	FROM [POWERFAIDS].[PFaids].[dbo].[student] s
	WHERE s.alternate_id = @PCID
		OR s.student_ssn = @GovID

	--If student not found, quit immediately
	IF @student_token IS NULL
	BEGIN
		SELECT NULL

		RETURN
	END

	--Using OR in join criteria for [stu_award_year] caused inefficiency, so queries are repeated
	IF @UseFINAIDMAPPING = 1
	BEGIN
		--Get POEs from FINAIDMAPPING
		INSERT INTO @POEs
		SELECT POE
			,ACADEMIC_SESSION
			,NULL
		FROM FINAIDMAPPING
		WHERE 1 = 1
			AND ACADEMIC_YEAR = @AcademicYear
			AND ACADEMIC_TERM = @AcademicTerm
			AND (
				ACADEMIC_SESSION = @AcademicSession
				OR ACADEMIC_SESSION = ''
				)
			AND [STATUS] = 'A'

		--If POE's are mapped by Session, delete POE's with blank session
		DELETE
		FROM @POEs
		WHERE ACADEMIC_SESSION = ''
			AND EXISTS (
				SELECT *
				FROM @POEs
				WHERE ACADEMIC_SESSION > ''
				)

		--Get Aid Year by POE from PowerFAIDS
		UPDATE p_local
		SET award_year = p_remote.award_year_token
		FROM @POEs p_local
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[poe] p_remote
			ON p_local.POE = p_remote.poe_token

		--Get tracking status
		SELECT @TrackStat = tracking_status
		FROM [POWERFAIDS].[PFaids].[dbo].[student] s
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award_year] say
			ON say.award_year_token IN (
					SELECT award_year
					FROM @POEs
					)
				AND s.student_token = say.student_token
		WHERE s.student_token = @student_token

		--Get raw award data (multiple POE's method)
		INSERT INTO @AwardsRaw
		SELECT CASE 
				WHEN net_disbursement_amount > 0
					AND net_disbursement_amount <> scheduled_amount
					THEN fund_long_name + ' (Net)'
				ELSE fund_long_name
				END [fund_long_name]
			,CASE 
				WHEN net_disbursement_amount > 0
					AND net_disbursement_amount <> scheduled_amount
					THEN net_disbursement_amount
				ELSE scheduled_amount
				END [amount]
			,CASE 
				WHEN attend_desc LIKE '%sp%'
					THEN 'Spring'
				WHEN attend_desc LIKE '%fa%'
					THEN 'Fall'
				WHEN attend_desc LIKE '%su%'
					THEN 'Summer'
				END AS [attend_desc]
		FROM [POWERFAIDS].[PFaids].[dbo].[student] s
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award_year] say
			ON say.award_year_token IN (
					SELECT award_year
					FROM @POEs
					)
				AND s.student_token = say.student_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award] sa
			ON sa.stu_award_year_token = say.stu_award_year_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award_transactions] sat
			ON sat.stu_award_token = sa.stu_award_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[funds] f
			ON f.fund_token = sa.fund_ay_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[poe]
			ON poe.poe_token = sat.poe_token
		WHERE s.student_token = @student_token
	END
	ELSE
	BEGIN
		--Get single POE from ACADEMICCALENDAR
		SET @FinAidYear = (
				SELECT FIN_AID_YEAR
				FROM ACADEMICCALENDAR
				WHERE ACADEMIC_YEAR = @AcademicYear
					AND ACADEMIC_TERM = @AcademicTerm
					AND ACADEMIC_SESSION = @AcademicSession
				)

		--Get tracking status
		SELECT @TrackStat = tracking_status
		FROM [POWERFAIDS].[PFaids].[dbo].[student] s
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award_year] say
			ON say.award_year_token = @FinAidYear
				AND s.student_token = say.student_token
		WHERE s.student_token = @student_token

		--Get raw award data (single POE method)
		INSERT INTO @AwardsRaw
		SELECT CASE 
				WHEN net_disbursement_amount > 0
					AND net_disbursement_amount <> scheduled_amount
					THEN fund_long_name + ' (Net)'
				ELSE fund_long_name
				END [fund_long_name]
			,CASE 
				WHEN net_disbursement_amount > 0
					AND net_disbursement_amount <> scheduled_amount
					THEN net_disbursement_amount
				ELSE scheduled_amount
				END [amount]
			,CASE 
				WHEN attend_desc LIKE '%sp%'
					THEN 'Spring'
				WHEN attend_desc LIKE '%fa%'
					THEN 'Fall'
				WHEN attend_desc LIKE '%su%'
					THEN 'Summer'
				END AS [attend_desc]
		FROM [POWERFAIDS].[PFaids].[dbo].[student] s
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award_year] say
			ON say.award_year_token = @FinAidYear
				AND s.student_token = say.student_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award] sa
			ON sa.stu_award_year_token = say.stu_award_year_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[stu_award_transactions] sat
			ON sat.stu_award_token = sa.stu_award_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[funds] f
			ON f.fund_token = sa.fund_ay_token
		INNER JOIN [POWERFAIDS].[PFaids].[dbo].[poe]
			ON poe.poe_token = sat.poe_token
		WHERE s.student_token = @student_token
	END

	--Format awards as XML
	SELECT (
			SELECT (
					SELECT 'fund_long_name' AS [k]
						,fund_long_name AS [v]
					FOR XML path('p')
						,type
					)
				,(
					SELECT 'Summer' AS [k]
						,FORMAT(Summer, 'C0') AS [v]
					FOR XML path('p')
						,type
					)
				,(
					SELECT 'Fall' AS [k]
						,FORMAT(Fall, 'C0') AS [v]
					FOR XML path('p')
						,type
					)
				,(
					SELECT 'Spring' AS [k]
						,FORMAT(Spring, 'C0') AS [v]
					FOR XML path('p')
						,type
					)
				,(
					SELECT 'Total' AS [k]
						,FORMAT(Total, 'C0') AS [v]
					FOR XML path('p')
						,type
					)
			FROM (
				--Individual awards
				SELECT [fund_long_name]
					,[Summer]
					,[Fall]
					,[Spring]
					,COALESCE([Summer], 0) + COALESCE([Fall], 0) + COALESCE([Spring], 0) AS Total
				FROM @AwardsRaw
				PIVOT(SUM([amount]) FOR attend_desc IN (
							[Summer]
							,[Fall]
							,[Spring]
							)) xx
				
				UNION ALL
				
				--Grand total
				SELECT 'Totals' AS [fund_long_name]
					,[Summer]
					,[Fall]
					,[Spring]
					,COALESCE([Summer], 0) + COALESCE([Fall], 0) + COALESCE([Spring], 0) AS Total
				FROM @AwardsRaw
				PIVOT(SUM([amount]) FOR attend_desc IN (
							[Summer]
							,[Fall]
							,[Spring]
							)) xx
				) x
			--Remove empty lines
			WHERE [Total] > 0
			ORDER BY CASE fund_long_name
					WHEN 'Totals'
						THEN 'zzzz'
					ELSE fund_long_name
					END
			FOR XML path('row')
				,type
			) AS [XML]
		,@TrackStat AS [tracking_status]
END
