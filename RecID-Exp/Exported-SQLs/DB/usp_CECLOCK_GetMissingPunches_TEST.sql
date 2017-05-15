CREATE PROC [dbo].[usp_CECLOCK_GetMissingPunches_TEST]
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

DECLARE @MissingPunchRange numeric(7,3)

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
DECLARE @InPunch Datetime
DECLARE @OutPunch Datetime

SELECT @Client = Client, @GroupCode = GroupCode, @SiteNo = SiteNo
FROM timecurrent..tblSiteNames
WHERE exportmailbox = @TermID

SET @SSN = (SELECT SSN FROM timecurrent..tblEmplNames WHERE Client = @Client and  groupcode = @GroupCode AND EmplBadge = @EmplBadge)

IF ISNULL(@SSN,0) = 0
BEGIN
    SELECT thd.RecordID,
           dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InDateTime,
          dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutDateTime
    FROM  TimeHistory..tblTimeHistDetail thd
    WHERE 1 = 2
END
ELSE
BEGIN
    SET @MissingPunchRange = (Select MissingPunchRangeInHours from Timecurrent..tblClientGroups where Client = @Client and groupcode = @Groupcode)
    
    IF @MissingPunchRange is NULL
      SET @MissingPunchRange = 9.00
    SET @MissingPunchRange = @MissingPunchRange * 60.00
    
    Set @RecordID = NULL 
    
    SELECT TOP 1 
           @RecordID = thd.RecordID, 
           @InPunch = dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) ,
           @OutPunch = dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime)
    FROM  TimeHistory..tblTimeHistDetail thd
    INNER JOIN TimeHistory..tblEmplNames empls 
    ON thd.Client = empls.Client
    AND thd.GroupCode = empls.GroupCode
    AND thd.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
    AND thd.SSN = empls.SSN
    AND (
        thd.InDay IN (10, 11) OR (
        thd.OutDay IN (10, 11)
        AND (
          DATEDIFF("n", dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) >= @MissingPunchRange
          OR dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) <> 
          (SELECT MAX(dbo.PunchDateTime2(TransDate, InDay, InTime)) 
           FROM tblTimeHistDetail 
           WHERE Client = thd.Client 
           AND GroupCode = thd.GroupCode 
           AND SSN = thd.SSN 
           AND PayrollPeriodEndDate = thd.PayrollPeriodEndDate)
	)
      )
    )
    INNER JOIN TimeCurrent..tblEmplNames AS TCempls
    ON TCempls.Client = empls.Client
    AND TCempls.GroupCode = empls.GroupCode
    AND TCempls.SSN = empls.SSN
    LEFT JOIN TimeHistory..tblFixedPunchByEe fix
    ON thd.RecordID = fix.RecordId
    WHERE empls.Client = @Client
    AND empls.GroupCode = @GroupCode
    AND thd.SiteNo = @SiteNo
    AND TCempls.SSN = @SSN
    AND empls.PayrollPeriodEndDate IN (select PayrollPeriodEndDate from timehistory..tblPeriodEndDates where client = @Client and groupcode =@GroupCode and PayrollPeriodEndDate > Dateadd(dd,-4, getdate()) and status <> 'C')
    AND empls.MissingPunch > 0
    AND thd.TransDate > DATEADD(dd, -7,getdate())
    AND fix.DateHandled is  null
    Order by ISNULL(dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime)) DESC

    IF ISNULL(@RecordID,0) = 0
    BEGIN
      SELECT RecordID = 0 ,
             InDateTime = '1/1/1970',
             OutDateTime = '1/1/1970'
      WHERE 1 = 2
      return
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
          Set @SPROC = 'InDateTime = ' + case when @InPunch is null then '' else CONVERT(varchar(32),@InPunch, 120) end 
                          + ' , OutDateTime = ' + case when @OutPunch is null then '' else CONVERT(varchar(32),@OutPunch, 120) end
                          
          Update TimeHistory..tblWork_CEClock_Audit
            Set Results = @SPROC
          Where RecordID = @AuditRecID  
        End
        
        Select RecordID = @RecordID,
          InDateTime = @InPunch,
          OutDateTime = @OutPunch
        RETURN  
      END
    END
    ELSE
    BEGIN
      SELECT RecordID = @RecordID,
             InDateTime = @InPunch ,
             OutDateTime = @OutPunch 
      return
    END
    
END




