SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON
GO

/*
This stored procedure is used to build the information needed for the 
Clock Detail - TimeCard Reports

 @DateFrom = If the user is requesting this report by date range, then this will contain a valid start date, else NULL
 @DateTo = If the user is requesting this report by date range, then this will contain a valid end date, else NULL
 @Date = This is the payroll period end date selected by the user for this report. Start and End date will override this value
 @Client = Client ID used by the report for client level selection(Required)
 @Group = Group ID used for group level selection (Required)
 @Report = Report Code from the system that determine which section of this stored procedure to execute.
 @Sites = A Comma separated lists of sites that will be used in the selection of records
 @Dept = A comma separated lists of departments that will be used in the selection of records
 @Shift = A comma separated lists of shift numbers that will be used in the selection of records
 @Ref1 = "W" only show worked hours, "A" or null - show all hours and adjustments.
 @Ref2 = List of SSNs (comma separated) or 'ALL'
 @Ref3 = Hours Amount to show employees with hours >= amount specified.
 @ClusterID = the cluster ID of the person who requested the report. Used to insure that only valid records are selected.

EXEC TimeHistory.dbo.usp_RPTClockDetailIndiv 
--NULL,NULL,NULL,NULL,'OLST',379,'ITRC','ALL','ALL',NULL,'A','','','S','R','SSN',4,'ALL','Name',''
NULL,NULL,'09/07/2014',NULL,'TYME',382718,'T3ME','ALL','ALL','ALL','A','','','S','R','SSN',4,'ALL',NULL,NULL

EXEC TimeHistory.dbo.usp_RPTClockDetailIndiv 
NULL,NULL,'03/06/2016',NULL,'MPOW',145,'PDIP','ALL','ALL','ALL','A','M7669427','','S','R','EmplId',4,'ALL',NULL,NULL

*/


ALTER PROCEDURE [dbo].[usp_RPTClockDetailIndiv]
(
  @DateFrom datetime,
  @DateTo datetime,
  @Date datetime,
  @MasterPayrollDate datetime,
  @Client varchar(8),
  @Group integer,
  @Report varchar(4),
  @Sites varchar(1024),
  @Dept varchar(2024),
  @Shift varchar(32),
  @Ref1 char(1),
  @Ref2 varchar(2048),
  @Ref3 varchar(7),
  @Ref4 char(1),
  @TimePrecision char(1), -- 'R' = Rounded Hours, 'A' = Actual Hours
  @Filter  varchar(20),
  @ClusterId integer = NULL,
  @Agency varchar(3) = 'ALL',
  @Sort1 VARCHAR(20) = 'Name', -- 'Name' = Sort by Employee Name, 'DeptName' = Sort by Department Name
  @ClientIdList VARCHAR(8000) = ''
) AS


--DECLARE
--@AGENCY varchar (3) = 'ALL', 
--@CLIENT varchar (8) = 'staf', 
--@ClientIdList varchar (8000) = '', 
--@CLUSTERID int = 4,
--@DATE datetime = NULL,--'11/6/2016', 
--@DateFrom datetime = '10/31/2016',
--@DateTo datetime = '11/06/2016',
--@DEPT varchar (2024) = 'ALL', 
--@FILTER varchar (20) = 'SSN', 
--@GROUP int = 791518,
--@MasterPayrollDate datetime = NULL,
--@REF1 char (1) = 'A', 
--@REF2 varchar (2048) = '', 
--@REF3 varchar (7) = '', 
--@REF4 char (1) = 'S', 
--@REPORT varchar (4) = 'T3ME', 
--@SHIFT varchar (32) = 'ALL', 
--@SITES varchar (1024) = 'ALL', 
--@Sort1 varchar (20) = '', 
--@TIMEPRECISION char (1) = 'R'





SET NOCOUNT ON;

DECLARE @SelectString VARCHAR(4000)
DECLARE @FromString VARCHAR(4000)
DECLARE @WhereString VARCHAR(5000)
DECLARE @GroupString VARCHAR(4000)
DECLARE @SSNs varchar(2048)
DECLARE @crlf CHAR(2)
DECLARE @HoursLimit numeric(7,2)
DECLARE @strSQL varchar(3048)
DECLARE @OtherWeek Datetime  --for bi-weekly option
DECLARE @bMissingPunches char(1)
DECLARE @PayrollFreq char(1)
DECLARE @EmplIdColumn varchar(50)
DECLARE @ALLMEDICAL_ALL_GROUPS VARCHAR(1)

IF ((@Date IS NULL AND @DateFrom IS NULL AND @DateTo IS NULL AND @MasterPayrollDate IS NULL) )
BEGIN
    RAISERROR ('Invalid Date Parameters. @Date,@DateFrom,@DateTo and @MasterPayrollDate are NULL. ', 16, 1) ;
    RETURN;
END
 
SET @ClientIdList = ISNULL(@ClientIdList,'')

IF (@REF2 = 'ALLMEDICAL_ALL_GROUPS')
BEGIN
	SELECT @ALLMEDICAL_ALL_GROUPS = '1'
	SELECT @REF2 = ''
END
ELSE
BEGIN
	SELECT @ALLMEDICAL_ALL_GROUPS = '0'
END

-- See what fields will make up the Dept name
-- NOTE: This stored proc assumes the short name for the TimeCurrent..tblGroupdepts table is GD.
--
DECLARE @DeptInfo varchar(180)
DECLARE @DeptStr varchar(180)

EXEC TimeHistory..usp_RPT_GetDeptNameString @Client, @Group, @Report, @DeptInfo OUTPUT, @DeptStr OUTPUT

-- Added to get siteno + sitename like dept above
--
DECLARE @SiteInfo varchar(180)
DECLARE @SiteStr varchar(180)
EXEC [TimeHistory].[dbo].[usp_RPT_GetSiteNameString] @Client, @Group, @Report, @SiteInfo OUTPUT , @SiteStr OUTPUT 


--timecard with signiture is same as PDI1
--IF @Report = 'PDIS'
--	SET @Report = 'PDI1'


if @Ref3 is NULL 
begin
  Select @Ref3 = '00'
end


if @Ref3 = ''
begin
  Select @Ref3 = '00'
end

if @Ref4 is NULL 
begin
  Select @Ref4 = 'S'
end

if @Ref4 = ''
begin
  Select @Ref4 = 'S'
end

Set @bMissingPunches = '0'
if @Ref2 = 'MissingPunches'
BEGIN
  Set @bMissingPunches = '1'
  Set @Ref2 = ''
END

SELECT @HoursLimit = CAST(@Ref3 as numeric(7,2))
IF @Filter = 'SSN'
    BEGIN
        SELECT  @SSNs = REPLACE(@Ref2, '-', '')

        IF SUBSTRING(@SSNs, LEN(@SSNs), 1) = ','
            BEGIN
                SELECT  @SSNs = SUBSTRING(@SSNs, 1, LEN(@SSNs) - 1)
            END
    END
ELSE
    BEGIN
        SET @Ref2 = REPLACE(@Ref2, ',', ''',''')
	   SET @ref2 = REPLACE(@ref2, ' ','')
        SET @SSNs = @Ref2
    END

Select @strSQL = ''

if @HoursLimit > 0.00
begin
  EXEC usp_RPTClockDetailIndiv2 @DateFrom,@DateTo,@Date,@Client,@Group,@Report,@Sites,@Dept,@Shift,@Ref1,@Ref2,@Ref3,@Ref4,@Filter,@ClusterId,@strSQL OUTPUT
 
end

IF @Filter = 'EmplId'
BEGIN
	SET @EmplIdColumn = 'EN.FileNo'
END
ELSE
BEGIN
	SELECT @EmplIdColumn = CASE WHEN IsNull(EmplIDColumn,'') = '' THEN 'EN.FileNo' WHEN EmplIDColumn = 'SSN' THEN '''''' ELSE 'EN.' + EmplIDColumn END + ' EmployeeId'
	FROM TimeCurrent..tblClients WITH (NOLOCK)
	WHERE Client = @Client
END

SELECT @crlf = char(13) + char(10)



DECLARE @IsVMSID_Custom1 CHAR(1)
IF @Client = 'OLST'
	SET @IsVMSID_Custom1 = 'Y';
ELSE
	SET @IsVMSID_Custom1 = 'N';



  DECLARE @PPEDStart DATE
      , @PPEDEnd DATE
      , @TransDateStart DATE
      , @TransDateEnd DATE
      , @DateText VARCHAR(100);

    IF @DateFrom IS NOT NULL -- Date range is passed
        BEGIN
            SELECT  @PPEDStart = MIN(PayrollPeriodEndDate)
                  , @PPEDEnd = MAX(PayrollPeriodEndDate)
            FROM    TimeHistory.dbo.tblPeriodEndDates (NOLOCK)
            WHERE   Client = @Client AND GroupCode = @Group AND PayrollPeriodEndDate BETWEEN DATEADD(DAY, -6, @DateFrom) AND DATEADD(DAY, +6, @DateTo);

            SELECT  @TransDateStart = @DateFrom
                  , @TransDateEnd = @DateTo;

			
        END;

    IF @Date IS NOT NULL -- Date range is NOT passed
        BEGIN
            SELECT  @PPEDStart = @Date
                  , @PPEDEnd = @Date
                  , @TransDateStart = DATEADD(DAY, -6, @Date)
                  , @TransDateEnd = @Date;
        END;


IF @MasterPayrollDate IS NOT NULL 
    BEGIN
    SELECT  @PPEDStart = DATEADD(DAY,-7,@MasterPayrollDate)
                  , @PPEDEnd = @MasterPayrollDate
                  , @TransDateStart = DATEADD(DAY, -13, @MasterPayrollDate)
                  , @TransDateEnd = @MasterPayrollDate;
    end





SELECT @SelectString = "
 ;WITH Breaks AS (
				 SELECT TOP 100 PERCENT THD.PayrollPeriodEndDate,THD.RecordID, THD.SSN
					 , THD.TransDate
					 , THD.TransType
					 , THD.ActualInTime
					 , THD.ActualOutTime
					 , BreakTime = ISNULL(DATEDIFF(MINUTE, THD.ActualOutTime, LEAD(THD.ActualInTime, 1) OVER ( PARTITION BY SSN, THD.TransDate ORDER BY SSN, THD.TransDate, THD.ActualInTime )),0)
				 FROM   TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK )
				 WHERE  THD.Client = '" + @client + "' 
				         AND THD.GroupCode = " + STR(@GROUP) + " 
				         AND THD.PayrollPeriodEndDate >= '" + FORMAT(isnull(@PPEDStart,'1900-01-01'),'yyyy-MM-dd') + "' 
					    AND THD.PayrollPeriodEndDate <= '" + FORMAT(isnull(@PPEDEnd,'1900-01-01'),'yyyy-MM-dd') + "'
					    AND THD.TRANSDATE >= '" + FORMAT(@TransDateStart,'yyyy-MM-dd') + "' 
					    AND THD.TRANSDATE <= '" + FORMAT(@TransDateEnd,'yyyy-MM-dd') + "'

					   AND THD.Hours <> 0 
				 ORDER BY THD.SSN
					 , THD.TransDate
					 , THD.ActualInTime
			  )

SELECT EN.PrimaryDept, THD.PayrollPeriodEndDate as PPED, EN.SSN," + @EmplIdColumn + ",EN.LastName, " + @crlf




IF @Report IN('PDI6','PDIH')
 BEGIN
  SELECT @SelectString = @SelectString +  "EN.FirstName, EN.FileNo, PrimaryJobCode = CASE WHEN ISNULL(EN.PrimaryJObCode, '') = '' THEN ISNULL(EN.EmpTitle,'') ELSE EN.PrimaryJobCode END, THD.ShiftNo,THD.ShiftDiffClass, " + @crlf
  IF @Report = 'PDIH'
    SELECT @SelectString = @SelectString +  "sn.PayrollUploadCode, en.Substatus6,"
 END
ELSE
 BEGIN
  SELECT @SelectString = @SelectString +  "EN.FirstName, EN.FileNo, EN.PrimaryJobCode, THD.ShiftNo,THD.ShiftDiffClass," + @crlf
 END

IF @Report IN ('PDI6','PDID','VMS2','STDH','PDIH')
BEGIN
  SELECT @SelectString = @SelectString +  "GD.DeptName, GD.DeptNo," + @crlf
END
ELSE
BEGIN
  SELECT @SelectString = @SelectString +  @DeptStr + " as DeptName, DeptNo = ''," + @crlf
END

SELECT @SelectString = @SelectString + @SiteStr + " as SiteAlias, " + @crlf

SELECT @SelectString = @SelectString +  "THD.TransDate, " + @crlf 
SELECT @SelectString = @SelectString +  "SrcAbrev1 = (CASE WHEN THD.InSrc = '3' AND THD.UserCode + '' <> '' Then THD.UserCode ELSE InSrc.SrcAbrev END), " + @crlf
--SELECT @SelectString = @SelectString +  "InDay = CASE WHEN THD.InDay > 7 OR THD.InDay = 7 THEN '0' ELSE THD.InDay END, " + @crlf
SELECT @SelectString = @SelectString +  "ActualInPunch = dbo.PunchDateTime(thd.transDate, thd.InDay, thd.InTime), " + @crlf
SELECT @SelectString = @SelectString +  "InDay, " + @crlf
SELECT @SelectString = @SelectString +  "InDayName = NDAY.DayAbrev," + @crlf
IF @TimePrecision = 'A'
BEGIN 
  SELECT @SelectString = @SelectString +  "InTime = CASE WHEN THD.InDay = 10 OR (THD.ActualInTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo <> '') THEN NULL ELSE convert(varchar(8),IsNull(THD.ActualInTime,THD.InTime),108) END, " + @crlf
END
ELSE
BEGIN
  SELECT @SelectString = @SelectString +  "InTime = CASE WHEN THD.InDay = 10 OR (THD.InTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo <> '') THEN NULL ELSE THD.InTime END, " + @crlf
END
--SELECT @SelectString = @SelectString +  "InTime = CASE WHEN THD.InDay = 10 OR THD.InDay = 0 OR THD.ClockAdjustmentNo <> '' THEN NULL ELSE THD.InTime END, " + @crlf
SELECT @SelectString = @SelectString +  "SrcAbrev2 = (CASE WHEN THD.OutSrc = '3' AND THD.outUserCode + '' <> '' Then THD.outUserCode ELSE OutSrc.SrcAbrev END), " + @crlf
SELECT @SelectString = @SelectString +  "OutDay = CASE WHEN THD.OutDay = 10 THEN '0' ELSE THD.OutDay END, " + @crlf
SELECT @SelectString = @SelectString +  "OutDayName = ODAY.DayAbrev," + @crlf
IF @TimePrecision = 'A'
BEGIN 
  SELECT @SelectString = @SelectString +  "OutTime = CASE WHEN THD.OutDay = 10 OR (THD.ActualOutTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo <> '') THEN NULL ELSE convert(varchar(8),IsNull(THD.ActualOutTime,THD.OutTime),108) END, " + @crlf
END
ELSE
BEGIN
  SELECT @SelectString = @SelectString +  "OutTime = CASE WHEN THD.OutDay = 10 OR (THD.OutTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo > '') THEN NULL ELSE THD.OutTime END, " + @crlf
END
SELECT @SelectString = @SelectString +  "ActualInTime = CASE WHEN THD.InDay = 10 OR (THD.ActualInTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo <> '') THEN NULL ELSE THD.ActualInTime END, " + @crlf
SELECT @SelectString = @SelectString +  "ActualOutTime = CASE WHEN THD.OutDay = 10 OR (THD.ActualOutTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo > '') THEN NULL ELSE THD.ActualOutTime END, " + @crlf
--SELECT @SelectString = @SelectString +  "OutTime = CASE WHEN THD.OutDay = 10 OR THD.OutDay = 0 OR THD.ClockAdjustmentNo <> '' THEN NULL ELSE THD.OutTime END, " + @crlf
SELECT @SelectString = @SelectString +  "AdjustmentName = Thd.ClockAdjustmentNo + ' ' + THD.AdjustmentName,THD.Dollars, THD.Hours, THD.SiteNo, " + @crlf
IF @Report IN ('PDI6','PDID','VMS2','PDIH')
BEGIN
  SELECT @SelectString = @SelectString +  "MappedTo = right('0000' + ltrim(str(case when isnull(sn.UploadAsSiteNo,0) = 0 then thd.Siteno else sn.UploadAsSiteNo end)), 4),"
  IF @Client IN('DAVT','ELWO')
  BEGIN
    SELECT @SelectString = @SelectString +  "THD.InSiteNo, THD.OutSiteNo, "
  END
  ELSE
  BEGIN
    SELECT @SelectString = @SelectString +  "InSiteNo = '', OutSiteNo = '', "
  END
END

IF @Report = 'PDIJ'
BEGIN
  SELECT @SelectString = @SelectString + "RegHours = CASE WHEN ac.ReportCol = 'H' THEN 0 ELSE THD.RegHours END," + @crlf
  SELECT @SelectString = @SelectString + "OT_Hours = CASE WHEN ac.ReportCol = 'H' THEN 0 ELSE THD.OT_Hours END," + @crlf
  SELECT @SelectString = @SelectString + "DT_Hours = CASE WHEN ac.ReportCol = 'H' THEN 0 ELSE THD.DT_Hours END," + @crlf
  SELECT @SelectString = @SelectString + "PTOHours = CASE WHEN ac.ReportCol = 'H' THEN THD.Hours else 0.00 END," + @crlf
END
ELSE
BEGIN
  SELECT @SelectString = @SelectString +  "THD.RegHours, THD.OT_Hours, THD.DT_Hours, " + @crlf
END
SELECT @SelectString = @SelectString +  "ARegHours = THD.AllocatedRegHours, AOT_Hours = THD.AllocatedOT_Hours, ADT_Hours = THD.AllocatedDT_Hours, " + @crlf
SELECT @SelectString = @SelectString +  "THD.PayRate, THD.BillOTRate, PayAmount = THD.RegDollars4 + THD.OT_Dollars4 + THD.DT_Dollars4" + @crlf

--Special case for Davita where they need a cost id with the individual time card
if @Report = 'PDIC'
begin
	SELECT @SelectString = @SelectString +  " , CostID = case when THD.CostID = '' or thd.costid is null then '0' else ltrim(rtrim(thd.costid)) end " + @crlf
END

SELECT @SelectString = @SelectString + ", reasons.ReasonCodeID " + @crlf

SELECT @SelectString = @SelectString +  ", CASE WHEN BackupApproval.RecordId IS NOT NULL THEN BackupApproval.FirstName + ' ' + BackupApproval.LastName " + @crlf
SELECT @SelectString = @SelectString +  "       WHEN ISNull(cg.StaffingSetupType, '0') <> '0' THEN isnull(tblUser.Email, '') ELSE tblUser.FirstName + ' ' + tblUser.LastName END as ApproverName " + @crlf
SELECT @SelectString = @SelectString + ", CASE WHEN thd.AprvlStatus IN ('A','L') THEN 'Approved' ELSE '' END as ApprovalStatus " + @crlf
SELECT @SelectString = @SelectString + ", AprvlStatus_Date " + @crlf

IF @Report = 'T3ME'
 BEGIN
	 SELECT @SelectString = @SelectString +  ",Lunch_Mins = B.Breaktime" + @crlf
 END

IF @Report = 'VMS2'
	BEGIN
		IF @IsVMSID_Custom1 =  'Y'
			SELECT @SelectString = @SelectString +  ", VMSID = tcEND.Custom1 " + @crlf
		ELSE
			SELECT @SelectString = @SelectString +  ", VMSID = tcEND.VMS_ID " + @crlf
	END

SELECT @FromString =  " 
				FROM tblTimeHistDetail AS THD WITH(NOLOCK) 
				left outer join breaks b on b.recordid = thd.recordID " + @crlf
if @strSQL <> '' 
begin
  SELECT @FromString =  @FromString + "INNER JOIN #tmpSSNs as TS WITH (NOLOCK) ON ts.SSN = THD.SSN " + @crlf
END
SELECT @FromString = @FromString + "INNER JOIN TimeCurrent..tblClientGroups cg  WITH(NOLOCK) " + @crlf
SELECT @FromString = @FromString + "ON cg.Client = thd.Client " + @crlf

IF (@Client IN ('AMED', 'LOCU') AND @ALLMEDICAL_ALL_GROUPS = '1')
BEGIN
	SELECT @FromString = @FromString + "AND cg.GroupCode <> 100 " + " " + @crlf
END
ELSE
BEGIN
  IF @ClientIdList = ''
  BEGIN
		SELECT @FromString = @FromString + "AND cg.GroupCode = " + str(@Group) + " " + @crlf
  END
END

SELECT @FromString = @FromString + "Left JOIN TimeCurrent..tblEmplNames as EN WITH (INDEX(ssn_key), NOLOCK) ON " + @crlf
SELECT @FromString = @FromString + " THD.Client = EN.Client AND THD.GroupCode = EN.GroupCode " + @crlf
SELECT @FromString = @FromString + " AND THD.SSN = EN.SSN " + @crlf
SELECT @FromString = @FromString + "LEFT JOIN TimeCurrent..tblGroupDepts as GD  WITH(NOLOCK) ON " + @crlf
SELECT @FromString = @FromString + " THD.Client = GD.Client AND THD.GroupCode = GD.GroupCode " + @crlf
SELECT @FromString = @FromString + " AND THD.DeptNo = GD.DeptNo " + @crlf
SELECT @FromString = @FromString + "LEFT JOIN TimeCurrent..tblInOutSrc AS OutSrc  WITH(NOLOCK) ON " + @crlf
SELECT @FromString = @FromString + " THD.OutSrc = OutSrc.Src " + @crlf
SELECT @FromString = @FromString + "LEFT JOIN TimeCurrent..tblInOutSrc AS InSrc  WITH(NOLOCK) ON " + @crlf
SELECT @FromString = @FromString + " THD.InSrc = InSrc.Src " + @crlf
SELECT @FromString = @FromString + "LEFT JOIN TimeCurrent..tblDayDef AS NDAY  WITH(NOLOCK) ON " + @crlf
SELECT @FromString = @FromString + " THD.InDay = NDAY.DayNo " + @crlf
SELECT @FromString = @FromString + "LEFT JOIN TimeCurrent..tblDayDef AS ODAY  WITH(NOLOCK) ON " + @crlf
SELECT @FromString = @FromString + " THD.OutDay = ODAY.DayNo " + @crlf
SELECT @FromString = @FromString + " LEFT JOIN TimeCurrent..tblAdjCodes AS AC  WITH(NOLOCK) ON" + @crlf
SELECT @FromString = @FromString + " THD.Client = AC.Client AND THD.GroupCode = AC.GroupCode " + @crlf
SELECT @FromString = @FromString + " AND THD.ClockAdjustmentNo = AC.ClockAdjustmentNo " + @crlf
SELECT @FromString = @FromString + " LEFT JOIN tblTimeHistDetail_Reasons AS reasons  WITH(NOLOCK) " + @crlf 
SELECT @FromString = @FromString + " ON reasons.Client = thd.Client " + @crlf 
SELECT @FromString = @FromString + " AND reasons.GroupCode = thd.GroupCode " + @crlf 
SELECT @FromString = @FromString + " AND reasons.SSN = thd.SSN " + @crlf 
SELECT @FromString = @FromString + " AND reasons.PPED = thd.PayrollPeriodEndDate " + @crlf 
SELECT @FromString = @FromString + " AND ((InTime IS NULL AND reasons.AdjustmentRecordID = thd.RecordID) OR (NOT (InTime IS NULL) AND reasons.AdjustmentRecordID = 0 AND reasons.InPunchDateTime = dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime))) " + @crlf 
SELECT @FromString = @FromString + " LEFT JOIN TimeCurrent..tblSiteNames as SN WITH(NOLOCK) " + @crlf 
SELECT @FromString = @FromString + " ON SN.Client = thd.Client " + @crlf 
SELECT @FromString = @FromString + " AND SN.GroupCode = thd.GroupCode " + @crlf 
SELECT @FromString = @FromString + " AND SN.SiteNo = thd.SiteNo " + @crlf 

SELECT @FromString =  @FromString + " Left Join TimeCurrent..tblUser as tblUser  WITH(NOLOCK) ON " + @crlf
SELECT @FromString =  @FromString + " tblUser.UserID = THD.AprvlStatus_UserID " + @crlf

SELECT @FromString =  @FromString + " Left Join TimeHistory..tblTimeHistDetail_BackupApproval as BackupApproval  WITH(NOLOCK, INDEX(ix_thdBackupApproval_thdRecid)) ON " + @crlf
SELECT @FromString =  @FromString + " BackupApproval.THDRecordId = THD.RecordId " + @crlf

if @bMissingPunches = '1'
BEGIN
  SELECT @FromString = @FromString + " LEFT JOIN TimeHistory..tblEmplNames as hen  WITH(NOLOCK) on hen.client = THD.Client and hen.groupcode = THD.Groupcode and hen.payrollperiodenddate = THD.Payrollperiodenddate and hen.ssn = thd.ssn " + @crlf 
END
SELECT @FromString = @FromString + " LEFT JOIN TimeCurrent..tblReasonCodes AS reasoncodes  WITH(NOLOCK) " + @crlf 
SELECT @FromString = @FromString + " ON reasoncodes.Client = reasons.Client " + @crlf 
SELECT @FromString = @FromString + " AND reasoncodes.GroupCode = reasons.GroupCode " + @crlf 
SELECT @FromString = @FromString + " AND reasoncodes.ReasonCodeID = reasons.ReasonCodeID " + @crlf 

IF @ClientIdList <> ''
BEGIN
	SELECT @FromString = @FromString + " INNER JOIN TimeCurrent..tblEmplAssignments AS ea  WITH(NOLOCK) " + @crlf 
	SELECT @FromString = @FromString + " ON ea.Client = THD.Client " + @crlf 
	SELECT @FromString = @FromString + " AND ea.GroupCode = THD.GroupCode " + @crlf 
	SELECT @FromString = @FromString + " AND ea.SSN = THD.SSN " + @crlf 	
	SELECT @FromString = @FromString + " AND ea.SiteNo = THD.SiteNo " + @crlf 	
	SELECT @FromString = @FromString + " AND ea.DeptNo = THD.DeptNo " + @crlf 	
END

IF @Report = 'VMS2'
BEGIN
  SELECT @FromString =  @FromString + "LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS tcEND WITH (NOLOCK) ON" + @crlf
  SELECT @FromString =  @FromString + " tcEND.Client = THD.Client " + @crlf
  SELECT @FromString =  @FromString + " AND tcEND.GroupCode = THD.GroupCode " + @crlf
  SELECT @FromString =  @FromString + " AND tcEND.SSN = THD.SSN " + @crlf
  SELECT @FromString =  @FromString + " AND tcEND.Department = THD.DeptNo " + @crlf
END

SELECT @WhereString = "Where "
SELECT @WhereString = @WhereString +  " THD.Client = '" + @Client + "' " + @crlf
SELECT @WhereString = @WhereString +  " AND THD.GroupCode = cg.GroupCode " + " " + @crlf


if @Agency <> 'ALL'
	Begin
		SELECT @WhereString = @WhereString + "And THD.AgencyNo = '" + @Agency + "' "
	End


if @SSNs <> '' and @SSNs <> 'ALL'
BEGIN
  IF @Filter = 'EmplID'
  BEGIN
--    SET @EmplIDColumn = (SELECT TOP 1 EmplIDColumn FROM TimeCurrent..tblClients  WITH(NOLOCK) WHERE Client = @Client)
--    IF ISNULL(@EmplIDColumn, '') = '' SET @EmplIDColumn = 'FileNo'
   
    SELECT @WhereString = @WhereString +  " And " + @EmplIDColumn + " IN ('" + @SSNs + "') " + @crlf
  END
  ELSE 
	BEGIN
		IF @Filter = 'Supervisor'
		BEGIN
			IF @Client in('DAVI','GAMB','GPRO','DAVT')
			BEGIN
				SELECT @WhereString = @WhereString +  " And EN.DivisionID IN (" + @SSNs + ") " + @crlf
			END
			IF @Client NOT IN ('DAVI','GAMB','GPRO','DAVT')
			BEGIN
				SELECT @WhereString = @WhereString +  
						" AND CASE WHEN BackupApproval.RecordId IS NOT NULL THEN BackupApproval.FirstName + ' ' + BackupApproval.LastName 
						WHEN ISNull(cg.StaffingSetupType, '0') <> '0' THEN isnull(tblUser.Email, '') ELSE tblUser.FirstName + ' ' + tblUser.LastName END IN (" + @SSNs + ") " + @crlf
			END
		END
		ELSE
  	BEGIN
		SELECT @WhereString = @WhereString +  "AND TimeCurrent.dbo.fn_InCSV('" + @SSNs + "', THD.SSN, 1) = 1" + @crlf
  	END
	END
END

IF @MasterPayrollDate IS NOT NULL
BEGIN
  SELECT @PayrollFreq = PayrollFreq
  FROM TimeCurrent..tblClientGroups
  WHERE Client = @Client
  AND GroupCode = @Group
  IF @PayrollFreq = 'S'
  BEGIN
    SET @DateFrom = DateAdd(dd,1,dbo.fn_getLastMasterPayrollDate_SM(@Client,@Group,@MasterPayrollDate))
    SET @DateTo = @MasterPayrollDate
  END 
END

IF @DateFrom IS NOT NULL and @DateTo is Not NULL 
  Begin
    SELECT @WhereString = @WhereString + " AND THD.PayrollPeriodEndDate >= '" + FORMAT(@DateFrom,'yyyy-MM-dd')  + "' 
								   AND THD.PayrollPeriodEndDate <= '" + FORMAT(dateadd(day, 7, @DateTo),'yyyy-MM-dd')  + "' 
                                           AND THD.TransDate >= '" + FORMAT(@DateFrom,'yyyy-MM-dd')  + "'
                                           AND THD.TransDate <= '" + FORMAT(@Dateto,'yyyy-MM-dd')  + "'"  + @crlf

  End
Else
  Begin
/*		IF @Report = 'PDIB'
			SELECT @WhereString = @WhereString + " AND THD.PayrollPeriodEndDate IN ('" + convert(varchar(20),@Date) +"','" + convert(varchar(20),@OtherWeek) +"')" + @crlf
		ELSE
		  BEGIN*/
	    IF @MasterPayrollDate IS NOT NULL
        SELECT @WhereString = @WhereString + " AND THD.PayrollPeriodEndDate in (SELECT PayrollPeriodEndDate FROM tblPeriodEndDates WITH(NOLOCK) WHERE Client='" + @Client + "' AND GroupCode = " + str(@Group) + " AND MasterPayrollDate = '" + FORMAT(@MasterPayrollDate,'yyyy-MM-dd') + "')" + @crlf
	    ELSE	  
      	SELECT @WhereString = @WhereString + " AND THD.PayrollPeriodEndDate = '" + FORMAT(@Date,'yyyy-MM-dd') + "'" + @crlf
    	END
--  End

IF @Sites <> 'ALL'
BEGIN
	SELECT @WhereString = @WhereString +  "AND THD.SiteNo IN(" + @Sites +  ") " + @crlf
END
IF @Dept <> 'ALL'
BEGIN
	if @Report = 'PDIB'
		SELECT @WhereString = @WhereString +  "AND EN.PrimaryDept IN(" + @Dept + ") " + @crlf
	else
		SELECT @WhereString = @WhereString +  "AND THD.DeptNo IN(" + @Dept + ") " + @crlf
END
IF @Shift <> 'ALL'
BEGIN
	SELECT @WhereString = @WhereString +  "AND THD.ShiftNo IN(" + @Shift + ") " + @crlf
END
IF @Ref1 = 'W' 
Begin
  SELECT @WhereString = @WhereString +  " AND (AC.Worked is NULL or AC.Worked = 'Y') " + @crlf
End
IF @Client = 'LTA'
Begin
  SELECT @WhereString = @WhereString +  " AND isnull(AC.SpecialHandling,'') <> 'EXCL' " + @crlf
End
if @bMissingPunches = '1'
BEGIN
  SELECT @WhereString = @WhereString +  " AND hen.missingpunch in('1','2') " + @crlf
END

IF @Report IN ('PDIS','T3ME')
BEGIN
  SELECT @WhereString = @WhereString +  " AND thd.hours != 0.00 " + @crlf
END


IF (@ALLMEDICAL_ALL_GROUPS = '1')
BEGIN
	SELECT @WhereString = @WhereString +  " AND tblUser.Email like '%@allmedstaffing.com%' " + @crlf	
END

IF @ClientIdList <> ''
BEGIN
SELECT @WhereString = @WhereString +  " AND ea.ClientId IN (SELECT item FROM timehistory..fn_List2Table('" + @ClientIdList +"', ',')) " + @crlf	
END

IF @Report = 'PDIB'
  BEGIN
      SELECT @GroupString = " ORDER BY EN.PrimaryDept, EN.LastName, EN.FirstName,THD.SSN, THD.PayrollPeriodEndDate,THD.TransDate, THD.ClockAdjustmentNo, ActualInPunch, THD.InDay,THD.InTime,THD.OutTime " + @crlf
  END
ELSE IF @Report = 'PDI0' or @Report = 'PDI5'
  BEGIN
    SELECT @GroupString = " ORDER BY EN.LastName, EN.FirstName,THD.SSN, EN.PrimaryDept,THD.PayrollPeriodEndDate,THD.TransDate, THD.ClockAdjustmentNo, ActualInPunch, THD.InDay,THD.InTime,THD.OutTime " + @crlf
  END
ELSE IF @Report = '2016'
  BEGIN
    SELECT @GroupString = " ORDER BY DeptName, EN.LastName, EN.FirstName,THD.SSN, THD.PayrollPeriodEndDate,THD.TransDate, THD.ClockAdjustmentNo, ActualInPunch, THD.InDay,THD.InTime,THD.OutTime " + @crlf
  END
ELSE IF @Report = 'PDIP'
BEGIN
    IF @Ref4 = 'S'
    BEGIN
	  SELECT @GroupString = " ORDER BY THD.SSN, EN.LastName, EN.FirstName, EN.PrimaryDept,THD.PayrollPeriodEndDate,THD.TransDate, THD.ClockAdjustmentNo, ActualInPunch, THD.InDay,THD.InTime,THD.OutTime " + @crlf
    END
    ELSE
    BEGIN
	  SELECT @GroupString = " ORDER BY EN.LastName, EN.FirstName, THD.SSN, EN.PrimaryDept,THD.PayrollPeriodEndDate,THD.TransDate, THD.ClockAdjustmentNo, ActualInPunch, THD.InDay,THD.InTime,THD.OutTime " + @crlf
    END    
END
ELSE IF @Report = 'TCBA'
BEGIN
	IF @Sort1 = 'DeptName'
	BEGIN
		SELECT @GroupString = " ORDER BY GD.DeptName_Long,EN.LastName,EN.FirstName,THD.SSN,THD.PayrollPeriodEndDate,THD.TransDate, THD.ClockAdjustmentNo, ActualInPunch, THD.InDay,THD.InTime,THD.OutTime " + @crlf
	END
	ELSE
	BEGIN
		SELECT @GroupString = " ORDER BY EN.LastName,EN.FirstName,THD.SSN,GD.DeptName_Long,THD.PayrollPeriodEndDate,THD.TransDate, THD.ClockAdjustmentNo, ActualInPunch, THD.InDay,THD.InTime,THD.OutTime " + @crlf
	END
END

ELSE
  BEGIN
    IF @Ref4 = 'S'
      SELECT @GroupString = " ORDER BY THD.SSN,THD.PayrollPeriodEndDate,THD.TransDate,THD.ClockAdjustmentNo,ActualInPunch,THD.InDay,THD.InTime,THD.OutTime " + @crlf
    Else
      SELECT @GroupString = " ORDER BY EN.LastName, EN.FirstName, EN.SSN ,THD.PayrollPeriodEndDate,THD.TransDate,THD.ClockAdjustmentNo,ActualInPunch,THD.InDay,THD.InTime,THD.OutTime " + @crlf
  END
  SET @WhereString = @WhereString + "AND EXISTS(SELECT ClusterID FROM dbo.tvf_GetTimeHistoryClusterDefAsFn(THD.groupcode,THD.siteno,THD.deptno,THD.agencyno,THD.ssn,THD.DivisionID,THD.shiftno," + str(@ClusterID) + ")) "



 --   PRINT @SelectString + @FromString + @WhereString + @GroupString
 EXEC(@strSQL + @SelectString + @FromString + @WhereString + @GroupString)
 
GO

