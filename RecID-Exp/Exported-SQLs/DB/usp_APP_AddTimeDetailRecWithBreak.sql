CREATE     procedure [dbo].[usp_APP_AddTimeDetailRecWithBreak](
         @Client char(4),
         @GroupCode int ,
         @SSN int ,
         @PayrollPeriodEndDate datetime ,
         @SiteNo INT ,  --< @SiteNo data type is converted from SMALLINT to INT by Srinsoft on 28July2016 >--
         @DeptNo INT ,  --< @DeptNo data type is converted from SMALLINT to INT by Srinsoft on 28July2016 >--
         @InDay tinyint ,
         @InTime Char(5), 
         @OutDay tinyint ,
         @OutTime Char(5),
         @TransDate DateTime,
      	 @BreakTime char(5),
         @TotHours numeric(5,2),
         @ClockAdjNo varchar(3), --< Srinsoft 08/05/2015  Changed @ClockAdjNo char(1) to varchar(3) >--
         @UserID int,
         @UserName varchar(20),
		 @CostID varchar(30)
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
DECLARE @BreakTime char(5)
DECLARE @UserID int
DECLARE @UserName varchar(20)

SELECT @Client = 'RAND'
SELECT @GroupCode = 510200
SELECT @SSN = 675887645 
SELECT @PayrollPeriodEndDate =  '4/22/2001'
SELECT @SiteNo = 1003
SELECT @DeptNo = 40
SELECT @InDay = 7
SELECT @InTime = '07:00'
SELECT @OutDay = 7
SELECT @OutTime = '15:30'
SELECT @TransDate = '4/21/2001'
SELECT @BreakTime = '00:30'
SELECT @UserID = 0
SELECT @UserName = ''

--/*
Select recordID, Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, --WeekEndDate,
SiteNo, DeptNo, JobID, 
TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
DaylightSavTime, Holiday, HandledByImporter, ClkTransNo 
From tblTimeHistDetail where
Client = 'RAND'
and groupCode = 510200
and Payrollperiodenddate = '4/22/2001'
and SSN = 675887645 
Order By Payrollperiodenddate, Inday, Intime 

Select * from timecurrent..tblFixedPunch where Client = 'RAND'
and GroupCode = 502700
and Payrollperiodenddate = '8/12/2000'
and SSN = 409820052

--*/
--delete from tblTimeHistDetail where RecordID = 56976037
*/


--Set the default values.

DECLARE @ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >-- 
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
DECLARE @ClockAdjustmentNo varchar(3) --< Srinsoft 08/05/2015  Changed @ClockAdjustmentNo char(1) to varchar(3) >--
DECLARE @AdjustmentCode varchar(3)  --< Srinsoft 09/21/2015  Changed @AdjustmentCode char(1) to varchar(3) >--
DECLARE @AdjustmentCodeFull varchar(3)
DECLARE @AdjustmentName char(16)
DECLARE @dtInTime DateTime
DECLARE @dtOutTime DateTime
DECLARE @tmpMinutes int
DECLARE @OrigRecordID BIGINT  --< @OrigRecordID data type is converted from INT to BIGINT by Srinsoft on 28July2016 >--
DECLARE @UserCode varchar(5)
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 25Oct2016 >--



SELECT @ClkTransNo = 0
SELECT @ClockAdjustmentNo = ''
SELECT @AdjustmentCode = '' 
SELECT @AdjustmentCodeFull = ''
SELECT @AdjustmentName = ''
SELECT @BillOTRate = 0.00
SELECT @BillOTRateOverride = 0.00
SELECT @dtInTime = '12/30/1899 ' + @InTime
SELECT @dtOutTime = '12/30/1899 ' + @OutTime
SELECT @Hours = 0.00
SELECT @Dollars = 0.00
SELECT @InSrc = 'S'
SELECT @OutSrc = 'S'
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

if @Userid = 0
begin
	SELECT @UserCode = ''
	SELECT @UserName = ltrim(str(@SSN))
end
else
begin
	SELECT @UserCode = (Select UserCode from timeCurrent..tblUser where UserID = @UserID)
end

SELECT @tmpMinutes = datediff(minute, @dtInTime, @dtOutTime)

SELECT @Hours = @tmpMinutes / 60.00

IF @Hours < 0 
BEGIN
   SELECT @Hours = 24 + @Hours
END 

if @ClockAdjNo <> ''
begin      

  Select @AdjustmentCodeFull = (Select AdjustmentCode from TimeCurrent..tblAdjCodes where Client = @Client and GroupCode = @GroupCode and ClockAdjustmentNo = @ClockAdjNo)
	Select @AdjustmentCode = substring(@AdjustmentCodeFull,1,1)
  Select @AdjustmentName = (Select AdjustmentName from TimeCurrent..tblAdjCodes where Client = @Client and GroupCode = @GroupCode and ClockAdjustmentNo = @ClockAdjNo)
  Set @ShiftNo = 1

  Insert into tblTimeHistDetail
  (Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
  SiteNo, DeptNo, CostID, 
  TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
  Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
  DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID )
  Values
  (@Client, @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, @SiteNo, @DeptNo, @CostID, 
  convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, null, 0, null, 
  @TotHours, @Dollars, @TransType, @AgencyNo, @InSrc, null, @ClockAdjNo, @AdjustmentCode, @AdjustmentName, 
  @DaylightSavTime, @Holiday, @HandledByImporter, @ClkTransNo, @UserCode, @DivisionID )

end
else
begin

  -- Bucyrus only wants employees to enter adjustments.
  --
  IF @Client = 'BUCY' 
    return

  Insert into tblTimeHistDetail
  (Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
  SiteNo, DeptNo, CostID, 
  TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
  Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
  DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID )
  Values
  (@Client, @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, @SiteNo, @DeptNo, @CostID, 
  convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, @dtInTime, @OutDay, @dtOutTime, 
  @Hours, @Dollars, @TransType, @AgencyNo, @InSrc, @OutSrc, @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, 
  @DaylightSavTime, @Holiday, @HandledByImporter, @ClkTransNo, @UserCode, @DivisionID )
  
  Select @OrigRecordID = SCOPE_IDENTITY()
  
  INSERT INTO [TimeCurrent].[dbo].[tblFixedPunch]( [OrigRecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], --WeekEndDate 
  [OldInSrc], [OldOutSrc], [OldDaylightSavTime], [OldHoliday], 
  [NewSiteNo], [NewDeptNo], [NewCostID], [NewTransDate], [NewEmpStatus], [NewBillRate], [NewBillOTRate], [NewBillOTRateOverride], 
  [NewPayRate], [NewShiftNo], [NewInDay], [NewInTime], [NewInSrc], 
  [NewOutDay], [NewOutTime], [NewOutSrc], [NewHours], [NewDollars], [NewClockAdjustmentNo], [NewAdjustmentCode], [NewAdjustmentName], [NewTransType], [NewAgencyNo], 
  [NewDaylightSavTime], [NewHoliday], [UserName], [UserID], [TransDateTime], [SweptDateTime], [IPAddr])
  VALUES(@OrigRecordID, @Client, @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, 
  '','','','',
  @SiteNo,@DeptNo,@CostID,convert(char(10), @TransDate,101),@EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride,
  @PayRate, @ShiftNo, @InDay, @dtInTime, @InSrc, 
  @OutDay, @dtOutTime, @OutSrc, @Hours, @Dollars, '', '', '', @TransType, @AgencyNo, 
  @DaylightSavTime, @Holiday, @UserName, @UserID, getdate(), getdate(), '')
end
  
if @BreakTime <> '00:00' and @BreakTime <> ''
begin
--Add the break
  SELECT @dtInTime = '12/30/1899 00:00:00'
  SELECT @dtOutTime = '12/30/1899 ' + @BreakTime
  SELECT @tmpMinutes = datediff(minute, @dtOutTime, @dtInTime)

  SELECT @Hours = @tmpMinutes / 60.00
  Select @InSrc = 0


  Insert into tblTimeHistDetail
  (Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
  SiteNo, DeptNo, CostID, 
  TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
  Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
  DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID )
  Values
  (@Client, @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, @SiteNo, @DeptNo, @CostID, 
  convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, null, 0, null, 
  @Hours, @Dollars, @TransType, @AgencyNo, @InSrc, null, '8', 'B', 'BREAK', 
  @DaylightSavTime, @Holiday, @HandledByImporter, @OrigRecordID, @UserCode, @DivisionID )

  Select @OrigRecordID = SCOPE_IDENTITY()

End


--for Hilton, Floating Holiday used date should be recorded such that it can only be used once a year
if @Client = 'HILT' and @ClockAdjNo = '5' and ltrim(rtrim(@AdjustmentCodeFull)) = 'FLH'
	update TimeCurrent..tblEmplnames
	set floatHolidayDate = @TransDate
	Where client = @Client
	and groupcode = @GroupCode
	and ssn = @ssn
	and recordStatus = '1'







