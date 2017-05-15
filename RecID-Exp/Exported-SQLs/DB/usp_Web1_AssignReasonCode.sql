CREATE  PROCEDURE [dbo].[usp_Web1_AssignReasonCode] 
(
  @Client           char(4),
  @GroupCode        int,
  @SSN              int,
  @PPED             datetime,
  @InPunchDateTime  datetime,
  @ReasonCodeID     int,
  @thdRecordID  BIGINT = 0,  --< @thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
  @AdjustmentRecordID  int = 0
) AS


SET NOCOUNT ON

DECLARE @PPED2 datetime
IF ISNULL(@thdRecordID,0) = 0 
BEGIN
	RETURN
    
END

Set @PPED2 = (select Payrollperiodenddate from TImeHistory..tblTImeHIstDetail with(nolock) where recordid = @thdRecordID )

IF @InPunchDateTime IS NULL
  SET @InPunchDateTime = '1899-12-30 00:00:00.000'

IF exists(SELECT ReasonID FROM tblTimeHistDetail_Reasons
					WHERE Client = @Client 
						AND GroupCode = @GroupCode 
						AND SSN = @SSN 
						AND PPED = @PPED2  
						AND (/*InPunchDateTime = @InPunchDateTime OR */AdjustmentRecordID = @thdRecordID )
						)
BEGIN
  UPDATE tblTimeHistDetail_Reasons 
		SET ReasonCodeID = @ReasonCodeID, 
				RecordStatus = 1,
				tblAdjustmentRecordID = @AdjustmentRecordID,
				AdjustmentRecordID = @thdRecordID,
				InPunchDateTime = @InPunchDateTime 
  WHERE Client = @Client 
	AND GroupCode = @GroupCode 
	AND SSN = @SSN 
	AND PPED = @PPED2 
	AND (/*InPunchDateTime = @InPunchDateTime or*/ AdjustmentRecordID = @thdRecordID )
END 
ELSE
BEGIN
  INSERT INTO tblTimeHistDetail_Reasons (Client, GroupCode, SSN, PPED, InPunchDateTime, ReasonCodeID, AdjustmentRecordID, tblAdjustmentRecordID)
  VALUES (@Client, @GroupCode, @SSN, @PPED2, @InPunchDateTime, @ReasonCodeID, @thdRecordID , @AdjustmentRecordID)
END



