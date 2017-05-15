Create PROCEDURE [dbo].[usp_WEB1_ChangeShiftDiff_Post]
(
  @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
  @ShiftNo int,
  @ShiftClass char(1),
  @UserID int,
  @UserName varchar(60),
  @IpAddr varchar(30)
)
AS

DECLARE @thdRecID BIGINT  --< @thdrecid data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
DECLARE @fpRecID int
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @AuditShiftChange char(1)
DECLARE @oldShiftNo int
DECLARE @TransDate datetime
DECLARE @oldShiftDiffClass char(1)
DECLARE @Client char(4)
DECLARE @GroupCode int
DECLARE @PPED datetime
DECLARE @SSN int

-- Make sure the record id has not been deleted out from under us
-- by another process
--
Select @thdRecID = recordID, @Client = Client, @GroupCode = GroupCode, @PPED = Payrollperiodenddate, @SSN = SSN, @SiteNo = SiteNo, @DeptNo = DeptNo, @oldShiftNo = ShiftNo, @TransDate = TransDate, @oldShiftDiffClass = ShiftDiffClass
  from TimeHistory.dbo.tblTimeHistDetail where recordID = @RecordID

IF @thdRecID is NULL
BEGIN
  -- Record must have been deleted so return.
  --
  RETURN
END

if @ShiftNo = @OldShiftNo and @ShiftClass = @oldShiftDiffClass 
BEGIN
  -- No change was made so return
  RETURN
END

-- Check to see if there is already a fixed punch record for this transaction.
-- Record the record ID for later use.
--
Set @fpRecID = (Select Top 1 RecordID from TimeCurrent.dbo.tblFixedPunch where OrigRecordID = @RecordID AND OldTransDate IS NOT NULL)

-- Update the transaction with the new shift number and shift diff class
-- Find the corresponding shift amount from the shift diff table.
-- 
DECLARE @DiffType char(1)
DECLARE @DiffAmount numeric(7,4)

-- Try to find the shift diff amount.
-- for the specific Site, Dept, Shift.
Select @DiffType = DiffType, @DiffAmount = DiffRate from TimeCurrent.dbo.tblDeptShiftDiffs
where client = @Client and groupcode = @GroupCode and SiteNo = @SiteNo
and DeptNo = @DeptNo
and DiffType in('R','P')
and ShiftNo = @ShiftClass

If @DiffType is NULL
BEGIN
  -- Try the default department ( 99 )
  Select @DiffType = DiffType, @DiffAmount = DiffRate from TimeCurrent.dbo.tblDeptShiftDiffs
  where client = @Client and groupcode = @GroupCode and SiteNo = @SiteNo
  and DeptNo = 99
  and DiffType in('R','P')
  and ShiftNo = @ShiftClass

END

IF @DiffType is NULL
BEGIN
  Set @DiffType = 'R'
  Set @DiffAmount = 0.00
END
IF @DiffAmount is NULL
  Set @DiffAmount = 0.00

Update TimeHistory.dbo.tblTimeHistDetail
  Set Changed_deptNo = '2',
    ShiftNo = @ShiftNo,
    ShiftDiffClass = @ShiftClass,
    ShiftDiffAmt = CASE WHEN @DiffType = 'P' 
                        THEN PayRate * @DiffAmount 
                        ELSE @DiffAmount END
Where RecordID = @RecordID

Set @AuditShiftChange = (SELECT isNull(AuditShiftChange, 'N')	FROM timeCurrent..tblClientGroups WHERE client = @Client AND groupCode = @GroupCode AND RecordStatus = '1')

IF @AuditShiftChange is NULL
  Set @AuditShiftChange = 'N'

IF @AuditShiftChange = 'Y' OR @AuditShiftChange = '1'
BEGIN
  DECLARE @Message varchar(1024)

  if @ShiftNo <> @OldShiftNo
  BEGIN
    Set @Message = 'Shift No. changed from ' + ltrim(str(@oldShiftNo)) + ' to ' + ltrim(str(@ShiftNo)) + ' for ' + convert(varchar(20), @TransDate, 1) + ' punch.'
    INSERT INTO TimeHistory.dbo.tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName)
			VALUES(@Client, @GroupCode, @PPED, @SSN, getdate(), @Message, @UserID, @UserName )
  END
  IF @ShiftClass <> @oldShiftDiffClass 
  BEGIN
    Set @Message = 'Shift Diff No. changed from ' + ltrim(str(@oldShiftDiffClass)) + ' to ' + ltrim(str(@ShiftClass)) + ' for ' + convert(varchar(20), @TransDate, 1) + ' punch.'
    INSERT INTO TimeHistory.dbo.tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName)
			VALUES(@Client, @GroupCode, @PPED, @SSN, getdate(), @Message, @UserID, @UserName )
  END
END

if @ShiftNo = @oldShiftNo 
BEGIN
  -- Shift Number is the same. So no need to make any changes to tblFixedPunch because
  -- the old clock is only concerned about ShiftNo changes not ShiftDiffClass changes.
  --
  RETURN
END

IF @fpRecID is NULL
BEGIN
  -- No previous changes to the record existing in tblFixedPunch so add a new
  -- record to table fixed punch based on the data in the Time Hist Detail Record.
  --
	INSERT INTO TimeCurrent..tblFixedPunch
		(
		OrigRecordId,Client,GroupCode,SSN,PayrollPeriodEndDate,MasterPayrollDate,
		OldSiteNo,OldDeptNo,OldJobID,OldTransDate,OldEmpStatus,OldBillRate,
		OldBillOTRate,OldBillOTRateOverride,OldPayRate,OldShiftNo,OldInDay,OldInTime,OldInSrc,
		OldOutDay,OldOutTime,OldOutSrc,OldHours,OldDollars,OldClockAdjustmentNo,OldAdjustmentCode,
		OldAdjustmentName,OldTransType,
		NewSiteNo,NewDeptNo,NewJobID,NewTransDate,NewEmpStatus,NewBillRate,
		NewBillOTRate,NewBillOTRateOverride,NewPayRate,NewShiftNo,NewInDay,NewInTime,NewInSrc,
		NewOutDay,NewOutTime,NewOutSrc,NewHours,NewDollars,NewClockAdjustmentNo,NewAdjustmentCode,
		NewAdjustmentName,NewTransType,
		UserName,UserID,TransDateTime,IPAddr
		)
   select RecordID, Client, GroupCode, SSN, PayrollPeriodendDate,MasterPayrollDate,
		SiteNo,DeptNo,JobID,TransDate,EmpStatus,BillRate,
		BillOTRate,BillOTRateOverride,PayRate,@oldShiftNo,InDay,isnull(InTime,'12/30/1899 00:00'),isnull(InSrc,''),
		OutDay,isnull(OutTime,'12/30/1899 00:00'),isnull(OutSrc,''),Hours,Dollars,ClockAdjustmentNo,isnull(AdjustmentCode,''),
		AdjustmentName,TransType,
		SiteNo,DeptNo,JobID,TransDate,EmpStatus,BillRate,
		BillOTRate,BillOTRateOverride,PayRate,@ShiftNo,InDay,isnull(InTime,'12/30/1899 00:00'),isnull(InSrc,''),
		OutDay,isnull(OutTime,'12/30/1899 00:00'),isnull(OutSrc,''),Hours,Dollars,ClockAdjustmentNo,isnull(AdjustmentCode,''),
		AdjustmentName,TransType,
    @UserName, @UserID, getdate(), @IPAddr
  from TimeHistory.dbo.tblTimeHistDetail
  where recordid = @RecordID
END
ELSE
BEGIN
  -- A previous change to the record exists in tblFixedPunch so add a new
  -- record to table fixed punch based on the old data from the previous fixed punch record 
  -- and new data from the Time Hist Detail Record.
  --
	INSERT INTO TimeCurrent..tblFixedPunch
		(
		OrigRecordId,Client,GroupCode,SSN,PayrollPeriodEndDate,MasterPayrollDate,
		OldSiteNo,OldDeptNo,OldJobID,OldTransDate,OldEmpStatus,OldBillRate,
		OldBillOTRate,OldBillOTRateOverride,OldPayRate,OldShiftNo,OldInDay,OldInTime,OldInSrc,
		OldOutDay,OldOutTime,OldOutSrc,OldHours,OldDollars,OldClockAdjustmentNo,OldAdjustmentCode,
		OldAdjustmentName,OldTransType,
		NewSiteNo,NewDeptNo,NewJobID,NewTransDate,NewEmpStatus,NewBillRate,
		NewBillOTRate,NewBillOTRateOverride,NewPayRate,NewShiftNo,NewInDay,NewInTime,NewInSrc,
		NewOutDay,NewOutTime,NewOutSrc,NewHours,NewDollars,NewClockAdjustmentNo,NewAdjustmentCode,
		NewAdjustmentName,NewTransType,
		UserName,UserID,TransDateTime,IPAddr
		)
   select f.OrigRecordID, f.Client, f.GroupCode, f.SSN, f.PayrollPeriodendDate, f.MasterPayrollDate,
		f.OldSiteNo,f.OldDeptNo,f.OldJobID,f.OldTransDate,f.OldEmpStatus,f.OldBillRate,
		f.OldBillOTRate,f.OldBillOTRateOverride,f.OldPayRate,f.OldShiftNo,f.OldInDay,f.OldInTime,f.OldInSrc,
		f.OldOutDay,f.OldOutTime,f.OldOutSrc,f.OldHours,f.OldDollars,f.OldClockAdjustmentNo,f.OldAdjustmentCode,
		f.OldAdjustmentName,f.OldTransType,
		t.SiteNo,t.DeptNo,t.JobID,t.TransDate,t.EmpStatus,t.BillRate,
		t.BillOTRate,t.BillOTRateOverride,t.PayRate,t.ShiftNo,t.InDay,isnull(t.InTime,'12/30/1899 00:00'),isnull(t.InSrc,''),
		t.OutDay,isnull(t.OutTime,'12/30/1899 00:00'),isnull(t.OutSrc,''),t.Hours,t.Dollars,t.ClockAdjustmentNo,isnull(t.AdjustmentCode,''),
		t.AdjustmentName,t.TransType,
    @UserName, @UserID, getdate(), @IPAddr
  from TimeHistory.dbo.tblTimeHistDetail as t
  Inner Join TimeCurrent.dbo.tblFixedPunch as f
  on f.RecordID = @fpRecID
  where t.Recordid = @RecordID

END
    





