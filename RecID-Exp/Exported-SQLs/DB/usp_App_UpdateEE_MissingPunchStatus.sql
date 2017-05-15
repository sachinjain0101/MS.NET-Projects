CREATE   Procedure [dbo].[usp_App_UpdateEE_MissingPunchStatus]
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

