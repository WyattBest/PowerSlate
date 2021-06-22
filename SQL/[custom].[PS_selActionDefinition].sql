USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updSMSOptIn]    Script Date: 2021-06-10 16:41:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-06-11
-- Description:	Select action definition by ACTION_ID. Limited to only active actions.
--
-- =============================================
CREATE PROCEDURE [custom].[PS_selActionDefinition] @ActionId NVARCHAR(8)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT ACTION_ID
		,ACTION_NAME
		,OFFICE
		,[TYPE]
	FROM [ACTION]
	WHERE ACTION_ID = @ActionId
		AND [STATUS] = 'A'
END
GO


