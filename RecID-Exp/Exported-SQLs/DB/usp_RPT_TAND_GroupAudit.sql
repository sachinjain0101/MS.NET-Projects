CREATE Procedure [dbo].[usp_RPT_TAND_GroupAudit] ( @Client char(4), @Group int, @Date DateTime, @Sites varchar(1000) = NULL ) AS 


/*
Debugging 
Declare @Client char(4)
Declare @Group int
Declare @Date Datetime

select @Client = 'LTA'
select @Group = 400100
Select @Date = '3/30/03'

Drop Table #tmpSiteInfo
Drop Table #tmpSiteInfo2
Drop Table #tmpProgressRpt1
Drop Table #tmpMsgInfo

*/

SET NOCOUNT ON

DECLARE @PPED dateTime
DECLARE @iDOW integer
DECLARE @strSQL varchar(2000)
DECLARE @crlf CHAR(2)

SELECT @crlf = char(13) + char(10)
SELECT @PPED = @Date 

Select 	sn.SiteNo, 
				sn.SiteName, 
				sn.CloseHour, 
				sn.IncludeInUpload, 
				sn.TrainingCompleted,
				sn.QtrHourRounding,
				sn.ShiftInWindow,
				sn.ShiftOutWindow,
				LastBackup = sn.DateLastUploadCreated,
				IsClose = '0',
				ShiftCount = 0,
				UnRoundedPunches = 0,
				UnRoundedWithin120 = 0,
				UnRoundedOver120 = 0
Into #tmpSiteInfo
From TimeCurrent..tblSiteNames as sn
where sn.Client = @Client
and sn.GroupCode = @Group
and sn.RecordStatus = 1
and ((IsNull(@Sites, 'ALL') = 'ALL') OR
		 (IsNull(@Sites, 'ALL') <> 'ALL') AND charindex(',' + cast(sn.SiteNo as varchar) + ',', ',' + replace(replace(replace(@Sites, ', 0', ','), ',0', ','), ',0', ',') + ',', 0) > 0)

Update #tmpSiteInfo
	Set ShiftCount = (Select Count(*) from TimeCurrent..tblDeptShifts where client = @Client and groupcode = @Group and siteno = #tmpSiteInfo.SiteNo and Recordstatus = '1' )

select es.SiteNo, EmplCount = sum(1) 
Into #tmpSiteInfo2
from TimeCurrent..tblEmplSites es
inner JOin TimeCurrent..tblEMplNames as en
on en.Client = @Client
and en.groupcode = @Group
and en.SSn = es.SSN
and en.Recordstatus = '1' and en.Status <> '9'
where es.Client = @Client
and es.GroupCode = @Group
and es.RecordStatus = 1
and es.Status <> '9'
and ((IsNull(@Sites, 'ALL') = 'ALL') OR
		 (IsNull(@Sites, 'ALL') <> 'ALL') AND charindex(',' + cast(es.SiteNo as varchar) + ',', ',' + replace(replace(replace(@Sites, ', 0', ','), ',0', ','), ',0', ',') + ',', 0) > 0)
Group By es.SiteNo

Select @iDOW = datepart(weekday, getdate())

Select 
SiteNo, 
SSN, 
TotMissing = Sum(Case when (OutDay = 10 and @iDow <> datepart(weekday,TransDate)) or Inday = 10 then 1 else 0 end),
TotAdjs = Sum(Case when ClockAdjustmentNo NOT IN('8','') or isnull(Changed_InPunch,'0') = '1' or isnull(Changed_OutPunch,'0') = '1' then 1 else 0 end),
EEPunches = Sum(Case when ClockAdjustmentNo = '' and InSrc = '0' and inDay < 8 then 1 else 0 end 
								+ Case when ClockAdjustmentNo = '' and OutSrc = '0' and OutDay < 8 then 1 else 0 end ),
RegHrs = Sum(RegHours),
OTHrs = Sum(OT_Hours),
DTHrs = Sum(DT_Hours)
into #tmpProgressRpt1
from tblTimeHistDetail 
where Client = @Client
and GroupCode = @Group
and PayrollPeriodEndDate = @PPED
and ((IsNull(@Sites, 'ALL') = 'ALL') OR
		 (IsNull(@Sites, 'ALL') <> 'ALL') AND charindex(',' + cast(SiteNo as varchar) + ',', ',' + replace(replace(replace(@Sites, ', 0', ','), ',0', ','), ',0', ',') + ',', 0) > 0)
Group by SiteNo, SSN
Order by SiteNo, SSN

------------------------------------
--
--  FIND Un Rounded punches
--
select RecordID, SSN, Type = '1', SiteNo, PunchDay = InDay, PunchTime = '1/1/1900 ' + convert(varchar(5),InTime,108), ActualPunchTime = ActualInTime, ShiftFound = 0, ShiftDifference = 0
INTO #tmpPunches
from TimeHistory..tblTimeHistDetail 
where client = @Client
and groupcode = @Group
and payrollperiodenddate = @PPED
and ClockADjustmentNo = ''
and OutDay < 8
and (case when InSrc = '0' and Hours <> 0.00 and  NOT(ActualInTime is NULL) and convert(varchar(5), ActualInTime, 108) = convert(varchar(5), InTime, 108) then 1 else 0 end) = 1
UNION ALL
select RecordID, SSN, Type = '0', SiteNo, PunchDay = OutDay, PunchTime = '1/1/1900 ' + convert(varchar(5),OutTime,108), ActualPunchTime = ActualOutTime, ShiftFound = 0, ShiftDifference = 0
from TimeHistory..tblTimeHistDetail 
where client = @Client
and groupcode = @Group
and payrollperiodenddate = @PPED
and ClockADjustmentNo = ''
and InDay < 8
and (case when OutSrc = '0' and Hours <> 0.00 and NOT(ActualOutTime is NULL) and convert(varchar(5), ActualOutTime, 108) = convert(varchar(5), OutTime, 108) then 1 else 0 end ) = 1

-- Set In Punches
Update #tmpPunches
	Set ShiftFound = (select Count(*) from TimeCurrent..tblDeptShifts where client = @Client 
												and groupcode = @Group 
												and SiteNo = #tmpPunches.SiteNo 
												and ShiftStart = #tmpPunches.PunchTime 
												and ( Case When PunchDay = 1 then ApplyDay1
 																	 When PunchDay = 2 then ApplyDay2
 																	 When PunchDay = 3 then ApplyDay3
 																	 When PunchDay = 4 then ApplyDay4
 																	 When PunchDay = 5 then ApplyDay5
 																	 When PunchDay = 6 then ApplyDay6
 																	 When PunchDay = 7 then ApplyDay7
																	 Else '0' end ) = '1'
												and Recordstatus = '1' )
where Type = '1'

-- Set Out Punches
Update #tmpPunches
	Set ShiftFound = (select Count(*) from TimeCurrent..tblDeptShifts where client = @Client 
												and groupcode = @Group 
												and SiteNo = #tmpPunches.SiteNo 
												and ShiftEnd = #tmpPunches.PunchTime 
												and ( Case When PunchDay = 1 then ApplyDay1
 																	 When PunchDay = 2 then ApplyDay2
 																	 When PunchDay = 3 then ApplyDay3
 																	 When PunchDay = 4 then ApplyDay4
 																	 When PunchDay = 5 then ApplyDay5
 																	 When PunchDay = 6 then ApplyDay6
 																	 When PunchDay = 7 then ApplyDay7
																	 Else '0' end ) = '1'
												and Recordstatus = '1' )
where Type = '0'

-- Determine how far away from the closest shift the punch is ( IN Punches Only)
DECLARE cInPunches CURSOR
READ_ONLY
FOR Select RecordID, SiteNo, PunchDay, Punchtime from #tmpPunches where ShiftFound = 0 and Type = '1'

DECLARE @RecID BIGINT  --< @RecId data type is changed from  INT to BIGINT by Srinsoft on 31Aug2016 >--
DECLARE @SiteNo int
DECLARE @PunchDay int
DECLARE @PunchTime Datetime
DECLARE @Minutes int


OPEN cInPunches

FETCH NEXT FROM cInPunches into @RecID, @SiteNo, @PunchDay, @PunchTime
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Set @Minutes = (Select MIN( abs(datediff(minute, ShiftStart, @PunchTime)) ) from TimeCurrent..tblDeptShifts 
												where client = @Client 
												and groupcode = @Group 
												and SiteNo = @SiteNo
--												and @PunchTime between dateadd(minute, -119, ShiftStart) and dateadd(minute, 119, ShiftStart)
												and ( Case When @PunchDay = 1 then ApplyDay1
 																	 When @PunchDay = 2 then ApplyDay2
 																	 When @PunchDay = 3 then ApplyDay3
 																	 When @PunchDay = 4 then ApplyDay4
 																	 When @PunchDay = 5 then ApplyDay5
 																	 When @PunchDay = 6 then ApplyDay6
 																	 When @PunchDay = 7 then ApplyDay7
																	 Else '0' end ) = '1'
												and Recordstatus = '1' )	END
		Print @PunchTime
		IF isnull(@Minutes,0) = 0
			Set @Minutes = 9999
		Update #tmpPunches Set ShiftDifference = @Minutes where recordid = @RecID

	FETCH NEXT FROM cInPunches into @RecID, @SiteNo, @PunchDay, @PunchTime
END

CLOSE cInPunches
DEALLOCATE cInPunches

Update #tmpSiteInfo
	Set UnRoundedPunches = (Select Count(*) from #tmpPunches where ShiftFound = 0 and SiteNo = #tmpSiteInfo.SiteNo)

Update #tmpSiteInfo
	Set UnRoundedWithin120 = (Select Count(*) from #tmpPunches where ShiftFound = 0 and SiteNo = #tmpSiteInfo.SiteNo and ShiftDifference <= 120)

Update #tmpSiteInfo
	Set UnRoundedOver120 = (Select Count(*) from #tmpPunches where ShiftFound = 0 and SiteNo = #tmpSiteInfo.SiteNo and ShiftDifference > 120)

select 
@PPED as PPED,
SI.Lastbackup,
SI.SiteNo, si.SiteName, 
QtrHr = case when si.QtrHourRounding = '1' then 'YES' else 'NO' end,
si.ShiftInWindow,
si.ShiftOutWindow,
si.ShiftCount,
si2.EmplCount,
TotalPunches = Sum(PR.EEPunches),
TotalAdjs = sum(PR.TotAdjs),
MissingPunches = sum(PR.TotMissing),
UnRounded = si.UnRoundedPunches,
si.UnRoundedWithin120,
si.UnRoundedOver120,
Reg = Sum(RegHrs),
OT = Sum(OTHrs),
DT = Sum(DTHrs)
From #tmpSiteInfo as SI
Left Join #tmpProgressRpt1 as PR on SI.SiteNo = PR.SiteNo
Left Join #tmpSiteInFo2 as SI2 on SI2.SiteNo = SI.SiteNo
Group By SI.Lastbackup, SI.SiteNo, si.SiteName, si.QtrHourRounding, si.ShiftInWindow,si.ShiftOutWindow, si.ShiftCount, 
si.UnRoundedPunches, 
si2.EmplCount,
si.UnRoundedWithin120,
si.UnRoundedOver120
Order By SI.SiteNo


DECLARE @TotalEmpls int
DECLARE @TotalEmplsPunching int
DECLARE @TotalUnRounded int
DECLARE @TotalUnRoundedWithin120 int
DECLARE @TotalUnRoundedOver120 int
DECLARE @TotDepts int
DECLARE @Depts int
DECLARE @PendingPunches int
DECLARE @EmployeeCountLast4Wks int
DECLARE @TempPPED datetime
DECLARE @NewEmpls int

Set @TotalEmpls = (Select count(*) from TimeHistory..tblEMplnames where client = @Client and Groupcode = @Group and PayrollPeriodenddate = @PPED and status <> '9')
Set @TotalEmplsPunching = (Select count(Distinct SSN) from #tmpProgressRpt1)
Set @TotalUnRounded = (select sum(UnRoundedPunches) from #tmpSiteInfo)
Set @TotalUnRoundedWithin120 = (select sum(UnRoundedWithin120) from #tmpSiteInfo)
Set @TotalUnRoundedOver120 = (select sum(UnRoundedOver120) from #tmpSiteInfo)
Set @TotDepts = (Select Count(*) from TimeCurrent..tblGroupDepts where client = @Client and Groupcode = @Group and RecordStatus = '1')
Set @Depts = (Select count(Distinct DeptNo) from TimeHistory..tblTimeHistDetail where client = @Client and Groupcode = @Group and PayrollPeriodenddate = @PPED)
Set @TotDepts = @TotDepts - @Depts
Set @PendingPunches = (Select Count(*) from TimeCurrent.dbo.tblPunchImportPending where client = @Client and Groupcode = @Group and DateProcessed is null and DateCreated >= dateadd(day, -8, getdate()) )
Set @TempPPED = dateadd(day, -28, @PPED)
Set @EmployeeCountLast4Wks = (SElect Count(Distinct SSN) from TimeHistory..tblTimeHistDetail where client = @Client and Groupcode = @Group and PayrollPeriodenddate >= @tempPPED and Payrollperiodenddate < @PPED)
Set @TempPPED = dateadd(day, -7, @PPED)
Set @NewEmpls = (Select Count(*) from TimeCurrent..tblEmplNames where client = @Client and Groupcode = @Group and DateAdded > @TempPPED and DateAdded <= @PPED)

select 
@PPED as PPED,
EmplCount = @TotalEmpls,
EmplNoPunch = @TotalEmpls - @TotalEmplsPunching, 
NewEmpls = @NewEmpls,
EmplCount4Wks = @EmployeeCountLast4Wks,
TotalPunches = Sum(EEPunches),
TotalAdjs = sum(TotAdjs),
MissingPunches = sum(TotMissing),
UnRounded = @TotalUnRounded,
UnRoundedWithin120 = @TotalUnRoundedwithin120,
UnRoundedOver120 = @TotalUnRoundedOver120,
PendingPunches = @PendingPunches,
DeptNoPunch = @TotDepts,
Reg = Sum(RegHrs),
OT = Sum(OTHrs),
DT = Sum(DTHrs)
From #tmpProgressRpt1

-- Missing Punches
--
Select en.LastName, en.FirstName, SSN = right(str(t.ssn),4), 
t.SiteNo, t.TransDate,
InPunch = Case when InDay <= 10 then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime) else '1/1/1900' end,
OutPunch = Case when InDay <= 10 then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime) else '1/1/1900' end
from TimeHistory..tblTimeHistDetail as t
Inner Join TimeCurrent..tblEmplNames as en
on en.Client = @Client
and en.Groupcode = @Group
and en.SSN = t.SSN
where t.Client = @Client
and t.Groupcode = @Group
and t.PayrollPeriodenddate = @PPED
and (t.InDay = 10 or (OutDay = 10 and @iDow <> datepart(weekday,TransDate)) )


-- UnRounded Punches
Select en.LastName, en.FirstName, SSN = right(str(t.ssn),4), 
PunchType = case when t.Type = 1 then 'IN' Else 'Out' end,
t.ActualPunchTime, 
t.ShiftDifference
from #tmpPunches as t
Inner Join TimeCurrent..tblEmplNames as en
on en.Client = @Client
and en.Groupcode = @Group
and en.SSN = t.SSN
where t.ShiftFound = 0
Order by en.LastName, en.FirstName, t.ActualPunchTime




