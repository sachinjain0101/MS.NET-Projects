Create PROCEDURE [dbo].[usp_DavitaShiftDiff06]
 @Client varchar(4),   
 @GroupCode int,
 @WeekEndDate DateTime, 
 @SSN int,
 @TransDate DateTime,
 @ClkTransNo BIGINT,  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 05Oct2016 >--
 @NewInTime datetime,
 @InSrc varchar(2),
 @Hours numeric(5,2),
 @OldInTime datetime,
 @RecordID BIGINT = 0   --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
 
AS

-- Reconnect morning split record
IF @RecordID = 0
BEGIN
  UPDATE tblTimeHistDetail
  SET InTime = CONVERT(DateTime, '12/30/1899 ' + @NewInTime),
  	InSrc = @InSrc,
  	Hours = Hours + @Hours
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND PayrollPeriodEndDate = @WeekEndDate
    AND SSN = @SSN
    AND TransDate = @TransDate
    AND convert(varchar(8), InTime, 8) = @OldInTime
    AND ClkTransNo = @ClkTransNo
END
ELSE
BEGIN
  UPDATE tblTimeHistDetail
  SET tblTimeHistDetail.InTime = t.InTime,
  	tblTimeHistDetail.InSrc = t.InSrc,
    tblTimeHistDetail.InSiteNo = t.InsiteNo,
    tblTimeHistDetail.InVerified = t.InVerified,
    tblTimeHistDetail.ActualInTime = t.ActualInTime,
    tblTimeHistDetail.InClass = t.InClass,
    tblTimeHistDetail.InTimeStamp = t.InTimeStamp,
  	tblTimeHistDetail.Hours = tblTimeHistDetail.Hours + t.Hours
  From tblTimeHistDetail
  Inner Join TimeHistory..tblTimeHistDetail as t
  on t.RecordID = @RecordID
  WHERE tblTimeHistDetail.Client = @Client
    AND tblTimeHistDetail.GroupCode = @GroupCode
    AND tblTimeHistDetail.PayrollPeriodEndDate = @WeekEndDate
    AND tblTimeHistDetail.SSN = @SSN
    AND tblTimeHistDetail.TransDate = @TransDate
    AND convert(varchar(8), tblTimeHistDetail.InTime, 8) = @OldInTime
    AND tblTimeHistDetail.ClkTransNo = @ClkTransNo
END

