Create PROCEDURE [dbo].[usp_APP_DAVT_DailyExtractv2]
(
  @Client     char(4), 
  @GroupCode  int, 
  @PPED       datetime,
	@MasterPPED datetime,
  @TransDate  dateTime,
  @ManualCheck char(1) = 'N'

) AS

SET NOCOUNT ON
--*/

DECLARE @Testing    tinyint
Declare @StartTime datetime
Set @starttime = getdate()
SET @Testing = 0

--printltrim(str(@groupCode)) + ' Start Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

truncate table TimeHistory..tblWork_TimeHistDetail 

-- Work thd to map Dept 88 records to their travelled _to_ Dept
INSERT INTO tblWork_TimeHistDetail (
  RecordID, PayrollPeriodEnddate, MasterPayrollDate,
  Client, GroupCode, SiteNo, SSN, DeptNo, 
  ShiftNo, AgencyNo, ClockAdjustmentNo,
  AprvlStatus, AprvlStatus_UserID, Holiday, CostID,
  Hours, RegHours, OT_Hours, DT_Hours, Dollars,
  TransDate, InDay, InTime, OutDay, OutTime
)
SELECT RecordID, PayrollPeriodEnddate, MasterPayrollDate,
  Client, GroupCode, SiteNo, SSN, 
  Case when DeptNo = 100 and JobID not IN(0,100) then JobID else DeptNo end, 
  ShiftNo, AgencyNo, ClockAdjustmentNo,
  IsNull(CrossoverStatus, ''), CrossoverOtherGroup, Holiday, '',
  Hours, RegHours, OT_Hours, DT_Hours, Dollars,
  TransDate, InDay, InTime, OutDay, OutTime
FROM tblTimeHistDetail thd  with (nolock)
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollperiodEndDate = @PPED 
  AND thd.TransDate <= @TransDate
  AND IsNull(thd.CrossoverStatus, '') not in('2')         -- Skip cross over records and immediate pay records
  AND thd.ClockAdjustmentNo IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND thd.Holiday = '0'


--printltrim(str(@groupCode)) + ' After Load Work table Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

-- Fix all travel punch records -- associate with the next IN or the prior out. 
--
DECLARE @Siteno int
DECLARE @RecordID BIGINT  --< @thdRecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
DECLARE @SiteNo2 int
DECLARE @DeptNo int
DECLARE @PrimarySIte int
DECLARE @PrimaryDept int

 DECLARE cTravel CURSOR
  READ_ONLY
  FOR 
  Select t.RecordID, t.SiteNo, NewSiteNo = isnull(thd2.SiteNo,thd4.Siteno), NewDeptNo = isnull(thd2.DeptNo,thd4.deptNo), e.PrimarySite, e.PrimaryDept
  from Timehistory..tblWork_TimeHistDetail as t with (nolock)
  inner Join TimeCurrent..tblEmplnames as e with(nolock)
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  LEFT JOIN tblWork_TimeHistDetail thd2  with (nolock)
  ON t.DeptNo = 88 
    AND thd2.RecordID = (
      SELECT TOP 1 thd3.RecordID
      FROM tblWork_TimeHistDetail thd3  with (nolock)
      WHERE thd3.DeptNo <> 88
        AND t.SSN = thd3.SSN
        AND (
            dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime) = dbo.PunchDateTime2(thd3.TransDate, thd3.InDay, thd3.InTime)
              OR
            dbo.PunchDateTime2(t.TransDate, t.OutDay, dateadd(minute,1,t.OutTime)) = dbo.PunchDateTime2(thd3.TransDate, thd3.InDay, thd3.InTime) )
        AND thd3.Hours > 0
    )
  LEFT JOIN tblWork_TimeHistDetail thd4  with (nolock)
  ON t.DeptNo = 88 
    AND thd4.RecordID = (
      SELECT TOP 1 thd5.RecordID
      FROM tblWork_TimeHistDetail thd5  with (nolock)
      WHERE thd5.DeptNo <> 88
        AND t.SSN = thd5.SSN
        AND (dbo.PunchDateTime2(t.TransDate, t.inDay, t.inTime) = dbo.PunchDateTime2(thd5.TransDate, thd5.outDay, thd5.outTime)
            OR dbo.PunchDateTime2(t.TransDate, t.inDay, dateadd(minute,-1,t.inTime)) = dbo.PunchDateTime2(thd5.TransDate, thd5.outDay, thd5.outTime) )
        AND thd5.Hours > 0
    )
  WHERE t.Client = @Client 
  AND t.GroupCode = @GroupCode
  AND t.PayrollperiodEndDate = @PPED
  AND t.AprvlStatus not in('2','1') -- Skip any records that were copied to the employees primary group or are immediate pay records
																		-- AprvlStatus is correct in this case since its selecting from the work table
  AND t.ClockAdjustmentNo in('', ' ' ) --IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND e.AgencyNo < 5    -- Do not include Contract Labor
  and t.DeptNo = 88
  --and isnull(thd2.siteno,0) = 0  -- does not have a match on the connecting IN Punch

  OPEN cTravel
  
  FETCH NEXT FROM cTravel INTO @RecordID, @SiteNo, @SIteNo2, @DeptNo, @PrimarySite, @PrimaryDept
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
  	  IF isnull(@SiteNo2,0) <> 0
  	  BEGIN
        Update TimeHistory..tblWork_TimeHistDetail 
          Set SiteNo = isnull(@SiteNo2,@PrimarySite),
            DeptNo = isnull(@DeptNo,@PrimaryDept) 
        where RecordID = @RecordID
      END  
  	END
  	FETCH NEXT FROM cTravel INTO @RecordID, @SiteNo, @SIteNo2, @DeptNo, @PrimarySite, @PrimaryDept
  END
  
  CLOSE cTravel
  DEALLOCATE cTravel
  
--printltrim(str(@groupCode)) + ' After Travel Fixup Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))


 DECLARE cTravel CURSOR
  READ_ONLY
  FOR 
  Select t.RecordID, t.SiteNo, isnull(d.DeptNo,0), e.PrimarySite, e.PrimaryDept
  from Timehistory..tblWork_TimeHistDetail as t with (nolock)
  inner Join TimeCurrent..tblEmplnames as e with (nolock)
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  Left Join TimeCurrent..tblDeptNames as d with (nolock)
  on d.Client = t.Client
  and d.GroupCode = t.GroupCode 
  and d.SiteNo = t.SiteNo 
  and d.DeptNo = e.PrimaryDept
  WHERE t.Client = @Client 
  AND t.GroupCode = @GroupCode
  AND t.PayrollperiodEndDate = @PPED
  AND t.AprvlStatus not in('2') -- Skip any records that were copied to the employees primary group or are immediate pay records
																		-- AprvlStatus is correct in this case since its selecting from the work table
  --AND t.ClockAdjustmentNo not in('', ' ' ) 
  AND e.AgencyNo < 5    -- Do not include Contract Labor
  and t.DeptNo = 88

  OPEN cTravel
  
  FETCH NEXT FROM cTravel INTO @RecordID, @SiteNo, @DeptNo, @PrimarySite, @PrimaryDept
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
  	  IF @DeptNo = 0 
  	  BEGIN
        Update TimeHistory..tblWork_TimeHistDetail 
          Set SiteNo = @PrimarySite,
            DeptNo = @PrimaryDept,
            OutSrc = 'D' 
        where RecordID = @RecordID
  	  END
  	  ELSE
  	  BEGIN
        Update TimeHistory..tblWork_TimeHistDetail 
          Set DeptNo = @DeptNo
        where RecordID = @RecordID
      END  
  	END
  	FETCH NEXT FROM cTravel INTO @RecordID, @SiteNo, @DeptNo, @PrimarySite, @PrimaryDept
  END
  
  CLOSE cTravel
  DEALLOCATE cTravel

--printltrim(str(@groupCode)) + ' After Travel Fixup 2 Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))
  
--select * from TimeHistory..tblWork_TimeHistDetail where ISNULL(outsrc,'') in('P','D') and Hours > 0.00
--select * from TimeHistory..tblWork_TimeHistDetail where ClockAdjustmentNo not in('',' ' ) and ISNULL(outsrc,'') = 'P' and Hours > 0.00


-- SELECT the all records from timehistdetail that 
--    - do not have an adjustment no.
--    - are not associated with a special holiday pay(overtime days table).
--      or if the employee is a prediem employee (tblEmplNames.SubStatus1 = ' ' )
--
-- Sum the values by Site, DeptNo, ShiftNo, SSN, SiteState(needed for the paycode xref)
--
SELECT 	
        thd.PayrollPeriodEndDate, 
				thd.TransDate,
				thd.SSN, 
				IsNull(en.FileNo, '') as FileNo,
			  WorkedSite = CASE WHEN isnull(sn.UploadAsSiteNo,0) = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
        CASE WHEN thd.DeptNo = 88 THEN en.PrimaryDept 
             WHEN thd.DeptNo IN(899,100) THEN en.PrimaryDept 
             ELSE thd.DeptNo END AS DeptNo,
			  en.AgencyNo, 
				thd.ShiftNo, 
				'   ' AS ClockAdjustmentNo, 
				' ' as AdjustmentName,
			  SUM(thd.RegHours) AS Reg, 
			  SUM(thd.OT_Hours) AS OT,
			  SUM(thd.DT_Hours) AS DT,
			  SUM(thd.Dollars) AS Dollars,
			  sn.SiteState, 
			  ExcludeFromUpload = CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
			  dxr.ClientDeptCode AS UploadCode,dxr.ClientDeptCode2 AS SalUploadCode
INTO #tmpHrs
FROM tblWork_TimeHistDetail AS thd  with (nolock)
Inner JOIN TimeCurrent..tblSiteNames AS sn  with (nolock)
  ON  sn.Client = thd.Client
  AND sn.GroupCode not in(999999,999899,500100) --= (CASE WHEN thd.AprvlStatus = 4 then thd.AprvlStatus_UserID else thd.GroupCode end)
  AND sn.SiteNo = thd.SiteNo
Inner JOIN TimeCurrent..tblEmplNames as en  with (nolock)
  ON  en.Client = thd.Client
  AND en.GroupCode = thd.GroupCode
  AND en.SSN = thd.SSN
Inner JOIN TimeCurrent..tblGroupDepts AS dxr  with (nolock)
  ON  dxr.Client = thd.Client
  AND dxr.GroupCode = thd.GroupCode
  AND dxr.DeptNo = CASE WHEN thd.DeptNo = 88 THEN en.PrimaryDept 
                        WHEN thd.DeptNo IN(899,100) THEN en.PrimaryDept ELSE thd.DeptNo END
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollperiodEndDate = @PPED 
  AND thd.TransDate <= @TransDate

  AND thd.AprvlStatus not in('2') -- Skip any records that were copied to the employees primary group or are immediate pay records
																		  -- AprvlStatus is correct in this case since its selecting from the work table
  AND thd.ClockAdjustmentNo IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND thd.Holiday = '0'
  AND en.AgencyNo < 5    -- Do not include Contract Labor
  AND (en.PayType = '0' or (en.Paytype = '1' and thd.ClockAdjustmentNo <> 'S'))  -- Only include Hourly EEs
GROUP BY 	
          thd.PayrollPeriodEndDate, 
					thd.TransDate,
					thd.SSN, 
					IsNull(en.FileNo, ''),
				  CASE WHEN isnull(sn.UploadAsSiteNo,0) = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
          CASE WHEN thd.DeptNo = 88 THEN en.PrimaryDept 
               WHEN thd.DeptNo IN(899,100) THEN en.PrimaryDept 
               ELSE thd.DeptNo END,
				  en.AgencyNo, 
					thd.ShiftNo,
				  sn.SiteState, 
				  CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
				  dxr.ClientDeptCode,dxr.ClientDeptCode2

DELETE FROM tblWork_TimeHistDetail WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED

--printltrim(str(@groupCode)) + ' After Hours Load Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

--
-- SELECT all records from timehistdetail that are for adjustments only.
-- Sum the values by Site, DeptNo, shift, SSN and ClockAdjustment
--
SELECT 	thd.PayrollPeriodEndDate, 
				thd.TransDate,
				thd.SSN, 
				IsNull(en.FileNo, '') as FileNo,
			  WorkedSite = CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
				DeptNo = (CASE WHEN thd.DeptNo IN(88,899) THEN en.PrimaryDept 
				          ELSE case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END ), 
				en.AgencyNo, 
				thd.ShiftNo, 
				thd.ClockAdjustmentNo, 
				' ' as AdjustmentName,
				-- For CA Penalty Break ('N') or CA Rest Penalty ('H'), Zero shows on the time card for reporting, but they want it loaded 
				-- as 1 hour on pay file.
				--
				SUM(case when (thd.ClockADjustmentNo in('N','H') and thd.RegHours = 0) 
                        or (thd.ClockADjustmentNo = '6' and thd.Transtype <> 7) then 1 else thd.RegHours end) AS Reg, 
				SUM(thd.OT_Hours) AS OT,
				SUM(thd.DT_Hours) AS DT,
				SUM(thd.Dollars) AS Dollars,
				sn.SiteState, 
				ExcludeFromUpload = CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
				dxr.ClientDeptCode AS UploadCode, dxr.ClientDeptCode2 AS SalUploadCode
INTO #tmpAdjs
FROM TimeHistory..tblTimeHistDetail AS thd with (nolock)
LEFT JOIN timecurrent..tblSiteNames AS sn  with (nolock)
ON  sn.Client = thd.Client
  AND sn.GroupCode not in(999999,999899,500100) --(CASE WHEN thd.AprvlStatus = 4 then thd.AprvlStatus_UserID else thd.GroupCode end)
  AND sn.SiteNo = thd.SiteNo
Inner JOIN timeCurrent..tblEMplNames as en with (nolock)
  ON  en.Client = thd.Client
  AND en.GroupCode = thd.GroupCode
  AND en.SSN = thd.SSN
Inner JOIN TimeCurrent..tblGroupDepts AS dxr with (nolock)
ON  dxr.Client = thd.Client
  AND dxr.GroupCode = thd.GroupCode
  AND dxr.DeptNo = (CASE WHEN thd.DeptNo IN(88,899) THEN en.PrimaryDept ELSE 
                       case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END )
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollperiodEndDate = @PPED 
	and thd.TransDate <= @TransDate
  AND IsNull(thd.CrossoverStatus, '') not in('2')        -- Skip any records that were copied to the employees primary group or are immediate pay records
  AND thd.ClockAdjustmentNo NOT IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND en.AgencyNo < 5    -- Do not include Contract Labor
GROUP BY 	thd.PayrollPeriodEndDate, 
   				thd.TransDate,
					thd.SSN, 
					IsNull(en.FileNo, ''),
					CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
					--(CASE WHEN thd.DeptNo = 88 or thd.DeptNo between 900 and 989 THEN en.PrimaryDept ELSE thd.DeptNo END), 
				  (CASE WHEN thd.DeptNo in(88,899) THEN en.PrimaryDept 
				          ELSE case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END ), 
					en.AgencyNo, 
					thd.ShiftNo, 
					thd.ClockAdjustmentNo, 
					--thd.AdjustmentName,
					sn.SiteState, 
					CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
					dxr.ClientDeptCode,dxr.ClientDeptCode2
ORDER BY 	thd.PayrollPeriodEndDate, 
					thd.SSN, 
					WorkedSite, 
					DeptNo, 
					thd.ShiftNo, 
					thd.ClockAdjustmentNo

--printltrim(str(@groupCode)) + ' After Non-Worked Adjs load Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

--
-- SELECT the all records from timehistdetail that are 
-- associated with a special holiday pay(overtime days table).
-- 
-- make these records appear to be a adjustment Type of '!' (shift 1 ) or '(' (shift 9)
-- Sum the values by Site, Deptno, ShiftNo, SSN, SiteState(needed for the paycode xref)
--
INSERT INTO #tmpAdjs
SELECT 	thd.PayrollPeriodEndDate, 
				thd.Transdate,
				thd.SSN, 
				IsNull(en.FileNo, '') as FileNo,
				WorkedSite = CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
				DeptNo = (CASE WHEN thd.DeptNo IN(88,899) THEN en.PrimaryDept 
				          ELSE case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END ), 
				en.AgencyNo, 
				thd.ShiftNo, 
				ClockAdjustmentNo = CASE WHEN Thd.ShiftNo = 1 or thd.ShiftNo = 5 Then '!' Else '(' END,
				' ',
				SUM(thd.RegHours) AS Reg, 
				SUM(thd.OT_Hours) AS OT,
				SUM(thd.DT_Hours) AS DT,
				SUM(thd.Dollars) AS Dollars,
				sn.SiteState,
				ExcludeFromUpload = CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
				dxr.ClientDeptCode AS UploadCode, dxr.ClientDeptCode2 AS SalUploadCode
FROM tblTimeHistDetail AS thd with (nolock)
LEFT JOIN timecurrent..tblSiteNames AS sn with (nolock)
  ON  sn.Client = thd.Client
  AND sn.GroupCode not in(999999,999899,500100) -- (CASE WHEN thd.AprvlStatus = 4 then thd.AprvlStatus_UserID else thd.GroupCode end)
  AND sn.SiteNo = thd.SiteNo
Inner JOIN timeCurrent..tblEMplNames as en with (nolock)
  ON  en.Client = thd.Client
  AND en.GroupCode = thd.GroupCode
  AND en.SSN = thd.SSN
Inner JOIN TimeCurrent..tblGroupDepts AS dxr with (nolock) 
  ON  dxr.Client = thd.Client
  AND dxr.GroupCode = thd.GroupCode
  AND dxr.DeptNo = (CASE WHEN thd.DeptNo in(88,899) THEN en.PrimaryDept ELSE 
                            case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END)
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollperiodEndDate = @PPED 
	AND thd.TransDate <= @TransDate
  AND thd.ClockAdjustmentNo IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND IsNull(thd.CrossoverStatus, '') not in('2')    -- Skip any records that were copied to the employees primary group or are immediate pay records
  AND thd.Holiday = '1'
  AND en.AgencyNo < 5    -- Do not include Contract Labor
GROUP BY 	thd.PayrollPeriodEndDate, 
				  thd.TransDate,
					thd.SSN, 
					IsNull(en.FileNo, ''),
          CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
					--CASE WHEN thd.DeptNo = 88 or thd.DeptNo between 900 and 989 THEN en.PrimaryDept ELSE thd.DeptNo END, 
          CASE WHEN thd.DeptNo in(88,899) THEN en.PrimaryDept 
				          ELSE case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END,
 					en.AgencyNo, 
					thd.ShiftNo, 
					CASE WHEN Thd.ShiftNo = 1 or thd.ShiftNo = 5 Then '!' Else '(' END,
					sn.SiteState,
					CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
					dxr.ClientDeptCode,dxr.ClientDeptCode2
ORDER BY 	thd.PayrollPeriodEndDate, 
					thd.SSN, 
					WorkedSite, 
					DeptNo, 
					thd.ShiftNo

--select * from #tmpHrs order By SSN
--select * from #tmpADjs order By SSN
--return
--printltrim(str(@groupCode)) + ' After Holiday load Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))


-- Spread the Salary Hours across the five days of the week.
--Drop Table #tmpSalHours

Create Table #tmpSalHours
(
  SSN int,
  Siteno int,
  DeptNo int,
  TransDate datetime,
  Hours numeric(9,2)
)

--Drop Table #tmpDays

Create Table #tmpDays
(
  TransDate datetime,
  Include char(1),
  DayID char(3)
)


  DECLARE @SSN int
  DECLARE @Mon int
  DECLARE @Tue int
  DECLARE @Wed int
  DECLARE @Thu int
  DECLARE @Fri int
  DECLARE @Sal numeric(9,2)
  DECLARE @SalDays numeric(5,2)

Insert into #tmpDays ( TransDate, Include, DayID ) Values( dateadd(day,-5,@PPED), '1', 'MON' )
Insert into #tmpDays ( TransDate, Include, DayID ) Values( dateadd(day,-4,@PPED), '1', 'TUE' )
Insert into #tmpDays ( TransDate, Include, DayID ) Values( dateadd(day,-3,@PPED), '1', 'WED' )
Insert into #tmpDays ( TransDate, Include, DayID ) Values( dateadd(day,-2,@PPED), '1', 'THU' )
Insert into #tmpDays ( TransDate, Include, DayID ) Values( dateadd(day,-1,@PPED), '1', 'FRI' )

DECLARE cEmpls CURSOR
READ_ONLY
FOR 
Select t.SSN, 
Mon = sum(case when datepart(weekday, t.TransDate) = 2 and t.ClockAdjustmentno not in('S','1','8') then Hours else 0 end ),
Tue = sum(case when datepart(weekday, t.TransDate) = 3 and t.ClockAdjustmentno not in('S','1','8') then Hours else 0 end ),
Wed = sum(case when datepart(weekday, t.TransDate) = 4 and t.ClockAdjustmentno not in('S','1','8') then Hours else 0 end ),
Thu = sum(case when datepart(weekday, t.TransDate) = 5 and t.ClockAdjustmentno not in('S','1','8') then Hours else 0 end ),
Fri = sum(case when datepart(weekday, t.TransDate) = 6 and t.ClockAdjustmentno not in('S','1','8') then Hours else 0 end ),
Sal = sum(case when t.ClockAdjustmentno in('S','1','8') then t.Hours else 0.00 end )
from Timehistory..tblTimehistDetail as t with (nolock)
inner Join TimeCurrent..tblEmplnames as e with (nolock)
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
and e.paytype = '1'
where 
t.client = @Client 
and t.groupcode = @Groupcode 
and t.PayrollPeriodenddate = @PPED
AND isnull(t.CrossOverStatus,'') <> '2'
--and t.ssn = 289768097
group By t.SSN

OPEN cEmpls

FETCH NEXT FROM cEmpls INTO @SSN, @Mon, @Tue, @Wed, @Thu, @Fri, @Sal
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- Skip and records that have zero salary hours. Vacation for the week, etc.
    If @Sal = 0.00
      GOTO NextRec

    Set @SalDays = 5
    -- Determine the number of days that should have salary Hours spread to them.
    IF @Mon <> 0
    Begin
      Update #tmpDays Set Include = '0' where DayID = 'MON'
      Set @SalDays = @SalDays - 1
    End
    IF @Tue <> 0
    Begin
      Update #tmpDays Set Include = '0' where DayID = 'TUE'
      Set @SalDays = @SalDays - 1
    End
    IF @Wed <> 0
    Begin
      Update #tmpDays Set Include = '0' where DayID = 'WED'
      Set @SalDays = @SalDays - 1
    End
    IF @Thu <> 0
    Begin
      Update #tmpDays Set Include = '0' where DayID = 'THU'
      Set @SalDays = @SalDays - 1
    End
    IF @Fri <> 0
    Begin
      Update #tmpDays Set Include = '0' where DayID = 'FRI'
      Set @SalDays = @SalDays - 1
    End

    --Select * from #tmpDays    
    IF @SalDays > 0 
    BEGIN
      -- Spread the salary days by @SalDays excluding any days that already have non-worked time.

      Insert into #tmpSalHours( SSN, SiteNo, DeptNo, TransDate, Hours )
      Select t.SSN, t.SiteNo, t.deptNo, dt.TransDate, sum(t.RegHours)
      from #tmpdays as dt      
      Inner Join TimeHistory..tblTimeHistDetail as t with (nolock)
      on t.Client = @client and t.Groupcode = @groupcode and t.PayrollPeriodenddate = @PPED and t.SSN = @SSN
      and t.ClockAdjustmentNo in('1','S','8')
      AND isnull(t.CrossOverStatus,'') <> '2'
      where dt.Include = '1'
      Group by t.SSN, t.SiteNo, t.deptNo, dt.TransDate

      Update #tmpSalHours
        Set Hours = round(Hours * (1.00 / @SalDays),2)
      where SSN = @SSN      

    END
    Update #tmpDays Set Include = '1'  

  NextRec:
	END
	FETCH NEXT FROM cEmpls INTO @SSN, @Mon, @Tue, @Wed, @Thu, @Fri, @Sal
END

CLOSE cEmpls
DEALLOCATE cEmpls

delete from #tmpSalHours where Hours = 0.00

--printltrim(str(@groupCode)) + ' After Salary load 1 Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

--select * from #tmpSalHours order by SSN, TransDate, siteNo, Deptno

Insert into #tmpHrs
SELECT 
        @PPED,
        thd.TransDate,
				thd.SSN, 
				IsNull(en.FileNo, '') as FileNo,
			  WorkedSite = CASE WHEN isnull(sn.UploadAsSiteNo,0) = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
        thd.DeptNo,
			  en.AgencyNo, 
				1,
				'   ' AS ClockAdjustmentNo, 
				' ' as AdjustmentName,
			  SUM(thd.Hours) AS Reg, 
			  0,
			  0,
			  0,
			  sn.SiteState, 
			  ExcludeFromUpload = CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
			  dxr.ClientDeptCode AS UploadCode,
				dxr.ClientDeptCode2 AS SalUploadCode
FROM #tmpSalHours AS thd 
LEFT JOIN TimeCurrent..tblSiteNames AS sn  with (nolock)
  ON  sn.Client = @Client
  AND sn.GroupCode not in(999999,999899,500100) 
  AND sn.SiteNo = thd.SiteNo
Inner JOIN TimeCurrent..tblEmplNames as en  with (nolock)
  ON  en.Client = @Client
  AND en.GroupCode = @Groupcode
  AND en.SSN = thd.SSN
Inner JOIN TimeCurrent..tblGroupDepts AS dxr  with (nolock)
  ON  dxr.Client = @Client
  AND dxr.GroupCode = @Groupcode
  AND dxr.DeptNo = thd.DeptNo
WHERE thd.TransDate <= @TransDate
  AND en.AgencyNo < 5    -- Do not include Contract Labor
GROUP BY 	
	        thd.TransDate,
  				thd.SSN, 
					IsNull(en.FileNo, ''),
				  CASE WHEN isnull(sn.UploadAsSiteNo,0) = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
          thd.DeptNo,
				  en.AgencyNo, 
				  sn.SiteState, 
				  CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
				  dxr.ClientDeptCode,dxr.ClientDeptCode2

--printltrim(str(@groupCode)) + ' After Salary load 2 Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

--*/
--
-- Union the two tables and join in the agency information and upload code info.
--
-- Here is an explanation of the weird CASE statements in the left join on tblDavitaUploadCodes. The table
-- was designed to mainly be joined by State Code from the Site. However, since certain sites need to upload
-- different pay codes by shift(differentials) then other sites in the same state, the table had to also
-- be joined by Site. So the Case statements determines if the Worked At Site is set up in the table for 
-- any shift > 1, then joins on the SiteNo to WorkedSite, else join on the State Code.
--
Update #tmpHrs 
  Set ShiftNo = 1
where ShiftNo = 0

Update #tmpAdjs 
  Set ShiftNo = 1
where ShiftNo = 0

SELECT th.PayrollPeriodEndDate,th.TransDate,
       en.PrimarySite, 
       th.WorkedSite, th.SSN, th.FileNo, th.UploadCode, th.SalUploadCode,
       uc.PayCode_RG, uc.RateCode_RG, th.Reg, 
       uc.PayCode_OT, uc.RateCode_OT, th.OT, 
       uc.PayCode_DT, uc.RateCode_DT, th.DT, 
       uc.ShiftDiffPct,  
       th.Dollars,th.DeptNo, th.AgencyNo, th.ShiftNo, th.ClockAdjustmentNo, th.AdjustmentName
INTO #tmpALL
FROM #tmpHrs AS th
Inner JOIN TimeCurrent..tblEmplNames AS en  with (nolock)
ON en.Client = @Client
  AND en.GroupCode = @GroupCode
  AND en.SSN = th.SSN
LEFT JOIN TimeCurrent..tblDAVT_UploadCodes AS uc  with (nolock)
ON
  (CASE WHEN isnull(th.WorkedSite,0) IN (SELECT DISTINCT SiteNo from TimeCurrent..tblDAVT_UploadCodes where ShiftNo = th.ShiftNo and SiteNo > 0) and th.ShiftNo > 1  THEN '' ELSE th.SiteState END ) = uc.State
  AND (CASE WHEN isnull(th.WorkedSite,0) IN (SELECT DISTINCT SiteNo from TimeCurrent..tblDAVT_UploadCodes where ShiftNo = th.ShiftNo and SiteNo > 0) and th.ShiftNo > 1 THEN th.WorkedSite ELSE 0 END ) = uc.SiteNo
  AND (CASE WHEN en.AgencyNo IS NULL or en.AgencyNo = 0 or en.AgencyNo > 3 THEN 1 ELSE en.AgencyNo END) = uc.Agency
  AND th.ShiftNo = uc.ShiftNo
WHERE th.ExcludeFromUpload = '0'
  AND (uc.ExcludeFromUpload = '0' OR uc.ExcludeFromUpload IS NULL)
  AND (th.reg <> 0 or th.OT <> 0 or th.DT <> 0 or Dollars <> 0)
UNION ALL
SELECT 
       th.PayrollPeriodEndDate,th.TransDate,
       en.PrimarySite, 
       th.WorkedSite, th.SSN, th.FileNo, th.UploadCode, th.SalUploadCode,
       uc.PayCode_RG, uc.RateCode_RG, th.Reg, 
       uc.PayCode_OT, uc.RateCode_OT, th.OT, 
       uc.PayCode_DT, uc.RateCode_DT, th.DT, 
       uc.ShiftDiffPct,  
       th.Dollars,th.DeptNo, th.AgencyNo, th.ShiftNo, th.ClockAdjustmentNo, th.AdjustmentName
FROM #tmpAdjs AS th
Inner JOIN TimeCurrent..tblEmplNames AS en with (nolock) 
ON en.Client = @Client
  AND en.GroupCode = @GroupCode
  AND en.SSN = th.SSN
LEFT JOIN TimeCurrent..tblDAVT_UploadCodes AS uc  with (nolock)
ON th.ClockAdjustmentNo = uc.State
WHERE th.ExcludeFromUpload = '0'
  AND (uc.ExcludeFromUpload = '0' OR uc.ExcludeFromUpload IS NULL)
-- commented out 08/03/09 DEH - 'X' (XLS import ) not used any more - re-purposed for another code AND th.ClockAdjustmentNo <> 'X'    -- Ignore 'X' adjustments these adjustments are handled differently, see below 
  AND (th.reg <> 0 or th.OT <> 0 or th.DT <> 0 or Dollars <> 0)
ORDER BY th.SSN, th.WorkedSite, th.DeptNo, th.ShiftNo, th.ClockAdjustmentNo

--printltrim(str(@groupCode)) + ' After Adjs/Hours Combine load Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

-- For Puerto Rico ClockadjustmentNo = 'E'
IF @GroupCode = 503900 
BEGIN
  Update #tmpAll
    Set PayCode_RG = 'MAT', 
        PayCode_OT = 'MAT', 
        PayCode_DT = 'MAT'
  where ClockAdjustmentNo = 'E'
END

-- Final Clean up to Convert any PrimarySites to UploadAsSites
-- Convert Rate Codes for Dept 49 to rate code of 'B' for all worked hours.
-- 
-- Worked Site Logic -- Force to costing Codes(LocationID) if the LocationID is different than the primary Site and the worked site is equal to primary site.
--                      Represents a remote employee working at a physical location that is different than the costing location.
--

SELECT 
UR.PayrollPeriodEndDate,
UR.TransDate,
PrimarySite = (CASE WHEN sn.UploadAsSiteNo = 0 or sn.uploadAsSiteNo is NULL 
                       then ur.PrimarySite 
                       else sn.UploadAsSiteNo END),
WorkedSite = case when ur.WorkedSite = en.PrimarySite and en.PrimarySite <> isnull(en.LocationID,en.PrimarySite) then en.LocationID else ur.WorkedSite end, 
WorkedSiteA = '00', 
ur.SSN, ur.FileNo, Company = 'DVT', JobCode = en.PrimaryJObCode, PayGroup = 'DVT', 
UploadCode = case when ur.UploadCode like 'HOME-%' and isnull(gd.ClientDeptCode,'') <> '' then gd.ClientDeptCode else ur.UploadCode end, 
ur.SalUploadCode,
ur.PayCode_RG AS PayCode_Reg, 
RateCode_Reg = (CASE WHEN Ur.DeptNo = 50 and en.PayType = '1' and ur.ClockAdjustmentNo in('!','(','') THEN 'B' ELSE ur.RateCode_Rg END), 
ur.Reg,
ur.PayCode_OT, 
RateCode_OT = (CASE WHEN ur.DeptNo = 50 and en.PayType = '1' and ur.ClockAdjustmentNo in('!','(','') THEN 'B' ELSE ur.RateCode_OT END),
ur.OT, 
ur.PayCode_DT, 
RateCode_DT = (CASE WHEN ur.DeptNo = 50 and en.PayType = '1' and ur.ClockAdjustmentNo in('!','(','') THEN 'B' ELSE ur.RateCode_DT END), 
ur.DT,
ur.ShiftDiffPct, 
ur.Dollars, ur.DeptNo, ur.AgencyNo, ur.ShiftNo, ur.ClockAdjustmentNo, ur.AdjustmentName, AssignmentNo = Upper(en.AssignmentNo),
CASE CAST(ur.AgencyNo AS varchar(1)) WHEN '1' THEN 'X' WHEN '2' THEN 'Z' WHEN '3' THEN 'Y' ELSE 'N' END AS HomeShiftNo,
Replace(en.FirstName, ',', '') as FirstName,
Replace(en.LastName, ',', '') as LastName,
en.PayType,
PrimaryJobCode = en.AssignmentNo 
into #tmpFinal1
FROM #tmpALL as UR
LEFT JOIN timecurrent..tblSiteNames AS sn with (nolock)
ON sn.client = @Client
AND sn.GroupCode not in(999999,999899,500100) --= @GroupCode
AND sn.SiteNo = ur.PrimarySite
Inner JOIN TimeCurrent..tblEmplNames AS en with (nolock)
ON en.Client = @Client
AND en.GroupCode = @GroupCode
AND en.SSN = ur.SSN
Inner Join TimeCurrent..tblGroupDepts as gd with (nolock)
on gd.client = en.client
and gd.groupcode = en.groupcode
and gd.deptno = en.primarydept
--ORDER BY UR.PayrollPeriodEndDate, UR.SSN, ur.WorkedSite, ur.DeptNo, ShiftNo, ClockAdjustmentNo

--printltrim(str(@groupCode)) + ' After Final load Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

-- NO CAL10 or CAL12 for Penalty break and Rest Penalty Codes
Update #tmpFinal1
	Set HomeShiftNo = 'X'
where PayCode_Reg in('NBR','NMR')

-- Force JobCOde based on Financial Class
--

Update #tmpFinal1
  Set #tmpFinal1.JobCode = isnull(x.XRefValue,'XXXX')
from #tmpFinal1
Left Join TimeCurrent.[dbo].[tblClientXRef] as x with(nolock)
on x.Client = @Client 
and x.XRefType = 80
and x.xrefID = right(#tmpFinal1.UploadCode,3) -- Get the financial class from the upload value

--printltrim(str(@groupCode)) + ' After Job Code true up Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

--select * from #tmpFinal  ORDER BY PayrollPeriodEndDate, SSN, WorkedSite, DeptNo, ShiftNo, ClockAdjustmentNo


SELECT 
UR.PayrollPeriodEndDate,
UR.TransDate,
ur.WorkedSite, 
uCode = ur.UploadCode,
PayCode = ur.PayCode_Reg,
Amount = Sum(ur.Reg + ur.Dollars)
into #tmpFinal
FROM #tmpFinal1 as UR
where UR.Reg <> 0.00 OR UR.Dollars <> 0.00
Group By UR.PayrollPeriodEndDate, UR.TransDate, ur.WorkedSite,  ur.UploadCode, ur.PayCode_Reg
UNION ALL
SELECT 
UR.PayrollPeriodEndDate,
UR.TransDate,
ur.WorkedSite, 
uCode = ur.UploadCode,
PayCode = ur.PayCode_OT,
Amount = Sum(ur.OT)
FROM #tmpFinal1 as UR
where UR.OT <> 0.00
Group By UR.PayrollPeriodEndDate, UR.TransDate, ur.WorkedSite, ur.UploadCode, ur.PayCode_OT
UNION ALL
SELECT 
UR.PayrollPeriodEndDate,
UR.TransDate,
ur.WorkedSite, 
uCode = ur.UploadCode,
PayCode = ur.PayCode_DT,
Amount = Sum(ur.DT)
FROM #tmpFinal1 as UR
where UR.DT <> 0.00
Group By UR.PayrollPeriodEndDate, UR.TransDate, ur.WorkedSite,  ur.UploadCode, ur.PayCode_DT

--400-300-62-3111
IF @ManualCheck = 'Y'
BEGIN
  Create Table #tmpSSN
  (
    SSN int
  )
  
  Create table #tmpSites
  (
    SiteNo int
  )
  -- Get the SSNs that have had Manual Check Adjustments made
  --
  Insert into #tmpSSN ( SSN )
  Select Distinct SSN from TimeHistory..tblTimeHistDetail  with (nolock)
  where client = @Client
  and groupcode = @Groupcode and PayrollPeriodenddate = @PPED
  and xAdjHours <> 0
  
  Insert into #tmpSites (SiteNo)
  Select Distinct thd.SiteNo 
  from TimeHistory..tblTimeHistDetail as thd with (nolock)
  Inner Join #tmpSSN on #tmpSSN.SSN = thd.SSN
  where thd.client = @Client
  and thd.groupcode = @Groupcode 
  and thd.PayrollPeriodenddate = @PPED

  select f.*, 
  LineOut = convert(varchar(12),f.TransDate,101) + ',' + 
  ltrim(str(f.WorkedSite)) + ',' + 
  replace(isnull(f.uCode,'????-???-???'), '-', ',') + ',,' + 
  isnull(f.PayCode,'???') + ',' + 
  ltrim(str(f.Amount,9,2))
  from #tmpFinal as f
  Inner Join #tmpSites on #tmpSites.SiteNo = f.WorkedSite
  ORDER BY f.WorkedSite, f.Transdate, f.uCode, f.PayCode
  
  DROP TABLE #tmpSSN
  DROP TABLE #tmpSites
END
ELSE
BEGIN  
  select *, 
  LineOut = convert(varchar(12),TransDate,101) + ',' + 
  ltrim(str(WorkedSite)) + ',' + 
  replace(isnull(uCode,'????-???-???'), '-', ',') + ',,' + 
  isnull(PayCode,'???') + ',' + 
  ltrim(str(Amount,9,2))
  from #tmpFinal ORDER BY WorkedSite, Transdate, uCode, PayCode
END


--printltrim(str(@groupCode)) + ' After last select Elapse Time (secs) = ' + ltrim(str(datediff(second,@StartTime,getdate())))

