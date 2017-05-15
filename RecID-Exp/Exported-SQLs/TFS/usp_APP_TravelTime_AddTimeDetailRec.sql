Create PROCEDURE [dbo].[usp_APP_TravelTime_AddTimeDetailRec](
         @Client char(4),
         @GroupCode int ,
         @SSN int ,
         @PayrollPeriodEndDate datetime ,
         @SiteNo INT ,  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
         @DeptNo INT ,  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
         @InDay tinyint ,
         @InTime Char(5), 
         @OutDay tinyint ,
         @OutTime Char(5),
         @TransDate DateTime,
         @UserID int,
         @UserName varchar(20)
)
AS
--*/

/*
DECLARE @Client char(4)
DECLARE @GroupCode int 
DECLARE @SSN int 
DECLARE @PayrollPeriodEndDate datetime 
DECLARE @SiteNo smallint 
DECLARE @DeptNo tinyint 
DECLARE @InDay tinyint 
DECLARE @InTime datetime 
DECLARE @OutDay tinyint 
DECLARE @OutTime datetime 
DECLARE @TransDate datetime
DECLARE @UserID int
DECLARE @UserName varchar(20)

SELECT @Client = ''
SELECT @GroupCode = 300900
SELECT @SSN = 451219226
SELECT @PayrollPeriodEndDate =  '3/2/2002'
SELECT @SiteNo = 119
SELECT @DeptNo = 88
SELECT @InDay = 5
SELECT @InTime = "13:49"
SELECT @OutDay = 5
SELECT @OutTime = "14:35"
SELECT @TransDate = '2/28/2002'
SELECT @UserID = 0
SELECT @UserName = 'TravelTime'

*/

--Set the default values.
DECLARE @JobID BIGINT  --< @JobID data type is changed from  INT to BIGINT by Srinsoft on 04Oct2016 >-- 
DECLARE @ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 04Oct2016 >-- 
DECLARE @Hours numeric(5,2) 
DECLARE @Dollars numeric(7,2) 
DECLARE @InSrc char(1) 
DECLARE @OutSrc char(1) 
DECLARE @EmpStatus tinyint 
DECLARE @BillRate numeric(7,2) 
DECLARE @PayRate numeric(7,2) 
DECLARE @BillOTRate numeric(7,2) 
DECLARE @BillOTRateOverride numeric(7,2) 
DECLARE @TransType tinyint 
DECLARE @ShiftNo tinyint 
DECLARE @HandledByImporter char(1) 
DECLARE @DaylightSavTime char(1) 
DECLARE @Holiday char(1) 
DECLARE @AgencyNo smallint 
DECLARE @MasterPayrollDate datetime
DECLARE @ClockAdjustmentNo varchar(3) --< Srinsoft 08/25/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
DECLARE @AdjustmentCode varchar(3)  --< Srinsoft 09/22/2015 Changed @AdjustmentCode char(1) to varchar(3) >--
DECLARE @AdjustmentName char(16)
DECLARE @dtInTime DateTime
DECLARE @dtOutTime DateTime
DECLARE @tmpMinutes int
DECLARE @OrigRecordID BIGINT  --< @OrigRecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
DECLARE @UserCode varchar(5)
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 26Oct2016 >--


SELECT @JobID = 0
SELECT @ClkTransNo = 0
SELECT @ClockAdjustmentNo = ' '
SELECT @AdjustmentCode = '' 
SELECT @AdjustmentName = ''
SELECT @BillOTRate = 0.00
SELECT @BillOTRateOverride = 0.00
SELECT @dtInTime = '12/30/1899 ' + @InTime
SELECT @dtOutTime = '12/30/1899 ' + @OutTime
SELECT @Hours = 0.00
SELECT @Dollars = 0.00
SELECT @InSrc = 3
SELECT @OutSrc = 3
SELECT @TransType = 0
SELECT @ShiftNo = 0
SELECT @HandledByImporter = 'V'
SELECT @DaylightSavTime = '0'  --Need to determine this on the fly.
SELECT @Holiday = '0'          --Need to determine what this is and how to determine it.
SELECT @MasterPayrollDate = @PayrollPeriodEndDate



DECLARE curEmpInfo CURSOR FOR
SELECT en.Status, en.AgencyNo, ed.BillRate, ed.PayRate, en.DivisionID
From timeCurrent..tblEmplNames as en
Left Join timecurrent..tblEmplSites_Depts as ed on
    ed.Client = en.Client
    and ed.GroupCode = en.GroupCode
    and ed.DeptNo = @DeptNo
    and ed.SiteNo = @SiteNo
    and ed.SSN = en.SSN
    and ed.RecordStatus = 1
where en.Client = @Client
      and en.GroupCode = @GroupCode
      and en.SSN = @SSN
      and en.RecordStatus = 1

OPEN curEmpInfo
Fetch Next From curEmpInfo Into @EmpStatus, @AgencyNo, @BillRate, @PayRate, @DivisionID
/*
if @@Fetch_Status = 0
  Begin

  End
Else
  Begin
  --Not Sute what to do here? maybe raise an error or something...
  End
*/
CLOSE CurEmpInfo
DEALLOCATE CurEmpInfo

SELECT @UserCode = 'TvT'

SELECT @tmpMinutes = datediff(minute, @dtInTime, @dtOutTime)

SELECT @Hours = @tmpMinutes / 60.00

IF @Hours < 0 
BEGIN
   SELECT @Hours = 24 + @Hours
END 

-- First check to see if the record already exist. If so then do not insert.
--
Select @RecordID = (Select RecordID from tblTimeHistDetail
                      Where Client = @Client
                        and GroupCode = @GroupCode
                        and PayrollPeriodEndDate = @PayrollPeriodEndDate
                        and SSN = @SSN
                        and SiteNo = @SiteNo
                        and DeptNo = @DeptNo
                        and TransDate = @TransDate
                        and Hours = @Hours
                        and InDay = @InDay
                        and InTime = @dtInTime
                        and OutDay = @OutDay
                        and OutTime = @dtOutTime
                        and HandledByImporter = @HandledByImporter)

if @RecordID is NULL  --No existing record so insert a new record
BEGIN
  Insert into tblTimeHistDetail
  (Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
  SiteNo, DeptNo, JobID, 
  TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
  Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
  DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID )
  Values
  (@Client, @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, @SiteNo, @DeptNo, @JobID, 
  convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, @dtInTime, @OutDay, @dtOutTime, 
  @Hours, @Dollars, @TransType, @AgencyNo, @InSrc, @OutSrc, @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, 
  @DaylightSavTime, @Holiday, @HandledByImporter, @ClkTransNo, @UserCode, @DivisionID )
  
  Select @OrigRecordID = SCOPE_IDENTITY()
  
  INSERT INTO [TimeCurrent].[dbo].[tblFixedPunch]( [OrigRecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], --WeekEndDate 
  [OldInSrc], [OldOutSrc], [OldDaylightSavTime], [OldHoliday], 
  [NewSiteNo], [NewDeptNo], [NewJobID], [NewTransDate], [NewEmpStatus], [NewBillRate], [NewBillOTRate], [NewBillOTRateOverride], 
  [NewPayRate], [NewShiftNo], [NewInDay], [NewInTime], [NewInSrc], 
  [NewOutDay], [NewOutTime], [NewOutSrc], [NewHours], [NewDollars], [NewClockAdjustmentNo], [NewAdjustmentCode], [NewAdjustmentName], [NewTransType], [NewAgencyNo], 
  [NewDaylightSavTime], [NewHoliday], [UserName], [UserID], [TransDateTime], [SweptDateTime], [IPAddr])
  VALUES(@OrigRecordID, @Client, @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, 
  '','','','',
  @SiteNo,@DeptNo,@JobID,convert(char(10), @TransDate,101),@EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride,
  @PayRate, @ShiftNo, @InDay, @dtInTime, @InSrc, 
  @OutDay, @dtOutTime, @OutSrc, @Hours, @Dollars, '', '', '', @TransType, @AgencyNo, 
  @DaylightSavTime, @Holiday, @UserName, @UserID, getdate(), null, '')
END  
ELSE
BEGIN
  -- Existing record so send warning to Dale for double check.
  Declare @Notification varchar(512)
  Select @Notification = 'WARNING: ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + convert(char(10), @PayrollPeriodEndDate, 101) + ',' + ltrim(str(@ssn)) + ' has duplicate travel record. RecID = ' + ltrim(str(@RecordID))
  --EXEC [Scheduler].[dbo].[usp_APP_AddNotification] 4, 4, 'TravelTime', 0, 0, @Notification, ''

  -- Clean up any travel dept records that were generated by the clock due to splitting
  -- punches at midnight.
  --
  INSERT INTO [TimeCurrent].[dbo].[tblFixedPunch]([OrigRecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], 
            [OldSiteNo], [OldDeptNo], [OldJobID], [OldTransDate], [OldEmpStatus], [OldBillRate], [OldBillOTRate], [OldBillOTRateOverride], 
            [OldPayRate], [OldShiftNo], [OldInDay], [OldInTime], [OldInSrc], [OldOutDay], [OldOutTime], [OldOutSrc], [OldHours], 
            [OldDollars], [OldClockAdjustmentNo], [OldAdjustmentCode], [OldAdjustmentName], [OldTransType], 
            [OldAgencyNo], [OldDaylightSavTime], [OldHoliday], 
            [NewSiteNo], [NewDeptNo], [NewJobID], [NewTransDate], [NewEmpStatus], [NewBillRate], [NewBillOTRate], [NewBillOTRateOverride], 
            [NewPayRate], [NewShiftNo], [NewInDay], [NewInTime], [NewInSrc], [NewOutDay], [NewOutTime], [NewOutSrc], [NewHours], 
            [NewDollars], [NewClockAdjustmentNo], [NewAdjustmentCode], [NewAdjustmentName], [NewTransType], 
            [NewAgencyNo], [NewDaylightSavTime], [NewHoliday], 
            [UserName], [UserID], [TransDateTime], [SweptDateTime], [IPAddr])
    (SELECT [RecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], 
            [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], 
            [PayRate], [ShiftNo], [InDay], [InTime], [Insrc], [OutDay], [OutTime], [OutSrc], [Hours], 
            [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], 
            [AgencyNo], [DaylightSavTime], [Holiday], 
            [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], 
            [PayRate], [ShiftNo], [InDay], [InTime], [Insrc], [InDay], [InTime], '3', 0.00, 
            [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], 
            [AgencyNo], [DaylightSavTime], [Holiday], 
            @UserName, @UserID, getdate(), null, '10.2.0.1'
        FROM [TimeHistory].[dbo].[tblTimeHistDetail]
        Where Client = @Client
          and GroupCode = @GroupCode
          and PayrollPeriodEndDate = @PayrollPeriodEndDate
          and SSN = @SSN
          and Insrc = '8'
          and InTime = '12/30/1899 00:01:00'
          and Outsrc = '8'
          and DeptNo = DeptNo)


     Update [TimeHistory].[dbo].[tblTimeHistDetail]
        Set OutSrc = '3', OutTime = InTime, OutDay = InDay, Hours = 0.00, UserCode = 'TvT'
        Where Client = @Client
          and GroupCode = @GroupCode
          and PayrollPeriodEndDate = @PayrollPeriodEndDate
          and SSN = @SSN
          and Insrc = '8'
          and InTime = '12/30/1899 00:01:00'
          and Outsrc = '8'
          and DeptNo = DeptNo

END






