CREATE   Procedure [dbo].[usp_RPT_TAND_GroupAudit2] ( @Client char(4), @Group int, @Date DateTime, @Sites varchar(1000) = NULL ) AS 


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
DECLARE @GroupName varchar(80)

SELECT @crlf = char(13) + char(10)
SELECT @PPED = @Date 

set @GroupName = (select Groupname from TimeCurrent..tblClientGroups where client = @Client and Groupcode = @Group)

Create Table #tmpReport
(
  SortID numeric(4,2),
  Col1 varchar(80) default '',
  Col2 varchar(80) default '',
  Col3 varchar(80) default '',
  Col4 varchar(80) default '',
  Col5 varchar(80) default '',
  Col6 varchar(80) default '',
  Col7 varchar(80) default '',
  Col8 varchar(80) default '',
  Col9 varchar(80) default '',
  Col10 varchar(80) default '',
  Col11 varchar(80) default '',
  Col12 varchar(80) default '',
  Col13 varchar(80) default '',
  Col14 varchar(80) default '',
  Col15 varchar(80) default '',
  Col16 varchar(80) default '',
  Col17 varchar(80) default '',
  Col18 varchar(80) default '',
  Col19 varchar(80) default '',
  Col20 varchar(80) default ''
)


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

DECLARE @SumShiftCnt int
Set @SumShiftCnt = (Select sum(ShiftCount) from #tmpSiteInfo)

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

Insert into #tmpreport(SortID, Col1, Col2)
values(1.0,'AUDIT REPORT FOR', @GroupName )
Insert into #tmpreport(SortID, Col1, Col2)
values(1.1,'', '' )

Insert into #tmpreport(SortID, Col1, Col2)
values(1.2,'SITE LEVEL', '' )

Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6,Col7,Col8,Col9,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18)
values(1.3,'Week Ending','Last Comms','Site No','Site Name','Qtr Hr','Shift In Window', 'Shift Out Window', 'Shift Count','Empl Count',
'Total Punches', 'Total Adjs', 'Total Missing Punches', 'Total UnRounded Punches', 'Tot UnRounded within 120', 'Tot UnRounded over 120',
'Reg Hrs', 'OT Hrs', 'DT Hrs')
Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6,Col7,Col8,Col9,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18)
select 
1.4,
convert(varchar(12),@PPED, 101),
convert(varchar(20), SI.Lastbackup,101),
ltrim(str(SI.SiteNo)), 
si.SiteName, 
QtrHr = case when si.QtrHourRounding = '1' then 'YES' else 'NO' end,
ltrim(str(si.ShiftInWindow)),
ltrim(str(si.ShiftOutWindow)),
ltrim(str(si.ShiftCount)),
ltrim(str(si2.EmplCount)),
ltrim(str(Sum(PR.EEPunches))),
Ltrim(str(sum(PR.TotAdjs))),
Ltrim(str(sum(PR.TotMissing))),
Ltrim(str(si.UnRoundedPunches)),
ltrim(str(si.UnRoundedWithin120)),
ltrim(str(si.UnRoundedOver120)),
Ltrim(str(Sum(RegHrs),8,3)),
Ltrim(str(Sum(OTHrs),8,3)),
Ltrim(str(Sum(DTHrs),8,3))
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

--- Do this within Pay period. ( Week ending )
--- 
Set @PendingPunches = (Select Count(*) from TimeCurrent.dbo.tblPunchImportPending where client = @Client and Groupcode = @Group and DateProcessed is null and DateCreated > dateadd(day, -7, @PPED) and DateCreated <= @PPED )
Set @TempPPED = dateadd(day, -28, @PPED)
Set @EmployeeCountLast4Wks = (SElect Count(Distinct SSN) from TimeHistory..tblTimeHistDetail where client = @Client and Groupcode = @Group and PayrollPeriodenddate >= @tempPPED and Payrollperiodenddate < @PPED)
Set @TempPPED = dateadd(day, -7, @PPED)
Set @NewEmpls = (Select Count(*) from TimeCurrent..tblEmplNames where client = @Client and Groupcode = @Group and DateAdded > @TempPPED and DateAdded <= @PPED)

Insert into #tmpreport(SortID, Col1)
values(2.0,'')
Insert into #tmpreport(SortID, Col1)
values(2.1,'')

Insert into #tmpreport(SortID, Col1)
values(2.2,'GROUP LEVEL')

Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6,Col7,Col8,Col9,Col10,Col11,Col12,Col13,Col14,Col15,Col16)
values(2.3,'Week Ending','Empl Count','Empl Not Punching','New Empls','Empl Count last 4 wks',
'Total Punches', 'Total Adjs', 'Total Missing Punches', 'Total UnRounded Punches', 'Tot UnRounded within 120', 
'Tot UnRounded over 120','Pending Punches','Depts without Punches','Reg Hrs', 'OT Hrs', 'DT Hrs')

Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6,Col7,Col8,Col9,Col10,Col11,Col12,Col13,Col14,Col15,Col16)
select 
2.4,
convert(varchar(12),@PPED,101),
ltrim(str(@TotalEmpls)),
ltrim(str(@TotalEmpls - @TotalEmplsPunching)), 
ltrim(str(@NewEmpls)),
ltrim(str(@EmployeeCountLast4Wks)),
ltrim(str(Sum(EEPunches))),
ltrim(str(sum(TotAdjs))),
ltrim(str(sum(TotMissing))),
ltrim(str(@TotalUnRounded)),
ltrim(str(@TotalUnRoundedwithin120)),
ltrim(str(@TotalUnRoundedOver120)),
ltrim(str(@PendingPunches)),
ltrim(str(@TotDepts)),
ltrim(str(Sum(RegHrs),8,2)),
ltrim(str(Sum(OTHrs),8,2)),
ltrim(str(Sum(DTHrs),8,2))
From #tmpProgressRpt1

-- Missing Punches
--
Insert into #tmpreport(SortID, Col1)
values(3.0,'')
Insert into #tmpreport(SortID, Col1)
values(3.1,'')
Insert into #tmpreport(SortID, Col1)
values(3.2,'MISSING PUNCHES')
Insert into #tmpreport(SortID, Col1)
values(3.3,'')

Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6,Col7)
values(3.4,'Last Name','First Name','LAST 4 SSN','Site No','Trans Date','In Punch', 'Out Punch')

Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6,Col7)
Select 3.5,
en.LastName, en.FirstName, right(str(t.ssn),4), 
ltrim(str(t.SiteNo)), convert(varchar(12),t.TransDate,101),
convert(varchar(24),Case when InDay <= 10 then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime) else '1/1/1900' end,100),
convert(varchar(24),Case when InDay <= 10 then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime) else '1/1/1900' end,100)
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

Insert into #tmpreport(SortID, Col1)
values(4,'')
Insert into #tmpreport(SortID, Col1)
values(4.1,'')
Insert into #tmpreport(SortID, Col1)
values(4.2,'UNROUNDED PUNCHES')
Insert into #tmpreport(SortID, Col1)
values(4.3,'')

IF @SumShiftCnt > 0 
BEGIN
  Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6)
  values(4.4,'Last Name','First Name','LAST 4 SSN','Punch Type','Act. Punch Time', 'Difference')
  
  Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6)
  Select 4.5, en.LastName, en.FirstName, SSN = right(str(t.ssn),4), 
  PunchType = case when t.Type = 1 then 'IN' Else 'Out' end,
  convert(varchar(24),t.ActualPunchTime,100), 
  ltrim(str(t.ShiftDifference))
  from #tmpPunches as t
  Inner Join TimeCurrent..tblEmplNames as en
  on en.Client = @Client
  and en.Groupcode = @Group
  and en.SSN = t.SSN
  where t.ShiftFound = 0
  Order by en.LastName, en.FirstName, t.ActualPunchTime
END
ELSE
BEGIN
  Insert into #tmpreport(SortID, Col1)
  values(4.3,'NO SHIFTS ARE SETUP FOR THIS GROUP')
END

--Pending Punches:
--
Insert into #tmpreport(SortID, Col1)
values(5,'')
Insert into #tmpreport(SortID, Col1)
values(5.1,'')
Insert into #tmpreport(SortID, Col1)
values(5.2,'PENDING PUNCHES')
Insert into #tmpreport(SortID, Col1)
values(5.3,'')

IF @PendingPunches > 0 
BEGIN
  Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6)
  values(5.4,'Clock Number','Punch Method','ID Entered','IN/OUT','DEPT CODE','PUNCH DATE/TIME')

  DECLARE @PunchRec varchar(80)
  DECLARE @Offset int
  DECLARE @Source char(1)
  DECLARE @Type char(1)
  DECLARE @ID varchar(10)
  DECLARE @DeptID varchar(10)
  DECLARE @Punch datetime
  DECLARE @Secs int
  DECLARE @Loc int
  DECLARE @Len int
  DECLARE @Temp varchar(50)
  DECLARE @PunchRec2 varchar(80)

  -- =============================================
  -- Extract the Pending Punches.
  -- =============================================
  DECLARE cPP CURSOR
  READ_ONLY
  FOR 
  Select p.SiteNo, sn.EST_HoursOffset, p.PunchType, p.PunchRecord
  from TimeCurrent.dbo.tblPunchImportPending as p
  Inner Join TimeCurrent.dbo.tblSiteNames as sn
  on sn.Client = @Client and sn.Groupcode = @Group and sn.SiteNo = p.SiteNo
  where p.client = @Client and p.Groupcode = @Group 
  and p.DateProcessed is null 
  and p.DateCreated > dateadd(day, -7, @PPED) and p.DateCreated <= @PPED
  
  OPEN cPP
  
  FETCH NEXT FROM cPP into @SiteNo, @Offset, @Source, @Punchrec
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
          Set @Source = substring(@PunchRec, 1, 1)
          Set @Loc = 2
          Set @Len = @Loc + 1
          Set @Loc = charindex(',', @PunchRec, @Len)
          Set @ID = substring(@PunchRec, @Len, (@Loc - @Len))
          Set @Len = @Loc + 1
          Set @Loc = charindex(',', @PunchRec, @Len)
          Set @Type = substring(@PunchRec, @Len, (@Loc - @Len))
          Set @Len = @Loc + 1
          Set @Loc = charindex(',', @PunchRec, @Len)
          Set @DeptID = substring(@PunchRec, @Len, (@Loc - @Len))
          Set @Len = @Loc + 1
          Set @Loc = charindex(',', @PunchRec, @Len)
          Set @Temp = substring(@PunchRec, @Len, (@Loc - @Len))
          Set @Len = @Loc + 1
          --Print @PunchRec + '   : ' + @Source + ',' + @ID + ',' + @Type + ',' + @Temp
          Set @Secs = cast(left(@temp,10) as int)
          Set @Punch = dateadd(second, @Secs, '1/1/1970 00:00')
          Set @Punch = dateadd(hour, @Offset, @Punch)
          Insert into #tmpreport(SortID, Col1,Col2,Col3,Col4,Col5,Col6)
          Values(5.5, ltrim(str(@SiteNo)), 
                 case when @Source = 'P' then 'PIN' When @Source = 'C' then 'CARD' else 'ID' end, 
                 @ID, @Type, case when @DeptID = '000' then '0' else @DeptID end, convert(varchar(24),@Punch,100))
  	END
  	FETCH NEXT FROM cPP into @SiteNo, @Offset, @Source, @Punchrec
  END
  
  CLOSE cPP
  DEALLOCATE cPP

END
ELSE
BEGIN
  Insert into #tmpreport(SortID, Col1)
  values(5.4,'NO PENDING PUNCHES FOR THIS GROUP')
END


select Col1,Col2,Col3,Col4,Col5,Col6,Col7,Col8,Col9,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,col19,col20 from #tmpreport order by SortID




