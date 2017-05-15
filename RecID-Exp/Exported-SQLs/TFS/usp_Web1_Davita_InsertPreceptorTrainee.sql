Create PROCEDURE [dbo].[usp_Web1_Davita_InsertPreceptorTrainee]
(
  @Client varchar(4), 
  @GroupCode int, 
  @PPED datetime,
  @SSN int,
  @SiteNo int,
  @DeptNo int,
  @origDeptNo int,
  @TransDate datetime,
  @InTime datetime,
  @TraineeSSN int,
  @JobCode varchar(512),
  @ExperienceLevel int,
  @Seq int,
  @MaintUserId int,
  @SIP int,
  @Hours numeric(5,2) = -1.99,
  @PreceptHrs numeric(9,2)
)

AS
SET NOCOUNT ON

--INSERT INTO [TimeCurrent].[dbo].[tbl_WorkPreceptorParams]([Client], [GroupCode], [PPED], [SSN], [SiteNo], [DeptNo], [TransDate], [InTime], [TraineeSSN], [JobCode], [ExperienceLevel], [Seq], [MaintUserId])
--VALUES(@Client, @Groupcode, @PPED, @SSN, @SiteNo, @DeptNo, @TransDate, @InTIme, @TraineeSSN, @JobCode, @ExperienceLevel, @Seq, @MaintUserID)

-- Need to Update the tblTimeHistDetail transactions with the Department selected.
-- IF Department = 0 then error out.

IF @DeptNo = 0
BEGIN
  Select ErrorMessage = 'You must select a Department Number for all transactions.'
  return
END

-- A SIP is a NON-Davita employee that is being trained by the preceptor .
-- they are tracked differently 
-- Also a SIP can only be assigned for PCT departmetns

DECLARE @SIP_SSN int
Set @SIP_SSN = 999000000 + @SiteNo
IF @TraineeSSN = @SIP_SSN
BEGIN
  IF @JobCode not in('400-300-62-3111-027','400-372-62-3111-076','400-380-62-3111-047','400-390-62-3111-067','400-350-62-3111-057','0401-301-62-0000-613')
  BEGIN
    Select ErrorMessage = 'A [SIP] can only be assigned to a PCT job code. Please select a valid trainee.'
    return
  END
END

IF @SIP = 1
BEGIN
  IF @JobCode not in('400-300-62-3111-027','400-372-62-3111-076','400-380-62-3111-047','400-390-62-3111-067','400-350-62-3111-057','0401-301-62-0000-613')
  BEGIN
    Select ErrorMessage = 'A "Prev SIP" can only be assigned to a PCT job code. Please change SIP to NO or select a valid Job Code.'
    return
  END
  IF @ExperienceLevel = 1 
  BEGIN
    Select ErrorMessage = 'A "Prev SIP" cannot be assigned to a trainee with experience. Please change SIP to NO or Experience to NO.'
    return
  END
END


-- the Preceptor Hours are inserted at the Trans Date Level, so the changes should apply to any days within the 
-- trans date.
-- set Cursor for Trans date and update days accordingly.
--
Declare @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
Declare @CurrDeptNo int
Declare @ThdHours numeric(9,2)
Declare @InDay int


DECLARE cTrans CURSOR
READ_ONLY
FOR 
select RecordID, DeptNo, Hours, InDay from TimeHistory..tblTimehistDetail
where client = @Client
and groupcode = @Groupcode
and Payrollperiodenddate = @PPED
and SSN = @SSN
and TransDate = @TransDate
and TransType <> '7'   --Skip Void transactions

OPEN cTrans

FETCH NEXT FROM cTrans INTO @recordId, @CurrdeptNo, @ThdHours, @InDay
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    IF @DeptNo <> @CurrDeptNo and @CurrDeptNo = @OrigDeptNo
    BEGIN
      -- Need to update the record, set the changed department flag and insert new record into tblFixedPunch to be swept and sent to the clock
      Update Timehistory..tblTimeHistDetail
        Set DeptNo = @DeptNo, Changed_DeptNo = '1', JobID = case when JobID = 0 then @CurrDeptNo else JobID end
      where RecordID = @RecordID
  
      INSERT INTO [TimeCurrent].[dbo].[tblFixedPunch]([OrigRecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [OldSiteNo], [OldDeptNo], [OldJobID], [OldTransDate], [OldEmpStatus], [OldBillRate], [OldBillOTRate], [OldBillOTRateOverride], [OldPayRate], [OldShiftNo], [OldInDay], [OldInTime], [OldInSrc], [OldOutDay], [OldOutTime], [OldOutSrc], [OldHours], [OldDollars], [OldClockAdjustmentNo], [OldAdjustmentCode], [OldAdjustmentName], [OldTransType], [OldAgencyNo], [OldDaylightSavTime], [OldHoliday], [NewSiteNo], [NewDeptNo], [NewJobID], [NewTransDate], [NewEmpStatus], [NewBillRate], [NewBillOTRate], [NewBillOTRateOverride], [NewPayRate], [NewShiftNo], [NewInDay], [NewInTime], [NewInSrc], [NewOutDay], [NewOutTime], [NewOutSrc], [NewHours], [NewDollars], [NewClockAdjustmentNo], [NewAdjustmentCode], [NewAdjustmentName], [NewTransType], [NewAgencyNo], [NewDaylightSavTime], [NewHoliday], [UserName], [UserID], [TransDateTime], [SweptDateTime], [IPAddr], [OldCostID], [NewCostID])
      Select RecordID, Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, @CurrDeptNo, JobID, TransDate, EmpStatus, BillRate, BillOTRate, 0, PayRate, ShiftNo, InDay, InTime, InSrc, OutDay, OutTime, OutSrc, Hours, Dollars, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, TransType, AgencyNo, DaylightSavTime, Holiday, SiteNo, DeptNo, JobID, TransDate, EmpStatus, BillRate, BillOTRate, 0, PayRate, ShiftNo, InDay, InTime, InSrc, OutDay, OutTime, OutSrc, Hours, Dollars, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, TransType, AgencyNo, DaylightSavTime, Holiday, 'Employee', 7584, getdate(), NULL, '', CostID, CostID
      From Timehistory..tblTimeHistDetail
      where RecordID = @RecordID
      
    END

	END
	FETCH NEXT FROM cTrans INTO @recordId, @CurrdeptNo, @ThdHours, @InDay
END

CLOSE cTrans
DEALLOCATE cTrans

-- If the hours are the default then reset them to the hours from the thd record.
--
IF @Hours = -1.99
  Set @Hours = isnull(@thdHours,0)

DECLARE @Exists int

SELECT @Exists = 1
FROM TimeHistory..tblTimeHistDetail_Preceptor
WHERE 
Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED
AND SSN = @SSN
AND TransDate = @TransDate
AND Seq = @Seq

IF @Exists = 1
BEGIN
  --INSERT INTO [TimeCurrent].[dbo].[tbl_WorkPreceptorParams]([Client], [GroupCode], [PPED], [SSN], [SiteNo], [DeptNo], [TransDate], [InTime], [TraineeSSN], [JobCode], [ExperienceLevel], [Seq], [MaintUserId],[Message])
  --VALUES(@Client, @Groupcode, @PPED, @SSN, @SiteNo, @DeptNo, @TransDate, @InTIme, @TraineeSSN, @JobCode, @ExperienceLevel, @Seq, @MaintUserID,'Record Found for this SSN and SEQ. Updating record')

  IF @TraineeSSN = 0
  BEGIN
    Delete from TimeHistory..tblTimeHistDetail_Preceptor
  	WHERE 
      Client = @Client
      AND GroupCode = @GroupCode
      AND PayrollPeriodEndDate = @PPED
      AND SSN = @SSN
      AND TransDate = @TransDate
      AND Seq = @Seq
  END
  ELSE
  BEGIN
  	UPDATE TimeHistory..tblTimeHistDetail_Preceptor
  	SET JobCode = @JobCode,
  	    TraineeSSN = @TraineeSSN,
  	    ExperienceLevel = @ExperienceLevel,
        SIP = @SIP,
        Hours = @Hours,
        SiteNo = @SiteNo,
        DeptNo = @DeptNo,
        PreceptorDailyHrs = @PreceptHrs
  	WHERE 
      Client = @Client
      AND GroupCode = @GroupCode
      AND PayrollPeriodEndDate = @PPED
      AND SSN = @SSN
      AND TransDate = @TransDate
      AND Seq = @Seq

    --INSERT INTO [TimeCurrent].[dbo].[tbl_WorkPreceptorParams]([Client], [GroupCode], [PPED], [SSN], [SiteNo], [DeptNo], [TransDate], [InTime], [TraineeSSN], [JobCode], [ExperienceLevel], [Seq], [MaintUserId],[Message])
    --VALUES(@Client, @Groupcode, @PPED, @SSN, @SiteNo, @DeptNo, @TransDate, @InTIme, @TraineeSSN, @JobCode, @ExperienceLevel, @Seq, @MaintUserID,'Record Updated')
  END
END
ELSE 
BEGIN

  --INSERT INTO [TimeCurrent].[dbo].[tbl_WorkPreceptorParams]([Client], [GroupCode], [PPED], [SSN], [SiteNo], [DeptNo], [TransDate], [InTime], [TraineeSSN], [JobCode], [ExperienceLevel], [Seq], [MaintUserId],[Message])
  --VALUES(@Client, @Groupcode, @PPED, @SSN, @SiteNo, @DeptNo, @TransDate, @InTIme, @TraineeSSN, @JobCode, @ExperienceLevel, @Seq, @MaintUserID,'No record Found for this SSN and SEQ, so Add it.')

  IF @TraineeSSN > 0
  BEGIN
  	INSERT INTO TimeHistory..tblTimeHistDetail_Preceptor(
  	Client,
  	GroupCode,
  	PayrollPeriodEndDate,
  	SSN,
  	SiteNo,
  	DeptNo,
  	TransDate,
  	InTime,
  	TraineeSSN,
  	JobCode,
  	ExperienceLevel,
  	Seq,
  	MaintUserId,
  	MaintDateTime, Hours, TotHours, ActualInTime,SIP,PreceptorDailyHrs)
  	VALUES (
  	@Client,
  	@GroupCode,
  	@PPED,
  	@SSN,
  	@SiteNo,
  	@DeptNo,
  	@TransDate,
  	@TransDate,
  	@TraineeSSN,
  	@JobCode,
  	@ExperienceLevel,
  	@Seq,
  	@MaintUserId,
  	GETDATE(), @Hours, 0, NULL, @SIP, @PreceptHrs
  	)
  END
  ELSE
  BEGIN
    Select ErrorMessage = '' 
    RETURN
  END
END

DECLARE @thdInTime datetime
Set @thdInTime = '12/30/1899 ' + convert(varchar(5), @InTime, 108)

UPDATE TimeHistory..tblTimeHistDetail
  SET InVerified = 'P'
WHERE Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED
AND SiteNo = @SiteNo
AND DeptNo = @DeptNo
AND SSN = @SSN
AND TransDate = @TransDate
AND InTime = @InTime

Declare @TotHours numeric(9,2)
Declare @EndDate datetime
Set @EndDate = @Transdate

-- Update the Total hours Trained for Preceptor, Trainee + JobCode 
Set @TotHours = 
  (select sum(Hours) from timehistory..tblTimeHistDetail_Preceptor
  	WHERE Client = @Client
      AND GroupCode = @GroupCode
--      AND SSN = @SSN            Removed the TRAINER from this summary per Preceptor Project team 6/22/09.
      AND TraineeSSN = @TraineeSSN
      AND JobCode = @JobCode
      AND TransDate <= @EndDate
      AND SessionComplete = '0' )

UPDATE TimeHistory..tblTimeHistDetail_Preceptor
  SET TotHours = isnull(@TotHours,0) 
WHERE 
  Client = @Client
  AND GroupCode = @GroupCode
  AND PayrollPeriodEndDate = @PPED
  AND SSN = @SSN
  AND TransDate = @TransDate
  AND Seq = @Seq


Select ErrorMessage = '' 





