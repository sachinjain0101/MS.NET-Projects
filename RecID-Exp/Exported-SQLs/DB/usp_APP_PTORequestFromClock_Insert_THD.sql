CREATE     Procedure [dbo].[usp_APP_PTORequestFromClock_Insert_THD]
(
  @Client char(4),
  @GroupCode int,
  @InSiteNo int,
  @EmplBadge int,
  @Seconds bigint,
  @Hour int,
  @Minutes int,
  @ESTOffset int,
  @Verified char(1),
  @JobID BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 29Sept2016 >--
)
AS

--*/
/*
DECLARE  @Client char(4)
DECLARE  @GroupCode int
DECLARE  @TransDate datetime
DECLARE  @SSN int
DECLARE  @InSiteNo int
DECLARE  @AdjCode char(1)
DECLARE  @Hours numeric(5,2)
DECLARE  @JobID int

SET  @Client = 'GAMB'
SET  @GroupCode = 720200
SET  @TransDate  = '3/22/05'
SET  @SSN = 524372517
SET  @InSiteNo = 206
SET  @Hours = 8.00
SET  @JobID = 15498208
Set  @AdjCode = '2'

--select * from tblTimeHistDetail where recordid = 85311163
--Client = 'GAMB' and Groupcode = 405000 --and SSN = 304749241
--and payrollperiodenddate = '12/08/01'
*/

Set NOCOUNT ON

--DECLARE @AgencyNo int
DECLARE @SSN int
DECLARE @CountAsOT char(1)
DECLARE @InDay tinyint 
--DECLARE @TransDate datetime 
DECLARE @DupID BIGINT  --< @DupId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
DECLARE @Message varchar(512)
DECLARE @PPED_DOW int
DECLARE @SaveError int
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
DECLARE @AdjType char(1)
DECLARE @AdjName varchar(20)
DECLARE @PPED datetime
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 26Oct2016 >--
DECLARE @AgencyNo int
DECLARE @BillRate numeric(9,4)
DECLARE @PayRate numeric(9,4)
DECLARE @Flag char(1)
DECLARE @Status tinyint
DECLARE @TransDate datetime
DECLARE @Hours numeric(7,2)
DECLARE @AdjCode char(1)
DECLARE @FileNo varchar(20)

Set @AdjCode = '2'
Set @TransDate = dateadd(Second,@Seconds,'1/1/1970')
--Set @TransDate = dateadd(Hour,( @ESTOffset + -5),@TransDate)
Set @Hours = round( ((@Hour * 60 ) + @Minutes ) / 60.00 , 2 )

Set @CountAsOT = '0'
Set @AdjType = 'H'
Set @Message = ''

Set @AdjCode = (select top 1 ClockAdjustmentNo from TimeCurrent..tblADjcodes where Client = @Client and Groupcode = @Groupcode and adjustmentname in('PTO','SCH PTO','SCHPTO') and recordstatus = '1' )

IF isnull(@AdjCode,'') = ''
BEGIN
  Set @Message = 'No PTO Adjustment Code for ' + @Client + ',' + ltrim(str(@GroupCode))
  EXEC [Scheduler].[dbo].[usp_APP_AddNotification] 1, 2, 'PTORequestFromClock', @JobID, 0, @Message, ''
  Select 'NOTFOUND' as ReturnCode, @SSN as SSN, @PPED as PPED
  Return
END

Set @InDay = datepart(weekday,@TransDate)
Set @AdjName = (Select AdjustmentName from TimeCurrent.dbo.tblADjCodes where client = @Client and GroupCode = @GroupCode and ClockAdjustmentNo = @AdjCode )

Set @SSN = NULL
Select  @SSN = SSN, 
        @SiteNo = PrimarySite, 
        @DeptNo = PrimaryDept, 
        @PayRate = PayRate, 
        @BillRate = BillRate, 
        @DivisionID = DivisionID, 
        @AgencyNo = AgencyNo,
        @Status = Status,
        @FileNo = FileNo 
from TimeCurrent..tblEmplnames 
where Client = @Client and GroupCode = @GroupCode and EmplBadge = @EmplBadge

IF @SSN is NULL
BEGIN
  Set @Message = 'Empl with Badge: ' + str(@EmplBadge) + ' does not exist. ' + @Client + ',' + ltrim(str(@GroupCode))
  EXEC [Scheduler].[dbo].[usp_APP_AddNotification] 1, 2, 'PTORequestFromClock', @JobID, 0, @Message, ''
  Select 'NOTFOUND' as ReturnCode, @SSN as SSN, @PPED as PPED
  Return
END

Set @Flag = (Select UseEmpLevelRates From TimeCurrent..tblClients where client = @Client)

if @Flag = '0'
BEGIN
  Select @PayRate = PayRate,
         @BillRate = BillRate
  From TimeCurrent..tblEmplNames_Depts
  Where CLient = @Client
    And GroupCode = @GroupCode
    And SSN = @SSN
    And Department = @DeptNo

  If @PayRate is NULL
    Set @PayRate = 0.00
  If @BillRate is NULL
    Set @BillRate = 0.00

END

Set @PPED = (Select Payrollperiodenddate from TimeHistory..tblPeriodEndDates 
              where client = @Client
                and groupcode = @GroupCode 
                and PayrollPeriodEndDate >= @TransDate 
                and PayrollPeriodEndDate <= dateadd(day,6,@TransDate))


if @PPED is NULL
BEGIN
  --Set @Message = 'Empl with Badge: ' + str(@EmplBadge) + ' has a future dated transaction. Trans not processed at this time. ' + @Client + ',' + ltrim(str(@GroupCode))
  --EXEC [Scheduler].[dbo].[usp_APP_AddNotification] 1, 2, 'PTORequestFromClock', @JobID, 0, @Message, ''

  -- Insert the future dated transaction into the AutomatedPTO table.
  -- for processing when the pay week is established.
  --
  IF @Client in('DAVT','DVPC')
  BEGIN
    INSERT INTO TimeHistory..tblAutomatedPTO ([Client],[GroupCode],[RecordType],[PrimarySite],[UsedSite],[SSN],[FileNo],[TransDate],[PPED],[ClockAdjustmentNo],[Hours],[TimeAdded])
    VALUES (@Client,@GroupCode,'A', @SiteNo, @SiteNo, @SSN, @FileNo, @TransDate, NULL, @AdjCode, @Hours, getdate() ) 
  END
  ELSE
  BEGIN
    IF @Client in('GPRO') and datediff(day,getdate(),@TransDate) > 21
    BEGIN
      Select 'INVALID DATE' as ReturnCode, @SSN as SSN, @PPED as PPED
    END
    Else
    BEGIN
      INSERT INTO [TimeHistory].[dbo].[tblPTORequests]([Client], [GroupCode], [SSN], [TransDate], [ClockAdjustmentNo], [Hours], [Reason], [Status], [ApproverUserID], [ApproverMessage], [DateAdded], [MaintDateTime], [RecordStatus], [NotificationDate], [Processed])
      VALUES(@Client, @Groupcode, @SSN, @TransDate, @ADjCode, @Hours, 'From Clock', 'A', 7584, 'Auto Approved', getdate(), getdate(), '1', getdate(), '0')
    END
  END  
  Select 'FUTURE' as ReturnCode, @SSN as SSN, @PPED as PPED
  Return  
END

Set @PPED_DOW = datepart(weekday,@PPED)
if @InDay > @PPED_DOW
BEGIN
  Set @TransDate = dateadd(day, -7 + (@Inday - @PPED_DOW), @PPED)
END
ELSE
BEGIN
  Set @TransDate = dateadd(day, (@Inday - @PPED_DOW), @PPED)
END

-- Check to make sure this is not a duplicate. 
Set @DupID = (Select RecordID from [TimeHistory].[dbo].[tblTimeHistDetail]
                  Where Client = @Client
                    and GroupCode = @GroupCode
                    and SSN = @SSN
                    and SiteNo = @SiteNo
                    and DeptNo = @DeptNo
                    and Payrollperiodenddate = @PPED
                    and Transdate = @TransDate
                    and Inday = @InDay
                    and Hours = @Hours
                    and ClockAdjustmentNo = @AdjCode)

if @DupID is NOT NULL
begin
  Set @Message = 'Empl with SSN: ' + str(@SSN) + ' has duplicate PTO Request. Request not processed. ' + @Client + ',' + ltrim(str(@GroupCode))
  EXEC [Scheduler].[dbo].[usp_APP_AddNotification] 1, 2, 'PTORequestFromClock', @JobID, 0, @Message, ''

  Select 'DUP' as ReturnCode, @SSN as SSN, @PPED as PPED
  Return  

End

BEGIN TRANSACTION
    -- Insert the detail for this employee.
  
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]
    ([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [EmpStatus],
    [PayRate], [BillRate], [Holiday], [ClkTransNo], [ShiftDiffClass],[DivisionID],[InSiteNo],
    [TransDate], [ShiftNo], [InDay], [InTime], 
    [OutDay], [OutTime], [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], 
    [TransType], [AgencyNo], [InSrc], [OutSrc], [CountAsOT], [JobID], [UserCode], [OutUserCode], [HandledByImporter], [InVerified] )
    Values (@Client, @GroupCode, @SSN, @PPED, @PPED, @SiteNo, @DeptNo, @Status,
    @PayRate, @BillRate, '0', @JobID, '', @DivisionID, @InSiteNo, 
    @TransDate, 1, @InDay, '12-30-1899 00:00:00', 
    @InDay, '12-30-1899 00:00:00', @Hours, 0.00, @AdjCode, @AdjCode, @AdjName, 
    0, @AgencyNo, '3', '3', @CountAsOT, 0, 'EMP', 'EMP', 'J', @Verified )

    if @@Error <> 0 
    begin

      Set @SaveError = @@Error
      goto RollBackTransaction
    end  
    Set @RecordID = SCOPE_IDENTITY()

    -- Add the adjustment to tblAdjustments for auditing purposes and for physical clocks
    -- so it will get sent back to the time clock.
    INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
          [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
          [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
          [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
          [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
          [RecordStatus], [IPAddr], [ShiftNo])
    (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
          'EMP', AdjustmentName, @AdjType, 
          Case when InDay = 2 then Hours else 0 end,
          Case when InDay = 3 then Hours else 0 end,
          Case when InDay = 4 then Hours else 0 end,
          Case when InDay = 5 then Hours else 0 end,
          Case when InDay = 6 then Hours else 0 end,
          Case when InDay = 7 then Hours else 0 end,
          Case when InDay = 1 then Hours else 0 end,
          Case when InDay < 1 or InDay > 7 then Hours else 0 end,
          Hours, AgencyNo, 'EMP',0,getdate(),null,null,0,null,'1','10.4.0.17',ShiftNo
    from tblTimeHistdetail
    where RecordID = @RecordID)

    if @@Error <> 0 
    begin
      Set @SaveError = @@Error
      goto RollBackTransaction
    end  

COMMIT TRANSACTION

Select 'GOOD' as ReturnCode, @SSN as SSN, @PPED as PPED

return

RollBackTransaction:
Rollback Transaction

Select 'ERROR' as ReturnCode, @SSN as SSN, @PPED as PPED






