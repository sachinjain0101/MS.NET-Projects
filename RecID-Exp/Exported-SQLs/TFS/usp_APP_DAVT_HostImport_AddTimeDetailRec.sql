Create PROCEDURE [dbo].[usp_APP_DAVT_HostImport_AddTimeDetailRec]
(
   @Client char(4),
   @GroupCode int ,
   @SSN int ,
   @PPED datetime ,
   @SiteNo INT ,  --< @SiteNo data type is converted from SMALLINT to INT by Srinsoft on 02Aug2016 >--
   @DeptNo INT ,  --< @DeptNo data type is converted from SMALLINT to INT by Srinsoft on 02Aug2016 >--
   @ActInTime datetime, 
   @ActOutTime datetime,
   @TransDate DateTime,
   @UserCode varchar(3),
   @FileNo varchar(20),
   @LastName varchar(30),
   @FirstName varchar(30),
   @ImportRec varchar(128),
   @JobID int
)
AS

--Set the default values.
DECLARE @JobNo BIGINT  --< @JobNo data type is changed from  INT to BIGINT by Srinsoft on 23Sept2016 >--
DECLARE @ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 23Sept2016 >-- 
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
DECLARE @ClockAdjustmentNo varchar(3)  --< Srinsoft 08/10/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
DECLARE @AdjustmentCode varchar(3)	--< Srinsoft 09/21/2015 Changed @AdjustmentCode char(1) to varchar(3) >--
DECLARE @AdjustmentName char(16)
DECLARE @dtInTime DateTime
DECLARE @dtOutTime DateTime
DECLARE @tmpMinutes int
DECLARE @OrigRecordID BIGINT  --< @OrigRecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 25Oct2016 >--
DECLARE @User varchar(50)
DECLARE @InDay int
DECLARE @OutDay int
DECLARE @PPED1 datetime
DECLARE @ErrorMsg varchar(1024)

Set @InDay  = datepart(weekday, @ActInTime)
Set @OutDay = datepart(weekday, @ActOutTime)

SELECT @JobNo = 0
SELECT @ClkTransNo = 0
SELECT @ClockAdjustmentNo = ''
SELECT @AdjustmentCode = '+' 
SELECT @AdjustmentName = 'overlap'
SELECT @BillOTRate = 0.00
SELECT @BillOTRateOverride = 0.00
SELECT @dtInTime = '12/30/1899 ' + convert(varchar(5), @ActInTime, 108)
SELECT @dtOutTime = '12/30/1899 ' + convert(varchar(5), @ActOutTime, 108)
SELECT @Hours = 0.00
SELECT @Dollars = 0.00
SELECT @InSrc = 'H'
SELECT @OutSrc = 'H'
SELECT @TransType = 8        -- So CigTrans Will ignore it on future punch inserts, 
SELECT @ShiftNo = 0
SELECT @HandledByImporter = 'V'
SELECT @DaylightSavTime = '0'  --Need to determine this on the fly.
SELECT @Holiday = '0'          --Need to determine what this is and how to determine it.


-- Find the most recent SAT associated with this transdate.
-- that will be the PPED, 
SET @PPED1 = @TransDate
While datepart(weekday,@PPED1) <> 7
BEGIN
  Set @PPED1 = dateadd(day,1,@PPED1)
END
-- make sure the PPED is in the database and is not closed.
Set @PPED = NULL
Select @PPED = PayrollPeriodenddate,
       @MasterPayrollDate = MasterPayrolldate
from TimeHistory..tblPeriodenddates where client = @Client and groupcode = @GroupCode
 and Status <> 'C' 
 and PayrollPeriodenddate = @PPED1

IF @PPED is NULL
BEGIN
  SET @ErrorMsg = 'No Open Period for Trans date <' + convert(varchar(12), @TransDate, 101) + '>. Transaction was not loaded.'
  EXEC [TimeHistory].[dbo].[usp_APP_DAVT_HostImport_LogErr] @Client, @FileNo, @LastName, @FirstName, @ImportRec, @ErrorMsg, 'N', @JobID
  Return
END


SELECT 
@EmpStatus = en.Status, 
@AgencyNo = en.AgencyNo, 
@BillRate = ISNULL(ed.BillRate, 0), 
@PayRate = ISNULL(ed.PayRate,0), 
@DivisionID = en.DivisionID
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

SELECT @tmpMinutes = datediff(minute, @dtInTime, @dtOutTime)

SELECT @Hours = @tmpMinutes / 60.00

IF @Hours < 0 
BEGIN
   SELECT @Hours = 24 + @Hours
END 

Insert into tblTimeHistDetail
(Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
SiteNo, DeptNo, JobID, 
TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID, ActualInTime, ActualOutTime )
Values
(@Client, @GroupCode, @SSN, @PPED, @MasterPayrollDate, @SiteNo, @DeptNo, @JobNo, 
convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, @dtInTime, @OutDay, @dtOutTime, 
@Hours, @Dollars, @TransType, @AgencyNo, @InSrc, @OutSrc, @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, 
@DaylightSavTime, @Holiday, @HandledByImporter, @ClkTransNo, '', @DivisionID, @ActInTime, @ActOutTime )




