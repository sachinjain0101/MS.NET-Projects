Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_AMED_GetData]
( 
  @Client char(4),
  @GroupCode int,
  @PPED DATETIME,
	@PAYRATEFLAG varchar(4),
	@EMPIDType varchar(6),
	@REGPAYCODE varchar(10),
	@OTPAYCODE varchar(10),
	@DTPAYCODE varchar(10),
  @PayrollType varchar(32),
  @IncludeSalary char(1),
  @TestingFlag char(1),
  @RecordType CHAR(1), 
  @PayRecordsSent datetime 
)
AS

SET NOCOUNT ON

/*
DECLARE  @Client char(4)
DECLARE  @GroupCode int
DECLARE  @PPED DateTime
DECLARE  @RecordType char(1)

SET @Client = 'AMED'
SET @GroupCode = 121
SET @PPED = '1/17/2010'
SET @RecordType = 'F'
*/

DECLARE @CalcBalanceCnt INT
DECLARE @Delim VARCHAR(1)
DECLARE @AutoApprovalUser INT 
DECLARE @CsrSSN INT 

SET @Delim = ';'

-- based on the RecordType get a list of employees.
--
Create Table #tmpSSNs
( 
  SSN int, 
  TransCount int, 
  ApprovedCount int,
  UnapprovedCount int,
  PayRecordsSent datetime,
  AprvlStatus_Date datetime
)

CREATE TABLE #tmpWorkedSummary
(
	RecordId INT IDENTITY,
	Client VARCHAR(4),
	GroupCode INT,
	PayrollPeriodEndDate DATETIME,  
	TransDate datetime,  
	SSN int,  
	FileNo VARCHAR(100),
	AssignmentNo VARCHAR(100),  
	BranchID VARCHAR(100),
	DeptName VARCHAR(100),
	TotalRegHours NUMERIC(7,2),  
	TotalOT_Hours NUMERIC(7,2),  
	TotalDT_Hours NUMERIC(7,2), 
	TotalWeeklyHours NUMERIC(7,2),
	ApproverName VARCHAR(100),
	ApproverDateTime datetime,
	ApprovalID int,
	ApprovalStatus VARCHAR(100),
	DayWorked VARCHAR(100),
	FlatPay NUMERIC(7,2),
	FlatBill NUMERIC(7,2),
	EmplName VARCHAR(100),
	PFP_Flag VARCHAR(100),
	PayRate NUMERIC(7,2),
	BillRate NUMERIC(7,2)
)

CREATE TABLE #tmpProjectSummary
(
	RecordId INT IDENTITY,
	SSN INT, 
	AssignmentNo VARCHAR(100), 
	TransDate DATETIME, 
	ProjectNum VARCHAR(100), 
	Hours NUMERIC(7,2)
)

IF (@PayrollType = 'QUEST')
BEGIN

	SELECT @AutoApprovalUser = UserID
	FROM TimeCurrent.dbo.tblUser
	WHERE Client = @Client
	AND JobDesc = 'AUTOAPPROVAL'
	
  Create Table #tmpAppSSN(SSN INT)

  INSERT INTO #tmpAppSSN(SSN)
  SELECT DISTINCT thd.SSN  
	FROM TimeCurrent.dbo.tblEmplAssignments AS ea
	INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS thd
	ON thd.Client = ea.Client
	AND thd.Groupcode = ea.Groupcode
	AND thd.PayrollPeriodEndDate = @PPED  	
	AND thd.SSN = ea.SSN
	AND thd.DeptNo =  ea.DeptNo
	WHERE ea.Client = @Client
	AND ea.Groupcode = @Groupcode
	AND ea.ClientID IN ('570', '1941', '2216', '102', '1868', '1867', '68', '1356', '177', '2229',
											'6301', '6154', '8394', '6703', '4705', '1308', '403', '1283', '1984',
											'7162', '10024', '8294', '4630', '5405', '6170', '10610',
											'1869', '6069', '13800', '2196', '6519', '14015', '14014', '13972', '14019', '14000', '14049', '15685', '7992', '16520', '1867', '2650')
	AND thd.AprvlStatus = ''	

	UPDATE TimeHistory.dbo.tblTimeHistDetail
	SET AprvlStatus = 'A',
			AprvlStatus_Date = @PayRecordsSent,
			AprvlStatus_UserID = @AutoApprovalUser
	FROM TimeCurrent.dbo.tblEmplAssignments AS ea
	INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS thd
	ON thd.Client = ea.Client
	AND thd.Groupcode = ea.Groupcode
	AND thd.PayrollPeriodEndDate = @PPED  	
	AND thd.SSN = ea.SSN
	AND thd.DeptNo =  ea.DeptNo
	WHERE ea.Client = @Client
	AND ea.Groupcode = @Groupcode
	AND ea.ClientID IN ('570', '1941', '2216', '102', '1868', '1867', '68', '1356', '177', '2229',
											'6301', '6154', '8394', '6703', '4705', '1308', '403', '1283', '1984',
											'7162', '10024', '8294', '4630', '5405', '6170', '10610',
											'1869', '6069', '13800', '2196', '6519', '14015', '14014', '13972', '14019', '14000', '14049', '15685', '7992', '16520', '1867', '2650')
	AND thd.AprvlStatus = ''
	
  DECLARE aprvlCursor CURSOR FOR
  SELECT * FROM #tmpAppSSN
  OPEN aprvlCursor

  FETCH NEXT FROM aprvlCursor
  INTO @CsrSSN

  WHILE @@FETCH_STATUS = 0
  BEGIN	   
    EXEC TimeHistory.dbo.usp_EmplCalc_SummarizeAprvlStatus @Client, @GroupCode, @PPED, @CsrSSN
    
	  FETCH NEXT FROM aprvlCursor
	  INTO @CsrSSN
  END
  CLOSE aprvlCursor
  DEALLOCATE aprvlCursor		
  
  DROP TABLE #tmpAppSSN		

END

Insert into #tmpSSNs ( SSN, TransCount, ApprovedCount, UnapprovedCount, PayRecordsSent, AprvlStatus_Date)
select 	t.SSN, 
			  TransCount = sum(1),
			  ApprovedCount = sum(case when t.AprvlStatus IN('A', 'L') then 1 else 0 end),
			  UnapprovedCount = SUM(CASE WHEN t.AprvlStatus IN('', ' ', 'D') THEN 1 ELSE 0 END),
			  isnull(en.PayRecordsSent,'1/1/1970'), 
			  max(isnull(t.AprvlStatus_Date,'1/2/1970'))
from TimeHistory..tblTimeHistDetail as t
Inner Join TimeHistory..tblEmplNames as en
on en.Client = t.Client 
and en.GroupCode = t.GroupCode 
and en.SSN = t.SSN
and en.PayrollPeriodenddate = t.PayrollPeriodenddate
where t.Client = @Client
and t.Groupcode = @GroupCode
and t.PayrollPeriodEndDate = @PPED
AND t.Hours <> 0
--AND ISNULL(en.ExcludeFromUpload, '0') <> '1'
group By t.SSN, en.PayRecordsSent



IF (@RecordType = 'F')
BEGIN
  -- FINAL pay file extract.
  -- Send all records that are not completely approved or have not been sent yet.
  --
  /*Delete from #tmpSSNs 
  where PayRecordsSent > AprvlStatus_Date 
  and TransCount = ApprovedCount */
  Delete from #tmpSSNs where PayRecordsSent <> '1/1/1970'
END
ELSE IF (@RecordType = 'L')
BEGIN
  -- LATE pay file extract.
  -- Send all records that have been entered and not paid
  --
  Delete from #tmpSSNs where PayRecordsSent <> '1/1/1970'
END
ELSE
BEGIN
	-- If its not a recognized type then return
	RETURN
END


Select t.GroupCode, t.PayrollPeriodEndDate, t.SSN,
       TotHours = Sum(t.Hours), TotCalcHrs = Sum(t.RegHours + t.OT_Hours + t.DT_Hours)
into #tmpCalcHrs
From timeHistory.dbo.tblTimeHistDetail as t
Inner Join #tmpSSNs as s
on s.SSN = t.SSN
Where t.Client = @Client
  and t.groupCode = @GroupCode
  and t.PayrollPeriodEnddate = @PPED
Group By t.GroupCode, t.PayrollPeriodEndDate, t.SSN
order By t.groupCode, t.PayrollPeriodEndDate, t.SSN

SELECT @CalcBalanceCnt = (Select count(*) from #tmpCalcHrs where TotHours <> TotCalcHrs)

Drop Table #tmpCalcHrs

if @CalcBalanceCnt > 0
begin
  RAISERROR ('Employees exists that are out of balance between worked and calculated.', 16, 1) 
  return
end


Create Table #tmpHours
(
	Client varchar(4), 
	GroupCode int,
	SSN int,
	AssignmentNo varchar(50),
	EmployeeName VARCHAR(100),
	CollectionFormat varchar(2),
	BranchID varchar(10),
	GroupingNo varchar(20),
	PayrollPeriodEndDate datetime,
	TimeType varchar(5),
	ConfirmationNumber varchar(10),
	TransactionType varchar(1),
	IndividualOrGroup varchar(1),
	ApproverEmail varchar(50), 
	ApprovalStatus varchar(1),
	ApproverConfirmationNumber varchar(20),
	ApproverComments varchar(1000),
	TimestampLastUpdate datetime,	
	Schedule410 varchar(1),
	WorkState varchar(2),
	ApproverDateTime datetime,
	MaxRecordID BIGINT,  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 04Aug2016 >--
	MonHours numeric(6,2),
	TueHours numeric(6,2),
	WedHours numeric(6,2),
	ThuHours numeric(6,2),
	FriHours numeric(6,2),
	SatHours numeric(6,2),
	SunHours numeric(6,2),
	TotalHours numeric(6,2),
	TotalIVRTransactions int
)


	--
	--Get the Daily totals for each SSN, display the weekly total as one of the columns.
	-- 
	INSERT INTO #tmpHours
	SELECT   thd.Client,
		       thd.GroupCode,
		       thd.SSN,
	         ea.AssignmentNo,
	         EmployeeName = en.LastName + ', ' + en.FirstName,
		       CollectionFormat = CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
		       ea.BranchID,
		       ea.GroupingNo,
	         thd.PayrollPeriodEndDate,           	         	         	         	         	         
	         TimeType = @REGPAYCODE,
	         ConfirmationNumber = '',
	         TransactionType = 'W',  -- Will set to IVR later if necessary
	         IndividualOrGroup = CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
					 ApproverEmail = '', 
					 ApprovalStatus = CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END,
					 ApproverConfirmationNumber = '',
					 ApproverComments = '',
					 TimeStampLastUpdate = ISNULL(th_en.EmplApprovalDate, '1/1/1900'),	
					 Schedule410 = ea.Schedule410,
					 WorkState = ea.WorkState,
				   ApproverDateTime = Max(ISNULL(thd.AprvlStatus_Date, '1/1/1900')),
				   MaxRecordID = Max(thd.recordID),
	         MonHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '2' THEN thd.RegHours ELSE 0 END),
	         TueHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '3' THEN thd.RegHours ELSE 0 END),
	         WedHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '4' THEN thd.RegHours ELSE 0 END),
	         ThuHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '5' THEN thd.RegHours ELSE 0 END),
	         FriHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '6' THEN thd.RegHours ELSE 0 END),
	         SatHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '7' THEN thd.RegHours ELSE 0 END),
	         SunHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '1' THEN thd.RegHours ELSE 0 END),
	         TotalHours = SUM(thd.RegHours),
	         TotalIVRTransactions = SUM(CASE WHEN thd.UserCode = 'IVR' THEN 1 ELSE 0 END)
	FROM TimeHistory..tblTimeHistDetail as thd
	INNER JOIN #tmpSSNs as S
	ON S.SSN = thd.SSN
	INNER JOIN TimeCurrent..tblEmplNames as en
	ON en.Client = thd.Client
	AND en.Groupcode = thd.Groupcode
	AND en.SSN = thd.SSN	
	INNER JOIN TimeCurrent..tblEmplAssignments as ea
	ON ea.Client = thd.Client
	AND ea.Groupcode = thd.Groupcode
	AND ea.SSN = thd.SSN
	AND ea.DeptNo =  thd.DeptNo
	AND ((@PayrollType <> 'QUEST') OR (@PayrollType = 'QUEST' AND ea.ClientID IN ('570', '1941', '2216', '102', '1868', '1867', '68', '1356', '177', '2229',
											'6301', '6154', '8394', '6703', '4705', '1308', '403', '1283', '1984',
											'7162', '10024', '8294', '4630', '5405', '6170', '10610',
											'1869', '6069', '13800', '2196', '6519', '14015', '14014', '13972', '14019', '14000', '14049', '15685', '7992', '16520', '1867', '2650')))
	INNER JOIN TimeHistory..tblEmplSites_Depts as esd
	ON esd.Client = thd.Client
	AND esd.Groupcode = thd.Groupcode
	AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate
	AND esd.SSN = thd.SSN
	AND esd.SiteNo = thd.SiteNo
	AND esd.DeptNo =  thd.DeptNo
	INNER JOIN TimeCurrent..tblGroupDepts gd
	ON gd.Client = thd.Client
	AND gd.GroupCode = thd.GroupCode     
	AND gd.DeptNo = thd.DeptNo         
	INNER JOIN TimeHistory.dbo.tblEmplNames th_en
	ON th_en.Client = thd.Client
	AND th_en.GroupCode = thd.GroupCode
	AND th_en.PayrollPeriodEndDate = thd.PayrollPeriodEndDate	
	AND th_en.SSN = thd.SSN
	INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
	ON ac.Client = thd.Client
	AND ac.GroupCode = thd.GroupCode
	AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', ' ', '1') THEN '1' ELSE thd.ClockAdjustmentNo END
	AND ac.Worked = 'Y'
	LEFT JOIN TimeCurrent..tblAgencies ag
	ON  ag.Client = thd.Client
	AND ag.GroupCode = thd.GroupCode
	AND ag.Agency = thd.AgencyNo
	WHERE thd.Client = @Client  
	AND thd.PayrollPeriodEndDate = @PPED  
	AND thd.GroupCode = @GroupCode  
	AND IsNull(ag.ExcludeFromPayFile,'0') <> '1'
	AND isnull(esd.ExcludeFromUpload,'0') <> '1'
	AND isnull(th_en.ExcludeFromUpload,'0') <> '1'	
	AND thd.RegHours <> 0
	GROUP BY thd.Client,  
	         thd.GroupCode,  
	         thd.SSN,  
	         en.LastName + ', ' + en.FirstName,
	         CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
	         ea.BranchID,
	         ea.GroupingNo,
	         thd.PayrollPeriodEndDate,
	         ISNULL(th_en.EmplApprovalDate, '1/1/1900'),
	         ea.AssignmentNo,
	         CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
	         ea.Schedule410,
					 ea.WorkState,
					 CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END

	INSERT INTO #tmpHours
	SELECT   thd.Client,
		       thd.GroupCode,
		       thd.SSN,
	         ea.AssignmentNo,
	         EmployeeName = en.LastName + ', ' + en.FirstName,
		       CollectionFormat = CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
		       ea.BranchID,
		       ea.GroupingNo,
	         thd.PayrollPeriodEndDate,           	         	         	         	         	         
	         TimeType = @OTPAYCODE,
	         ConfirmationNumber = ea.AssignmentNo,
	         TransactionType = 'W',  -- Will set to IVR later if necessary
	         IndividualOrGroup = CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
					 ApproverEmail = '', 
					 ApprovalStatus = CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END,
					 ApproverConfirmationNumber = '',
					 ApproverComments = '',
					 TimeStampLastUpdate = th_en.EmplApprovalDate,	
					 Schedule410 = ea.Schedule410,
					 WorkState = ea.WorkState,
				   ApproverDateTime = Max(ISNULL(thd.AprvlStatus_Date, '1/1/1900')),
				   MaxRecordID = Max(thd.recordID),
	         MonHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '2' THEN thd.OT_Hours ELSE 0 END),
	         TueHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '3' THEN thd.OT_Hours ELSE 0 END),
	         WedHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '4' THEN thd.OT_Hours ELSE 0 END),
	         ThuHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '5' THEN thd.OT_Hours ELSE 0 END),
	         FriHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '6' THEN thd.OT_Hours ELSE 0 END),
	         SatHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '7' THEN thd.OT_Hours ELSE 0 END),
	         SunHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '1' THEN thd.OT_Hours ELSE 0 END),
	         TotalHours = SUM(thd.OT_Hours),
	         TotalIVRTransactions = SUM(CASE WHEN thd.UserCode = 'IVR' THEN 1 ELSE 0 END)
	FROM TimeHistory..tblTimeHistDetail as thd
	INNER JOIN #tmpSSNs as S
	ON S.SSN = thd.SSN
	INNER JOIN TimeCurrent..tblEmplNames as en
	ON en.Client = thd.Client
	AND en.Groupcode = thd.Groupcode
	AND en.SSN = thd.SSN	
	INNER JOIN TimeCurrent..tblEmplAssignments as ea
	ON ea.Client = thd.Client
	AND ea.Groupcode = thd.Groupcode
	AND ea.SSN = thd.SSN
	AND ea.DeptNo =  thd.DeptNo
	AND ((@PayrollType <> 'QUEST') OR (@PayrollType = 'QUEST' AND ea.ClientID IN ('570', '1941', '2216', '102', '1868', '1867', '68', '1356', '177', '2229',
											'6301', '6154', '8394', '6703', '4705', '1308', '403', '1283', '1984',
											'7162', '10024', '8294', '4630', '5405', '6170', '10610',
											'1869', '6069', '13800', '2196', '6519', '14015', '14014', '13972', '14019', '14000', '14049', '15685', '7992', '16520', '1867', '2650')))	
	INNER JOIN TimeHistory..tblEmplSites_Depts as esd
	ON esd.Client = thd.Client
	AND esd.Groupcode = thd.Groupcode
	AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate
	AND esd.SSN = thd.SSN
	AND esd.SiteNo = thd.SiteNo
	AND esd.DeptNo =  thd.DeptNo
	INNER JOIN TimeCurrent..tblGroupDepts gd
	ON gd.Client = thd.Client
	AND gd.GroupCode = thd.GroupCode     
	AND gd.DeptNo = thd.DeptNo         
	INNER JOIN TimeHistory.dbo.tblEmplNames th_en
	ON th_en.Client = thd.Client
	AND th_en.GroupCode = thd.GroupCode
	AND th_en.PayrollPeriodEndDate = thd.PayrollPeriodEndDate		
	AND th_en.SSN = thd.SSN
	INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
	ON ac.Client = thd.Client
	AND ac.GroupCode = thd.GroupCode
	AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', ' ', '1') THEN '1' ELSE thd.ClockAdjustmentNo END
	AND ac.Worked = 'Y'	
	LEFT JOIN TimeCurrent..tblAgencies ag
	ON  ag.Client = thd.Client
	AND ag.GroupCode = thd.GroupCode
	AND ag.Agency = thd.AgencyNo
	WHERE thd.Client = @Client  
	AND thd.PayrollPeriodEndDate = @PPED  
	AND thd.GroupCode = @GroupCode  
	AND IsNull(ag.ExcludeFromPayFile,'0') <> '1'
	AND isnull(esd.ExcludeFromUpload,'0') <> '1'
	AND isnull(th_en.ExcludeFromUpload,'0') <> '1'	
	AND thd.OT_Hours <> 0
	GROUP BY thd.Client,  
	         thd.GroupCode,  
	         thd.SSN,  
	         en.LastName + ', ' + en.FirstName,
	         CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
	         ea.BranchID,
	         ea.GroupingNo,
	         thd.PayrollPeriodEndDate,
	         th_en.EmplApprovalDate,
	         ea.AssignmentNo,
	         CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
	         ea.Schedule410,
					 ea.WorkState,
					 CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END		

	INSERT INTO #tmpHours
	SELECT   thd.Client,
		       thd.GroupCode,
		       thd.SSN,
	         ea.AssignmentNo,
	         EmployeeName = en.LastName + ', ' + en.FirstName,
		       CollectionFormat = CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
		       ea.BranchID,
		       ea.GroupingNo,
	         thd.PayrollPeriodEndDate,           	         	         	         	         	         
	         TimeType = @DTPAYCODE,
	         ConfirmationNumber = ea.AssignmentNo,
	         TransactionType = 'W',  -- Will set to IVR later if necessary
	         IndividualOrGroup = CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
					 ApproverEmail = '', 
					 ApprovalStatus = CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END,
					 ApproverConfirmationNumber = '',
					 ApproverComments = '',
					 TimeStampLastUpdate = th_en.EmplApprovalDate,	
					 Schedule410 = ea.Schedule410,
					 WorkState = ea.WorkState,
				   ApproverDateTime = Max(ISNULL(thd.AprvlStatus_Date, '1/1/1900')),
				   MaxRecordID = Max(thd.recordID),
	         MonHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '2' THEN thd.DT_Hours ELSE 0 END),
	         TueHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '3' THEN thd.DT_Hours ELSE 0 END),
	         WedHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '4' THEN thd.DT_Hours ELSE 0 END),
	         ThuHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '5' THEN thd.DT_Hours ELSE 0 END),
	         FriHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '6' THEN thd.DT_Hours ELSE 0 END),
	         SatHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '7' THEN thd.DT_Hours ELSE 0 END),
	         SunHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '1' THEN thd.DT_Hours ELSE 0 END),
	         TotalHours = SUM(thd.DT_Hours),
	         TotalIVRTransactions = SUM(CASE WHEN thd.UserCode = 'IVR' THEN 1 ELSE 0 END)
	FROM TimeHistory..tblTimeHistDetail as thd
	INNER JOIN #tmpSSNs as S
	ON S.SSN = thd.SSN
	INNER JOIN TimeCurrent..tblEmplNames as en
	ON en.Client = thd.Client
	AND en.Groupcode = thd.Groupcode
	AND en.SSN = thd.SSN	
	INNER JOIN TimeCurrent..tblEmplAssignments as ea
	ON ea.Client = thd.Client
	AND ea.Groupcode = thd.Groupcode
	AND ea.SSN = thd.SSN
	AND ea.DeptNo =  thd.DeptNo
	AND ((@PayrollType <> 'QUEST') OR (@PayrollType = 'QUEST' AND ea.ClientID IN ('570', '1941', '2216', '102', '1868', '1867', '68', '1356', '177', '2229',
											'6301', '6154', '8394', '6703', '4705', '1308', '403', '1283', '1984',
											'7162', '10024', '8294', '4630', '5405', '6170', '10610',
											'1869', '6069', '13800', '2196', '6519', '14015', '14014', '13972', '14019', '14000', '14049', '15685', '7992', '16520', '1867', '2650')))	
	INNER JOIN TimeHistory..tblEmplSites_Depts as esd
	ON esd.Client = thd.Client
	AND esd.Groupcode = thd.Groupcode
	AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate
	AND esd.SSN = thd.SSN
	AND esd.SiteNo = thd.SiteNo
	AND esd.DeptNo =  thd.DeptNo
	INNER JOIN TimeCurrent..tblGroupDepts gd
	ON gd.Client = thd.Client
	AND gd.GroupCode = thd.GroupCode     
	AND gd.DeptNo = thd.DeptNo         
	INNER JOIN TimeHistory.dbo.tblEmplNames th_en
	ON th_en.Client = thd.Client
	AND th_en.GroupCode = thd.GroupCode
	AND th_en.PayrollPeriodEndDate = thd.PayrollPeriodEndDate	
	AND th_en.SSN = thd.SSN
	INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
	ON ac.Client = thd.Client
	AND ac.GroupCode = thd.GroupCode
	AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', ' ', '1') THEN '1' ELSE thd.ClockAdjustmentNo END
	AND ac.Worked = 'Y'	
	LEFT JOIN TimeCurrent..tblAgencies ag
	ON  ag.Client = thd.Client
	AND ag.GroupCode = thd.GroupCode
	AND ag.Agency = thd.AgencyNo
	WHERE thd.Client = @Client  
	AND thd.PayrollPeriodEndDate = @PPED  
	AND thd.GroupCode = @GroupCode  
	AND IsNull(ag.ExcludeFromPayFile,'0') <> '1'
	AND isnull(esd.ExcludeFromUpload,'0') <> '1'
	AND isnull(th_en.ExcludeFromUpload,'0') <> '1'	
	AND thd.DT_Hours <> 0
	GROUP BY thd.Client,  
	         thd.GroupCode,  
	         thd.SSN,  
	         en.LastName + ', ' + en.FirstName,
	         CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
	         ea.BranchID,
	         ea.GroupingNo,
	         thd.PayrollPeriodEndDate,
	         th_en.EmplApprovalDate,
	         ea.AssignmentNo,
	         CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
	         ea.Schedule410,
					 ea.WorkState,
					 CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END
					 
	INSERT INTO #tmpHours
	SELECT   thd.Client,
		       thd.GroupCode,
		       thd.SSN,
	         ea.AssignmentNo,
	         EmployeeName = en.LastName + ', ' + en.FirstName,
		       CollectionFormat = CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
		       ea.BranchID,
		       ea.GroupingNo,
	         thd.PayrollPeriodEndDate,           	         	         	         	         	         
	         TimeType = ac.ADP_HoursCode,
	         ConfirmationNumber = ea.AssignmentNo,
	         TransactionType = 'W',  -- Will set to IVR later if necessary
	         IndividualOrGroup = CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
					 ApproverEmail = '', 
					 ApprovalStatus = CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END,
					 ApproverConfirmationNumber = '',
					 ApproverComments = '',
					 TimeStampLastUpdate = th_en.EmplApprovalDate,	
					 Schedule410 = ea.Schedule410,
					 WorkState = ea.WorkState,
				   ApproverDateTime = Max(ISNULL(thd.AprvlStatus_Date, '1/1/1900')),
				   MaxRecordID = Max(thd.recordID),
	         MonHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '2' THEN thd.Hours ELSE 0 END),
	         TueHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '3' THEN thd.Hours ELSE 0 END),
	         WedHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '4' THEN thd.Hours ELSE 0 END),
	         ThuHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '5' THEN thd.Hours ELSE 0 END),
	         FriHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '6' THEN thd.Hours ELSE 0 END),
	         SatHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '7' THEN thd.Hours ELSE 0 END),
	         SunHours = SUM(CASE WHEN DATEPART(dw, thd.Transdate) = '1' THEN thd.Hours ELSE 0 END),
	         TotalHours = SUM(thd.Hours),
	         TotalIVRTransactions = SUM(CASE WHEN thd.UserCode = 'IVR' THEN 1 ELSE 0 END)
	FROM TimeHistory..tblTimeHistDetail as thd
	INNER JOIN #tmpSSNs as S
	ON S.SSN = thd.SSN
	INNER JOIN TimeCurrent..tblEmplNames as en
	ON en.Client = thd.Client
	AND en.Groupcode = thd.Groupcode
	AND en.SSN = thd.SSN	
	INNER JOIN TimeCurrent..tblEmplAssignments as ea
	ON ea.Client = thd.Client
	AND ea.Groupcode = thd.Groupcode
	AND ea.SSN = thd.SSN
	AND ea.DeptNo =  thd.DeptNo
	AND ((@PayrollType <> 'QUEST') OR (@PayrollType = 'QUEST' AND ea.ClientID IN ('570', '1941', '2216', '102', '1868', '1867', '68', '1356', '177', '2229',
											'6301', '6154', '8394', '6703', '4705', '1308', '403', '1283', '1984',
											'7162', '10024', '8294', '4630', '5405', '6170', '10610',
											'1869', '6069', '13800', '2196', '6519', '14015', '14014', '13972', '14019', '14000', '14049', '15685', '7992', '16520', '1867', '2650')))	
	INNER JOIN TimeHistory..tblEmplSites_Depts as esd
	ON esd.Client = thd.Client
	AND esd.Groupcode = thd.Groupcode
	AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate
	AND esd.SSN = thd.SSN
	AND esd.SiteNo = thd.SiteNo
	AND esd.DeptNo =  thd.DeptNo
	INNER JOIN TimeCurrent..tblGroupDepts gd
	ON gd.Client = thd.Client
	AND gd.GroupCode = thd.GroupCode     
	AND gd.DeptNo = thd.DeptNo         
	INNER JOIN TimeHistory.dbo.tblEmplNames th_en
	ON th_en.Client = thd.Client
	AND th_en.GroupCode = thd.GroupCode
	AND th_en.PayrollPeriodEndDate = thd.PayrollPeriodEndDate	
	AND th_en.SSN = thd.SSN
	INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
	ON ac.Client = thd.Client
	AND ac.GroupCode = thd.GroupCode
	AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', ' ', '1') THEN '1' ELSE thd.ClockAdjustmentNo END
	AND ac.Worked = 'N'	
	LEFT JOIN TimeCurrent..tblAgencies ag
	ON  ag.Client = thd.Client
	AND ag.GroupCode = thd.GroupCode
	AND ag.Agency = thd.AgencyNo
	WHERE thd.Client = @Client  
	AND thd.PayrollPeriodEndDate = @PPED  
	AND thd.GroupCode = @GroupCode  
	AND IsNull(ag.ExcludeFromPayFile,'0') <> '1'
	AND isnull(esd.ExcludeFromUpload,'0') <> '1'
	AND isnull(th_en.ExcludeFromUpload,'0') <> '1'	
	AND thd.Hours <> 0
	GROUP BY thd.Client,  
	         thd.GroupCode,  
	         thd.SSN,  
	         en.LastName + ', ' + en.FirstName,
	         CASE WHEN ea.QtrHrRound = '1' THEN '10' WHEN ea.BranchID = '999' THEN '3' ELSE '9' END,
	         ea.BranchID,
	         ea.GroupingNo,
	         thd.PayrollPeriodEndDate,
	         ac.ADP_HoursCode,
	         th_en.EmplApprovalDate,
	         ea.AssignmentNo,
	         CASE WHEN ISNULL(ea.AgencyNo, '') IN ('', '0') THEN 'I' ELSE 'G' END,
	         ea.Schedule410,
					 ea.WorkState,
					 CASE WHEN s.UnapprovedCount > 0 THEN '0' ELSE '2' END					 

-- Delete zero hour transactions
delete from #tmpHours 
where TotalHours = 0.00 

-- Fix up the approval information
Update #tmpHours
  Set #tmpHours.ApproverEmail = CASE WHEN bkp.RecordId IS NOT NULL THEN bkp.Email
  																																	 ELSE CASE WHEN isnull(usr.Email,'') = '' THEN (CASE WHEN isnull(usr.LastName,'') = '' THEN isnull(usr.LogonName,'') 
																					  																																																							 ELSE left(isnull(usr.FirstName,'') + ' ' + usr.LastName, 50)
																					  																																																							 END)
																																								 															ELSE left(usr.Email,50) 
																																								 															END
																																		 END,	
		  #tmpHours.ApproverConfirmationNumber = CASE WHEN ApproverDateTime = '1/1/1900' THEN '' ELSE LEFT(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, ApproverDateTime, 121), '-', ''), ':', ''), ' ', ''), 14) END
FROM #tmpHours
INNER JOIN TimeHistory..tblTimeHistDetail as thd
on thd.RecordID = #tmpHours.MaxRecordID
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp
ON bkp.THDRecordId = #tmpHours.MaxRecordID
LEFT JOIN TimeCurrent..tblUser as Usr
ON usr.Client = thd.Client
AND usr.UserID = isnull(thd.AprvlStatus_UserID,0)

-- Set the Last Update Date/Time if it didn't come from WTE or IVR
UPDATE #tmpHours
SET #tmpHours.TimeStampLastUpdate = adjs.MaxTransDateTime
FROM #tmpHours
INNER JOIN (SELECT a.Client, a.GroupCode, a.SSN, a.PayrollPeriodEndDate, MAX(a.TransDateTime) AS MaxTransDateTime
						FROM TimeCurrent.dbo.tblAdjustments a
						WHERE a.Client = @Client
						AND a.GroupCode = @GroupCode						
						AND a.PayrollPeriodEndDate = @PPED
						GROUP BY a.Client, a.GroupCode, a.SSN, a.PayrollPeriodEndDate) adjs
ON #tmpHours.Client = adjs.Client
AND #tmpHours.GroupCode = adjs.GroupCode
AND #tmpHours.PayrollPeriodEndDate = adjs.PayrollPeriodEndDate
AND #tmpHours.SSN = adjs.SSN						
WHERE ISNULL(#tmpHours.TimeStampLastUpdate, '1/1/1900') < ISNULL(adjs.MaxTransDateTime, '1/1/1900')

UPDATE #tmpHours
SET #tmpHours.TimeStampLastUpdate = fixes.MaxTransDateTime
FROM #tmpHours
INNER JOIN (SELECT f.Client, f.GroupCode, f.SSN, f.PayrollPeriodEndDate, MAX(f.TransDateTime) AS MaxTransDateTime
						FROM TimeCurrent.dbo.tblFixedPunch f
						WHERE f.Client = @Client
						AND f.GroupCode = @GroupCode						
						AND f.PayrollPeriodEndDate = @PPED
						GROUP BY f.Client, f.GroupCode, f.SSN, f.PayrollPeriodEndDate) fixes
ON #tmpHours.Client = fixes.Client
AND #tmpHours.GroupCode = fixes.GroupCode
AND #tmpHours.PayrollPeriodEndDate = fixes.PayrollPeriodEndDate
AND #tmpHours.SSN = fixes.SSN						
WHERE ISNULL(#tmpHours.TimeStampLastUpdate, '1/1/1900') < ISNULL(fixes.MaxTransDateTime, '1/1/1900')

-- Set transaction type to IVR (if any IVR transactions exist)
UPDATE #tmpHours
SET #tmpHours.TransactionType = 'I'
WHERE #tmpHours.TotalIVRTransactions > 0

UPDATE TimeHistory.dbo.tblEmplNames
SET PayRecordsSent = @PayRecordsSent
WHERE Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED
AND SSN IN (SELECT DISTINCT SSN
						FROM #tmpHours)
AND ISNULL(PayRecordsSent, '1/1/1970') = '1/1/1970'

SELECT 	GroupCode,
				SSN, 
				EmployeeID = SSN, 
				EmployeeName, 
				PayrollPeriodEndDate AS PPED,
				AssignmentNo,
				Line1 = AssignmentNo + @Delim + 
								CAST(SSN AS VARCHAR) + @Delim +
								CollectionFormat + @Delim +
								'1' /*ReportingInterval */ + @Delim + 
								BranchID + @Delim +
								GroupingNo + @Delim +
								CONVERT(VARCHAR(10), @PPED, 101) + @Delim +
								REPLACE(RIGHT('00' + CAST(CAST(MonHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(MonHours * 60 - (CAST(MonHours AS INT) * 60),0) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +
								REPLACE(RIGHT('00' + CAST(CAST(TueHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(TueHours * 60 - (CAST(TueHours AS INT) * 60),0) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +
								REPLACE(RIGHT('00' + CAST(CAST(WedHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(WedHours * 60 - (CAST(WedHours AS INT) * 60),0) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(ThuHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(ThuHours * 60 - (CAST(ThuHours AS INT) * 60),0) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(FriHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(FriHours * 60 - (CAST(FriHours AS INT) * 60),0) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(SatHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(SatHours * 60 - (CAST(SatHours AS INT) * 60),0) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(SunHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(SunHours * 60 - (CAST(SunHours AS INT) * 60),0) AS INT) AS VARCHAR), 2), '0000', '') + @Delim	+
								RIGHT('00' + CAST(CAST(TotalHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ROUND(TotalHours * 60 - (CAST(TotalHours AS INT) * 60),0) AS INT) AS VARCHAR), 2) + @Delim	+
                /*
								REPLACE(RIGHT('00' + CAST(CAST(MonHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(MonHours * 60 - (CAST(MonHours AS INT) * 60) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +
								REPLACE(RIGHT('00' + CAST(CAST(TueHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(TueHours * 60 - (CAST(TueHours AS INT) * 60) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(WedHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(WedHours * 60 - (CAST(WedHours AS INT) * 60) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(ThuHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(ThuHours * 60 - (CAST(ThuHours AS INT) * 60) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(FriHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(FriHours * 60 - (CAST(FriHours AS INT) * 60) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(SatHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(SatHours * 60 - (CAST(SatHours AS INT) * 60) AS INT) AS VARCHAR), 2), '0000', '') + @Delim +								
								REPLACE(RIGHT('00' + CAST(CAST(SunHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(SunHours * 60 - (CAST(SunHours AS INT) * 60) AS INT) AS VARCHAR), 2), '0000', '') + @Delim	+
								RIGHT('00' + CAST(CAST(TotalHours AS INT) AS VARCHAR), 2) + RIGHT('00' + CAST(CAST(TotalHours * 60 - (CAST(TotalHours AS INT) * 60) AS INT) AS VARCHAR), 2) + @Delim	+
								*/
								TimeType + @Delim +
								ConfirmationNumber + @Delim +
								TransactionType + @Delim +
								IndividualOrGroup + @Delim +
								CASE WHEN TimeStampLastUpdate = '1/1/1900 00:00:00' THEN '' ELSE LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR, TimeStampLastUpdate, 101), '') + ' ' + ISNULL(CONVERT(VARCHAR, TimeStampLastUpdate, 108), ''))) END + @Delim +
								ApprovalStatus + @Delim + 
								'' + @Delim +
								'' + @Delim + 
								'' + @Delim + 
								'' + @Delim + 
								'' + @Delim + 
								CASE WHEN ApproverDateTime = '1/1/1900' THEN '' ELSE LTRIM(RTRIM(CONVERT(VARCHAR, ApproverDateTime, 101) + ' ' + CONVERT(VARCHAR, ApproverDateTime, 108))) END + @Delim +
								ApproverEmail + @Delim +
								ApproverConfirmationNumber + @Delim +
								ApproverComments + @Delim +
								CASE WHEN ISNULL(Schedule410, '0') IN ('','0') THEN 'N' ELSE 'Y' END + @Delim +
								WorkState + @Delim +
								'N' /*Override*/
FROM #tmpHours
ORDER BY GroupCode, SSN

DROP TABLE #tmpSSNs
DROP TABLE #tmpHours
DROP TABLE #tmpWorkedSummary
DROP TABLE #tmpProjectSummary









