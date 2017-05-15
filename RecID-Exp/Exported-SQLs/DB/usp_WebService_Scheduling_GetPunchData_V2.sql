CREATE Procedure [dbo].[usp_WebService_Scheduling_GetPunchData_V2]
(
  @Client varchar(4),
  @GroupCode int,
  @StartTime varchar(32),
  @EndTime varchar(32),
  @WeekNo DATETIME,
  @UserID varchar(80) = ''
)
as

Set nocount on

DECLARE @SiteNo int
DECLARE @dtEndTime datetime
DECLARE @dtStartTime datetime
DECLARE @PPED1 datetime
DECLARE @PPED2 datetime
DECLARE @WeekDay datetime
DECLARE @SSN int
DECLARE @TransDate datetime
DECLARE @Deptno int 
DECLARE @RecID int
DECLARE @WorkedHours numeric(9,2)
DECLARE @BreakHours numeric(9,2)
DECLARE @RecID2 int
DECLARE @MaxHrs numeric(9,2)


Update TimeCurrent..tblClientGroups 
  Set ADP_TipsCode = 'On Shift' 
where Client = @Client 
and GroupCode = @GroupCode 
and ADP_TipsCode <> 'On Shift'

Create Table #tmpRecs
(
	RecordID int IDENTITY (1, 1) NOT NULL,
	PPED datetime,
  SSN int,
  EmplID varchar(20),
  DeptNo INT, 
  TransDate datetime, 
  InTime datetime, 
  OutTime datetime, 
  WorkedHours numeric(9,2),
	BreakHours numeric(9,2),
  PayCode varchar(12), 
  NonWorked numeric(9,2),
  PdInTime datetime,
  ReasonCode varchar(20),
  thdRecordID BIGINT  --< thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
)  
CREATE INDEX [ix_tmpRecs1] ON #tmpRecs (SSN, TransDate) WITH  FILLFACTOR = 90 ON [PRIMARY]
CREATE INDEX [ix_tmpRecs2] ON #tmpRecs (RecordID) WITH  FILLFACTOR = 90 ON [PRIMARY]

--Select @Client = Client, @GroupCode = groupCode from TimeCurrent..tblClientGroups where ClientgroupID2 = @ClientID

If @StartTime <> ''
  Set @dtStartTime = @StartTime
If @EndTime <> ''
  Set @dtEndTime = @EndTime

IF @WeekNo <> ''
BEGIN
  Set @WeekDay = CONVERT(varchar(20), @WeekNo, 101)
	SET @WeekNo = @WeekDay
	
  Select 
  @PPED1 = PayrollPeriodenddate
  from TimeHistory..tblPeriodenddates with(nolock)
  where client = @Client
  and groupcode = @GroupCode
  and @WeekDay <= PayrollPeriodenddate
  and @weekDay >= dateadd(day, -6, PayrollPeriodenddate)

  insert into #tmpRecs(PPED, SSN, EmplID, DeptNo, TransDate, InTime, OutTime, WorkedHours, BreakHours, PayCode, NonWorked, PdIntime, ReasonCode, thdRecordID )  
  Select
  t.PayrollPeriodEndDate,
  t.SSN, 
  EmplID = en.FileNo,
  t.DeptNo,
  t.TransDate,
  InTime = case when t.clockadjustmentno in('',' ') 
                then isnull(t.ActualInTime, timehistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime)) 
           else NULL end, 
  OutTime = case when t.clockadjustmentno in('',' ') then isnull(t.ActualOutTime,timehistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime)) else NULL end, 
  WorkedHours = case when ac.worked = 'Y' then t.Hours else 0.00 end,
	BreakHours = case when t.clockadjustmentno = '8' then t.Hours else 0.00 end,
  PayCode = ac.ADjustmentCode,
  NonWorked = case when ac.worked <> 'Y' then t.Hours else 0.00 end,
  timehistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime),
  '',
  t.RecordID
  from TimeHistory..tblTimeHistDetail as t with (nolock)
  Inner Join TimeCurrent..tblAdjCodes as ac with (nolock)
  on ac.Client = t.client and ac.Groupcode = t.Groupcode
  and ac.ClockAdjustmentNo = case when t.clockADjustmentNo = '' then '1' else t.clockadjustmentNo end
  Inner Join TimeCurrent..tblEmplNames as en with (nolock)
  on en.client = t.client
  and en.groupcode = t.groupcode
  and en.ssn = t.ssn  
  where t.client = @Client
  and t.groupcode = @GroupCode
  and t.Payrollperiodenddate = @PPED1
	AND NOT( t.TransType IN(7,10) AND t.Hours = 0.00 )
	and isnull(ac.SpecialHandling,'') <> 'EXCL'

  Update #tmpRecs
	  Set #tmpRecs.ReasonCode = case when rc.ReasonCode = 'InSrv' then 'IN' 
	                                 when rc.ReasonCode = 'MD' then 'MD'  else '' end 
  from #tmprecs as t
  Inner Join TImeHIstory..tblTImeHistDetail_Reasons as r
  on r.client = @Client
  and r.groupcode = @GroupCode 
  and r.PPED = t.PPED
  and r.ssn = t.ssn 
  and (r.InPunchDateTime = t.PdInTime or r.adjustmentRecordID = t.thdRecordID )
  INNER JOIN TimeCurrent..tblReasonCodes AS rc
  ON rc.ReasonCodeID = r.ReasonCodeID

  -- Loop through the records that are break adjustments and add them to the 
  -- hours associated with the punch that has the most hours for the day.
  --

  DECLARE cBreaks CURSOR
  READ_ONLY
  FOR select RecordID, SSN, TransDate, BreakHours, DeptNo from #tmpRecs where BreakHours < 0.00 
  
  OPEN cBreaks
  
  FETCH NEXT FROM cBreaks INTO @RecID, @SSN, @Transdate, @BreakHours, @DeptNo 
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
      Set @MaxHrs = (Select max(workedhours) from #tmpRecs where SSN = @SSN and TransDate = @TransDate and WorkedHours > 0 and DeptNo = @DeptNo )
      IF isnull(@MaxHrs,0) > 0 and (@MaxHrs + @BreakHours) > 0 
      BEGIN
        Set @RecID2 = (Select top 1 RecordID from #tmpRecs where SSN = @SSN and TransDate = @TransDate and WorkedHours = @MaxHrs and DeptNo = @Deptno )
        Update #tmpRecs
          Set WorkedHours = WorkedHours + @BreakHours
        where RecordID = @RecID2
        Delete from #tmpRecs where RecordID = @RecID
      END
  	END
	  FETCH NEXT FROM cBreaks INTO @RecID, @SSN, @Transdate, @BreakHours, @DeptNo 
  END
  
  CLOSE cBreaks
  DEALLOCATE cBreaks

  --select * from #tmpRecs order by SSN, TransDate
  select 
     SSN	
    ,EmplID	
    ,DeptNo	
    ,TransDate	
    ,InTime	
    ,OutTime	
    ,WorkedHours	
    ,BreakHours	
    ,PayCode = reasonCode + PayCode 
    ,NonWorked	
  from #tmpRecs 
  order by SSN, TransDate

  drop table #tmpRecs
  RETURN
END

-- Get the PPED for that covers the start and end times.

Select 
@PPED1 = Min(PayrollPeriodenddate) 
from TimeHistory..tblPeriodenddates 
where client = @Client
and groupcode = @GroupCode
--and dateadd(day, 1, Payrollperiodenddate) >= @dtEndTime
--and PayrollPeriodenddate >= dateadd(day, -70, getdate())
and PayrollPeriodenddate >= @dtStartTime


--if @dtStartTime > dateadd(day, -7, @PPED1)
--  set @PPED2 = @PPED1
--else
--  Set @PPED2 = dateadd(day, -7, @PPED1)

Print @PPED1
--Print @PPED2

insert into #tmpRecs(PPED, SSN, EmplID, DeptNo, TransDate, InTime, OutTime, WorkedHours, BreakHours, PayCode, NonWorked, PdIntime, ReasonCode, thdRecordID )  
Select 
t.PayrollPeriodEndDate,
t.SSN,
EmplID = en.FileNo,
t.DeptNo, 
t.TransDate, 
InTime = case when t.clockadjustmentno in('',' ') 
              then isnull(t.ActualInTime, timehistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime)) 
         else NULL end, 
OutTime = case when t.clockadjustmentno in('',' ') then isnull(t.ActualOutTime,timehistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime)) else NULL end, 
WorkedHours = case when ac.worked = 'Y' then t.Hours else 0.00 end,
BreakHours = case when t.clockadjustmentno = '8' then t.Hours else 0.00 end,
PayCode = ac.ADjustmentCode,
NonWorked = case when ac.worked <> 'Y' then t.Hours else 0.00 end,
timehistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime),
'',
t.RecordID
from TimeHistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeCurrent..tblAdjCodes as ac with (nolock)
on ac.Client = t.client and ac.Groupcode = t.Groupcode
and ac.ClockAdjustmentNo = case when t.clockADjustmentNo = '' then '1' else t.clockadjustmentNo end
Inner Join TimeCurrent..tblEmplNames as en with (nolock)
on en.client = t.client
and en.groupcode = t.groupcode
and en.ssn = t.ssn  
where t.client = @Client
and t.groupcode = @GroupCode
and t.Payrollperiodenddate >= @PPED1 --, @PPED2)
and isnull(ac.SpecialHandling,'') <> 'EXCL'
AND NOT( t.TransType IN(7,10) AND t.Hours = 0.00 )
and t.Transdate >= @dtStartTime 
AND t.TransDAte <= @dtEndTime
/*( 
isnull(t.ActualinTime,timehistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime)) between  @dtStartTime and @dtEndTime
OR 
isnull(t.ActualOutTime,timehistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime)) between  @dtStartTime and @dtEndTime
)*/

Update #tmpRecs
	  Set #tmpRecs.ReasonCode = case when rc.ReasonCode = 'InSrv' then 'IN' 
	                                 when rc.ReasonCode = 'MD' then 'MD'  else '' end 
from #tmprecs as t
Inner Join TImeHIstory..tblTImeHistDetail_Reasons as r
on r.client = @Client
and r.groupcode = @GroupCode 
and r.PPED = t.PPED
and r.ssn = t.ssn 
and (r.InPunchDateTime = t.PdInTime or r.adjustmentRecordID = t.thdRecordID )
INNER JOIN TimeCurrent..tblReasonCodes AS rc
ON rc.ReasonCodeID = r.ReasonCodeID
  
-- Loop through the records that are break adjustments and add them to the 
-- hours associated with the punch that has the most hours for the day.
--

DECLARE cBreaks CURSOR
READ_ONLY
FOR select RecordID, SSN, TransDate, BreakHours, DeptNo from #tmpRecs where BreakHours < 0.00 

OPEN cBreaks

FETCH NEXT FROM cBreaks INTO @RecID, @SSN, @Transdate, @BreakHours, @DeptNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    Set @MaxHrs = (Select max(workedhours) from #tmpRecs where SSN = @SSN and TransDate = @TransDate and WorkedHours > 0 and DeptNo = @Deptno )
    IF isnull(@MaxHrs,0) > 0 and (@MaxHrs + @BreakHours) > 0
    BEGIN
      Set @RecID2 = (Select top 1 RecordID from #tmpRecs where SSN = @SSN and TransDate = @TransDate and WorkedHours = @MaxHrs and DeptNo = @Deptno )
      Update #tmpRecs
        Set WorkedHours = WorkedHours + @BreakHours
      where RecordID = @RecID2
      Delete from #tmpRecs where RecordID = @RecID
    END
	END
  FETCH NEXT FROM cBreaks INTO @RecID, @SSN, @Transdate, @BreakHours, @DeptNo
END

CLOSE cBreaks
DEALLOCATE cBreaks

select 
   SSN	
  ,EmplID	
  ,DeptNo	
  ,TransDate	
  ,InTime	
  ,OutTime	
  ,WorkedHours	
  ,BreakHours	
  ,PayCode = reasonCode + PayCode 
  ,NonWorked	
from #tmpRecs 
order by SSN, TransDate

drop table #tmpRecs







