CREATE             procedure [dbo].[usp_APP_AddTimeDetailRec_In](
         @Client char(4),
         @GroupCode int ,
         @SSN int ,
         @PayrollPeriodEndDate datetime ,
         @SiteNo INT ,  --< @SiteNo data type is converted from SMALLINT to INT by Srinsoft on 28July2016 >--
         @DeptNo INT ,  --< @DeptNo data type is converted from SMALLINT to INT by Srinsoft on 28July2016 >--
         @JobID BIGINT ,  --< @JOBId data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
         @TransDate datetime ,
         @ClkTransNo BIGINT,  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
         @InSrc char(1) = 'V',
         @UserCode varchar(5) = ''
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
DECLARE @JobID int 
DECLARE @TransDate datetime 
DECLARE @ClkTransNo int 

SELECT @Client = 'RAND'
SELECT @GroupCode = 502700 
SELECT @SSN = 409820052
SELECT @PayrollPeriodEndDate =  '8/12/2000'
SELECT @SiteNo = 1027
SELECT @DeptNo = 17
SELECT @JobID = 0
SELECT @TransDate = '8/11/2000 13:15:22'
SELECT @ClkTransNo = 406 

*/

--Set the default values.
DECLARE @InDay tinyint 
DECLARE @InTime datetime 
DECLARE @OutDay tinyint 
DECLARE @OutTime datetime 
DECLARE @Hours numeric(5,2) 
DECLARE @Dollars numeric(7,2) 
--DECLARE @InSrc char(1) 
DECLARE @OutSrc char(1) 
DECLARE @EmpStatus tinyint 
DECLARE @EmpPayType int 
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
DECLARE @ClockAdjustmentNo varchar(3) --< Srinsoft 08/05/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
DECLARE @AdjustmentCode varchar(3)  --< Srinsoft 09/21/2015 Changed @AdjustmentCode char(1) to varchar(3) >--
DECLARE @AdjustmentName char(16)
DECLARE @MPCount int
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 25Oct2016 >--

SELECT @ClockAdjustmentNo = ''
SELECT @AdjustmentCode = '' 
SELECT @AdjustmentName = ''
SELECT @BillOTRate = 0.00
SELECT @BillOTRateOverride = 0.00
SELECT @InDay = datepart(weekday, @TransDate)
SELECT @InTime = '12/30/1899 ' + cast(datepart(hh,@TransDate) as char(2)) + ':' + cast(datepart(mi, @TransDate) as char(2))
SELECT @OutDay = 10
SELECT @OutTime = '12/30/1899 00:00:00'
SELECT @Hours = 0.00
SELECT @Dollars = 0.00
--SELECT @InSrc = 'V'
SELECT @OutSrc = '9'
SELECT @TransType = 0
SELECT @ShiftNo = 0
SELECT @HandledByImporter = 'V'
SELECT @DaylightSavTime = '0'  --Need to determine this on the fly.
SELECT @Holiday = '0'          --Need to determine what this is and how to determine it.
SELECT @MasterPayrollDate = @PayrollPeriodEndDate
SELECT @MPCount = 0

DECLARE curEmpInfo CURSOR FOR
SELECT en.Status, en.PayType, en.AgencyNo, ISNULL(ed.BillRate, 0) BillRate, ISNULL(ed.PayRate, 0) PayRate, en.DivisionID
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
Fetch Next From curEmpInfo Into @EmpStatus, @EmpPayType, @AgencyNo, @BillRate, @PayRate, @DivisionID
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

IF @EmpPayType = 1
  SET @OutDay = 11
      

Insert into tblTimeHistDetail
(Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, 
SiteNo, DeptNo, JobID, 
TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, DivisionID, UserCode )
Values
(@Client, @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, @SiteNo, @DeptNo, @JobID, 
convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, @InTime, @OutDay, @OutTime, 
@Hours, @Dollars, @TransType, @AgencyNo, @InSrc, @OutSrc, @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, 
@DaylightSavTime, @Holiday, @HandledByImporter, @ClkTransNo, @DivisionID, @UserCode )


  -- Reset the Missing Punch Flag.      
  -- The employee will always have at least a missing out punch, beacuse we just added
  -- an in punch without an out punch.
  -- so to determine if there is truely a missing punch the missing punch count must be
  -- greater than 1
  --
  IF @Client = 'HRZS'
  BEGIN
    Select @MPCount = (Select Sum(1) from tblTimeHistDetail 
                          where Client = @Client 
                            and Groupcode = @groupcode 
                            and SSN = @SSN 
                            and payrollperiodenddate = @PayrollPeriodEndDate
                            and (Inday = 10 or OutDay = 10 or InDay = 11 or OutDay = 11) )
  END
  ELSE
  BEGIN
    Select @MPCount = (Select Sum(1) from tblTimeHistDetail 
                          where Client = @Client 
                            and Groupcode = @groupcode 
                            and SSN = @SSN 
                            and payrollperiodenddate = @PayrollPeriodEndDate
                            and (Inday = 10 or OutDay = 10) )
  END

  if @MPCount is NULL
    Select @MPCount = 0

  if @MPCount > 1
  BEGIN
    update tblEmplNames Set MissingPunch = '1'
                        where Client = @Client 
                          and Groupcode = @groupcode 
                          and SSN = @SSN 
                          and payrollperiodenddate = @PayrollPeriodEndDate
  END
  ELSE
  BEGIN
    update tblEmplNames Set MissingPunch = '2'
                        where Client = @Client 
                          and Groupcode = @groupcode 
                          and SSN = @SSN 
                          and payrollperiodenddate = @PayrollPeriodEndDate
  
  END










