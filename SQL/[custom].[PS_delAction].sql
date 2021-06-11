USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updSMSOptIn]    Script Date: 2021-06-10 16:41:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-06-10
-- Description: Deletes a Scheduled Action by ACTIONSCHEDULE_ID
--
-- =============================================
CREATE PROCEDURE [custom].[PS_delAction] @Actionschedule_Id INT
AS
BEGIN
	SET NOCOUNT ON;

	DELETE
	FROM ACTIONSCHEDULE
	WHERE ACTIONSCHEDULE_ID = @Actionschedule_Id
END
GO


