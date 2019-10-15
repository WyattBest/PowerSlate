USE [Campus6]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-09-16
-- Description:	Get PCID, RecruiterApplication status, and Application status from ApplicationNumber GUID.
--				Used for SlaPowInt
--
--	2016-09-26	Wyatt Best: Added column ra_errormessage and renamed procedure from MCNY_SPI_GetStatus
--	2017-04-18	Wyatt Best: Added column PersonId
--	2017-10-06	Wyatt Best: Capitalized PEOPLE_CODE_ID for consistency.
--  2019-10-15	Wyatt Best:	Renamed and moved to [custom] schema.
-- =============================================
CREATE PROCEDURE [custom].[PS_selRAStatus]
	@ApplicationNumber uniqueidentifier

AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		dbo.fnGetPeopleCodeId(apl.PersonId) AS PEOPLE_CODE_ID
		,apl.PersonId as PersonId
		,ra.[Status] AS 'ra_status'
		,ra.[ErrorMessage] AS 'ra_errormessage'
		,apl.[Status] AS 'apl_status'
	FROM RecruiterApplication ra
		LEFT JOIN [Application] apl ON apl.ApplicationId = ra.ApplicationId
	WHERE ApplicationNumber = @ApplicationNumber

END


GO


