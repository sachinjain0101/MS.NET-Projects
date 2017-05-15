Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_ADVO]
(
  @Client varchar(4),
  @GroupCode  int,
  @PPED   datetime,
	@PAYRATEFLAG 	 varchar(4),
	@EMPIDType    varchar(6),
	@REGPAYCODE		varchar(10),
	@OTPAYCODE		varchar(10),
	@DTPAYCODE		varchar(10),
  @PayrollType  varchar(32),
  @IncludeSalary char(1)
)
AS
SET NOCOUNT ON
--*/

/*
DECLARE  @Client varchar(4)
DECLARE  @GroupCode  int
DECLARE  @PPED   datetime
DECLARE	@PAYRATEFLAG 	 varchar(4)
DECLARE	@EMPIDType    varchar(6)
DECLARE	@REGPAYCODE		varchar(10)
DECLARE	@OTPAYCODE		varchar(10)
DECLARE	@DTPAYCODE		varchar(10)
DECLARE  @PayrollType  varchar(32)
DECLARE  @IncludeSalary char(1)


SET  @Client = 'ADVO'
SET  @GroupCode = 730004
SET  @PPED   = '11/02/05'
SET	@PAYRATEFLAG = 'NONE'
SET	@EMPIDType = 'FileNo'
SET	@REGPAYCODE = '1'
SET	@OTPAYCODE	= '2'
SET	@DTPAYCODE = '3'
SET  @PayrollType = 'Optimus'
SET  @IncludeSalary = '1'
*/

DECLARE @CompanyID varchar(5)
DECLARE @PayrollFreq char(1)
DECLARE @PPED2 datetime
DECLARE @GroupID varchar(2)

Set @PPED2 = @PPED
-- First check to see if this is bi-weekly.
-- 
Set @PayrollFreq = (SELECT PayrollFreq 
										FROM TimeCurrent..tblClientGroups 
										WHERE client = @Client 
										AND GroupCode = @GroupCode)

if @PayrollFreq = 'B' 
BEGIN
  Set @PPED2 = dateadd(day, -7, @PPED)
END

if @PayrollFreq = 'B'
BEGIN
	Exec usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'Y'
	if @@error <> 0 
	   return
END
else
BEGIN
	Exec usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'N'
	if @@error <> 0 
	   return
END

-- =============================================
-- Fix any shiftdiffs that were assigned to adjustments
-- =============================================
DECLARE cRecs CURSOR
READ_ONLY
FOR 
select RecordID, deptno, shiftNo, Hours
from tblTimeHistDetail where client = @Client
and groupcode = @GroupCode
and payrollperiodenddate in(@PPED, @PPED2)
and shiftno > 1
and ClockAdjustmentNo not in('',' ')
--and isnull(ShiftDiffAmt,0) = 0

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 04Aug2016 >--
DECLARE @DeptNo int
DECLARE @ShiftNo int
DECLARE @Hours numeric(9,2)
DECLARE @Rate numeric(9,2)

OPEN cRecs

FETCH NEXT FROM cRecs INTO @recordID, @DeptNo, @ShiftNo, @Hours
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    Set @Rate = (Select DiffRate from TimeCurrent..tblDeptShiftDiffs where client = @Client
                  and groupcode = @GroupCode
                  and Deptno = @DeptNo
                  and ShiftNo = @ShiftNo
                  and RecordStatus = '1')

    IF @Rate is NULL
    BEGIN
      Set @Rate = 0
    END  
    ELSE
    BEGIN
      Update tblTimeHistDetail
        Set ShiftDiffAmt = @Rate
      where RecordID = @RecordID
    END
	END
	FETCH NEXT FROM cRecs INTO @recordID, @DeptNo, @ShiftNo, @Hours
END

CLOSE cRecs
DEALLOCATE cRecs

Set @CompanyID = (Select ADP_CompanyCode from TimeCurrent.dbo.tblClientGroups where client = @Client and GroupCode = @GroupCode)

SELECT 	en.ssn, SUBSTRING(en.LastName + ', ' + en.FirstName, 1, 25) as EmpName, 
	EmployeeID = case when isnull(sn.UploadAsSiteNo,0) = 0 then right('00' + ltrim(str(hd.SiteNo)),2) else right('00' + ltrim(str(sn.UploadAsSiteNo)),2) end
    + ltrim(rtrim(en.AssignmentNo)),
	ltrim(rtrim(case when ac.ADjustmentType = 'D' then ac.ADP_EarningsCode else ac.ADP_HoursCode end)) as EarningsID,
	ac.ClockAdjustmentNo,
  DeptCode = gd.ClientDeptCode,
	DateWorked = hd.Payrollperiodenddate,
	hd.RegHours,
	hd.OT_Hours,
	hd.DT_Hours,
	hd.Hours,
	hd.ShiftNo,
  hd.Dollars,
  ShiftDiffAmt = isnull(hd.ShiftDiffAmt,0.00),
	Holiday = isnull(hd.Holiday, '0')
INTO	#tmpRecs
FROM 	TimeHistory..tblTimeHistDetail as hd
INNER JOIN TimeCurrent..tblEmplNames as en
ON	en.Client = hd.Client
AND	en.GroupCode = hd.GroupCode
AND	en.SSN = hd.SSN
INNER JOIN TimeCurrent..tblGroupDepts as gd
ON	gd.Client = hd.Client
AND	gd.GroupCode = hd.GroupCode
AND	gd.DeptNo = hd.deptNo
INNER JOIN TimeCurrent..tblSiteNames as sn
ON	sn.Client = hd.Client
AND	sn.GroupCode = hd.GroupCode
AND	sn.SiteNo = hd.SiteNo
INNER JOIN TimeCurrent..tblAdjCodes as ac
ON	ac.Client = hd.Client
AND	ac.GroupCode = hd.GroupCode
AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
WHERE	hd.Client = @Client 
AND hd.GroupCode = @GroupCode 
AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)

SELECT 	SSN,EmpName,
				EmployeeID,
				EarningsID,
        DeptCode,
				ShiftNo,
				DateWorked,
				SUM(RegHours + OT_Hours) as Hours
Into #tmpPayrollRecs
FROM 	#tmpRecs
--WHERE Holiday = '0'
GROUP BY ssn,EmpName,
				EmployeeID,
				EarningsID,
        DeptCode,
				ShiftNo,
				DateWorked
HAVING 	 sum(RegHours + OT_Hours) <> 0
UNION ALL
--SELECT 	ssn,EmpName,
--				EmployeeID,
--				@OTPAYCODE  as EarningsID,
--        DeptCode,
--				ShiftNo,
--				DateWorked,
--				SUM(OT_Hours) as Hours
--FROM 	#tmpRecs
----WHERE Holiday = '0'
--GROUP BY ssn,EmpName,
--				EmployeeID,
--        DeptCode,
--				ShiftNo,
--				DateWorked
--HAVING 	 sum(OT_Hours) <> 0
--UNION ALL
SELECT 	ssn,EmpName,
				EmployeeID,
				'19' as EarningsID,
        DeptCode,
				ShiftNo,
				DateWorked,
				SUM( (ShiftDiffAmt * (RegHours + OT_Hours)) ) as Hours
FROM 	#tmpRecs
--WHERE Holiday = '1'
GROUP BY ssn,EmpName,
				EmployeeID,
        DeptCode,
				ShiftNo,
				DateWorked
HAVING sum( (ShiftDiffAmt * (RegHours + OT_Hours)) ) <> 0
UNION ALL
SELECT 	ssn,EmpName,
				EmployeeID,
				EarningsID,
        DeptCode,
				ShiftNo,
				DateWorked,
				SUM(Dollars) as Hours
FROM 	#tmpRecs
--WHERE Holiday = '1'
GROUP BY ssn,EmpName,
				EmployeeID,
				EarningsID,
        DeptCode,
				ShiftNo,
				DateWorked
HAVING sum( Dollars ) <> 0

ORDER BY ssn

Drop Table #tmpRecs


(
  select ssn = 0, EmpName = '', EmployeeID = '1', EarningsID = '', DeptCode = '',Shiftno = 0, DateWorked = '1/1/2000',Hours = 0.00,SortOrder = 0,
  Line1 = cast('#BadgeNumber,#EmployeeID,#CompanyID,#DateWorked,#Amount,#EarningsID,#JobClassID,#ShiftID' as varchar(512) )
  union all
  select SSN, EmpName, EmployeeID = case when len(EmployeeID) = 2 then '' else EmployeeID end, EarningsID, DeptCode, Shiftno, DateWorked, Hours,
  SortOrder = 1,
  Line1 = ',' + case when len(EmployeeID) = 2 then '' else EmployeeID end
  + ',' + @CompanyID + ',' + replace(convert(varchar(10), DateWorked, 101),'/','-') + ',' +
  ltrim(str(Hours,8,2))
  + ',' + EarningsID + ',' + ltrim(DeptCode) + ',' + ltrim(str(ShiftNo)) 
  from #tmpPayrollRecs 
  where Hours <> 0
)
Order by SortOrder, EmployeeID, DateWorked









