USE [Campus6_train]
GO

/****** Object:  StoredProcedure [dbo].[MCNY_SlaPowInt_UpdContactPrimacy]    Script Date: 1/12/2017 11:30:29 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Wyatt Best
-- Create date: 2017-01-11
-- Description:	Updates address hierarchy and sets primary phone number flag.
--
-- Address type HOME happens to be AddressTypeId = 1 in CODE_ADDRESSTYPE.
-- Would need to be another parameter if usage scope expands.
-- =============================================

CREATE PROCEDURE [dbo].[MCNY_SlaPowInt_UpdContactPrimacy]
	@PCID nvarchar(10)
	,@Opid nvarchar(8)

AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION

		DECLARE @Terminal nvarchar(4) = '0001'
		DECLARE @PersonId int = dbo.fnGetPersonId(@PCID)

		

		IF (SELECT PrimaryPhoneId FROM PEOPLE WHERE PersonId = @PersonId) IS NULL
			UPDATE PEOPLE
			SET PEOPLE.PrimaryPhoneId = PP2.PersonPhoneId
			FROM (SELECT TOP 1
						PersonPhoneId
					FROM PersonPhone
					WHERE PersonId = @PersonId
					ORDER BY CASE PhoneType
						WHEN 'MOBILE1' THEN 1
						WHEN 'RES1' THEN 2
						WHEN 'BUS1' THEN 3
						END DESC) AS PP2
			WHERE PersonId = @PersonId

	COMMIT
END



GO


