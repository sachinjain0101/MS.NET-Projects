Create PROCEDURE [dbo].[usp_APP_DAVI_SpecialPayWeek_Site1533] AS

DECLARE @Client char(4)
DECLARE @GroupCode int
Declare @PPED datetime
Declare @SiteNo int
Declare @DOW int

Set @GroupCode = 300200
Set @Client = 'DAVI'
Set @SiteNo = 1533

-- Assumption here is that this will run on Monday at 11:00am
-- 
Set @DOW = datepart(weekday, getdate())

if @DOW = 2
BEGIN
  Set @PPED = convert(varchar(12), dateadd(day, -2, getdate()),101)
END
else
BEGIN
  Return
END

-- First Step is to change week ending date for all transactions where in time is after
-- 10:00am on Saturday.
--

update tblTimeHistDetail
  Set tblTimeHistDetail.PayrollPeriodEndDate = dateadd(day, 7, tblTimeHistDetail.PayrollPeriodEndDate),
      tblTimeHistDetail.HandledByImporter = 'V'
from tblTimeHistDetail 
inner join timecurrent..tblEmplNames as e
  on e.client = tblTimeHistDetail.client
  and e.groupcode = tblTimeHistDetail.groupcode
  and e.ssn = tblTimeHistDetail.ssn
  and e.PrimarySite = @SiteNo
where tblTimeHistDetail.client = @Client
  and tblTimeHistDetail.groupcode = @GroupCode
  and tblTimeHistDetail.payrollperiodenddate = @PPED
  and tblTimeHistDetail.inday = 7
  and tblTimeHistDetail.Transdate = @PPED
  and tblTimeHistDetail.intime >= '12/30/1899 10:00'
  and tblTimeHistDetail.ClockAdjustmentNo = ''
  and tblTimeHistDetail.SiteNo = @SiteNo


-- Step two is to split any transactions that span 10:00 am on Saturday.
-- Before 10:00am goes to current week, after 10:00am goes to previous week.
-- 
DECLARE @RecID BIGINT  --< @RecID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @Outday int
DECLARE @OutTime datetime
DECLARE @InTime datetime
DECLARE @intMinutes int
DECLARE @NewHours numeric(5,2)


Select t.RecordID, t.InTime, t.OutDay, t.OutTime
into #tmprecs
from tblTimeHistDetail as t
inner join timecurrent..tblEmplNames as e
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  and e.PrimarySite = @SiteNo
where t.client = @Client
  and t.groupcode = @GroupCode
  and t.payrollperiodenddate = @PPED
  and t.inday = 7
  and t.Transdate = @PPED
  and t.intime < '12/30/1899 10:00'
  and t.outtime > '12/30/1899 10:00'
  and t.ClockAdjustmentNo = ''
  and t.siteno = @SiteNo

-- =============================================
-- 
-- =============================================
DECLARE curRecs CURSOR
READ_ONLY
FOR select RecordID, InTime, OutDay, OutTime from #tmpRecs

OPEN curRecs

FETCH NEXT FROM curRecs INTO @RecID, @InTime, @OutDay, @OutTime
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    --Calculate new amount hours
    SET @intMinutes = DateDiff(minute, '12/30/1899 10:00', @OutTime)
    SET @NewHours = abs(Round( (@intMinutes / 60.0), 2))

    begin transaction xth
    -- Insert the new record based on new values and values from the original rec.
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail](
            [Client], [GroupCode], [SSN], [PayrollPeriodEndDate],             [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime],              [OutDay], [OutTime], [Hours],   [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [CountAsOT], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], [DivisionID], [ShiftDiffAmt], [UserCode], [OutUserCode])
    (SELECT [Client], [GroupCode], [SSN], dateadd(day,7,PayrollPeriodEndDate),[MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], '12/30/1899 10:00:00', [OutDay], [OutTime], @NewHours, [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], '3',     [OutSrc], [DaylightSavTime], [Holiday], [CountAsOT], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], 'V',                 [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], [DivisionID], [ShiftDiffAmt], [UserCode], [OutUserCode]
      from tblTimeHistDetail where RecordID = @RecID )

    if @@Error <> 0
    begin
      goto EndSP    
    end
    --Calculate new amount hours
    SET @intMinutes = DateDiff(minute, @InTime, '12/30/1899 10:00')
    SET @NewHours = abs(Round( (@intMinutes / 60.0), 2))
    -- Update Original
    Update tblTimeHistDetail
        Set OutSrc = '3',
            OutTime = '12/30/1899 10:00:00',
            Hours = @NewHours,
            HandledByImporter = 'V'
    Where RecordID = @RecID

    if @@Error <> 0
    begin
      goto EndSP    
    end

    commit transaction xth
	END
	FETCH NEXT FROM curRecs INTO @RecID, @InTime, @OutDay, @OutTime
END

CLOSE curRecs
DEALLOCATE curRecs

drop table #tmpRecs

--
-- Allocate the break proportionally from the new splits made
--

Declare @PPED1 datetime
SET @PPED1 = dateadd(day, 7, @PPED)

Select t.ssn, 
  BHours = sum(case when t.ClockAdjustmentNo = '8' then t.Hours else 0 end), 
  Hours1 = sum(Case when t.Payrollperiodenddate = @PPED then t.hours else 0 end ),
  Hours2 = sum(Case when t.Payrollperiodenddate = @PPED1 then t.hours else 0 end )
into #tmpHours
from tblTimeHistDetail as t
inner join timecurrent..tblEmplNames as e
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  and e.PrimarySite = @SiteNo
where t.client = @Client
  and t.groupcode = @GroupCode
  and t.payrollperiodenddate in(@PPED,@PPED1)
  and t.inday = 7
  and t.transdate = @PPED
  and t.ClockAdjustmentNo in('','8',' ')
  and t.Siteno = @SiteNo

Group By t.ssn

select * from #tmpHours

-- =============================================
-- 
-- =============================================

DECLARE @Hours1 numeric(8,4)
DECLARE @Hours2 numeric(8,4)
DECLARE @NewHours2 numeric(5,2)
DECLARE @bHours numeric(5,2)
DECLARE @SSN int

select t.SSN, t.RecordID, t.Hours,
Percent1 = round( (b.Hours1 / (b.Hours1 + b.Hours2) ), 4),
Percent2 = round( (b.Hours2 / (b.Hours1 + b.Hours2) ), 4)
into #tmpRec2
from tblTimeHistDetail as t
inner join timecurrent..tblEmplNames as e
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  and e.PrimarySite = @SiteNo
Inner Join #tmpHours as b
on b.ssn = t.ssn
where t.client = @Client
  and t.groupcode = @GroupCode
  and t.payrollperiodenddate in(@PPED,@PPED1)
  and t.inday = 7
  and t.ClockAdjustmentNo = '8'
  and t.Siteno = @SiteNo
  and t.Transdate = @PPED


select * from #tmpRec2

DECLARE curRecs2 CURSOR
READ_ONLY
FOR select ssn, RecordID, Hours, Percent1, Percent2 from #tmpRec2

OPEN curRecs2

FETCH NEXT FROM curRecs2 INTO @SSN, @RecID, @bHours, @Hours1, @Hours2
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    --Calculate new amount hours
    SET @NewHours = round((@bHours * @Hours1), 2)
    if @bHours < 0 
    Begin
      SET @NewHours2 = @bHours + abs(@NewHours)
    end 
    if @bHours > 0 
    Begin
      SET @NewHours2 = @bHours - @NewHours
    end 

    Print @SSN
    print @NewHours
    print @NewHours2

    begin transaction xth2
    -- Insert the new record based on new values and values from the original rec.
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [CountAsOT], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], [DivisionID], [ShiftDiffAmt], [UserCode], [OutUserCode])
    (SELECT [Client], [GroupCode], [SSN], dateadd(day,7,PayrollPeriodEndDate), [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], [OutTime], @NewHours2, [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], '3', [OutSrc], [DaylightSavTime], [Holiday], [CountAsOT], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], 'V', [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], [DivisionID], [ShiftDiffAmt], [UserCode], [OutUserCode]
      from tblTimeHistDetail where RecordID = @RecID )

    if @@Error <> 0
    begin
      goto EndSP2
    end
    -- Update Original
    Update tblTimeHistDetail
        Set OutSrc = '3',
            Hours = @NewHours,
            HandledByImporter = 'V'
    Where RecordID = @RecID

    if @@Error <> 0
    begin
      goto EndSP2    
    end

    commit transaction xth2
	END
  FETCH NEXT FROM curRecs2 INTO @SSN, @RecID, @bHours, @Hours1, @Hours2
END

CLOSE curRecs2
DEALLOCATE curRecs2

drop table #tmpHours
--drop table #tmpRec2
--*/

-- Delete any NULL records.
delete from tblTimeHistDetail where client =  @Client
  and Groupcode = @GroupCode
  and SiteNo = @SiteNo
  and PayrollPeriodEndDate = @PPED
  and Hours is null


--
-- ADD Recalc job to database to recalc the employees for this site.
--
  DECLARE @lJobID int
  DECLARE @sSQL varchar(1500)

  Set @sSQL = 'Select Distinct RecordID = 0, Client, GroupCode, SSN, LastName = ''Unk'', PayrollPeriodEndDate from TimeHistory..tblTimeHistDetail where Client = ''' + @Client + ''' and Groupcode = ' + ltrim(str(@GroupCode)) + ' and siteno = ' + ltrim(str(@SiteNo)) + ' and payrollperiodenddate in(''' + convert(varchar(12),@PPED,101) + ''', ''' + convert(varchar(12),dateadd(day,7,@PPED),101) + ''')'

  INSERT INTO [Scheduler].[dbo].[tblJobs]([ProgramName], [TimeRequested], [TimeQued], [TimeStarted], [TimeCompleted],  [Client], [GroupCode], [PayrollPeriodEndDate], [Weekly])
  VALUES('ReCalcEmpl',getdate(),null,null,null,@Client, @GroupCode, @PPED,'1')

  Select @lJobId = SCOPE_IDENTITY()

  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@lJobID,'SQL',@sSQL)


return

EndSP:
Rollback transaction xth
return

EndSP2:
Rollback transaction xth2
return





