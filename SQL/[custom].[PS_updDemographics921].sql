USE [Campus6]
GO

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
-- 2019-10-15 Wyatt Best:	Renamed and moved to [custom] schema.
-- 2021-02-17 Wyatt Best:	Pass @DemographicsEthnicity to [WebServices].[spSetDemographics].
-- 2021-03-07 Wyatt Best:	Added @PrimaryLanguage and @HomeLanguage. Don't UPDATE demographics row unless needed. Make most parameters optional.
-- 2021-03-16 Wyatt Best:	Added @GovernmentId. For safety, existing GOVERNMENT_ID will not be overwritten with Slate-supplied value.
-- 2021-04-27 Wyatt Best:	Added TOP 1 to existing people search by GOVERNMENT_ID to avoid subquery error.
-- 2021-09-01 Wyatt Best:	Named transaction.
-- 2023-10-05 Rafael Gomez:	Added @Religion.
-- 2023-11-09 Wyatt Best:	Updated error message when GOVERNMENT_ID already assigned to other record.
-- 2024-04-10 Wyatt Best:	Updated for 9.2.3 changes to [WebServices].[spSetDemographics]'s @Gender parameter.
--							Default Legal Name if blank.
-- 2024-08-30 Wyatt Best:	Forked from PS_updDemographics as part of bringing back support for pre-9.2.1 versions.
-- =============================================
CREATE PROCEDURE [custom].[PS_updDemographics921] @PCID NVARCHAR(10)
	,@Opid NVARCHAR(8)
	,@GenderId TINYINT
	,@Ethnicity TINYINT --0 = None, 1 = Hispanic, 2 = NonHispanic. Ellucian's API was supposed to record nothing for ethnicity for 0. I don't think it supports multi-value, but this sproc does.
	,@DemographicsEthnicity NVARCHAR(6)
	,@MaritalStatus NVARCHAR(4) NULL
	,@Religion NVARCHAR(4) NULL
	,@Veteran NVARCHAR(4) NULL
	,@PrimaryCitizenship NVARCHAR(6) NULL
	,@SecondaryCitizenship NVARCHAR(6) NULL
	,@Visa NVARCHAR(4) NULL
	,@RaceAfricanAmerican BIT
	,@RaceAmericanIndian BIT
	,@RaceAsian BIT
	,@RaceNativeHawaiian BIT
	,@RaceWhite BIT
	,@PrimaryLanguage NVARCHAR(12) NULL
	,@HomeLanguage NVARCHAR(12) NULL
	,@GovernmentId nvarchar(40) NULL
	
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION PS_updDemographics

	DECLARE @PersonId INT = dbo.fnGetPersonId(@PCID)
		,@getdate DATETIME = getdate()
	DECLARE @Today DATETIME = dbo.fnMakeDate(@getdate)
		,@Now DATETIME = dbo.fnMakeTime(@getdate)

	--Error check
	IF (
			@GenderId IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_GENDER
				WHERE GenderId = @GenderId
				)
			)
	BEGIN
		RAISERROR (
				'@GenderId %d not found in CODE_ETHNICITY.'
				,11
				,1
				,@GenderId
				)

		RETURN
	END

	IF (
			@DemographicsEthnicity IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_ETHNICITY
				WHERE CODE_VALUE_KEY = @DemographicsEthnicity
				)
			)
	BEGIN
		RAISERROR (
				'@DemographicsEthnicity ''%s'' not found in CODE_ETHNICITY.'
				,11
				,1
				,@DemographicsEthnicity
				)

		RETURN
	END

	IF (
			@PrimaryLanguage IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_LANGUAGE
				WHERE CODE_VALUE_KEY = @PrimaryLanguage
				)
			)
	BEGIN
		RAISERROR (
				'@PrimaryLanguage ''%s'' not found in CODE_LANGUAGE.'
				,11
				,1
				,@PrimaryLanguage
				)

		RETURN
	END

	IF (
			@HomeLanguage IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_LANGUAGE
				WHERE CODE_VALUE_KEY = @HomeLanguage
				)
			)
	BEGIN
		RAISERROR (
				'@HomeLanguage ''%s'' not found in CODE_LANGUAGE.'
				,11
				,1
				,@HomeLanguage
				)

		RETURN
	END
	
	DECLARE @DupPCID NVARCHAR(10) = (
			SELECT TOP 1 PEOPLE_CODE_ID
			FROM PEOPLE
			WHERE GOVERNMENT_ID = @GovernmentId
				AND PEOPLE_CODE_ID <> @PCID
			)
		,@ExistingGovId NVARCHAR(40) = (
			SELECT GOVERNMENT_ID
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @PCID
			)
	DECLARE @GenderCode NVARCHAR(1)
		,@GenderMed NVARCHAR(20)

	SELECT @GenderCode = CODE_VALUE_KEY
		,@GenderMed = MEDIUM_DESC
	FROM CODE_GENDER
	WHERE GenderId = @GenderId


	--Treat blanks as NULL
	SET @ExistingGovId = NULLIF(@ExistingGovId, '')
	SET @GovernmentId  = NULLIF(@GovernmentId, '')

	IF @DupPCID IS NOT NULL
	BEGIN
		RAISERROR (
				'Cannot assign @GovernmentId to %s because it is already assigned to %s.'
				,11
				,1
				,@DupPCID
				,@PCID
				)
	END

	IF @GovernmentId <> @ExistingGovId
	BEGIN
		RAISERROR (
				'Existing GOVERNMENT_ID for %s does not match @GovernmentId supplied by Slate. Please reconcile manually.'
				,11
				,1
				,@PCID
				)
	END
	IF (
			@Religion IS NOT NULL
			AND NOT EXISTS (
				SELECT *
				FROM CODE_RELIGION
				WHERE CODE_VALUE_KEY = @Religion
				)
			)
	BEGIN
		RAISERROR (
				'@Religion ''%s'' not found in CODE_RELIGION.'
				,11
				,1
				,@Religion
				)

		RETURN
	END
	
	--IPEDS Ethnicity
	IF (@Ethnicity = 1 --Hispanic
		AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
			FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 1))
		EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 1;
	IF (@RaceAmericanIndian = 1
		AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
			FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 2))
		EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 2;
	IF (@RaceAsian = 1
		AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
			FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 3))
		EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 3;
	IF (@RaceAfricanAmerican = 1
		AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
			FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 4))
		EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 4;
	IF (@RaceNativeHawaiian = 1
		AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
			FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 5))
		EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 5;
	IF (@RaceWhite = 1
		AND NOT EXISTS (SELECT PersonId, IpedsFederalCategoryId
			FROM PersonEthnicity WHERE PersonId = @PersonId and IpedsFederalCategoryId = 6))
		EXEC [custom].[PS_insPersonEthnicity] @PersonId, @Opid, @Today, @Now, 6;
		
	--Update DEMOGRAPHICS rollup if needed
	IF NOT EXISTS (
			SELECT *
			FROM DEMOGRAPHICS
			WHERE PEOPLE_CODE_ID = @PCID
				AND ACADEMIC_YEAR = ''
				AND ACADEMIC_TERM = ''
				AND ACADEMIC_SESSION = ''
				AND GENDER = @GenderCode
				AND ETHNICITY = @DemographicsEthnicity
				AND MARITAL_STATUS = @MaritalStatus
				AND VETERAN = @Veteran
				AND CITIZENSHIP = @PrimaryCitizenship
				AND DUAL_CITIZENSHIP = @SecondaryCitizenship
				AND PRIMARY_LANGUAGE = @PrimaryLanguage
				AND HOME_LANGUAGE = @HomeLanguage
				AND RELIGION = @Religion
			)
	BEGIN
		DECLARE @return_value INT

		EXECUTE @return_value = [WebServices].[spSetDemographics] @PersonId
			,@Opid
			,'001'
			,@GenderMed
			,@DemographicsEthnicity
			,@MaritalStatus
			,@Religion
			,@Veteran
			,NULL
			,@PrimaryCitizenship
			,@SecondaryCitizenship
			,@Visa
			,NULL
			,@PrimaryLanguage
			,@HomeLanguage
			,NULL

		--Ellucian stopped raising errors in spSetDemographics and just returns an int??
		--Probably some modern trend to make it harder for end users to see meaningful error messages.
		IF @return_value <> 0
		BEGIN
			RAISERROR (
					'WebServices.spSetDemographics returned error code %d.'
					,11
					,1
					,@return_value
					)

			RETURN
		END
	END

	--Update GOVERNMENT_ID if needed.
	IF @GovernmentId IS NOT NULL
		AND NOT EXISTS (
			SELECT *
			FROM PEOPLE
			WHERE PEOPLE_CODE_ID = @PCID
				AND GOVERNMENT_ID = @GovernmentId
			)
		UPDATE PEOPLE
		SET GOVERNMENT_ID = @GovernmentId
		WHERE PEOPLE_CODE_ID = @PCID

	--Update Legal Name if blank
	UPDATE PEOPLE
	SET LegalName = dbo.fnPeopleOrgName(@PCID, 'LN, |FN |MN, |SX')
	WHERE PEOPLE_CODE_ID = @PCID
		AND (
			LegalName = ''
			OR LegalName IS NULL
			)

	COMMIT TRANSACTION PS_updDemographics
END
GO

