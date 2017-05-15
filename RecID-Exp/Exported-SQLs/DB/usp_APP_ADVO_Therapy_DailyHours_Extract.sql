CREATE Procedure [dbo].[usp_APP_ADVO_Therapy_DailyHours_Extract] 
(
	@Client char(4) = 'ADVO',
	@GroupCode int = 0,
	@PPED2 datetime = '1/1/2000'
)
AS


SET NOCOUNT ON

DECLARE @Group int
DECLARE @PPED datetime
DECLARE @StartDate datetime
Set @Startdate = convert(varchar(12), getdate(), 101 )
Set @StartDate = dateadd(day,-15,@StartDate)


Create Table #tmpOut
(
  GroupCode int,
  SSN int,
  HomeFacility varchar(20),
  EmplID varchar(20),
  Dept varchar(20),
  TransDate datetime,
  AdjCode varchar(20),
  Hours numeric(9,2),
  BorrowedFacility varchar(20)
)

DECLARE cGroups CURSOR
READ_ONLY
FOR 
select GroupCode, PayrollPeriodenddate 
from TimeHistory..tblPeriodenddates 
where client = 'ADVO' 
and PayrollPeriodenddate >= @StartDate --dateadd(day, -15, getdate() )
AND groupcode <> 730053

OPEN cGroups

FETCH NEXT FROM cGroups INTO @Group, @PPED
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    --EXEC usp_APP_PRECHECK_Upload @Client, @Group, @PPED, 'N'
    --if @@error <> 0 
    --  return

    SELECT 	thd.Groupcode, thd.ssn,
    	HomeFacility = sn.ClientFacility,
    	en.AssignmentNo,
    	Dept = left(cd.ClientDeptCode,4), -- substring(cd.ClientDeptCode, 1,2) as Dept,
    	cast(ua.ADP_HoursCode as varchar(20) ) as UploadAdjustmentCode,
    	CASE WHEN thd.ClockAdjustmentNo in ('1', '8', '', NULL) then '1'
    			ELSE thd.ClockAdjustmentNo END ClockadjustmentNo,
      AdjCode = thd.ClockAdjustmentNo,
    	thd.Hours,
    	thd.RegHours,
    	thd.OT_Hours,
      thd.RecordID,
      thd.TransDate,
      InDateTime = dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime),
	  BorrowedGroup = thd.CrossoverOtherGroup,
      BorrowedFacility = sn.ClientFacility -- Default it to the home facility
    INTO #advoTemp	
    FROM tblTimeHistDetail thd with (nolock)
    INNER JOIN TimeCurrent..tblEmplNames en with (nolock)
    ON en.client = thd.client
    AND en.groupCode = thd.groupCode
    AND en.ssn = thd.ssn
    --AND en.recordStatus = '1'
    INNER JOIN TimeCurrent..tblSiteNames sn with (nolock)
    ON sn.client = thd.client
    AND sn.groupCode = thd.groupCode
    AND sn.siteNo = thd.siteNo
    --AND sn.recordStatus = '1'
    INNER JOIN TimeCurrent..tblGroupDepts cd with (nolock)
    ON cd.client = thd.client
    AND cd.groupCode = thd.groupCode
    AND cd.deptNo = thd.deptNo
    --AND cd.recordStatus = '1'
    INNER JOIN TimeCurrent..tblAdjCodes ua with (nolock)
    ON ua.client = thd.client
    AND ua.groupCode = thd.groupCode
    AND ua.clockAdjustmentNo = CASE WHEN thd.clockAdjustmentNo IN ('1', '8', '', 'S', NULL) THEN '1'
    				ELSE thd.clockAdjustmentNo END
    --AND ua.recordStatus = '1'
    WHERE thd.client = @client
    AND thd.groupCode = @group
    AND	thd.PayrollPeriodEndDate = @PPED
    AND thd.TransDate >= @StartDate
    --and substring(cd.ClientDeptCode, 1,4) in('6505','6506','6510','7005','7006','7505','7506','7510','8005','8006')
  
	UPDATE #advoTemp
	SET #advoTemp.BorrowedFacility = sn.ClientFacility
	FROM #advoTemp
	INNER Join TimeCurrent..tblSiteNames sn
	ON #advoTemp.BorrowedGroup = sn.GroupCode
	WHERE sn.Client = @Client
    AND isNull(ClientFacility,'') <> ''

 /*   
    Update #advoTemp
      Set #advoTemp.TherapySite = case when isNULL(rc.ReasonCode,'') in('','1') then '--' else rc.ReasonDescription end
    from #advoTemp
    Left Join TimeHistory..tblTimeHistDetail_Reasons as tr1 with (nolock)
    on tr1.Client = @Client
    and tr1.groupcode = @Group
    and tr1.pped = @PPED
    and tr1.ssn = #advoTemp.ssn
    and tr1.AdjustmentRecordID = #advoTemp.RecordID
    Left Join TImeCurrent..tblReasonCodes as rc with (nolock)
    on rc.client = tr1.client
    and rc.groupcode = tr1.groupcode
    and rc.ReasonCodeID = tr1.ReasonCodeID
    where
    #advoTemp.AdjCode <> ''
    
    Update #advoTemp
      Set #advoTemp.TherapySite = case when isNULL(rc.ReasonCode,'') in('','1') then '--' else rc.ReasonDescription end
    from #advoTemp
    Left Join TimeHistory..tblTimeHistDetail_Reasons as tr1 with (nolock)
    on tr1.Client = @Client
    and tr1.groupcode = @Group
    and tr1.pped = @PPED
    and tr1.ssn = #advoTemp.ssn
    and tr1.InPunchDateTime = #advoTemp.InDateTime
    Left Join TImeCurrent..tblReasonCodes as rc with (nolock)
    on rc.client = tr1.client
    and rc.groupcode = tr1.groupcode
    and rc.ReasonCodeID = tr1.ReasonCodeID
    where
    #advoTemp.AdjCode = ''
    
    Update #advoTemp
      Set TherapySite = ClientFacility
    where TherapySite in('--','',' ','  ')
*/

    INSERT INTO #tmpOut
    	SELECT GroupCode, ssn,
    		HomeFacility,
    		AssignmentNo,
    		Dept,
            TransDate,
    		UploadAdjustmentCode,
    		SUM(Hours) Hours,
            BorrowedFacility
    	FROM #advoTemp
    	WHERE ClockAdjustmentNo NOT IN ('1', 'W')
    	GROUP BY groupcode, ssn,
    		HomeFacility,
    		AssignmentNo,
    		Dept,
            TransDate,
    		UploadAdjustmentCode,
            BorrowedFacility
    	HAVING SUM(Hours) <> 0
    
    	UNION ALL
    
    	SELECT 	GroupCode, ssn,
    		HomeFacility,
    		AssignmentNo,
    		Dept,
    		TransDate,
    		UploadAdjustmentCode,
    		SUM(RegHours) Hours,
            BorrowedFacility
    	FROM #advoTemp
    	WHERE ClockAdjustmentNo = '1'
    	GROUP BY groupcode,ssn,
    		HomeFacility,
    		AssignmentNo,
    		Dept,
            TransDate,
      	    UploadAdjustmentCode,
            BorrowedFacility
    	HAVING SUM(RegHours) <> 0
    
    	UNION ALL
    
    	SELECT 	GroupCode, ssn,
    		HomeFacility,
    		AssignmentNo,
    		Dept,
            TransDate,
    		'2' as UploadAdjustmentCode,
    		SUM(OT_Hours) Hours,
            BorrowedFacility
    	FROM #advoTemp
    	WHERE ClockAdjustmentNo = '1'
    	GROUP BY groupcode,ssn,
    		HomeFacility,
    		AssignmentNo,
    		Dept,
    		TransDate,
    		UploadAdjustmentCode,
            BorrowedFacility
    	HAVING SUM(OT_Hours) <> 0

/*    
    	UNION ALL
    
    	SELECT 	GroupCode, ssn,
    		ClientFacility,
    		AssignmentNo,
    		Dept,
    		TransDate,
    		UploadAdjustmentCode,
    		SUM(Dollars) Hours, -- this is dollars actually but using the same column as hours
        TherapySite
    	FROM #advoTemp
    	GROUP BY groupcode,ssn,
    		ClientFacility,
    		AssignmentNo,
    		Dept,
    		TransDate,
    		UploadAdjustmentCode,
        TherapySite
    	HAVING SUM(Dollars) <> 0
  */
  
    drop table #advoTemp    
	END
	FETCH NEXT FROM cGroups INTO @Group, @PPED
END

CLOSE cGroups
DEALLOCATE cGroups

/*
Employee Home Facility number
Employee Number
Job Code
Facility Worked At Number
Date of Work
Hours
Earning Code

    
    insert into #tmpOut(SSN, UploadadjustmentCode, Hours, AssignmentNo, LineOut)
    (    
    SELECT t.ssn, t.UploadAdjustmentCode, t.Hours, ltrim(isnull(str(t.AssignmentNo),'')) as AssignmentNo, 
    	'"' + ltrim(isnull(t.ClientFacility,'')) + '","' + 
      ltrim(isnull(str(t.AssignmentNo),'')) + '","' + 
      ltrim(isnull(t.dept, '')) + ',' + 
    	'"' + ltrim(isnull(t.ClientFacility,'')) + '","' + 
      convert(varchar(8), TraPayrollDate, 1) + '",' + 
      ltrim(isnull(str(t.shiftNo),'')) + ',"' +  
      convert(varchar(8), PayrollDate, 1) + '",' + 
      ltrim(isnull(str(t.UploadAdjustmentCode),'')) + ',' + 
      ltrim(str(t.Hours, 10,2)) + ',"' + 
      TherapySite + '"' as LineOut
    FROM
*/

Update #tmpOut
  Set AdjCode = right('00' + rtrim(ltrim(adjCode)),2)

select *, 
LineOut = 
'"' + HomeFacility + '",' + 
'"' + EmplID + '",' + 
'"' + Dept + '",' + 
'"' + BorrowedFacility + '",' + 
'"' + convert(varchar(12),TransDate,101) + '",' + 
 ltrim(str(Hours,6,2)) + ',' + 
'"' + AdjCode + '"'
from #tmpOut order by EmplID, TransDate

drop table #tmpOut








