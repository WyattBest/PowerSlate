USE [Campus6]
GO

/****** Object:  StoredProcedure [custom].[PS_updSMSOptIn]    Script Date: 2021-01-04 11:25:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Wyatt Best
-- Create date: 2019-10-11
-- Description:	Initially populates or updates SMS Opt-In status from Slate.
--				If initial import, call custom.CadenceDefaultSMSOpts to update other departments.
--
-- 2021-01-04 Wyatt Best: Renamed custom.defaultSMSOpts to custom.CadenceDefaultSMSOpts
-- =============================================
CREATE PROCEDURE [custom].[PS_updSMSOptIn]
	@PCID NVARCHAR(10)
	,@Opid NVARCHAR(8)
	,@AdmSMSOptBit BIT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @SMSADM NVARCHAR(1) = (
			SELECT CASE @AdmSMSOptBit
					WHEN 1
						THEN 'A'
					WHEN 0
						THEN 'I'
					END
			);
	DECLARE @getdate DATETIME = getdate();
	DECLARE @Today DATETIME = dbo.fnMakeDate(@getdate);
	DECLARE @Now DATETIME = dbo.fnMakeTime(@getdate);

	IF NOT EXISTS (
			SELECT COM_TYPE
			FROM TELECOMMUNICATIONS
			WHERE COM_TYPE = 'SMSADM'
				AND PEOPLE_ORG_CODE_ID = @PCID
			)
	BEGIN
		INSERT INTO [dbo].[TELECOMMUNICATIONS] (
			[PEOPLE_ORG_CODE_ID]
			,[COM_TYPE]
			,[COM_STRING]
			,[PRIMARY_FLAG]
			,[PRIVATE_FLAG]
			,[STATUS]
			,[ADDRESS_TYPE]
			,[COMMENTS]
			,[CREATE_DATE]
			,[CREATE_TIME]
			,[CREATE_OPID]
			,[CREATE_TERMINAL]
			,[REVISION_DATE]
			,[REVISION_TIME]
			,[REVISION_OPID]
			,[REVISION_TERMINAL]
			)
		VALUES (
			@PCID
			,'SMSADM'
			,'SMS Opt-in'
			,'N'
			,'N'
			,@SMSADM
			,'CAMP'
			,'Imported from Slate'
			,@Today
			,@Now
			,@Opid
			,'001'
			,@Today
			,@Now
			,@Opid
			,'001'
			);

		--Set up opts for other departments
		EXEC [custom].CadenceDefaultSMSOpts @PCID;
	END
	ELSE
		UPDATE TELECOMMUNICATIONS
		SET [STATUS] = @SMSADM
			,COMMENTS = 'Imported from Slate'
			,REVISION_DATE = @Today
			,REVISION_TIME = @Now
			,REVISION_OPID = @Opid
			,REVISION_TERMINAL = '001'
		WHERE PEOPLE_ORG_CODE_ID = @PCID
			AND COM_TYPE = 'SMSADM'
			AND [STATUS] <> @SMSADM
END
GO

