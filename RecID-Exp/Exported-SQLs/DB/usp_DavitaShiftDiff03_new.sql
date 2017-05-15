CREATE    procedure [dbo].[usp_DavitaShiftDiff03_new]
 @Client varchar(4),   
 @GroupCode int,
 @WeekEndDate DateTime, 
 @SSN int,
 @TransDate DateTime,
 @ClkTransNo BIGINT,  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 05Oct2016 >--
 @NewOutTime datetime,
 @OutSrc varchar(2),
 @Hours numeric(5,2),
 @OldOutTime datetime,
 @RecordID BIGINT = 0   --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
 
AS


if @RecordID = 0
BEGIN
  -- Reconnect split record
  UPDATE tblTimeHistDetail
  SET OutTime = CONVERT(DateTime, '12/30/1899 ' + @NewOutTime),
  	OutSrc = @OutSrc,
  	Hours = Hours + @Hours
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND PayrollPeriodEndDate = @WeekEndDate
    AND SSN = @SSN
    AND TransDate = @TransDate
    AND convert(varchar(8), OutTime, 8) = @OldOutTime
    AND ClkTransNo = @ClkTransNo
END
ELSE
BEGIN
  -- Reconnect split record
  UPDATE tblTimeHistDetail
    SET tblTimeHistDetail.OutTime = t.OutTime,
  	    tblTimeHistDetail.OutSrc = t.OutSrc,
  	    tblTimeHistDetail.OutUserCode = t.OutUserCode,
  	    tblTimeHistDetail.OutDay = t.OutDay,
        tblTimeHistDetail.ActualOutTime = t.ActualOutTime,
        tblTimeHistDetail.OutSiteNo = t.OutSiteNo,
        tblTimeHistDetail.OutVerified = t.OutVerified,
        tblTimeHistDetail.OutClass = t.OutClass,
        tblTimeHistDetail.OutTimeStamp = t.OutTimeStamp,
  	    tblTimeHistDetail.Hours = tblTimeHistDetail.Hours + t.Hours
  From tblTimeHistDetail
  Inner Join TimeHistory..tblTimeHistdetail as t
    on t.recordId = @RecordID  
  WHERE tblTimeHistDetail.Client = @Client
    AND tblTimeHistDetail.GroupCode = @GroupCode
    AND tblTimeHistDetail.PayrollPeriodEndDate = @WeekEndDate
    AND tblTimeHistDetail.SSN = @SSN
    AND tblTimeHistDetail.TransDate = @TransDate
    AND convert(varchar(8), tblTimeHistDetail.OutTime, 8) = @OldOutTime
    AND tblTimeHistDetail.ClkTransNo = @ClkTransNo
END




