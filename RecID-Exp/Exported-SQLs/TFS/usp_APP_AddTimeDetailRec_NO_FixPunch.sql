Create PROCEDURE [dbo].[usp_APP_AddTimeDetailRec_NO_FixPunch](
         @Client char(4),
         @GroupCode int ,
         @SSN int ,
         @PayrollPeriodEndDate datetime ,
         @SiteNo INT ,
         @DeptNo INT ,
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

SELECT @Client = 'SAMP'
SELECT @GroupCode = 999901
SELECT @SSN = 999038359
SELECT @PayrollPeriodEndDate =  '3/25/2001'
SELECT @SiteNo = 1
SELECT @DeptNo = 80
SELECT @InDay = 2
SELECT @InTime = "16:30"
SELECT @OutDay = 3
SELECT @OutTime = "02:00"
SELECT @TransDate = '3/20/2001'
SELECT @UserID = 1209
SELECT @UserName = 'Daleh'

--/*
Select recordID, Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, --WeekEndDate,
SiteNo, DeptNo, JobID, 
TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
DaylightSavTime, Holiday, HandledByImporter, ClkTransNo 
From tblTimeHistDetail where
Client = 'SAMP'
and groupCode = 999901
and Payrollperiodenddate = '3/25/2001'
and SSN = 999038359
Order By Payrollperiodenddate, Inday, Intime 

Select * from timecurrent..tblFixedPunch where Client = 'RAND'
and GroupCode = 502700
and Payrollperiodenddate = '8/12/2000'
and SSN = 409820052

--*/
--delete from tblTimeHistDetail where RecordID = 56976037
*/


--Set the default values.
DECLARE @JobID BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >-- 
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
DECLARE @ClockAdjustmentNo varchar(3)  --< Srinsoft 08/05/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
DECLARE @AdjustmentCode varchar(3)  --< Srinsoft 08/05/2015 Changed @AdjustmentCode char(1) to varchar(3) >--
DECLARE @AdjustmentName char(16)
DECLARE @dtInTime DateTime
DECLARE @dtOutTime DateTime
DECLARE @tmpMinutes int
DECLARE @OrigRecordID BIGINT  --< @OrigRecordID data type is converted from INT to BIGINT by Srinsoft on 28July2016 >--
DECLARE @UserCode varchar(5)
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 25Oct2016 >--
DECLARE @User varchar(50)

SELECT @JobID = 0
SELECT @ClkTransNo = 0
SELECT @ClockAdjustmentNo = ''
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
SELECT en.Status, en.AgencyNo, ISNULL(ed.BillRate, 0) BillRate, ISNULL(ed.PayRate,0) PayRate, en.DivisionID
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

SELECT @UserCode = (Select UserCode from timeCurrent..tblUser where UserID = @UserID)

SELECT @tmpMinutes = datediff(minute, @dtInTime, @dtOutTime)

SELECT @Hours = @tmpMinutes / 60.00

IF @Hours < 0 
BEGIN
   SELECT @Hours = 24 + @Hours
END 

/*
IF (SELECT auditNewPunch FROM timeCurrent..tblClientGroups WHERE Client = @Client AND GroupCode = @Groupcode) = '1'
-- if logging is required
BEGIN
	SET @User = (SELECT FirstName + ' ' + LastName FROM timeCurrent..tblUser WHERE LogonName = @UserName)
	INSERT INTO tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName)
	VALUES ( @Client, @GroupCode, @PayrollPeriodEndDate, @SSN, GetDate(),
				 'New punch created for ' + Convert(varchar(8), @TransDate, 1) + ' with ' + str(@Hours,5,2) + ' hours', @userID, @User)
END
*/

Insert into tblTimeHistDetail
(Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
SiteNo, DeptNo, JobID, 
TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID )
Values
('adv2', @GroupCode, @SSN, @PayrollPeriodEndDate, @MasterPayrollDate, @SiteNo, @DeptNo, @JobID, 
convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, @dtInTime, @OutDay, @dtOutTime, 
@Hours, @Dollars, @TransType, @AgencyNo, @InSrc, @OutSrc, @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, 
@DaylightSavTime, @Holiday, @HandledByImporter, @ClkTransNo, @UserCode, @DivisionID )

Select @OrigRecordID = SCOPE_IDENTITY()

/*
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
*/








