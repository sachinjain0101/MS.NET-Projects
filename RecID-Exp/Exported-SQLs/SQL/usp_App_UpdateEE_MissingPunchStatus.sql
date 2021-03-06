USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_App_UpdateEE_MissingPunchStatus]    Script Date: 8/26/2015 3:41:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_App_UpdateEE_MissingPunchStatus]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_App_UpdateEE_MissingPunchStatus] AS' 
END
GO




ALTER   Procedure [dbo].[usp_App_UpdateEE_MissingPunchStatus]
(
@THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
@AutoAccepted TINYINT
) as

SET NOCOUNT ON

DECLARE @PIN INT

SELECT @PIN = PIN
FROM TimeCurrent..tblEmplMissingPunchAlert
WHERE THDRecordId = @THDRecordId

UPDATE TimeCurrent..tblAvailableEmplPIN
SET ExpirationDate = NULL
WHERE PIN = @PIN

IF @AutoAccepted <> 0
BEGIN
	UPDATE TimeHistory..tblFixedPunchByEE
	SET AutoAccepted = @AutoAccepted
	WHERE RecordID = @THDRecordId
END

