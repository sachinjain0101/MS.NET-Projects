Create PROCEDURE [dbo].[usp_RPTPayCodeSelection_YTD]
(
  @DateFrom DATETIME = null,
  @DateTo DATETIME = null,
  @Date DATETIME = null,
  @Client VARCHAR(8),
  @Group INTEGER,
  @Report VARCHAR(4) = 'MB13',
  @Sites VARCHAR(1024)=null,
  @Dept VARCHAR(512)=null,
  @PyCode VARCHAR(100)=null,
  @Ref1 VARCHAR(255)=null,  -- order by
  @Ref2 VARCHAR(255)=null,  -- ssn
  @Shift VARCHAR(64)=null,
  @Sort1 VARCHAR(10),
  @OrigUserID INT=null,
  @Ref7 VARCHAR(80)=null,  -- Division ID Filter for Davita
  @DOW INTEGER = NULL,
  @ClusterId INTEGER = NULL
)
AS

SET NOCOUNT ON

DECLARE @SQLStr VARCHAR(4000)
DECLARE @SSNs varchar(255)
DECLARE @ParmString VARCHAR(1000)
DECLARE @crlf char(2)
Set @crlf = char(13) + char(10)


DECLARE @TransDate DateTime

SELECT @TransDate = Null

DECLARE @RoleID int

if @Sort1 <> 'DETAIL'
BEGIN
  Set @OrigUserID = isnull(@OrigUserID,0)
  IF @OrigUserID <> 0
  BEGIN
    Set @RoleID = (select RoleID from TimeCurrent..tblUser WITH (NOLOCK) where UserID = @OrigUserID)
  END
  Set @RoleID = isnull(@RoleID,0)
  
  -- Super-User or Payroll -- Then pull all of the groups on report.
  --
  IF @RoleID IN(15,17) OR @OrigUserID = 1209
  BEGIN
  	Set @Group = 0
    SET @ClusterId = 4
  END
END



SET @ParmString = " "
SELECT @SQLStr = "SELECT thd.SSN
				, empls.fileno
				, empls.LastName
				, empls.FirstName
				, vs.StatusDesc
				, empls.SubStatus1
				, PayType = CASE when empls.PayType = '1' then 'Salary' else 'Hourly' end
				, thd.SiteNo
				, sites.SiteName
				, thd.DeptNo
				, depts.DeptName
				, AdjustmentName = adjs.adjustmentName, 
			"

IF @Sort1 = 'DETAIL'
	BEGIN -- detail	
		SELECT @SQLStr = @SQLStr + " thd.TransDate, Hours, Dollars , thd.DivisionId, ApproverName = CONCAT(u.FirstName,' ',u.LastName) 
								   "
	END
ELSE -- summary
	BEGIN
		SELECT @SQLStr = @SQLStr + " TransDate = '1/1/2000'
									, Hours = Sum(Hours)
									, Dollars = Sum(Dollars)
									, DivisionId = 0 
							"
	END

SELECT @SQLStr = @SQLStr + @crlf + " FROM TimeHistory..tblTimeHistDetail as thd WITH (NOLOCK) 
									 INNER JOIN TimeCurrent..tblClientGroups as cg  WITH(NOLOCK) on cg.Client = thd.client and cg.groupcode = thd.groupcode 
									 INNER JOIN TimeCurrent..tblAdjCodes as adjs WITH(NOLOCK) 
											ON thd.ClockAdjustmentNo = adjs.ClockAdjustmentNo 
											AND thd.Client = adjs.Client 
											AND thd.GroupCode = adjs.GroupCode
									 INNER JOIN TimeCurrent..tblEmplNames as empls WITH(NOLOCK) 
											ON thd.Client = empls.Client 
											AND thd.GroupCode = empls.GroupCode 
											AND thd.SSN = empls.SSN
									 INNER JOIN TimeCurrent..tblSiteNames as sites WITH(NOLOCK) 
											ON thd.Client = sites.Client
											AND thd.GroupCode = sites.GroupCode 
											AND thd.SiteNo = sites.SiteNo 
									 INNER JOIN TimeCurrent..tblValidStatusCodes as vs WITH(NOLOCK) 
											ON empls.Status = vs.Status
									 INNER JOIN TimeCurrent..tblDeptNames as depts WITH(NOLOCK)
											ON thd.Client = depts.Client
											AND thd.GroupCode = depts.GroupCode 
											AND thd.SiteNo = depts.SiteNo 
											AND thd.DeptNo = depts.DeptNo "

IF @Sort1 = 'DETAIL'
begin -- detail	
	SELECT @SQLStr = @SQLStr + " LEft OUTER JOIN TimeCurrent..tblUser AS U ON U.Client = thd.Client AND U.UserID = CONVERT(VARCHAR(100), thd.AprvlStatus_UserID) " + @CRLF
end


SELECT @SQLStr = @SQLStr + " WHERE thd.Client = '" + @Client + "' AND thd.GroupCode = " + ltrim(str(@Group)) + @CRLF
SELECT @SQLStr = @SQLStr + " and EXISTS(SELECT ClusterID FROM TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn(thd.groupcode,thd.siteno,thd.deptno,thd.agencyno,thd.ssn,thd.DivisionID,thd.shiftno," + str(@ClusterID) + ")) " + @CRLF


IF @Sites <> 'ALL' and @Sites is not null
begin
	SELECT @SQLStr = @SQLStr + " AND thd.SiteNo IN (" + @Sites + ") "
end

IF @dept <> 'ALL' and @dept is not null
begin
	SELECT @SQLStr = @SQLStr + " AND thd.DeptNo IN (" + @dept + ") "

end

IF @Pycode <> 'ALL' and @Pycode is not null
begin
	SELECT @SQLStr = @SQLStr + " AND thd.ClockAdjustmentNo IN (" + @PyCode +") "
end
ELSE
BEGIN

	IF @Client not in('DAVI','DAVT','HCPA','PARA')
	BEGIN
		SELECT @SQLStr = @SQLStr + " AND thd.ClockAdjustmentNo NOT IN ('1', '8') "
	END
END

SELECT @SQLStr = @SQLStr + " AND thd.TransDate between CONVERT(VARCHAR(4), YEAR(getdate())) + '/01/01' and getdate()
							 AND thd.payrollPeriodEndDate between CONVERT(VARCHAR(4), YEAR(getdate())) + '/01/01' and DATEADD(d, 6, getdate()) "
							


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
IF ISNULL(@Ref7,'') <> ''
BEGIN
  SELECT @SQLStr = @SQLStr + " and TimeCurrent.dbo.fn_InCSV('" + @Ref7 + "',ltrim(str(sites.Division)),1) = 1" + @crlf
END

	
IF @Sort1 = 'SUMMARY'
begin 
	SELECT @SQLStr = @SQLStr + "Group By  thd.SSN, empls.fileno, empls.LastName, empls.FirstName, vs.StatusDesc, empls.SubStatus1, empls.PayType, "

	SELECT @SQLStr = @SQLStr + "thd.SiteNo, sites.SiteName, thd.DeptNo, depts.DeptName, adjs.adjustmentName "
END

IF @Ref1 = 'Employee'
begin
	SELECT @SQLStr = @SQLStr + "ORDER BY empls.LastName, empls.FirstName,  AdjustmentName, thd.SiteNo, thd.DeptNo "
end


ELSE IF @Ref1 = 'Site'
begin

	SELECT @SQLStr = @SQLStr + "ORDER BY thd.SiteNo, empls.LastName, AdjustmentName, empls.FirstName, thd.DeptNo  "
end

ELSE 
BEGIN
	SELECT @SQLStr = @SQLStr + "ORDER BY thd.SiteNo,  thd.DeptNo, empls.LastName, empls.FirstName, AdjustmentName "
END

IF @Sort1 = 'DETAIL'
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
  FOR SELECT GroupCode FROM TimeCurrent..tblClientGroups WITH (NOLOCK) WHERE client = @Client AND recordstatus = '1'
  
  DECLARE @NewGroupCode INT
  DECLARE @NewSQLStr VARCHAR(4000)
  OPEN cGroups
  
  FETCH NEXT FROM cGroups INTO @newGroupCode
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
      SET @NewSQLStr = REPLACE(@SQLStr, 'thd.GroupCode = 0', 'thd.GroupCode = ' + LTRIM(STR(@newgroupCode)))
      INSERT INTO #tmpRptRecs
      EXEC(@NewSQLStr)
  	END
  	FETCH NEXT FROM cGroups INTO @newGroupCode
  END
  
  CLOSE cGroups
  DEALLOCATE cGroups
  
  SELECT * FROM #tmpRptRecs ORDER BY SiteNo, LastName, FirstName

  DROP TABLE #tmpRptRecs

END
ELSE
EXEC(@SQLStr)

  --Print @SQLStr 



GO

