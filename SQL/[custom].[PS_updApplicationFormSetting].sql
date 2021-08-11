USE [Campus6_test]
GO

/****** Object:  StoredProcedure [custom].[PS_updApplicationFormSetting]    Script Date: 2021-08-11 15:27:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-08-11
-- Description:	Set whether or not a particular application form processes automatically.
-- =============================================
CREATE PROCEDURE [custom].[PS_updApplicationFormSetting] @AppFormSettingId INT
	,@ProcessAutomatically BIT
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE ApplicationFormSetting
	SET ProcessAutomatically = @ProcessAutomatically
	WHERE ApplicationFormSettingId = @AppFormSettingId
		AND ProcessAutomatically <> @ProcessAutomatically
END
GO

