Create PROCEDURE [dbo].[usp_RPTPayCodeSelection_Prod]
(
  @DateFrom datetime,
  @DateTo datetime,
  @Date datetime,
  @Client varchar(8),
  @Group integer,
  @Report varchar(4),
  @Sites varchar(1024),
  @Dept varchar(512),
  @PyCode varchar(100),
  @Ref1 varchar(255),  -- order by
  @Ref2 varchar(255),  -- ssn
  @Shift varchar(64),
  @Sort1 varchar(10),
	@OrigUserID int,
	@Ref7 varchar(80),  -- Division ID Filter for Davita
  @DOW integer = null,
  @ClusterId integer = NULL
)
AS


/*Test Data
DECLARE @DateFrom datetime
DECLARE @DateTo datetime
DECLARE @Date datetime
DECLARE @Client varchar(8)
DECLARE @Group integer
DECLARE @Report varchar(4)
DECLARE @Sites varchar(1024)
DECLARE @Dept varchar(512)
DECLARE @PyCode varchar(100)
DECLARE @Ref1 varchar(255)
DECLARE @Ref2 varchar(255)
DECLARE @Ref3 char(1)
DECLARE @Shift varchar(64)
DECLARE @Sort1 varchar(10)
DECLARE @ClusterId integer
DECLARE @DOW integer
DECLARE @OrigUserID int
DECLARE @ref7 VARCHAR(100)
--79671270	CLIENT	HCPA
--79671270	CLUSTERID	4
--79671270	DATE	10/17/2015
--79671270	DEPT	ALL
--79671270	DOW	8
--79671270	GROUP	550050
--79671270	ORIGUSERID	527402
--79671270	PYCODE	ALL
--79671270	REF1	Employee
--79671270	REF2	
--79671270	REPORT	MB07
--79671270	SITES	ALL
--79671270	SORT1	DETAIL
--79671270	SSN	0
--79671270	XMAIL	monika.patel@peoplenet.com
--79671270	XMAILTYPE	EA
SET @DateFrom ='7/12/2015'
SET @DateTo = '7/25/2015'
SET @Date = '10/17/2015'
SET @Client = 'HCPA'
SET @Group = 550050 
SET @Report = 'PCSL'
SET @Sites = 'ALL'
SET @Dept = 'ALL'
SET @PyCode = 'ALL'
SET @Ref1 = 'Employee'
SET @Ref2 = ''
SET @Ref3 = '1'
SET @Shift = 'ALL'
SET @Sort1 = 'Detail'
SET @ClusterId = 4
SET	@OrigUserID = 527402
SET @DOW = 8
*/
--Select * from scheduler..tblJobs_Parms where jobid = 7423372


SET NOCOUNT ON

--IF @Client = 'DAVT' AND @Report = 'PCSD'
--RETURN

DECLARE @SQLStr VARCHAR(4000)
DECLARE @SSNs varchar(255)
DECLARE @ParmString VARCHAR(1000)
DECLARE @crlf char(2)
Set @crlf = char(13) + char(10)

DECLARE @EndDOW integer
DECLARE @TransDate DateTime

SELECT @TransDate = Null

DECLARE @RoleID int

if @Report = 'PCSD' and @Sort1 <> 'DETAIL'
BEGIN
  Set @OrigUserID = isnull(@OrigUserID,0)
  IF @OrigUserID <> 0
  BEGIN
    Set @RoleID = (select RoleID from TimeCurrent..tblUser WITH (NOLOCK) where UserID = @OrigUserID)
  END
  Set @RoleID = isnull(@RoleID,0)
  
  -- Super-User or Payroll -- Then pull all of the groups on report.
  --
  IF @RoleID in(15,17) OR @OrigUserID = 1209
  BEGIN
  	Set @Group = 0
    Set @ClusterId = 4
  END
END

IF @DOW is NOT NULL
Begin
  IF @DOW <> 8
  Begin
    SELECT @EndDOW = DATEPART(weekday, @Date)
    IF @DOW > @EndDOW
      Begin 
        SELECT @EndDOW = @EndDOW + 7
      End
    SELECT @TransDate = DATEADD(day, @DOW - @EndDOW, @Date )
  End
End

SET @ParmString = " "
SELECT @SQLStr = "SELECT thd.SSN, empls.fileno, empls.LastName, empls.FirstName, vs.StatusDesc, empls.SubStatus1, PayType = CASE when empls.PayType = '1' then 'Salary' else 'Hourly' end, "
SELECT @SQLStr = @SQLStr + "thd.SiteNo, sites.SiteName, thd.DeptNo, depts.DeptName, adjs.adjustmentName, "

IF @Sort1 = 'DETAIL'
begin -- detail	
	SELECT @SQLStr = @SQLStr + "thd.TransDate, Hours, Dollars , thd.DivisionId, ApproverName = CONCAT(u.FirstName,' ',u.LastName) "
end
else -- summary
begin
	SELECT @SQLStr = @SQLStr + "TransDate = '1/1/2000', Sum(Hours) as Hours, Sum(Dollars) as Dollars, DivisionID = 0 "
end

IF @Client IN('DAVT','HCPA')
  SELECT @SQLStr = @SQLStr + "FROM TimeHistory..tblTimeHistDetail as thd WITH(NOLOCK)" + @CRLF
ELSE
	IF ((@DateFrom IS NOT NULL AND @DateFrom > DATEADD(dd, -360, GETDATE())) OR (@Date IS NOT NULL AND @Date > DATEADD(dd, -360, GETDATE())))
		SELECT @SQLStr = @SQLStr + @crlf + "FROM TimeHistory..tblTimeHistDetail as thd WITH (NOLOCK) " + @CRLF
	ELSE
	  SELECT @SQLStr = @SQLStr + @crlf + "FROM VTimeHistDetail_all as thd WITH (NOLOCK) " + @CRLF

SELECT @SQLStr = @SQLStr + "INNER JOIN TimeCurrent..tblClientGroups as cg  WITH(NOLOCK) on cg.Client = thd.client and cg.groupcode = thd.groupcode " + @CRLF
SELECT @SQLStr = @SQLStr + "INNER JOIN TimeCurrent..tblAdjCodes as adjs WITH(NOLOCK) "
SELECT @SQLStr = @SQLStr + "ON thd.ClockAdjustmentNo = adjs.ClockAdjustmentNo "
SELECT @SQLStr = @SQLStr + "AND thd.Client = adjs.Client "
SELECT @SQLStr = @SQLStr + "AND thd.GroupCode = adjs.GroupCode " + @CRLF
--SELECT @SQLStr = @SQLStr + "AND adjs.recordStatus = 1 "
SELECT @SQLStr = @SQLStr + "INNER JOIN TimeCurrent..tblEmplNames as empls WITH(NOLOCK) "
SELECT @SQLStr = @SQLStr + "ON thd.Client = empls.Client "
SELECT @SQLStr = @SQLStr + "AND thd.GroupCode = empls.GroupCode "
SELECT @SQLStr = @SQLStr + "AND thd.SSN = empls.SSN " + @CRLF
--SELECT @SQLStr = @SQLStr + "AND empls.recordStatus = 1 "
SELECT @SQLStr = @SQLStr + "INNER JOIN TimeCurrent..tblSiteNames as sites WITH(NOLOCK) "
SELECT @SQLStr = @SQLStr + "ON thd.Client = sites.Client "
SELECT @SQLStr = @SQLStr + "AND thd.GroupCode = sites.GroupCode "
SELECT @SQLStr = @SQLStr + "AND thd.SiteNo = sites.SiteNo " + @CRLF
--SELECT @SQLStr = @SQLStr + "AND sites.recordStatus = 1 "
SELECT @SQLStr = @SQLStr + "INNER JOIN TimeCurrent..tblValidStatusCodes as vs WITH(NOLOCK) "
SELECT @SQLStr = @SQLStr + "ON empls.Status = vs.Status " + @CRLF
SELECT @SQLStr = @SQLStr + "INNER JOIN TimeCurrent..tblDeptNames as depts WITH(NOLOCK) "
SELECT @SQLStr = @SQLStr + "ON thd.Client = depts.Client "
SELECT @SQLStr = @SQLStr + "AND thd.GroupCode = depts.GroupCode "
SELECT @SQLStr = @SQLStr + "AND thd.SiteNo = depts.SiteNo "
SELECT @SQLStr = @SQLStr + "AND thd.DeptNo = depts.DeptNo " + @CRLF
--SELECT @SQLStr = @SQLStr + "AND depts.recordStatus = 1 "

IF @Sort1 = 'DETAIL'
begin -- detail	
	SELECT @SQLStr = @SQLStr + " LEFT OUTER JOIN TimeCurrent..tblUser AS U ON U.UserID = thd.AprvlStatus_UserID " + @CRLF
end


IF ISNULL(@ClusterId, 0) NOT IN (0, 4)
BEGIN
	--if group level cluster exists, don't restrict
	IF NOT Exists(Select 1 from timecurrent.dbo.tblClusterDef WITH (NOLOCK) where ClusterID = @ClusterID and Type = 'G' and Value = @Group and RecordStatus = '1')
		IF Exists(Select 1 from timecurrent.dbo.tblClusterDef WITH (NOLOCK) where ClusterID = @ClusterID and Type != 'C' and GroupCode = @Group and RecordStatus = '1')
			SET @ParmString =  " and EXISTS(SELECT ClusterID FROM TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn(thd.groupcode,thd.siteno,thd.deptno,thd.agencyno,thd.ssn,thd.DivisionID,thd.shiftno," + str(@ClusterID) + ")) " + @CRLF
		ELSE
		-- if site level is the only type, then do inner join rather than going thru fn
		BEGIN
			SET @SQLStr = @SQLStr + "INNER JOIN TimeCurrent.dbo.tblClusterDef Cluster WITH(NOLOCK) ON Cluster.Client = thd.Client "
			SET @SQLStr = @SQLStr + "AND Cluster.GroupCode = thd.GroupCode " 
			SET @SQLStr = @SQLStr + "AND Cluster.SiteNo = thd.SiteNo " 
			SET @SQLStr = @SQLStr + "AND Cluster.ClusterID = " + str(@clusterID) + " " 
			SET @SQLStr = @SQLStr + "AND Cluster.Type = 'C' " 
			SET @SQLStr = @SQLStr + "AND Cluster.RecordStatus = '1' "  + @CRLF

		END
END


SELECT @SQLStr = @SQLStr + "WHERE thd.Client = '" + @Client + "'" + @CRLF
SELECT @SQLStr = @SQLStr + "AND thd.GroupCode = " + ltrim(str(@Group)) + @CRLF
SELECT @SQLStr = @SQLStr + @ParmString


IF @Sites <> 'ALL' and @Sites is not null
begin
	SELECT @SQLStr = @SQLStr + "AND thd.SiteNo IN (" + @Sites + ") "
end

IF @dept <> 'ALL' and @dept is not null
begin
	SELECT @SQLStr = @SQLStr + "AND thd.DeptNo IN (" + @dept + ") "

end

IF @Pycode <> 'ALL' and @Pycode is not null
begin
	SELECT @SQLStr = @SQLStr + "AND thd.ClockAdjustmentNo IN (" + @PyCode +") "
end
else
begin
	-- Davita want to see worked adjustments on the Paycode Selection Report
/*	IF @Client = 'DAVI'
	begin
    SELECT @SQLStr = @SQLStr + "AND thd.ClockAdjustmentNo NOT IN ('8') "
	end
*/
	IF @Client not in('DAVI','DAVT','HCPA','PARA')
	begin
		SELECT @SQLStr = @SQLStr + "AND thd.ClockAdjustmentNo NOT IN ('1', '8') "
	end
end


IF @DateFrom is not null and @DateTo is not null and @TransDate is null
begin
	SELECT @SQLStr = @SQLStr + "AND thd.TransDate >= '" + convert(varchar(20), @DateFrom) + "' "
	SELECT @SQLStr = @SQLStr + "AND thd.TransDate <= '" + convert(varchar(20), @DateTo) + "' "

	SELECT @SQLStr = @SQLStr + "AND thd.payrollPeriodEndDate >= '" + convert(varchar(20), @DateFrom) + "' "
	SELECT @SQLStr = @SQLStr + "AND thd.PayrollPeriodEndDate <= '" + convert(varchar(20), DATEADD(d, 6, @DateTo)) + "' "

end
else
begin
	SELECT @SQLStr = @SQLStr + "AND thd.PayrollPeriodEndDate = '" + convert(varchar(20), @Date) + "' "
end

if @TransDate IS NOT NULL
  Begin
    SELECT @SQLStr = @SQLStr +  " And THD.TransDate = '" +  convert(VARCHAR(12),@TransDate,100) +  "' " 
End

--process SSN#
IF @Ref2 is not null AND @Ref2 <> ''
BEGIN
	
	SELECT @SSNs = REPLACE(@Ref2, '-','')
	
	if Substring(@SSNs, len(@SSNs), 1 ) = ','
	begin
	  Select @SSNs = SUBSTRING(@SSNs, 1, len(@SSNs) - 1 )
	end

	SELECT @SQLStr = @SQLStr + "AND thd.SSN IN (" + @SSNs + ") "
END

-- Filter by Division ID if non-blank
--
IF ISNULL(@Ref7,'') <> '' and @Report = 'PCSD'
BEGIN
  SELECT @SQLStr = @SQLStr + " and TimeCurrent.dbo.fn_InCSV('" + @Ref7 + "',ltrim(str(sites.Division)),1) = 1" + @crlf
END

	
IF @Sort1 = 'SUMMARY'
begin 
	SELECT @SQLStr = @SQLStr + "Group By  thd.SSN, empls.fileno, empls.LastName, empls.FirstName, vs.StatusDesc, empls.SubStatus1, empls.PayType, "

	SELECT @SQLStr = @SQLStr + "thd.SiteNo, sites.SiteName, thd.DeptNo, depts.DeptName, adjs.adjustmentName "
end

IF @Ref1 = 'Employee'
begin
	SELECT @SQLStr = @SQLStr + "ORDER BY empls.LastName, empls.FirstName,  adjs.adjustmentName, thd.SiteNo, thd.DeptNo "
end


else if @Ref1 = 'Site'
begin

	SELECT @SQLStr = @SQLStr + "ORDER BY thd.SiteNo, empls.LastName, adjs.adjustmentName, empls.FirstName, thd.DeptNo  "
end

else 
begin
	SELECT @SQLStr = @SQLStr + "ORDER BY thd.SiteNo,  thd.DeptNo, empls.LastName, empls.FirstName, adjs.adjustmentName "
end

IF @Sort1 = 'DETAIL'
--add transdte to order by
begin 
	SELECT @SQLStr = @SQLStr + ", thd.transdate  "
end

IF @Group = 0
BEGIN
  Create Table #tmpRptRecs
  (
    SSN int,
    fileno varchar(20),
    LastName varchar(80),
    FirstName varchar(80),
    StatusDesc varchar(20),
    SubStatus1 varchar(20),
    PayType varchar(20),
    SiteNo int,
    SiteName varchar(80),
    DeptNo varchar(80),
    DeptName varchar(80),
    adjustmentName varchar(20),
    TransDate datetime,
    Hours numeric(9,2),
    Dollars numeric(9,2),
    DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 01Nov2016 >--
  )

  DECLARE cGroups CURSOR
  READ_ONLY
  FOR select GroupCode from TimeCurrent..tblClientGroups WITH (NOLOCK) where client = @Client and recordstatus = '1'
  
  DECLARE @NewGroupCode int
  DECLARE @NewSQLStr varchar(4000)
  OPEN cGroups
  
  FETCH NEXT FROM cGroups INTO @newGroupCode
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
      set @NewSQLStr = replace(@SQLStr, 'thd.GroupCode = 0', 'thd.GroupCode = ' + ltrim(str(@newgroupCode)))
      INSERT INTO #tmpRptRecs
      EXEC(@NewSQLStr)
  	END
  	FETCH NEXT FROM cGroups INTO @newGroupCode
  END
  
  CLOSE cGroups
  DEALLOCATE cGroups
  
  Select * from #tmpRptRecs order by SiteNo, LastName, FirstName

  Drop table #tmpRptRecs

END
ELSE
EXEC(@SQLStr)

 -- Print @SQLStr 









--GO

--SELECT * FROM Scheduler..tblReports2 WHERE ReportCode ='PCSL'

--SELECT * FROM scheduler..tblJobs_Parms WHERE JobID IN (
--SELECT JobID FROM Scheduler..tblJobs_Parms WHERE jobID IN(
--SELECT DISTINCT JobID FROM Scheduler..tblJobs_Parms WHERE Parm = 'PCSL')
--AND parm ='HCPA')
