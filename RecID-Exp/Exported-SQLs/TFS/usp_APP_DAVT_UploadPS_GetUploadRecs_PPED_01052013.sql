Create PROCEDURE [dbo].[usp_APP_DAVT_UploadPS_GetUploadRecs_PPED_01052013]
(
  @Client     char(4), 
  @GroupCode  int, 
  @PPED       datetime,
	@MasterPPED datetime,
  @Accrual    tinyint = 0
) AS

SET NOCOUNT ON
--*/

DECLARE @Testing    tinyint
SET @Testing = 0

/*
SET @Testing = 1

DECLARE @Client     char(4)
DECLARE @GroupCode  int
DECLARE @PPED       datetime
DECLARE @MasterPPED datetime
DECLARE @Accrual    tinyint

SET @Client = 'DAVT'
SET @GroupCode = 500600
SET @PPED = '4/15/06'
SET @MasterPPED = '4/22/06'
SET @Accrual = 0

DECLARE @SSN        int
DECLARE @SiteNo     int

SET @SiteNo = 320

DROP TABLE #tmpHrs
DROP TABLE #tmpAdjs
DROP TABLE #tmpALL
DROP TABLE #tmpFinal 
*/

--
-- If called with a date other than an actual PPED, process as Accrual
--
DECLARE @CutoffDate  as datetime

SET @CutoffDate = @PPED

IF (SELECT COUNT(*) 
		FROM TimeHistory..tblPeriodEndDates 
  	WHERE Client = @Client 
		AND GroupCode = @GroupCode 
		AND PayrollPeriodEndDate = @PPED) = 0
BEGIN
  SET @Accrual = 1
  SET @CutoffDate = @PPED
  SET @PPED = (	SELECT TOP 1 PayrollPeriodEndDate 
								FROM TimeHistory..tblPeriodEndDates 
								WHERE Client = @Client 
								AND GroupCode = @GroupCode 
								AND PayrollPeriodEndDate >= @CutoffDate 
								ORDER BY PayrollPeriodEndDate ASC)
END

DECLARE @ShiftZeroCount int
DECLARE @CalcBalanceCnt int
DECLARE @SalaryCnt int
DECLARE @SiteStateMissingCnt int 
DECLARE @AllocateSalaryRecs char(1)

--
-- Check to make sure all Sites have a State Code assigned. The State code is important
-- because it drives how the pay codes are associated with each time detail record.
--

SET @SiteStateMissingCnt = 0
IF @Accrual = 0
  SET @SiteStateMissingCnt = (
    SELECT COUNT(*) 
		FROM TimeCurrent..tblSiteNames 
    WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND (SiteState IS NULL OR SiteState = '')
    AND RecordStatus = '1'
  )
  
IF @SiteStateMissingCnt > 0
BEGIN
  RAISERROR ('Site has missing State Code.', 16, 1) 
  RETURN
END

--
-- Check to see if there are any records for this cycle that have 0 shift numbers.
--
IF @Accrual = 0
BEGIN
	SET @ShiftZeroCount = 0
	IF @Accrual = 0
	  SET @ShiftZeroCount = (
	    SELECT COUNT(*) FROM tblTimeHistDetail with (nolock)
	    WHERE Client = @Client
	    AND GroupCode = @GroupCode
	    AND PayrollPeriodEndDate = @PPED
	    AND ShiftNo = 0 
	  )
	ELSE
	  SET @ShiftZeroCount = (
	    SELECT COUNT(*) FROM tblTimeHistDetail with (nolock)
	    WHERE Client = @Client
	    AND GroupCode = @GroupCode
	    AND PayrollPeriodEndDate = @PPED
	    AND ShiftNo = 0 
	    AND Inday IN (1,2,3,4,5,6,7)
	    AND OutDay IN (1,2,3,4,5,6,7)
			AND TransDate <= @CutoffDate
	  )
	
	IF @ShiftZeroCount > 0
	BEGIN
	  RAISERROR ('Employees exists that have a 0(Zero) Shift Number.', 16, 1) 
	  RETURN
	END
END

--
-- Make sure all records got calculated correctly for this cycle.
--
IF @Accrual = 0 
BEGIN
  SELECT GroupCode, PayrollPeriodEndDate, SSN, -- GG
         TotHours = Sum(Hours), -- SUM(CASE WHEN Hours = 0 THEN xAdjHours ELSE Hours END), 
         TotCalcHrs = SUM(RegHours + OT_Hours + DT_Hours)
  INTO #tmpCalcHrs
  FROM TimeHistory..tblTimeHistDetail with (nolock)
  WHERE Client = @Client
  AND GroupCode = @GroupCode
--	AND GroupCode <> 910000   -- TAKE THIS OUT - GG
  AND PayrollPeriodEndDate = @PPED
  GROUP BY GroupCode, PayrollPeriodEndDate, SSN
  ORDER BY GroupCode, PayrollPeriodEndDate, SSN
  
  SET @CalcBalanceCnt = (	SELECT COUNT(*) 
  												FROM #tmpCalcHrs 
  												WHERE TotHours <> TotCalcHrs)
  
  DROP TABLE #tmpCalcHrs
  
  IF @CalcBalanceCnt > 0
  BEGIN
    RAISERROR ('Employees exists that are out of balance between worked and calculated.', 16, 1) 
    RETURN
  END
END

--
-- Make sure salary employees do not have OT or DT.
--
IF @Accrual = 0
BEGIN
  SELECT t.GroupCode, t.PayrollPeriodEndDate, t.SSN,
         TotOTDTHours = Sum(t.OT_Hours + t.DT_Hours) 
  INTO #tmpSalHrs
  FROM TimeHistory..tblTimeHistDetail AS t with (nolock)
  INNER join tblEmplNames AS e
  ON e.client = t.client
  AND e.groupcode = t.groupcode
  AND e.ssn = t.ssn
  AND e.payrollperiodenddate = @PPED
  AND e.paytype = '1'
  WHERE t.Client = @Client
    AND t.groupCode = @GroupCode
    AND t.PayrollperiodEndDate = @PPED
    AND (@Accrual = 0 OR t.TransDate <= @CutoffDate)
  GROUP BY t.GroupCode, t.PayrollPeriodEndDate, t.SSN
  ORDER BY t.groupCode, t.PayrollPeriodEndDate, t.SSN
  
  SET @CalcBalanceCnt = (	SELECT COUNT(*) 
													FROM #tmpSalHrs 
													WHERE TotOTDTHours > 0)
   
  DROP TABLE #tmpSalHrs
  
  IF @CalcBalanceCnt > 0
  BEGIN
    RAISERROR ('Salary Employees exist that have OT/DT.', 16, 1) 
    RETURN
  END
END

--
-- Allocate Salary hours based on tblEmplAllocations if Client/Group is turned on.
-- Need to allocate for each week.
--
/* 1/14/2008 - Salary Allocation not necessary here anymore since its happening real-time with GenNetSalaryRecs

IF @Accrual = 0 AND @Testing = 0 AND @GroupCode NOT IN (500500,501100,500600,502500,501700,502200,500700,501200,501400,502300,502400,500800,501300,501500,501800)
BEGIN
  SELECT @AllocateSalaryRecs = (SELECT AllocateSalaryRecs 
														    FROM TimeCurrent..tblClientGroups 
														    WHERE Client = @Client 
																AND GroupCode = @Groupcode)
  IF @AllocateSalaryRecs = '1'
  BEGIN
    EXEC usp_APP_ReAllocateSalaryHours @Client, @GroupCode, @PPED, @MasterPPED
    IF @@Error <> 0 
    BEGIN
      RAISERROR ('Failed in Re-Allocate Salary Hours', 16, 1) 
      RETURN --@@Error
    END
  END
END
*/
--
-- IF ALCOTT THEN RUN DIFFERENT UPLOAD SCRIPT
--
IF @GroupCode IN (500100)
BEGIN
--  EXEC [TimeHistory].[dbo].[usp_APP_Davita_GetUploadRecs_ALCOTT] @Client, @GroupCode, @PPED
  RAISERROR ('Alcott Groups Do Not Use PeopleSoft Upload', 16, 1) 
  RETURN
END

/*
IF @Accrual = 0
BEGIN
  ---
  -- switch all un-approved Preceptor Bonus transactions to a different Clock adjustment No so they will not get paid 
  -- in the pay file.
  ---
  Update TimeHistory..tblTimeHistdetail 
    Set ClockAdjustmentno = '\'
  where 
  client = @Client 
  and Groupcode = @Groupcode 
  and PayrollPeriodenddate = @PPED
  and isnull(AprvlStatus,'') <> 'A'
  and ClockAdjustmentNo = 'D' and InSrc = '3' and UserCode = 'SYS' and left(AdjustmentName,3) = 'PRE'
END
*/
--

DELETE FROM tblWork_TimeHistDetail WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED

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
  AND thd.PayrollperiodEndDate = @PPED AND (@Accrual = 0 OR thd.TransDate <= @CutoffDate)
  AND IsNull(thd.CrossoverStatus, '') <> '2'
  AND thd.ClockAdjustmentNo IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND thd.Holiday = '0'



-- Fix travel records that don't have an associated OUT PUNCH to IN PUNCH Connection
--
DECLARE @Siteno int
DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
DECLARE @SiteNo2 int
DECLARE @DeptNo int
DECLARE @PrimarySIte int
DECLARE @PrimaryDept int

 DECLARE cTravel CURSOR
  READ_ONLY
  FOR 
  Select t.RecordID, t.SiteNo, NewSiteNo = isnull(thd2.SiteNo,thd4.Siteno), NewDeptNo = isnull(thd2.DeptNo,thd4.deptNo), e.PrimarySite, e.PrimaryDept
  from Timehistory..tblWork_TimeHistDetail as t with (nolock)
  inner Join TimeCurrent..tblEmplnames as e
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
        AND dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime) = dbo.PunchDateTime2(thd3.TransDate, thd3.InDay, thd3.InTime)
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
  AND t.AprvlStatus <> '2'        -- Skip any records that were copied to the employees primary group
																		-- AprvlStatus is correct in this case since its selecting from the work table
  AND t.ClockAdjustmentNo IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND e.AgencyNo < 5    -- Do not include Contract Labor
  and t.DeptNo = 88
  and isnull(thd2.siteno,0) = 0  -- does not have a match on the connecting IN Punch

  OPEN cTravel
  
  FETCH NEXT FROM cTravel INTO @RecordID, @SiteNo, @SIteNo2, @DeptNo, @PrimarySite, @PrimaryDept
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
      Update TimeHistory..tblWork_TimeHistDetail 
        Set SiteNo = isnull(@SIteNo2,@PrimarySite),
          DeptNo = isnull(@DeptNo,@PrimaryDept) 
      where RecordID = @RecordID
  	END
  	FETCH NEXT FROM cTravel INTO @RecordID, @SiteNo, @SIteNo2, @DeptNo, @PrimarySite, @PrimaryDept
  END
  
  CLOSE cTravel
  DEALLOCATE cTravel
  

-- SELECT the all records from timehistdetail that 
--    - do not have an adjustment no.
--    - are not associated with a special holiday pay(overtime days table).
--      or if the employee is a prediem employee (tblEmplNames.SubStatus1 = ' ' )
--
-- Sum the values by Site, DeptNo, ShiftNo, SSN, SiteState(needed for the paycode xref)
--
SELECT 	
        thd.PayrollPeriodEndDate, 
				thd.SSN, 
				IsNull(en.FileNo, '') as FileNo,
				Upper(IsNull(en.AssignmentNo, '')) as Company, 
				IsNull(en.PrimaryJobCode, '') as JobCode, 
				Upper(IsNull(en.PayGroup, '')) as PayGroup,
			  WorkedSite = CASE WHEN isnull(sn.UploadAsSiteNo,0) = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
        CASE WHEN thd.DeptNo = 88 THEN ISNULL(thd2.DeptNo, en.PrimaryDept) 
             WHEN thd.DeptNo between 899 and 989 THEN en.PrimaryDept 
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
--FROM tblTimeHistDetail AS thd
FROM tblWork_TimeHistDetail AS thd  with (nolock)
LEFT JOIN tblWork_TimeHistDetail thd2  with (nolock)
ON thd.DeptNo = 88 
  AND thd2.RecordID = (
    SELECT TOP 1 thd3.RecordID
    FROM tblWork_TimeHistDetail thd3  with (nolock)
    WHERE thd3.DeptNo <> 88
      AND thd.SSN = thd3.SSN
      AND dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) = dbo.PunchDateTime2(thd3.TransDate, thd3.InDay, thd3.InTime)
      AND thd3.Hours > 0
  )
LEFT JOIN TimeCurrent..tblSiteNames AS sn  with (nolock)
  ON  sn.Client = thd.Client
  AND sn.GroupCode not in(999999,999899,500100) --= (CASE WHEN thd.AprvlStatus = 4 then thd.AprvlStatus_UserID else thd.GroupCode end)
  AND sn.SiteNo = thd.SiteNo
LEFT JOIN TimeCurrent..tblEmplNames as en  with (nolock)
  ON  en.Client = thd.Client
  AND en.GroupCode = thd.GroupCode
  AND en.SSN = thd.SSN
LEFT JOIN TimeCurrent..tblGroupDepts AS dxr 
  ON  dxr.Client = thd.Client
  AND dxr.GroupCode = thd.GroupCode
  AND dxr.DeptNo = CASE WHEN thd.DeptNo = 88 THEN ISNULL(thd2.DeptNo, en.PrimaryDept) 
                        WHEN thd.DeptNo between 899 and 989 THEN en.PrimaryDept ELSE thd.DeptNo END
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollperiodEndDate = @PPED AND (@Accrual = 0 OR thd.TransDate <= @CutoffDate)
  AND thd.AprvlStatus <> '2'        -- Skip any records that were copied to the employees primary group
																		-- AprvlStatus is correct in this case since its selecting from the work table
  AND thd.ClockAdjustmentNo IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND thd.Holiday = '0'
  AND en.AgencyNo < 5    -- Do not include Contract Labor
GROUP BY 	
          thd.PayrollPeriodEndDate, 
					thd.SSN, 
					IsNull(en.FileNo, ''),
          Upper(IsNull(en.AssignmentNo, '')),
					IsNull(en.PrimaryJobCode, ''), 
					Upper(IsNull(en.PayGroup, '')),
				  CASE WHEN isnull(sn.UploadAsSiteNo,0) = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
          CASE WHEN thd.DeptNo = 88 THEN ISNULL(thd2.DeptNo, en.PrimaryDept) 
               WHEN thd.DeptNo between 899 and 989 THEN en.PrimaryDept 
               ELSE thd.DeptNo END,
				  en.AgencyNo, 
					thd.ShiftNo,
				  sn.SiteState, 
				  CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
				  dxr.ClientDeptCode,dxr.ClientDeptCode2
ORDER BY 	thd.PayrollPeriodEndDate, 
					thd.SSN, 
					WorkedSite, 
					DeptNo, 
					thd.ShiftNo

DELETE FROM tblWork_TimeHistDetail WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED

--
-- SELECT all records from timehistdetail that are for adjustments only.
-- Sum the values by Site, DeptNo, shift, SSN and ClockAdjustment
--
SELECT 	thd.PayrollPeriodEndDate, 
				thd.SSN, 
				IsNull(en.FileNo, '') as FileNo,
        Upper(IsNull(en.AssignmentNo, '')) as Company,
				IsNull(en.PrimaryJobCode, '') as JobCode, 
				Upper(IsNull(en.PayGroup, '')) as PayGroup,
			  WorkedSite = CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
				DeptNo = (CASE WHEN thd.DeptNo IN(88,899) or thd.DeptNo between 900 and 989 THEN en.PrimaryDept 
				          ELSE case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END ), 
				en.AgencyNo, 
				thd.ShiftNo, 
				thd.ClockAdjustmentNo, 
				thd.AdjustmentName,
				-- For CA Penalty Break ('N') or CA Rest Penalty ('H'), Zero shows on the time card for reporting, but they want it loaded 
				-- as 1 hour on pay file.
				--
				SUM(case when thd.ClockADjustmentNo in('N','H') and thd.RegHours = 0 then 1 else thd.RegHours end) AS Reg, 
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
LEFT JOIN timeCurrent..tblEMplNames as en with (nolock)
  ON  en.Client = thd.Client
  AND en.GroupCode = thd.GroupCode
  AND en.SSN = thd.SSN
LEFT JOIN TimeCurrent..tblGroupDepts AS dxr with (nolock)
ON  dxr.Client = thd.Client
  AND dxr.GroupCode = thd.GroupCode
  AND dxr.DeptNo = (CASE WHEN thd.DeptNo IN(88,899) or thd.DeptNo between 900 and 989 THEN en.PrimaryDept ELSE 
                       case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END )
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollperiodEndDate = @PPED AND (@Accrual = 0 OR thd.TransDate <= @CutoffDate)
  AND IsNull(thd.CrossoverStatus, '') <> '2'        -- Skip any records that were copied to the employees primary group
  AND thd.ClockAdjustmentNo NOT IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND en.AgencyNo < 5    -- Do not include Contract Labor
GROUP BY 	thd.PayrollPeriodEndDate, 
					thd.SSN, 
					IsNull(en.FileNo, ''),
          Upper(IsNull(en.AssignmentNo, '')),
					IsNull(en.PrimaryJobCode, ''), 
					Upper(IsNull(en.PayGroup, '')),
					CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
					--(CASE WHEN thd.DeptNo = 88 or thd.DeptNo between 900 and 989 THEN en.PrimaryDept ELSE thd.DeptNo END), 
				  (CASE WHEN thd.DeptNo in(88,899) or thd.DeptNo between 900 and 989 THEN en.PrimaryDept 
				          ELSE case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END ), 
					en.AgencyNo, 
					thd.ShiftNo, 
					thd.ClockAdjustmentNo, 
					thd.AdjustmentName,
					sn.SiteState, 
					CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
					dxr.ClientDeptCode,dxr.ClientDeptCode2
ORDER BY 	thd.PayrollPeriodEndDate, 
					thd.SSN, 
					WorkedSite, 
					DeptNo, 
					thd.ShiftNo, 
					thd.ClockAdjustmentNo

--
-- SELECT the all records from timehistdetail that are 
-- associated with a special holiday pay(overtime days table).
-- 
-- make these records appear to be a adjustment Type of '!' (shift 1 ) or '(' (shift 9)
-- Sum the values by Site, Deptno, ShiftNo, SSN, SiteState(needed for the paycode xref)
--
INSERT INTO #tmpAdjs
SELECT 	thd.PayrollPeriodEndDate, 
				thd.SSN, 
				IsNull(en.FileNo, '') as FileNo,
        Upper(IsNull(en.AssignmentNo, '')) as Company,
				IsNull(en.PrimaryJobCode, '') as JobCode, 
				Upper(IsNull(en.PayGroup, '')) as PayGroup,
				WorkedSite = CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
				DeptNo = (CASE WHEN thd.DeptNo IN(88,899) or thd.DeptNo between 900 and 989 THEN en.PrimaryDept 
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
LEFT JOIN timeCurrent..tblEMplNames as en with (nolock)
  ON  en.Client = thd.Client
  AND en.GroupCode = thd.GroupCode
  AND en.SSN = thd.SSN
LEFT JOIN TimeCurrent..tblGroupDepts AS dxr 
  ON  dxr.Client = thd.Client
  AND dxr.GroupCode = thd.GroupCode
  AND dxr.DeptNo = (CASE WHEN thd.DeptNo in(88,899) or thd.DeptNo between 900 and 989 THEN en.PrimaryDept ELSE 
                            case when thd.deptno = 100 then thd.jobid else thd.DeptNo end END)
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollperiodEndDate = @PPED AND (@Accrual = 0 OR thd.TransDate <= @CutoffDate)
  AND thd.ClockAdjustmentNo IN('1','8','Q','R','S','M','T','U','V','Z','O','',' ')
  AND IsNull(thd.CrossoverStatus, '') <> '2'        -- Skip any records that were copied to the employees primary group
  AND thd.Holiday = '1'
  AND en.AgencyNo < 5    -- Do not include Contract Labor
GROUP BY 	thd.PayrollPeriodEndDate, 
					thd.SSN, 
					IsNull(en.FileNo, ''),
          Upper(IsNull(en.AssignmentNo, '')),
					IsNull(en.PrimaryJobCode, ''), 
					Upper(IsNull(en.PayGroup, '')),
          CASE WHEN sn.UploadAsSiteNo = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
					--CASE WHEN thd.DeptNo = 88 or thd.DeptNo between 900 and 989 THEN en.PrimaryDept ELSE thd.DeptNo END, 
          CASE WHEN thd.DeptNo in(88,899) or thd.DeptNo between 900 and 989 THEN en.PrimaryDept 
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


--SELECT * FROM #tmpAdjs
--/* GG

IF @Accrual = 1 and @PPED <> @CutoffDate
BEGIN

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
  from Timehistory..tblTimehistDetail as t
  inner Join TimeCurrent..tblEmplnames as e
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
        Inner Join TimeHistory..tblTimeHistDetail as t
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
  
  --select * from #tmpSalHours order by SSN, TransDate, siteNo, Deptno
  
  Insert into #tmpHrs
  SELECT 	
          @PPED,
  				thd.SSN, 
  				IsNull(en.FileNo, '') as FileNo,
  				Upper(IsNull(en.AssignmentNo, '')) as Company, 
  				IsNull(en.PrimaryJobCode, '') as JobCode, 
  				Upper(IsNull(en.PayGroup, '')) as PayGroup,
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
  			  dxr.ClientDeptCode AS UploadCode,dxr.ClientDeptCode2 AS SalUploadCode
  FROM #tmpSalHours AS thd  with (nolock)
  LEFT JOIN TimeCurrent..tblSiteNames AS sn  with (nolock)
    ON  sn.Client = @Client
    AND sn.GroupCode not in(999999,999899,500100) 
    AND sn.SiteNo = thd.SiteNo
  LEFT JOIN TimeCurrent..tblEmplNames as en  with (nolock)
    ON  en.Client = @Client
    AND en.GroupCode = @Groupcode
    AND en.SSN = thd.SSN
  LEFT JOIN TimeCurrent..tblGroupDepts AS dxr 
    ON  dxr.Client = @Client
    AND dxr.GroupCode = @Groupcode
    AND dxr.DeptNo = thd.DeptNo
  WHERE thd.TransDate <= @CutoffDate
    AND en.AgencyNo < 5    -- Do not include Contract Labor
  GROUP BY 	
    				thd.SSN, 
  					IsNull(en.FileNo, ''),
            Upper(IsNull(en.AssignmentNo, '')),
  					IsNull(en.PrimaryJobCode, ''), 
  					Upper(IsNull(en.PayGroup, '')),
  				  CASE WHEN isnull(sn.UploadAsSiteNo,0) = 0 THEN thd.SiteNo ELSE sn.UploadAsSiteNo END,
            thd.DeptNo,
  				  en.AgencyNo, 
  				  sn.SiteState, 
  				  CASE WHEN sn.IncludeInUpload = '1' THEN '0' ELSE '1' END,
  				  dxr.ClientDeptCode,dxr.ClientDeptCode2
END

--select * from #tmpHrs order By SSN
--select * from #tmpADjs order By SSN
--return

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

SELECT th.PayrollPeriodEndDate,
       en.PrimarySite, 
       th.WorkedSite, th.SSN, th.FileNo, th.Company, th.JobCode, th.PayGroup, th.UploadCode, th.SalUploadCode,
       uc.PayCode_RG, uc.RateCode_RG, th.Reg, 
       uc.PayCode_OT, uc.RateCode_OT, th.OT, 
       uc.PayCode_DT, uc.RateCode_DT, th.DT, th.Dollars,th.DeptNo, th.AgencyNo, th.ShiftNo, th.ClockAdjustmentNo, th.AdjustmentName
INTO #tmpALL
FROM #tmpHrs AS th
LEFT JOIN TimeCurrent..tblEmplNames AS en  with (nolock)
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
       th.PayrollPeriodEndDate,
       en.PrimarySite, 
       th.WorkedSite, th.SSN, th.FileNo, th.Company, th.JobCode, th.PayGroup, th.UploadCode, th.SalUploadCode,
       uc.PayCode_RG, uc.RateCode_RG, th.Reg, 
       uc.PayCode_OT, uc.RateCode_OT, th.OT, 
       uc.PayCode_DT, uc.RateCode_DT, th.DT, th.Dollars,th.DeptNo, th.AgencyNo, th.ShiftNo, th.ClockAdjustmentNo, th.AdjustmentName
FROM #tmpAdjs AS th
LEFT JOIN TimeCurrent..tblEmplNames AS en with (nolock) 
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

/*
-- Process the 'X' adjustment records that were created from the XLS import process.
-- These records have the valid pay code in place of the AdjustmentName in the detail transaction.
-- so we can join on the ADjustmentName to get the paycode information from the paycode table.
-- Join on the RG, OT, DT paycode based on the value in the OT, DT, Reg fields.
--
INSERT INTO #tmpALL
SELECT 
       th.PayrollPeriodEndDate,
       en.PrimarySite, 
       th.WorkedSite, th.SSN, th.FileNo, th.Company, th.JobCode, th.PayGroup, th.UploadCode, th.SalUploadCode,
       uc.PayCode_RG, uc.RateCode_RG, th.Reg, 
       uc.PayCode_OT, uc.RateCode_OT, th.OT, 
       uc.PayCode_DT, uc.RateCode_DT, th.DT, th.Dollars,th.DeptNo, th.AgencyNo, th.ShiftNo, th.ClockAdjustmentNo, th.AdjustmentName
FROM #tmpAdjs AS th
LEFT JOIN TimeCurrent..tblEmplNames AS en  with (nolock)
ON en.Client = @Client
  AND en.GroupCode = @GroupCode
  AND en.SSN = th.SSN
LEFT JOIN TimeCurrent..tblDAVT_UploadCodes AS uc with (nolock)
ON
  (CASE WHEN th.DT > 0 THEN uc.PayCode_DT WHEN th.OT > 0 THEN uc.PayCode_OT ELSE uc.PayCode_RG END) = th.AdjustmentName
  AND uc.State = 'X'
WHERE th.ExcludeFromUpload = '0'
  AND (uc.ExcludeFromUpload = '0' OR uc.ExcludeFromUpload IS NULL)
  AND th.ClockAdjustmentNo = 'X'
  AND (th.reg <> 0 or th.OT <> 0 or th.DT <> 0 or Dollars <> 0)
ORDER BY th.SSN, th.WorkedSite, th.DeptNo, th.ShiftNo, th.ClockAdjustmentNo
*/

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

SELECT 
UR.PayrollPeriodEndDate,
@CutoffDate AS ActualEndDate,
PrimarySite = (CASE WHEN sn.UploadAsSiteNo = 0 or sn.uploadAsSiteNo is NULL 
                       then ur.PrimarySite 
                       else sn.UploadAsSiteNo END),
ur.WorkedSite, 
WorkedSiteA = '00', 
ur.SSN, ur.FileNo, Upper(ur.Company) as Company, ur.JobCode, ur.PayGroup, ur.UploadCode, ur.SalUploadCode,
ur.PayCode_RG AS PayCode_Reg, 
RateCode_Reg = (CASE WHEN Ur.DeptNo = 50 and en.PayType = '1' and ur.ClockAdjustmentNo in('!','(','') THEN 'B' ELSE ur.RateCode_Rg END), 
ur.Reg,
ur.PayCode_OT, 
RateCode_OT = (CASE WHEN ur.DeptNo = 50 and en.PayType = '1' and ur.ClockAdjustmentNo in('!','(','') THEN 'B' ELSE ur.RateCode_OT END),
ur.OT, 
ur.PayCode_DT, 
RateCode_DT = (CASE WHEN ur.DeptNo = 50 and en.PayType = '1' and ur.ClockAdjustmentNo in('!','(','') THEN 'B' ELSE ur.RateCode_DT END), 
ur.DT,
ur.Dollars, ur.DeptNo, ur.AgencyNo, ur.ShiftNo, ur.ClockAdjustmentNo, ur.AdjustmentName, AssignmentNo = Upper(en.AssignmentNo),
CASE CAST(ur.AgencyNo AS varchar(1)) WHEN '1' THEN 'X' WHEN '2' THEN 'Z' WHEN '3' THEN 'Y' ELSE 'N' END AS HomeShiftNo,
Replace(en.FirstName, ',', '') as FirstName,
Replace(en.LastName, ',', '') as LastName,
en.PayType
into #tmpFinal
FROM #tmpALL as UR
LEFT JOIN timecurrent..tblSiteNames AS sn with (nolock)
ON sn.client = @Client
AND sn.GroupCode not in(999999,999899,500100) --= @GroupCode
AND sn.SiteNo = ur.PrimarySite
LEFT JOIN TimeCurrent..tblEmplNames AS en with (nolock)
ON en.Client = @Client
AND en.GroupCode = @GroupCode
AND en.SSN = ur.SSN
ORDER BY UR.PayrollPeriodEndDate, UR.SSN, ur.WorkedSite, ur.DeptNo, ShiftNo, ClockAdjustmentNo

-- NO CAL10 or CAL12 for Penalty break and Rest Penalty Codes
Update #tmpFinal
	Set HomeShiftNo = 'X'
where PayCode_Reg in('NBR','NMR')

select * from #tmpFinal 
ORDER BY PayrollPeriodEndDate, SSN, WorkedSite, DeptNo, ShiftNo, ClockAdjustmentNo

