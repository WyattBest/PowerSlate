USE [Campus6_train]
GO

/****** Object:  StoredProcedure [dbo].[MCNY_SlaPowInt_UpdDemographics]   ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2016-11-17
-- Description:	Updates a number of fields that the PowerCampus WebAPI has issues with. Common case is an application
--				went to HandleInquries.
-- =============================================

CREATE PROCEDURE [dbo].[MCNY_SlaPowInt_UpdDemographics]
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

		DECLARE @PersonId int = dbo.fnGetPersonId(@PCID)
		DECLARE @getdate datetime = getdate()
		DECLARE @Today datetime = dbo.fnMakeDate(@getdate)
		DECLARE @Now datetime = dbo.fnMakeTime(@getdate)
	
		--IPEDS Ethnicity
		IF (@RaceAfricanAmerican = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 4))
			EXEC [dbo].[MCNY_SlaPowInt_InsPersonEthnicity] @PersonId, @Opid, @Today, @Now, 4;
		IF (@RaceAmericanIndian = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 2))
			EXEC [dbo].[MCNY_SlaPowInt_InsPersonEthnicity] @PersonId, @Opid, @Today, @Now, 2;
		IF (@RaceAsian = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 3))
			EXEC [dbo].[MCNY_SlaPowInt_InsPersonEthnicity] @PersonId, @Opid, @Today, @Now, 3;
		IF (@RaceNativeHawaiian = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 5))
			EXEC [dbo].[MCNY_SlaPowInt_InsPersonEthnicity] @PersonId, @Opid, @Today, @Now, 5;
		IF (@RaceWhite = 1
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 6))
			EXEC [dbo].[MCNY_SlaPowInt_InsPersonEthnicity] @PersonId, @Opid, @Today, @Now, 6;
		IF (@Ethnicity = 1 --Hispanic
			AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
				FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 1))
			EXEC [dbo].[MCNY_SlaPowInt_InsPersonEthnicity] @PersonId, @Opid, @Today, @Now, 1;

		execute [WebServices].[spSetDemographics] @PersonId, @Opid, '001', @Gender, null, @MaritalStatus, null
			, @Veteran, null, @PrimaryCitizenship, @SecondaryCitizenship, @Visa, null, null, null, null
	
	COMMIT
END


GO


