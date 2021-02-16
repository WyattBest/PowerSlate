USE [Campus6_odyssey]
GO

/****** Object:  StoredProcedure [custom].[PS_updDemographics]    Script Date: 2/15/2021 10:19:03 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-11-17
-- Description:	Updates a number of fields that the PowerCampus WebAPI has issues with. Common case is an application
--				went to HandleInquries.
--
--  2019-10-15	Wyatt Best:	Renamed and moved to [custom] schema.
--	2021-02-15	Wyatt Best:	Pass Ethnicity code value to [WebServices].[spSetDemographics].
-- =============================================

CREATE PROCEDURE [custom].[PS_updDemographics]
	@PCID nvarchar(10)
	,@Opid nvarchar(8)
	,@Gender tinyint
	,@Ethnicity tinyint --Approx of @RaceHispanic
	,@MaritalStatus nvarchar(4)
	,@Veteran nvarchar(4)
	,@PrimaryCitizenship nvarchar(6)
	,@SecondaryCitizenship nvarchar(6)
	,@Visa nvarchar(4)
	,@RaceAfricanAmerican bit
	,@RaceAmericanIndian bit
	,@RaceAsian bit
	,@RaceNativeHawaiian bit
	,@RaceWhite bit

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRANSACTION

		DECLARE @PersonId INT = dbo.fnGetPersonId(@PCID)
			,@getdate DATETIME = getdate()
		DECLARE @Today DATETIME = dbo.fnMakeDate(@getdate)
			,@Now DATETIME = dbo.fnMakeTime(@getdate)
			,@CodeEthnicity NVARCHAR(12) = (
				SELECT code_value_key
				FROM code_ethnicity
				WHERE ethnicityid = @ethnicity
				)

		--IPEDS Ethnicity
		IF (@RaceAfricanAmerican = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 4))
			EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 4;
		IF (@RaceAmericanIndian = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 2))
			EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 2;
		IF (@RaceAsian = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 3))
			EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 3;
		IF (@RaceNativeHawaiian = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 5))
			EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 5;
		IF (@RaceWhite = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 6))
			EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 6;
		IF (@Ethnicity = 1 --Hispanic
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 1))
			EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 1;

		EXECUTE [WebServices].[spSetDemographics] @PersonId, @Opid, '001', @Gender, @CodeEthnicity, @MaritalStatus, NULL, @Veteran, NULL, @PrimaryCitizenship, @SecondaryCitizenship, @Visa, NULL, NULL, NULL, NULL



	
	COMMIT
END
GO

