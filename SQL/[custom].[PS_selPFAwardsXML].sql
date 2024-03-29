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
--
-- 2022-04-19	Wyatt Best:		Removed gross amounts and added total line.
-- =============================================
CREATE PROCEDURE [custom].[PS_selPFAwardsXML]
	-- Add the parameters for the stored procedure here
	@PCID NVARCHAR(10)
	,@GovID INT
	,@AcademicYear NVARCHAR(4)
	,@AcademicTerm NVARCHAR(10)
	,@AcademicSession NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @FinAidYear NVARCHAR(4) = (
			SELECT FIN_AID_YEAR
			FROM ACADEMICCALENDAR
			WHERE ACADEMIC_YEAR = @AcademicYear
				AND ACADEMIC_TERM = @AcademicTerm
				AND ACADEMIC_SESSION = @AcademicSession
			)

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
				SELECT *
					,COALESCE([Summer], 0) + COALESCE([Fall], 0) + COALESCE([Spring], 0) AS Total
				FROM (
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
						,IIF(attend_desc = 'T-Summer', 'Summer', attend_desc) [attend_desc]
					FROM [VMCNYPF01].[PFaids].[dbo].[student] s
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[stu_award_year] say
						ON say.award_year_token = @FinAidYear
							AND s.student_token = say.student_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[stu_award] sa
						ON sa.stu_award_year_token = say.stu_award_year_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[stu_award_transactions] sat
						ON sat.stu_award_token = sa.stu_award_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[funds] f
						ON f.fund_token = sa.fund_ay_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[poe]
						ON poe.poe_token = sat.poe_token
					WHERE s.alternate_id = @PCID
						OR s.student_ssn = @GovID
					) a_raw
				PIVOT(SUM([amount]) FOR attend_desc IN (
							[Summer]
							,[Fall]
							,[Spring]
							)) xx
				
				UNION ALL
				
				--Grand total
				SELECT *
					,COALESCE([Summer], 0) + COALESCE([Fall], 0) + COALESCE([Spring], 0) AS Total
				FROM (
					SELECT 'Totals' [fund_long_name]
						,CASE 
							WHEN net_disbursement_amount > 0
								AND net_disbursement_amount <> scheduled_amount
								THEN net_disbursement_amount
							ELSE scheduled_amount
							END [amount]
						,IIF(attend_desc = 'T-Summer', 'Summer', attend_desc) [attend_desc]
					FROM [VMCNYPF01].[PFaids].[dbo].[student] s
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[stu_award_year] say
						ON say.award_year_token = @FinAidYear
							AND s.student_token = say.student_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[stu_award] sa
						ON sa.stu_award_year_token = say.stu_award_year_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[stu_award_transactions] sat
						ON sat.stu_award_token = sa.stu_award_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[funds] f
						ON f.fund_token = sa.fund_ay_token
					INNER JOIN [VMCNYPF01].[PFaids].[dbo].[poe]
						ON poe.poe_token = sat.poe_token
					WHERE (
							s.alternate_id = @PCID
							OR s.student_ssn = @GovID
							)
						--AND net_disbursement_amount > 0
						--AND net_disbursement_amount <> scheduled_amount
					) a_raw
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
		,tracking_status
	FROM [VMCNYPF01].[PFaids].[dbo].[student] s
	INNER JOIN [VMCNYPF01].[PFaids].[dbo].[stu_award_year] say
		ON say.award_year_token = @FinAidYear
			AND s.student_token = say.student_token
	WHERE s.alternate_id = @PCID
		OR s.student_ssn = @GovID
END
