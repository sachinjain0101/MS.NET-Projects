CREATE PROC [dbo].[usp_CECLOCK_GetMissingPunches_NEW]
(
  @TermID varchar(20),
  @EmplBadge        int 
) AS


SET NOCOUNT ON

Declare @AuditRecID int
DECLARE @SPROC varchar(300)

IF @TermID = '4311340001'
BEGIN
  Set @SPROC = 'TimeHistory..usp_CECLOCK_GetMissingPunches ''' + @TermID + ''',' + LTRIM(str(@EmplBadge)) 
  
  Insert into TimeHistory..tblWork_CEClock_Audit(TermID, EmplBadge, SPROC, CreatedDate)
  Values(@TermID, @EmplBadge , @SPROC, GETDATE())
  
  Set @AuditRecID = @@IDENTITY 
END

DECLARE @SSN int
DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @SiteNo int
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
DECLARE @InDateTime datetime
DECLARE @OutDateTime datetime
DECLARE @MaxIn datetime
DECLARE @MaxOut datetime
DECLARE @MissingPunchRange numeric(7,3)
DECLARE @PPED datetime

SELECT 
  @Client = Client, 
  @GroupCode = GroupCode, 
  @SiteNo = SiteNo
FROM timecurrent..tblSiteNames
WHERE exportmailbox = @TermID

SET @SSN = (SELECT SSN FROM timecurrent..tblEmplNames WHERE Client = @Client and  groupcode = @GroupCode AND EmplBadge = @EmplBadge)
SET @PPED = (SELECT MIN(PayrollPeriodenddate) from TimeHistory..tblPeriodEndDates 
                where Client = @Client and  groupcode = @GroupCode
                  and PayrollPeriodEndDate >= DATEADD(day, -4, getdate())
                  and [Status] <> 'C')

IF ISNULL(@SSN,0) = 0 OR @PPED is NULL
BEGIN
    SELECT RecordID = 0 ,
           InDateTime = '1/1/1970',
           OutDateTime = '1/1/1970'
    WHERE 1 = 2
    return
END
ELSE
BEGIN
    SET @MissingPunchRange = (Select MissingPunchRangeInHours from Timecurrent..tblClientGroups where Client = @Client and groupcode = @Groupcode)

    IF @MissingPunchRange is NULL
      SET @MissingPunchRange = 9.00

    SET @MissingPunchRange = @MissingPunchRange * 60.00

    Select Top 1
          @RecordID = thd.RecordID, 
          @InDateTime  = dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime),
          @OutDateTime = dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime)
    from TimeHistory..tblTimeHistDetail as thd
    Inner Join TimeHistory..tblEmplNames as en
    on en.Client = thd.Client
    and en.GroupCode = thd.GroupCode
    and en.SSN = thd.SSN
    and en.PayrollPeriodEndDate = thd.PayrollPeriodEndDate 
    where thd.Client = @Client
    and thd.GroupCode = @GroupCode
    and thd.PayrollPeriodEndDate >= @PPED
    and thd.SSN = @SSN
    and (thd.InDay > 7
      OR (Thd.OutDay > 7 
          AND DATEDIFF(minute, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) >= @MissingPunchRange ) 
      OR en.MissingPunch = '1')
END

IF ISNULL(@RecordID , 0) = 0
BEGIN
    SELECT RecordID = 0 ,
           InDateTime = '1/1/1970',
           OutDateTime = '1/1/1970'
    WHERE 1 = 2
    RETURN
END

IF @Client = 'COAS' 
BEGIN
  IF Exists (Select RecordID from TimeHistory.dbo.tblEmplMissingPunchReceipt where recordID = @RecordID )
  BEGIN
      SELECT RecordID = 0 ,
             InDateTime = '1/1/1970',
             OutDateTime = '1/1/1970'
      WHERE 1 = 2
      RETURN
  END
  ELSE
  BEGIN
    IF Exists (Select RecordID from TimeHistory.dbo.tblEmplMissingPunchReceipt where Client = @Client and GroupCode = @Groupcode and SSN = @SSN )
    BEGIN
      Update TimeHistory.dbo.tblEmplMissingPunchReceipt 
        Set RecordID = @RecordID, LastUpdated = getdate()
      where Client = @Client and GroupCode = @Groupcode and SSN = @SSN 
    END
    ELSE
    BEGIN
      INSERT INTO [TimeHistory].[dbo].[tblEmplMissingPunchReceipt]([RecordID], [Client], [GroupCode], [SSN], [LastUpdated])
      VALUES(@RecordID, @Client, @GroupCode, @SSN, getdate())
    END

    IF @TermID = '4311340001'
    BEGIN
      Set @SPROC = 'InDateTime = ' + case when @IndateTime is null then '' else CONVERT(varchar(32),@IndateTime, 120) end 
                      + ' , OutDateTime = ' + case when @OutDatetime is null then '' else CONVERT(varchar(32),@OutdateTime, 120) end
                      
      Update TimeHistory..tblWork_CEClock_Audit
        Set Results = @SPROC
      Where RecordID = @AuditRecID  
    End
    
    Select RecordID = @RecordID,
      InDateTime = @InDateTime,
      OutDateTime = @OutDateTime
    RETURN  
  END
  RETURN
END

Select RecordID = @RecordID,
  InDateTime = @InDateTime,
  OutDateTime = @OutDateTime

