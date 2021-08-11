USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_selPersonDuplicate]    Script Date: 2021-08-11 15:15:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Wyatt Best
-- Create date: 2021-08-11
-- Description:	Check for duplicate person records. Initially checks by SSN only.
--
-- =============================================
CREATE PROCEDURE [custom].[PS_selPersonDuplicate] @PCID NVARCHAR(10)
	,@GovernmentId NVARCHAR(20)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT CASE 
			WHEN EXISTS (
					SELECT *
					FROM PEOPLE
					WHERE GOVERNMENT_ID = @GovernmentId
						AND @GovernmentId > ''
					)
				THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
			END [DuplicateFound]
END
GO

