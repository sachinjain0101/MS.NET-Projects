Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_MPOW_PCT]
(   
  @Client         char(4),  
  @GroupCode      int,  
  @PPED           DateTime,  
  @PAYRATEFLAG    varchar(4),  
  @EMPIDType      varchar(6),  
  @REGPAYCODE     varchar(10),  
  @OTPAYCODE     varchar(10),  
  @DTPAYCODE     varchar(10),  
  @PayrollType    varchar(32) = '',  
  @IncludeSalary  char(1),  
  @TestingFlag    char(1) = 'N'  
) AS  
SET NOCOUNT ON  

--DECLARE
-- @Client CHAR(4) = 'MPOW'
--,@GroupCode INT = 102
--,@PPED DATETIME = '2015-07-24'
--,@PAYRATEFLAG VARCHAR(4) = ''
--,@EMPIDType VARCHAR(6) = 'FILENO'
--,@REGPAYCODE VARCHAR(10) = 'REG'
--,@OTPAYCODE VARCHAR(10) = 'OVD'
--,@DTPAYCODE VARCHAR(10) = 'OTS'
--,@PayrollType VARCHAR(32) = 'A'
--,@IncludeSalary CHAR(1) = ''
--,@TestingFlag CHAR(1) = 'Y';

--update timehistory..tblemplsites_depts
--set payrecordssent = null
--where client = 'mpow'
--and groupcode < 100000
--and payrecordssent > '9/9/2015 10:00'
--and payrollperiodenddate > '8/1/2015'


DECLARE @RecordType         CHAR(1)  
DECLARE @PPEDMinus6         DATETIME  
DECLARE @Now				DATETIME   
DECLARE @Today				DATE
DECLARE @ExcludeSubVendors  VARCHAR(1)  
DECLARE @Delim              CHAR(1)  
DECLARE @FaxApprover        INT  
DECLARE @AdditionalApprovalWeeks TINYINT
DECLARE @MinAAWeek DATE
DECLARE @MaxAAWeek DATE
DECLARE @AdditionalVMSLateTimeEntryWks TINYINT,@VMSRangeStart DATE,@VMSRangeEnd DATE;
  
SET @Now = GETDATE()  
SET @Today = @Now
SET @PPEDMinus6 = DATEADD(dd, -6, @PPED)  
SET @ExcludeSubVendors = '0' -- Exclude SubVendors from all Unapproved pay files  
SET @Delim = '|'  
SET @RecordType = LEFT(@PayrollType, 1)  -- default to Approved  

SELECT @FaxApprover = UserID   
FROM TimeCurrent.dbo.tblUser WITH(NOLOCK)  
WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER'   
AND Client = @Client

SELECT @AdditionalVMSLateTimeEntryWks = ISNULL(AdditionalLateTimeEntryWks,0)
FROM TimeCurrent.dbo.tblClients_AssignmentType
WHERE Client = @Client AND AssignmentTypeID = 1 AND RefreshCode = 'V';

-- update @AdditionalVMSLateTimeEntryWks with AdditionalCPAWeeks so we can keep the code same but just update this variable for 'C'
IF @RecordType IN ('C', 'S')
BEGIN
    SELECT  @AdditionalVMSLateTimeEntryWks = AdditionalCPAWeeks
    FROM    TimeCurrent..tblClients c
    WHERE   c.Client = @Client; 
END

IF EXISTS
(
	SELECT * FROM tempdb.dbo.sysobjects
	WHERE id = object_id(N'tempdb.dbo.#groupLastPPED')
)

DROP TABLE #groupLastPPED;
CREATE TABLE #groupLastPPED  
(  
  Client          VARCHAR(4),  
  GroupCode       INT,  
  PPED            DATETIME, 
  LateTimeEntryWeeks INT, 
  LateTimeCutoff  DATETIME,
  RecordType		VARCHAR(1) NOT NULL DEFAULT 'A' -- Default everything to Approved Only
)  

IF EXISTS
(
	SELECT * FROM tempdb.dbo.sysobjects
	WHERE id = object_id(N'tempdb.dbo.#groupPPED')
)

DROP TABLE #groupPPED;
CREATE TABLE #groupPPED  
(  
  Client          VARCHAR(4),  
  GroupCode       INT,  
  PPED            DATETIME,
  RecordType	  VARCHAR(1)
);
CREATE CLUSTERED INDEX CIDX_groupPPED_PK ON #groupPPED
(Client,GroupCode,PPED);

IF EXISTS
(
	SELECT * FROM tempdb.dbo.sysobjects
	WHERE id = object_id(N'tempdb.dbo.#groupALTEWks')
)

DROP TABLE #groupALTEWks;
CREATE TABLE #groupALTEWks  
(  
  Client CHAR(4)
 ,GroupCode INT
 ,PPED DATE
 ,RecordType CHAR(1)
);

--   (Use @PayrollType parameter in the "payroll type" field of the scheduled job.)  
/*  
  A = Approved Only  
  F = Approved and Unapproved  
  L = Late Time Only   
  P = Employees whose time was approved after it was sent unapproved in the pay file  
  D = Return Client/Group/PPED's that we need to check for disputes in  
  EXPENSES = Expense report file  
*/  
  
INSERT INTO #groupLastPPED(Client, GroupCode, PPED, LateTimeEntryWeeks, LateTimeCutoff)  
SELECT cg.Client, cg.GroupCode, MAX(ped.PayrollPeriodEndDate), cg.LateTimeEntryWeeks
, LateTimeCutoff = DATEADD(dd,cg.LateTimeEntryWeeks * 7 * -1, MAX(ped.PayrollPeriodEndDate))
FROM TimeCurrent.[dbo].tblClientGroups cg WITH(NOLOCK)  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = [cg].[Client]  
AND ped.GroupCode = [cg].[GroupCode]  
AND ped.PayrollPeriodEndDate < @Today
WHERE cg.Client = @Client  
AND cg.RecordStatus = '1'  
AND cg.IncludeInUpload = '1'  
AND cg.StaffingSetupType = '1'  
GROUP BY cg.Client, cg.GroupCode, cg.LateTimeEntryWeeks

CREATE INDEX IDX_groupLastPPED_PK ON #groupLastPPED (Client,GroupCode,PPED) INCLUDE (LateTimeCutoff)

IF (@RecordType IN ('C', 'S'))
BEGIN
	UPDATE #groupLastPPED
	SET RecordType = @RecordType
END

-- Standard Sweep File (F) and Corrections Sweep File (S)
IF (@RecordType IN ('F', 'S'))
BEGIN
	UPDATE #groupLastPPED
	SET RecordType = @RecordType
	WHERE (
		   (CASE WHEN DATEPART(dw, PPED) = 2 AND DATEPART(dw, @Today) = 5 THEN 1 ELSE 0 END = 1) -- EOW Monday
		OR (CASE WHEN DATEPART(dw, PPED) = 3 AND DATEPART(dw, @Today) = 6 THEN 1 ELSE 0 END = 1) -- EOW Tuesday
		OR (CASE WHEN DATEPART(dw, PPED) = 4 AND DATEPART(dw, @Today) = 6 THEN 1 ELSE 0 END = 1) -- EOW Wednesday
		OR (CASE WHEN DATEPART(dw, PPED) IN (5,6,7,1) AND DATEPART(dw, @Today) IN (2, 3, 4) THEN 1 ELSE 0 END = 1) -- EOW Wednesday  
		  )
END

-- Close out "Last Week"  
IF (@RecordType = 'F' AND @TestingFlag = 'N')  
BEGIN  
  DECLARE @CloseClient varchar(4)  
  DECLARE @CloseGroupCode int   
  DECLARE @ClosePPED datetime   
    
  -- Close the current week and make it available for Late Time Entry  
  UPDATE ped    
  SET [Status] = 'C',  
      OverrideStatus = '1',  
      WeekClosedDateTime = @Now,  
      MaintUserName = 'System',  
      MaintDateTime = @Now  
  FROM TimeHistory.dbo.tblPeriodEndDates ped  
  INNER JOIN #groupLastPPED tmp  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate = tmp.PPED  
  WHERE tmp.RecordType = 'F'
  AND (ped.Status <> 'C' OR ISNULL(ped.OverrideStatus, '') <> '1')
      
  -- Let the oldest of the three weeks drop off so that it can't be used anymore on WTE  
  UPDATE ped  
  SET OverrideStatus = '0',  
      MaintUserName = 'System',  
      MaintDateTime = @Now  
  FROM TimeHistory.dbo.tblPeriodEndDates ped  
  INNER JOIN #groupLastPPED tmp  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate <= tmp.PPED  
  AND ped.PayrollPeriodEndDate <= tmp.LateTimeCutoff  
  AND ISNULL(ped.OverrideStatus, '') <> '0'    
  WHERE tmp.RecordType = 'F'
  AND ped.OverrideStatus = '1'
    
  DECLARE closeCursor CURSOR READ_ONLY  
  FOR SELECT Client, GroupCode, PPED  
      FROM #groupLastPPED  
	  WHERE RecordType = 'F'
  
  OPEN closeCursor  
  
  FETCH NEXT FROM closeCursor INTO @CloseClient, @CloseGroupCode, @ClosePPED  
  WHILE (@@fetch_status <> -1)  
  BEGIN  
   IF (@@fetch_status <> -2)  
   BEGIN  
      EXEC TimeHistory.dbo.usp_Web1_PayPeriodClose_AddTrigger @CloseClient, @CloseGroupCode, 0, @ClosePPED, 'ClosedGroupPeriod'  
   END  
   FETCH NEXT FROM closeCursor INTO @CloseClient, @CloseGroupCode, @ClosePPED  
  END  
  CLOSE closeCursor  
  DEALLOCATE closeCursor    
END  
  
-- Fill out the remaining PPED's that need to be included  
INSERT INTO #groupPPED(Client, GroupCode, PPED, RecordType)  
SELECT ped.Client, ped.GroupCode, ped.PayrollPeriodEndDate, tmp.RecordType  
FROM #groupLastPPED tmp  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode  
AND ped.PayrollPeriodEndDate BETWEEN tmp.LateTimeCutoff AND tmp.PPED   

CREATE STATISTICS statG_PPED ON #groupPPED
(PPED) WITH FULLSCAN;

SELECT @MaxAAWeek = MAX(PPED),@MinAAWeek = MIN(PPED) FROM #groupPPED;

INSERT INTO #groupALTEWks(Client,GroupCode,PPED,RecordType)  
SELECT ped.Client,ped.GroupCode,ped.PayrollPeriodEndDate,tmp.RecordType
FROM #groupLastPPED tmp
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode
WHERE ped.PayrollPeriodEndDate < tmp.LateTimeCutoff
AND ped.PayrollPeriodEndDate >= 
 DATEADD(WK,-1*ISNULL(@AdditionalVMSLateTimeEntryWks,0),tmp.LateTimeCutoff);

CREATE UNIQUE NONCLUSTERED INDEX uncixALTEW ON #groupALTEWks
(Client,GroupCode,PPED);
CREATE STATISTICS statALTEW_PPED ON #groupALTEWks
(PPED) WITH FULLSCAN;

SELECT @VMSRangeStart = MIN(PPED),@VMSRangeEnd = MAX(PPED) FROM #groupALTEWks;

Create Table #tmpAssSumm  
(   
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    SSN               INT,  
    SiteNo            INT,
    DeptNo            INT, 
	AprvlStatus			CHAR(1),
	AprvlStatus_UserID	INT, 
	UserCode			VARCHAR (5),
    TransCount        INT,   
    ApprovedCount     INT,  
    PayRecordsSent    DATETIME,    
    IVR_Count         INT,   
    WTE_Count         INT,   
    Fax_Count         INT,   
	DLT_Count		  INT,
    FaxApprover_Count INT,    
    EmailClient_Count INT,  
    EmailOther_Count  INT,   
    Dispute_Count     INT,  
    OtherTxns_Count   INT,  
    AssignmentNo      VARCHAR(50),  
    LateApprovals     INT,  
    Client_Count      INT,
    Branch_Count      INT,
    SubVendorAgency_Count INT,
    Interface_Count   INT,
    Mobile_Count      INT,
    Mobile_Approver   INT,
    Web_Approver_Count INT,
    Clock_Count       INT, 
    SnapshotDateTime  DATETIME,  
    JobID             INT,  
    AttachmentName    VARCHAR(200),  
    ApprovalMethodID  INT,  
    WorkState         VARCHAR(2),  
    IsSubVendor       VARCHAR(1),  
    ApproverName      VARCHAR(100),  
    ApproverEmail     VARCHAR(100), 
    ApprovalStatus    CHAR(1),  
    ApprovalDateTime  DATETIME,  
    MaxRecordID       INT,
    TimeSource        VARCHAR(1), 
    ApprovalSource    VARCHAR(1), 
	VendorReferenceID VARCHAR(100),
	AssignmentTypeID  INT,
	ExcludeFromPayfile	BIT,
	SendAsRegInPayfile	BIT,
	SendAsUnapproved	BIT,
	NoHours				BIT,
	Brand				VARCHAR(32),
	OpenDisputeCount	INT 
)  
 
Create Table #tmpAss_TransDate  
(   
    Client                VARCHAR(4),  
    GroupCode             INT,  
    PayrollPeriodEndDate  DATETIME,   
    SSN                   INT,  
    SiteNo                INT,
    DeptNo                INT, 
    TransDate             DATETIME,
	ADP_HoursCode		  VARCHAR(50),
	ADP_EarningsCode	  VARCHAR(50),
	Payable				  VARCHAR(1),
	Billable			  VARCHAR(1),
    TotalHours            NUMERIC(7, 2),  
    RegHours              NUMERIC(7, 2),  
    OTHours               NUMERIC(7, 2),  
    DTHours               NUMERIC(7, 2),  
    CalcHours             NUMERIC(7, 2),
	Dollars				  NUMERIC(9, 2),
	NoHours				  BIT
)  
 
Create Table #tmpUploadExport  
(  
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    weDate            VARCHAR(10),
    SSN               INT,  
    EmployeeID        VARCHAR(50),
    EmpName           VARCHAR(50),
    SiteNo            INT,
    DeptNo            INT, 
    AssignmentNo      VARCHAR(50),  
    TransDate         DATETIME,
    SnapshotDateTime  DATETIME,  
    AttachmentName    VARCHAR(200),  
    WorkState         VARCHAR(2),  
    ApproverName      VARCHAR(100), 
    ApproverEmail     VARCHAR(100),  
    ApprovalStatus    CHAR(1),  
    ApprovalDateTime  DATETIME,  
    TimeSource        VARCHAR(1), 
    ApprovalSource    VARCHAR(1), 
    PayCode           VARCHAR(50),
    WorkedHours       NUMERIC(7, 2),
    PayAmt            NUMERIC(7, 2),
    BillAmt           NUMERIC(7, 2),
    Line1             VARCHAR(1000),
    LateApprovals     VARCHAR(1),
    FileBreakID       VARCHAR(50),
    CRF1_Name         VARCHAR(50) DEFAULT '',
    CRF1_Value        VARCHAR(512) DEFAULT '',
    CRF2_Name         VARCHAR(50) DEFAULT '',
    CRF2_Value        VARCHAR(512) DEFAULT '',
    CRF3_Name         VARCHAR(50) DEFAULT '',
    CRF3_Value        VARCHAR(512) DEFAULT '',
    CRF4_Name         VARCHAR(50) DEFAULT '',
    CRF4_Value        VARCHAR(512) DEFAULT '',
    CRF5_Name         VARCHAR(50) DEFAULT '',
    CRF5_Value        VARCHAR(512) DEFAULT '',
    CRF6_Name         VARCHAR(50) DEFAULT '',
    CRF6_Value        VARCHAR(512) DEFAULT '',
	VendorReferenceID VARCHAR(100)                   
)
 
--Used to return a list of Groups and PPED's to VB to auto-resolve disputes  
IF (@RecordType = 'D')  
BEGIN  
  INSERT INTO #tmpUploadExport( Client, GroupCode, SSN, PayrollPeriodEndDate, weDate, EmployeeID, EmpName, FileBreakID, Line1, PayCode, SiteNo, DeptNo)  
  SELECT @Client, GroupCode, 1, PPED, CONVERT(VARCHAR(10), PPED, 101), '', '', '', '', '', 0, 0
  FROM #groupPPED  
    
  SELECT *
  FROM #tmpUploadExport  
    
  DROP TABLE #tmpUploadExport  
    
  RETURN         
END 
ELSE IF (@RecordType IN ('A','L','F'))  
BEGIN  
  --PRINT 'Before: INSERT INTO #tmpAssSumm' + CONVERT(VARCHAR, GETDATE(), 121)  
  INSERT INTO #tmpAssSumm  
  (  
        Client  
      , GroupCode  
      , PayrollPeriodEndDate  
      , SSN  
      , SiteNo
      , DeptNo
	  , PayRecordsSent  
      , AssignmentNo  
      , TransCount  
      , ApprovedCount  
      , ApprovalDateTime
      , IVR_Count  
      , WTE_Count  
      , Fax_Count  
	  , DLT_Count
      , FaxApprover_Count  
      , EmailClient_Count  
      , EmailOther_Count  
      , Dispute_Count  
      , OtherTxns_Count  
      , LateApprovals  
      , Client_Count 
      , Branch_Count 
      , SubVendorAgency_Count
      , Interface_Count
      , Mobile_Count 
      , Mobile_Approver
      , Web_Approver_Count
      , Clock_Count      
      , SnapshotDateTime  
      , JobID  
      , AttachmentName  
      , ApprovalMethodID  
      , WorkState  
      , IsSubVendor       
      , MaxRecordID  
	  , VendorReferenceID
	  , AssignmentTypeID
	  , NoHours
	  , Brand
	  , OpenDisputeCount
  )  
  SELECT   
       t.Client  
     , t.GroupCode  
     , t.PayrollPeriodEndDate  
     , t.SSN  
     , t.SiteNo
     , t.DeptNo       
     , PayRecordsSent = th_esds.PayRecordsSent
     , ea.AssignmentNo  
     , TransCount = SUM(1)  
     , ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)  
     , ApprovalDateTime = MAX(isnull(t.AprvlStatus_Date, '1/2/1970'))  
     , IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)  
     , WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END)  
     , Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)  
	 , DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1 ELSE 0 END)
     , FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID, 0) = @FaxApprover THEN 1 ELSE 0 END)  
     , EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)  
     , EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END)  
     , Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('@') THEN 1 ELSE 0 END)  
     , OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END)  
     , LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > th_esds.PayRecordsSent THEN 1 ELSE 0 END)  
     , Client_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
     , Branch_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('BRA')) THEN 1 ELSE 0 END)
     , SubVendorAgency_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('AGE')) THEN 1 ELSE 0 END)
     , Interface_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('INT')) THEN 1 ELSE 0 END)
     , Mobile_Count = SUM( CASE WHEN ISNULL(th_en.Mobile, 0) = 0 THEN 0 ELSE 1 END )
     , Mobile_Approver = SUM( CASE WHEN ISNULL(t.[AprvlStatus_Mobile],0) = 0 THEN 0 ELSE 1 END )
     , Web_Approver_Count = 0
     , Clock_Count = 0
     , SnapshotDateTime = @Now  
     , JobID = 0  
     , AttachmentName = th_esds.RecordID  
     , ApprovalMethodID = ea.ApprovalMethodID  
     , WorkState = ISNULL(ea.WorkState, '')  
     , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
     , MAX(t.RecordID)
	 , th_esds.VendorReferenceID
	 , ea.AssignmentTypeID
	 , '0'
	 , ea.Brand
	 , OpenDisputeCount = SUM(CASE WHEN t.AprvlStatus = 'D' THEN 1 ELSE 0 END)
  FROM #groupPPED grpped  
  INNER JOIN TimeHistory.dbo.tblTimeHistDetail as t  
  ON t.Client = grpped.Client  
  AND t.Groupcode = grpped.GroupCode  
  AND t.PayrollPeriodEndDate = grpped.PPED  
  INNER JOIN TimeCurrent.dbo.tblEmplAssignments as ea  WITH(NOLOCK) 
  ON  ea.Client = t.Client  
  AND ea.Groupcode = t.Groupcode  
  AND ea.SSN = t.SSN  
  AND ea.SiteNo = t.SiteNo
  AND ea.DeptNo =  t.DeptNo  
  INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds  WITH(NOLOCK) 
  ON  th_esds.Client = t.Client  
  AND th_esds.GroupCode = t.GroupCode  
  AND th_esds.SSN = t.SSN  
  AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
  AND th_esds.SiteNo = t.SiteNo  
  AND th_esds.DeptNo = t.DeptNo  
  AND th_esds.PayRecordsSent IS NULL
  INNER JOIN TimeHistory.dbo.tblEmplNames th_en  WITH(NOLOCK) 
  ON  th_en.Client = t.Client  
  AND th_en.GroupCode = t.GroupCode  
  AND th_en.SSN = t.SSN  
  AND th_en.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
  LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)  
  ON a.client = ea.Client  
  AND a.GroupCode = ea.GroupCode  
  AND a.Agency = ea.AgencyNo   
  --Ignore those records in tblWTE_Spreadsheet_ClosedPeriodAdjustment as they will be sent in Corrected file
	LEFT JOIN TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
		ON t.Client = cpa.Client
		AND t.GroupCode = cpa.GroupCode
		AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
		AND t.SSN = cpa.SSN
		AND t.SiteNo = cpa.SiteNo
		AND t.DeptNo = cpa.DeptNo 
		AND cpa.Status <> '4'
 	WHERE t.Client = @Client
	AND t.PayrollPeriodEndDate >= @MinAAWeek
	AND t.PayrollPeriodEndDate <= @MaxAAWeek
	AND (t.Hours <> 0 OR t.Dollars <> 0)
	AND cpa.RecordID IS NULL
  GROUP BY  
        t.Client  
      , t.GroupCode  
      , t.PayrollPeriodEndDate  
      , t.SSN  
      , t.SiteNo
      , t.DeptNo
      , th_esds.PayRecordsSent
      , ea.AssignmentNo  
      , ea.approvalMethodID  
      , th_esds.RecordID  
      , ISNULL(ea.WorkState, '')  
      , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
	  , th_esds.VendorReferenceID
	  , ea.AssignmentTypeID
	  , ea.Brand
  --PRINT 'After: INSERT INTO #tmpAssSumm A, L, F' + CONVERT(VARCHAR, GETDATE(), 121)          

 --INSERT VMS LateTimeEntryRecords
 INSERT INTO #tmpAssSumm  
 (
  Client,GroupCode,PayrollPeriodEndDate,SSN,SiteNo,DeptNo,PayRecordsSent,AssignmentNo
 ,TransCount,ApprovedCount,ApprovalDateTime,IVR_Count,WTE_Count,Fax_Count,DLT_Count
 ,FaxApprover_Count,EmailClient_Count,EmailOther_Count,Dispute_Count,OtherTxns_Count
 ,LateApprovals,Client_Count ,Branch_Count ,SubVendorAgency_Count,Interface_Count
 ,Mobile_Count,Mobile_Approver,Web_Approver_Count,Clock_Count,SnapshotDateTime,JobID
 ,AttachmentName,ApprovalMethodID,WorkState,IsSubVendor,MaxRecordID,VendorReferenceID
 ,AssignmentTypeID,NoHours,Brand,OpenDisputeCount
 )
 SELECT 
  t.Client,t.GroupCode,t.PayrollPeriodEndDate,t.SSN,t.SiteNo,t.DeptNo
 ,PayRecordsSent = th_esds.PayRecordsSent
 ,ea.AssignmentNo,TransCount = SUM(1)
 ,ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)
 ,ApprovalDateTime = MAX(isnull(t.AprvlStatus_Date, '1/2/1970'))
 ,IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)
 ,WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END)
 ,Fax_Count = SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)
 ,DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1 ELSE 0 END)
 ,FaxApprover_Count = SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID, 0) = @FaxApprover THEN 1 ELSE 0 END)
 ,EmailClient_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
 ,EmailOther_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END)
 ,Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('@') THEN 1 ELSE 0 END)
 ,OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END)
 ,LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > th_esds.PayRecordsSent THEN 1 ELSE 0 END)
 ,Client_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
 ,Branch_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('BRA')) THEN 1 ELSE 0 END)
 ,SubVendorAgency_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('AGE')) THEN 1 ELSE 0 END)
 ,Interface_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('INT')) THEN 1 ELSE 0 END)
 ,Mobile_Count = SUM( CASE WHEN ISNULL(th_en.Mobile, 0) = 0 THEN 0 ELSE 1 END )
 ,Mobile_Approver = SUM( CASE WHEN ISNULL(t.[AprvlStatus_Mobile],0) = 0 THEN 0 ELSE 1 END )
 ,Web_Approver_Count = 0
 ,Clock_Count = 0
 ,SnapshotDateTime = @Now
 ,JobID = 0
 ,AttachmentName = th_esds.RecordID
 ,ApprovalMethodID = ea.ApprovalMethodID
 ,WorkState = ISNULL(ea.WorkState, '')
 ,IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
 ,MaxRecordID = MAX(t.RecordID)
 ,th_esds.VendorReferenceID
 ,ea.AssignmentTypeID
 ,'0' -- NoHours
 ,ea.Brand
 , OpenDisputeCount = SUM(CASE WHEN t.AprvlStatus = 'D' THEN 1 ELSE 0 END)
 FROM #groupALTEWks grpped
 INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS t
 ON t.Client = grpped.Client
 AND t.Groupcode = grpped.GroupCode
 AND t.PayrollPeriodEndDate = grpped.PPED
 INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea WITH(NOLOCK)
 ON  ea.Client = t.Client  
 AND ea.Groupcode = t.Groupcode  
 AND ea.SSN = t.SSN  
 AND ea.SiteNo = t.SiteNo
 AND ea.DeptNo =  t.DeptNo  
 INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds WITH(NOLOCK)
 ON  th_esds.Client = t.Client  
 AND th_esds.GroupCode = t.GroupCode  
 AND th_esds.SSN = t.SSN  
 AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
 AND th_esds.SiteNo = t.SiteNo  
 AND th_esds.DeptNo = t.DeptNo  
 INNER JOIN TimeHistory.dbo.tblEmplNames th_en WITH(NOLOCK)
 ON  th_en.Client = t.Client  
 AND th_en.GroupCode = t.GroupCode  
 AND th_en.SSN = t.SSN  
 AND th_en.PayrollPeriodEndDate = t.PayrollPeriodEndDate
 INNER JOIN TimeCurrent.dbo.tblClients_AssignmentType tcCAT WITH(NOLOCK)
 ON tcCAT.Client = ea.Client
 AND tcCAT.AssignmentTypeID = ea.AssignmentTypeID
 LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)
 ON a.client = ea.Client  
 AND a.GroupCode = ea.GroupCode  
 AND a.Agency = ea.AgencyNo
 LEFT JOIN TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
	ON t.Client = cpa.Client
	AND t.GroupCode = cpa.GroupCode
	AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
	AND t.SSN = cpa.SSN
	AND t.SiteNo = cpa.SiteNo
	AND t.DeptNo = cpa.DeptNo
	AND cpa.Status <> '4'
 WHERE t.Client = @Client
 AND t.GroupCode < 100000
 AND t.PayrollPeriodEndDate BETWEEN @VMSRangeStart AND @VMSRangeEnd
 AND t.[Hours] <> 0
 AND th_esds.PayRecordsSent IS NULL
 AND tcCAT.AssignmentTypeID = 1 AND tcCAT.RefreshCode = 'V'
 AND cpa.RecordID IS NULL -- To restrict adjusted PPED records to go in the pay file
 GROUP BY
 t.Client  
 ,t.GroupCode  
 ,t.PayrollPeriodEndDate  
 ,t.SSN  
 ,t.SiteNo
 ,t.DeptNo
 ,th_esds.PayRecordsSent
 ,ea.AssignmentNo  
 ,ea.approvalMethodID  
 ,th_esds.RecordID  
 ,ISNULL(ea.WorkState, '')  
 ,CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
 ,th_esds.VendorReferenceID
 ,ea.AssignmentTypeID
 ,ea.Brand;
END
ELSE IF (@RecordType IN ('C', 'S'))
BEGIN
	--PRINT '@MinAAWeek: ' + CAST(@MinAAWeek AS VARCHAR)
	--PRINT '@MaxAAWeek: ' + CAST(@MaxAAWeek AS VARCHAR)

	--SELECT * from #groupPPED

	--#region Populate #tmpAssSumm with #groupPPED
	INSERT  INTO #tmpAssSumm
	( Client ,
		GroupCode ,
		PayrollPeriodEndDate ,
		SSN ,
		SiteNo ,
		DeptNo ,
		PayRecordsSent ,
		AssignmentNo ,
		TransCount ,
		ApprovedCount ,
		ApprovalDateTime ,
		IVR_Count ,
		WTE_Count ,
		Fax_Count ,
		DLT_Count ,
		FaxApprover_Count ,
		EmailClient_Count ,
		EmailOther_Count ,
		Dispute_Count ,
		OtherTxns_Count ,
		LateApprovals ,
		Client_Count ,
		Branch_Count ,
		SubVendorAgency_Count ,
		Interface_Count ,
		Mobile_Count ,
		Mobile_Approver ,
		Web_Approver_Count ,
		Clock_Count ,
		SnapshotDateTime ,
		JobID ,
		AttachmentName ,
		ApprovalMethodID ,
		WorkState ,
		IsSubVendor ,
		MaxRecordID ,
		VendorReferenceID ,
		AssignmentTypeID,
		NoHours,
		Brand,
		OpenDisputeCount
	)
	SELECT  t.Client ,
			t.GroupCode ,
			t.PayrollPeriodEndDate ,
			t.SSN ,
			t.SiteNo ,
			t.DeptNo ,
			PayRecordsSent = th_esds.PayRecordsSent ,
			ea.AssignmentNo ,
			TransCount = SUM(1) ,
			ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ( 'A',
													'L' ) THEN 1
										ELSE 0
								END) ,
			ApprovalDateTime = MAX(ISNULL(t.AprvlStatus_Date,
											'1/2/1970')) ,
			IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1
									ELSE 0
							END) ,
			WTE_Count = SUM(CASE WHEN t.UserCode IN ( 'WTE', 'VTS' )
									THEN 1
									ELSE 0
							END) ,
			Fax_Count = SUM(CASE WHEN t.UserCode = 'FAX' THEN 1
									ELSE 0
							END) ,
			DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1
									ELSE 0
							END) ,
			FaxApprover_Count = SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID,
													0) = @FaxApprover
											THEN 1
											ELSE 0
									END) ,
			EmailClient_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
												AND t.OutUserCode = 'CLI'
												) THEN 1
											ELSE 0
									END) ,
			EmailOther_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
												AND t.OutUserCode IN (
												'BRA', 'COR', 'AGE' )
												) THEN 1
										ELSE 0
									END) ,
			Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN (
											'@' ) THEN 1
										ELSE 0
								END) ,
			OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN (
											'$', '@', '' )
											AND ISNULL(t.UserCode,
													'') NOT IN (
											'WTE', 'COR', 'FAX',
											'EML', 'SYS' )
											AND ISNULL(t.OutUserCode,
													'') NOT IN (
											'CLI', 'BRA', 'COR',
											'AGE' ) THEN 1
										ELSE 0
									END) ,
			LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > th_esds.PayRecordsSent
										THEN 1
										ELSE 0
								END) ,
			Client_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
											AND t.OutUserCode = 'CLI'
											) THEN 1
									ELSE 0
								END) ,
			Branch_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
											AND t.OutUserCode IN (
											'BRA' )
											) THEN 1
									ELSE 0
								END) ,
			SubVendorAgency_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
													AND t.OutUserCode IN (
													'AGE' )
													) THEN 1
												ELSE 0
										END) ,
			Interface_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
												AND t.OutUserCode IN (
												'INT' )
											) THEN 1
										ELSE 0
									END) ,
			Mobile_Count = SUM(CASE WHEN ISNULL(th_en.Mobile, 0) = 0
									THEN 0
									ELSE 1
								END) ,
			Mobile_Approver = SUM(CASE WHEN ISNULL(t.[AprvlStatus_Mobile],
													0) = 0 THEN 0
										ELSE 1
									END) ,
			Web_Approver_Count = 0 ,
			Clock_Count = 0 ,
			SnapshotDateTime = @Now ,
			JobID = 0 ,
			AttachmentName = th_esds.RecordID ,
			ApprovalMethodID = ea.ApprovalMethodID ,
			WorkState = ISNULL(ea.WorkState, '') ,
			IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> ''
								THEN '1'
								ELSE '0'
							END ,
			MAX(t.RecordID) ,
			th_esds.VendorReferenceID ,
			ea.AssignmentTypeId,
			'0',
			ea.Brand,
			OpenDisputeCount = SUM(CASE WHEN t.AprvlStatus = 'D' THEN 1 ELSE 0 END)
	FROM    #groupPPED grpped
			INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS t ON t.Client = grpped.Client
													AND t.GroupCode = grpped.GroupCode
													AND t.PayrollPeriodEndDate = grpped.PPED
			INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea
			WITH ( NOLOCK ) ON ea.Client = t.Client
								AND ea.GroupCode = t.GroupCode
								AND ea.SSN = t.SSN
								AND ea.SiteNo = t.SiteNo
								AND ea.DeptNo = t.DeptNo
			INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds
			WITH ( NOLOCK ) ON th_esds.Client = t.Client
								AND th_esds.GroupCode = t.GroupCode
								AND th_esds.SSN = t.SSN
								AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
								AND th_esds.SiteNo = t.SiteNo
								AND th_esds.DeptNo = t.DeptNo
								AND th_esds.PayRecordsSent IS NULL
			INNER JOIN TimeHistory.dbo.tblEmplNames th_en WITH ( NOLOCK ) ON th_en.Client = t.Client
													AND th_en.GroupCode = t.GroupCode
													AND th_en.SSN = t.SSN
													AND th_en.PayrollPeriodEndDate = t.PayrollPeriodEndDate
			LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH ( NOLOCK ) ON a.Client = ea.Client
													AND a.GroupCode = ea.GroupCode
													AND a.Agency = ea.AgencyNo
	WHERE   t.Client = @Client
			AND t.PayrollPeriodEndDate >= @MinAAWeek
			AND t.PayrollPeriodEndDate <= @MaxAAWeek
			AND (t.Hours <> 0 OR t.Dollars <> 0)
			AND EXISTS (SELECT 1
						FROM TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
						WHERE t.Client = cpa.Client
						AND t.GroupCode = cpa.GroupCode
						AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
						AND t.SSN = cpa.SSN
						AND t.SiteNo = cpa.SiteNo
						AND t.DeptNo = cpa.DeptNo
						AND cpa.Status <> '4')
			--AND t.SSN = 100102317
	GROUP BY t.Client ,
			t.GroupCode ,
			t.PayrollPeriodEndDate ,
			t.SSN ,
			t.SiteNo ,
			t.DeptNo ,
			th_esds.PayRecordsSent ,
			ea.AssignmentNo ,
			ea.ApprovalMethodID ,
			th_esds.RecordID ,
			ISNULL(ea.WorkState, '') ,
			CASE WHEN ISNULL(a.ClientAgencyCode, '') <> ''
					THEN '1'
					ELSE '0'
			END ,
			th_esds.VendorReferenceID ,
			ea.AssignmentTypeId,
			ea.Brand;
	--#region Populate #tmpAssSumm with #groupALTEWks

	--PRINT '@VMSRangeStart: ' + CAST(@VMSRangeStart AS VARCHAR)
	--PRINT '@VMSRangeEnd: ' + CAST(@VMSRangeEnd AS VARCHAR)
	--SELECT '#groupALTEWks'
	--SELECT * FROM #groupALTEWks WHERE groupcode = 172 ORDER BY PPED

	--SELECT * FROM #tmpAssSumm

	INSERT  INTO #tmpAssSumm
	( Client ,
		GroupCode ,
		PayrollPeriodEndDate ,
		SSN ,
		SiteNo ,
		DeptNo ,
		PayRecordsSent ,
		AssignmentNo ,
		TransCount ,
		ApprovedCount ,
		ApprovalDateTime ,
		IVR_Count ,
		WTE_Count ,
		Fax_Count ,
		DLT_Count ,
		FaxApprover_Count ,
		EmailClient_Count ,
		EmailOther_Count ,
		Dispute_Count ,
		OtherTxns_Count ,
		LateApprovals ,
		Client_Count ,
		Branch_Count ,
		SubVendorAgency_Count ,
		Interface_Count ,
		Mobile_Count ,
		Mobile_Approver ,
		Web_Approver_Count ,
		Clock_Count ,
		SnapshotDateTime ,
		JobID ,
		AttachmentName ,
		ApprovalMethodID ,
		WorkState ,
		IsSubVendor ,
		MaxRecordID ,
		VendorReferenceID ,
		AssignmentTypeID,
		NoHours,
		Brand,
		OpenDisputeCount
	)
	SELECT  t.Client ,
			t.GroupCode ,
			t.PayrollPeriodEndDate ,
			t.SSN ,
			t.SiteNo ,
			t.DeptNo ,
			PayRecordsSent = th_esds.PayRecordsSent ,
			ea.AssignmentNo ,
			TransCount = SUM(1) ,
			ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ( 'A',
													'L' ) THEN 1
										ELSE 0
								END) ,
			ApprovalDateTime = MAX(ISNULL(t.AprvlStatus_Date,
											'1/2/1970')) ,
			IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1
									ELSE 0
							END) ,
			WTE_Count = SUM(CASE WHEN t.UserCode IN ( 'WTE', 'VTS' )
									THEN 1
									ELSE 0
							END) ,
			Fax_Count = SUM(CASE WHEN t.UserCode = 'FAX' THEN 1
									ELSE 0
							END) ,
			DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1
									ELSE 0
							END) ,
			FaxApprover_Count = SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID,
													0) = @FaxApprover
											THEN 1
											ELSE 0
									END) ,
			EmailClient_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
												AND t.OutUserCode = 'CLI'
												) THEN 1
											ELSE 0
									END) ,
			EmailOther_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
												AND t.OutUserCode IN (
												'BRA', 'COR', 'AGE' )
												) THEN 1
										ELSE 0
									END) ,
			Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN (
											'@' ) THEN 1
										ELSE 0
								END) ,
			OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN (
											'$', '@', '' )
											AND ISNULL(t.UserCode,
													'') NOT IN (
											'WTE', 'COR', 'FAX',
											'EML', 'SYS' )
											AND ISNULL(t.OutUserCode,
													'') NOT IN (
											'CLI', 'BRA', 'COR',
											'AGE' ) THEN 1
										ELSE 0
									END) ,
			LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > th_esds.PayRecordsSent
										THEN 1
										ELSE 0
								END) ,
			Client_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
											AND t.OutUserCode = 'CLI'
											) THEN 1
									ELSE 0
								END) ,
			Branch_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
											AND t.OutUserCode IN (
											'BRA' )
											) THEN 1
									ELSE 0
								END) ,
			SubVendorAgency_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
													AND t.OutUserCode IN (
													'AGE' )
													) THEN 1
												ELSE 0
										END) ,
			Interface_Count = SUM(CASE WHEN ( t.UserCode <> t.OutUserCode
												AND t.OutUserCode IN (
												'INT' )
											) THEN 1
										ELSE 0
									END) ,
			Mobile_Count = SUM(CASE WHEN ISNULL(th_en.Mobile, 0) = 0
									THEN 0
									ELSE 1
								END) ,
			Mobile_Approver = SUM(CASE WHEN ISNULL(t.[AprvlStatus_Mobile],
													0) = 0 THEN 0
										ELSE 1
									END) ,
			Web_Approver_Count = 0 ,
			Clock_Count = 0 ,
			SnapshotDateTime = @Now ,
			JobID = 0 ,
			AttachmentName = th_esds.RecordID ,
			ApprovalMethodID = ea.ApprovalMethodID ,
			WorkState = ISNULL(ea.WorkState, '') ,
			IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> ''
								THEN '1'
								ELSE '0'
							END ,
			MaxRecordID = MAX(t.RecordID) ,
			th_esds.VendorReferenceID ,
			ea.AssignmentTypeId,
			'0',
			ea.Brand,
			OpenDisputeCount = SUM(CASE WHEN t.AprvlStatus = 'D' THEN 1 ELSE 0 END)
	FROM    #groupALTEWks grpped
			INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS t ON t.Client = grpped.Client
													AND t.GroupCode = grpped.GroupCode
													AND t.PayrollPeriodEndDate = grpped.PPED
			INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea
			WITH ( NOLOCK ) ON ea.Client = t.Client
								AND ea.GroupCode = t.GroupCode
								AND ea.SSN = t.SSN
								AND ea.SiteNo = t.SiteNo
								AND ea.DeptNo = t.DeptNo
			INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds
			WITH ( NOLOCK ) ON th_esds.Client = t.Client
								AND th_esds.GroupCode = t.GroupCode
								AND th_esds.SSN = t.SSN
								AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
								AND th_esds.SiteNo = t.SiteNo
								AND th_esds.DeptNo = t.DeptNo
			INNER JOIN TimeHistory.dbo.tblEmplNames th_en WITH ( NOLOCK ) ON th_en.Client = t.Client
													AND th_en.GroupCode = t.GroupCode
													AND th_en.SSN = t.SSN
													AND th_en.PayrollPeriodEndDate = t.PayrollPeriodEndDate
			LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH ( NOLOCK ) ON a.Client = ea.Client
													AND a.GroupCode = ea.GroupCode
													AND a.Agency = ea.AgencyNo
	WHERE   t.Client = @Client
			AND t.GroupCode < 100000
			AND t.PayrollPeriodEndDate BETWEEN @VMSRangeStart AND @VMSRangeEnd
			AND (t.Hours <> 0 OR t.Dollars <> 0)
			AND th_esds.PayRecordsSent IS NULL
			AND EXISTS (SELECT 1
						FROM TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa 
						WHERE t.Client = cpa.Client
						AND t.GroupCode = cpa.GroupCode
						AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
						AND t.SSN = cpa.SSN
						AND t.SiteNo = cpa.SiteNo
						AND t.DeptNo = cpa.DeptNo
						AND cpa.Status <> '4')
			--AND t.SSN = 100102317
	GROUP BY t.Client ,
			t.GroupCode ,
			t.PayrollPeriodEndDate ,
			t.SSN ,
			t.SiteNo ,
			t.DeptNo ,
			th_esds.PayRecordsSent ,
			ea.AssignmentNo ,
			ea.ApprovalMethodID ,
			th_esds.RecordID ,
			ISNULL(ea.WorkState, '') ,
			CASE WHEN ISNULL(a.ClientAgencyCode, '') <> ''
					THEN '1'
					ELSE '0'
			END ,
			th_esds.VendorReferenceID ,
			ea.AssignmentTypeId,
			ea.Brand
	--#endregion Populate #tmpAssSumm with #groupALTEWks
	
	-- Did Not Work - Late Time Entry Period
	INSERT  INTO #tmpAssSumm
	( Client ,
		GroupCode ,
		PayrollPeriodEndDate ,
		SSN ,
		SiteNo ,
		DeptNo ,
		PayRecordsSent ,
		AssignmentNo ,
		TransCount ,
		ApprovedCount ,
		ApprovalDateTime ,
		IVR_Count ,
		WTE_Count ,
		Fax_Count ,
		DLT_Count ,
		FaxApprover_Count ,
		EmailClient_Count ,
		EmailOther_Count ,
		Dispute_Count ,
		OtherTxns_Count ,
		LateApprovals ,
		Client_Count ,
		Branch_Count ,
		SubVendorAgency_Count ,
		Interface_Count ,
		Mobile_Count ,
		Mobile_Approver ,
		Web_Approver_Count ,
		Clock_Count ,
		SnapshotDateTime ,
		JobID ,
		AttachmentName ,
		ApprovalMethodID ,
		WorkState ,
		IsSubVendor ,
		MaxRecordID ,
		VendorReferenceID ,
		AssignmentTypeID,
		NoHours,
		Brand
	)
	SELECT  th_esds.Client ,
			th_esds.GroupCode ,
			th_esds.PayrollPeriodEndDate ,
			th_esds.SSN ,
			th_esds.SiteNo ,
			th_esds.DeptNo ,
			PayRecordsSent = th_esds.PayRecordsSent ,
			ea.AssignmentNo ,
			TransCount = 1 ,
			ApprovedCount = 1 ,
			ApprovalDateTime = NULL,
			IVR_Count = 0,
			WTE_Count = 1,
			Fax_Count = 0,
			DLT_Count = 0,
			FaxApprover_Count = 0,
			EmailClient_Count = 0,
			EmailOther_Count = 0,
			Dispute_Count = 0,
			OtherTxns_Count = 0,
			LateApprovals = 0,
			Client_Count = 0,
			Branch_Count = 0,
			SubVendorAgency_Count = 0,
			Interface_Count = 0,
			Mobile_Count = 0 ,
			Mobile_Approver = 0,
			Web_Approver_Count = 0 ,
			Clock_Count = 0 ,
			SnapshotDateTime = @Now ,
			JobID = 0 ,
			AttachmentName = th_esds.RecordID ,
			ApprovalMethodID = ea.ApprovalMethodID ,
			WorkState = ISNULL(ea.WorkState, '') ,
			IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> ''
								THEN '1'
								ELSE '0'
							END ,
			MaxRecordID = 0 ,
			th_esds.VendorReferenceID ,
			ea.AssignmentTypeId,
			'1',
			ea.Brand
	FROM    #groupPPED grpped
			INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds WITH ( NOLOCK )
			ON th_esds.Client = grpped.Client
			AND th_esds.GroupCode = grpped.GroupCode
			AND th_esds.PayrollPeriodEndDate = grpped.PPED
			AND th_esds.PayRecordsSent IS NULL
			INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea WITH ( NOLOCK )
			ON ea.Client = th_esds.Client
			AND ea.GroupCode = th_esds.GroupCode
			AND ea.SSN = th_esds.SSN
			AND ea.SiteNo = th_esds.SiteNo
			AND ea.DeptNo = th_esds.DeptNo		
			INNER JOIN TimeHistory.dbo.tblEmplNames th_en WITH ( NOLOCK ) 
			ON th_en.Client = th_esds.Client
			AND th_en.GroupCode = th_esds.GroupCode
			AND th_en.SSN = th_esds.SSN
			AND th_en.PayrollPeriodEndDate = th_esds.PayrollPeriodEndDate
			LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH ( NOLOCK ) 
			ON a.Client = ea.Client
			AND a.GroupCode = ea.GroupCode
			AND a.Agency = ea.AgencyNo
	WHERE   th_esds.Client = @Client
			AND th_esds.GroupCode < 100000
			AND th_esds.PayrollPeriodEndDate >= @MinAAWeek
			AND th_esds.PayrollPeriodEndDate <= @MaxAAWeek
			AND th_esds.NoHours = '1'
			AND EXISTS (SELECT 1
						FROM TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
						WHERE th_esds.Client = cpa.Client
						AND th_esds.GroupCode = cpa.GroupCode
						AND th_esds.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
						AND th_esds.SSN = cpa.SSN
						AND th_esds.SiteNo = cpa.SiteNo
						AND th_esds.DeptNo = cpa.DeptNo
						AND cpa.Status <> '4')
			AND NOT EXISTS (SELECT 1
							FROM #tmpAssSumm tas
							WHERE tas.Client = th_esds.Client
							AND tas.GroupCode = th_esds.GroupCode
							AND tas.SSN = th_esds.SSN
							AND tas.SiteNo = th_esds.SiteNo
							AND tas.DeptNo = th_esds.DeptNo
							AND tas.PayrollPeriodEndDate = th_esds.PayrollPeriodEndDate)
			--AND th_esds.SSN = 100102317
			--SELECT * FROM #tmpAssSumm
	-- Did Not Work - Outside Late Time Entry Period
	INSERT  INTO #tmpAssSumm
	( Client ,
		GroupCode ,
		PayrollPeriodEndDate ,
		SSN ,
		SiteNo ,
		DeptNo ,
		PayRecordsSent ,
		AssignmentNo ,
		TransCount ,
		ApprovedCount ,
		ApprovalDateTime ,
		IVR_Count ,
		WTE_Count ,
		Fax_Count ,
		DLT_Count ,
		FaxApprover_Count ,
		EmailClient_Count ,
		EmailOther_Count ,
		Dispute_Count ,
		OtherTxns_Count ,
		LateApprovals ,
		Client_Count ,
		Branch_Count ,
		SubVendorAgency_Count ,
		Interface_Count ,
		Mobile_Count ,
		Mobile_Approver ,
		Web_Approver_Count ,
		Clock_Count ,
		SnapshotDateTime ,
		JobID ,
		AttachmentName ,
		ApprovalMethodID ,
		WorkState ,
		IsSubVendor ,
		MaxRecordID ,
		VendorReferenceID ,
		AssignmentTypeID,
		NoHours,
		Brand
	)
	SELECT  th_esds.Client ,
			th_esds.GroupCode ,
			th_esds.PayrollPeriodEndDate ,
			th_esds.SSN ,
			th_esds.SiteNo ,
			th_esds.DeptNo ,
			PayRecordsSent = th_esds.PayRecordsSent ,
			ea.AssignmentNo ,
			TransCount = 1 ,
			ApprovedCount = 1 ,
			ApprovalDateTime = NULL,
			IVR_Count = 0,
			WTE_Count = 1,
			Fax_Count = 0,
			DLT_Count = 0,
			FaxApprover_Count = 0,
			EmailClient_Count = 0,
			EmailOther_Count = 0,
			Dispute_Count = 0,
			OtherTxns_Count = 0,
			LateApprovals = 0,
			Client_Count = 0,
			Branch_Count = 0,
			SubVendorAgency_Count = 0,
			Interface_Count = 0,
			Mobile_Count = 0 ,
			Mobile_Approver = 0,
			Web_Approver_Count = 0 ,
			Clock_Count = 0 ,
			SnapshotDateTime = @Now ,
			JobID = 0 ,
			AttachmentName = th_esds.RecordID ,
			ApprovalMethodID = ea.ApprovalMethodID ,
			WorkState = ISNULL(ea.WorkState, '') ,
			IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> ''
								THEN '1'
								ELSE '0'
							END ,
			MaxRecordID = 0 ,
			th_esds.VendorReferenceID ,
			ea.AssignmentTypeId,
			'1',
			ea.Brand
	FROM    TimeHistory.dbo.tblEmplSites_Depts th_esds WITH ( NOLOCK )
			INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea WITH ( NOLOCK )
			ON ea.Client = th_esds.Client
			AND ea.GroupCode = th_esds.GroupCode
			AND ea.SSN = th_esds.SSN
			AND ea.SiteNo = th_esds.SiteNo
			AND ea.DeptNo = th_esds.DeptNo		
			INNER JOIN TimeHistory.dbo.tblEmplNames th_en WITH ( NOLOCK ) 
			ON th_en.Client = th_esds.Client
			AND th_en.GroupCode = th_esds.GroupCode
			AND th_en.SSN = th_esds.SSN
			AND th_en.PayrollPeriodEndDate = th_esds.PayrollPeriodEndDate
			LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH ( NOLOCK ) 
			ON a.Client = ea.Client
			AND a.GroupCode = ea.GroupCode
			AND a.Agency = ea.AgencyNo
	WHERE   th_esds.Client = @Client
			AND th_esds.GroupCode < 100000
			AND th_esds.PayrollPeriodEndDate BETWEEN @VMSRangeStart AND @VMSRangeEnd
			AND th_esds.PayRecordsSent IS NULL
			AND th_esds.NoHours = '1'
			AND EXISTS (SELECT 1
						FROM TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
						WHERE th_esds.Client = cpa.Client
						AND th_esds.GroupCode = cpa.GroupCode
						AND th_esds.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
						AND th_esds.SSN = cpa.SSN
						AND th_esds.SiteNo = cpa.SiteNo
						AND th_esds.DeptNo = cpa.DeptNo
						AND cpa.Status <> '4')
			AND NOT EXISTS (SELECT 1
							FROM #tmpAssSumm tas
							WHERE tas.Client = th_esds.Client
							AND tas.GroupCode = th_esds.GroupCode
							AND tas.SSN = th_esds.SSN
							AND tas.SiteNo = th_esds.SiteNo
							AND tas.DeptNo = th_esds.DeptNo
							AND tas.PayrollPeriodEndDate = th_esds.PayrollPeriodEndDate)
			--AND th_esds.SSN = 100102317

	-- Do not send time cards with disputed time in the CPA Sweep if there's an open dispute
	DELETE FROM #tmpAssSumm WHERE OpenDisputeCount > 0
END;

--SELECT * FROM #tmpAssSumm
--RETURN
--SELECT '#tmpAssSumm'
--SELECT * FROM #tmpAssSumm

IF ( @RecordType IN ( 'A', 'L', 'F', 'C', 'S') )
BEGIN  
	-- Summarize Assignment Types
	UPDATE ass
	SET ExcludeFromPayfile = cat.ExcludeFromPayfile,
		SendAsRegInPayfile = cat.SendAsRegInPayfile,
		SendAsUnapproved = cat.SendAsUnapprovedInPayfile
	FROM #tmpAssSumm ass
	INNER JOIN TimeCurrent..tblClients_AssignmentType cat
	ON cat.Client = @Client
	AND cat.AssignmentTypeID = ass.AssignmentTypeID

	-- Force all Experis Assignment to Regular, regardless
	UPDATE #tmpAssSumm
	SET SendAsRegInPayfile = '1'
	WHERE Brand LIKE 'EX%'
	AND ISNULL(SendAsRegInPayfile, '0') = '0'

	-- Remove AssignmentTypes that should not be included in pay file
	DELETE FROM #tmpAssSumm
	WHERE ExcludeFromPayfile = '1'

	-- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL  
	--IF (@RecordType = 'A')  
	--BEGIN       
		--PRINT 'Before DELETE FROM #tmpAssSumm WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  

	DELETE ass
	FROM #tmpAssSumm ass
	INNER JOIN #groupPPED pped
	ON pped.Client = ass.Client
	AND pped.GroupCode = ass.GroupCode
	AND pped.PPED = ass.PayrollPeriodEndDate
	WHERE ass.TransCount <> ass.ApprovedCount  
	AND pped.RecordType IN ('A', 'C')
	AND ISNULL(ass.SendAsUnapproved, '0') = '0'

	DELETE tass
	FROM #tmpAssSumm tass
	INNER JOIN #groupALTEWks pped
	ON pped.Client = tass.Client
	AND pped.GroupCode = tass.GroupCode
	AND pped.PPED = tass.PayrollPeriodEndDate
	WHERE tass.TransCount <> tass.ApprovedCount  
	AND pped.RecordType IN ('A', 'C')
	AND ISNULL(tass.SendAsUnapproved, '0') = '0'
      --PRINT 'After DELETE FROM #tmpAssSumm WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  
  --END  
END

-- Remove Subvendors from the file  
IF (@ExcludeSubVendors = '1')  
BEGIN  
  DELETE FROM #tmpAssSumm  
  WHERE IsSubVendor = '1'  
  AND TransCount <> ApprovedCount  
END  
--PRINT 'After: ExcludeSubVendors' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: CREATE INDEX IDX_tmpSSNs_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpSSNs_PK ON #tmpAssSumm(Client, GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo)  
--PRINT 'After: CREATE INDEX IDX_tmpSSNs_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
    
--PRINT 'Before: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  
UPDATE tas  
SET ApproverName = CASE  WHEN bkp.RecordId IS NOT NULL   
                         THEN LEFT(bkp.LastName + '; ' + ISNULL(bkp.FirstName,''), 50)  
                         ELSE LEFT(usr.LastName + '; ' + ISNULL(usr.FirstName,''), 50)   
                    END,
    ApproverEmail = CASE WHEN bkp.RecordId IS NOT NULL   
                         THEN LEFT(bkp.Email, 50)
                         ELSE LEFT(usr.Email, 50)   
                         END,
	AprvlStatus = thd.AprvlStatus,
	AprvlStatus_UserID = thd.AprvlStatus_UserID,
	UserCode = thd.UserCode                    
FROM #tmpAssSumm AS tAS  
INNER JOIN TimeHistory.dbo.tblTimeHistDetail as thd WITH(NOLOCK) 
ON thd.RecordID = tAS.MaxRecordID  
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval bkp  WITH(NOLOCK) 
ON bkp.THDRecordId = tAS.MaxRecordID  
LEFT JOIN TimeCurrent.dbo.tblUser as Usr  WITH(NOLOCK) 
ON usr.UserID = ISNULL(thd.AprvlStatus_UserID,0)  
--PRINT 'After: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  

UPDATE #tmpAssSumm
SET ApproverName = CASE WHEN ApprovedCount = TransCount THEN ApproverName ELSE '' END,
    ApprovalStatus = CASE WHEN ApprovedCount <> TransCount THEN '0'
                          WHEN ApprovedCount = TransCount AND Dispute_Count = 0 THEN '1'
                          WHEN ApprovedCount = TransCount AND Dispute_Count > 0 THEN '2' 
                     END
      
--PRINT 'Before: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)  
UPDATE #tmpAssSumm
SET TimeSource =  CASE WHEN IVR_Count > 0 THEN 'I'  
                       ELSE CASE WHEN WTE_Count > 0 THEN 'H'   
                            ELSE CASE WHEN Fax_Count > 0 THEN 'Q'   
                                 ELSE CASE WHEN EmailClient_Count > 0 THEN 'D'  
                                      ELSE CASE WHEN EmailOther_Count > 0 THEN 'J'                                          
                                           ELSE TimeSource
                                           END  
                                      END  
                                 END  
                            END  
                       END           
                                              
UPDATE #tmpAssSumm 
SET TimeSource = CASE  WHEN IVR_Count>0 THEN 'I'
                       WHEN Fax_Count > 0 THEN 'F'
                       WHEN WTE_Count > 0 THEN 'W'
                       WHEN Client_Count > 0 THEN 'D'
                       WHEN Branch_Count > 0 THEN 'B'                                                                                                                           
                       WHEN SubVendorAgency_Count > 0 THEN 'S'
                       WHEN Interface_Count > 0 THEN 'X'
                       WHEN Clock_Count > 0 THEN 'C'
                       WHEN Mobile_Count > 0 THEN 'M'
					   WHEN DLT_Count > 0 THEN 'T'
                       ELSE 'P'  --PeopleNet Dashboard
                  END
  , ApprovalSource = CASE WHEN FAXApprover_Count > 0 THEN 'F'
                          WHEN Mobile_Approver > 0 THEN 'M'
                          WHEN Web_Approver_Count > 0 THEN 'W'
                          ELSE 'P'   --PeopleNet Dashboard
                     END     
					 
UPDATE #tmpAssSumm
SET ApproverName = '', ApproverEmail = '', AprvlStatus = '0', AprvlStatus_UserID = 0, UserCode = '',
	TimeSource = 'H', ApprovalSource = 'W'
WHERE NoHours = '1'					 
					                   
 
--PRINT 'After: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)  

-- Get the Trans Date and sum to the day level
INSERT INTO #tmpAss_TransDate ( Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ADP_HoursCode, ADP_EarningsCode, Payable, Billable,
                                TransDate, TotalHours, RegHours, OTHours, DTHours, CalcHours, Dollars, NoHours)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo, adjs.ADP_HoursCode, adjs.ADP_EarningsCode, ISNULL(adjs.Payable, 'Y'), ISNULL(adjs.Billable, 'Y'),
        thd.TransDate, SUM(thd.Hours), SUM(thd.RegHours), SUM(thd.OT_Hours), SUM(thd.DT_Hours), SUM(thd.RegHours + thd.OT_Hours + thd.DT_Hours), SUM(thd.Dollars), tas.NoHours
FROM #tmpAssSumm tas
INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
INNER JOIN TimeCurrent..tblAdjCodes adjs WITH(NOLOCK)
ON	adjs.Client = thd.Client
AND adjs.GroupCode = thd.GroupCode
AND adjs.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('','1', '8', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo, adjs.ADP_HoursCode, adjs.ADP_EarningsCode, thd.TransDate, ISNULL(adjs.Payable, 'Y'), ISNULL(adjs.Billable, 'Y'), tas.NoHours

-- Remove Out of Balance Transactions so as not to hold up the rest of the file  
--DELETE FROM #tmpAss_TransDate WHERE [TotalHours] <> CalcHours  
        
--PRINT 'Before: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)                 
DELETE FROM #tmpAss_TransDate  
WHERE TotalHours = 0
AND RegHours = 0
AND OTHours = 0 
AND DTHours = 0
AND Dollars = 0
AND ISNULL(NoHours, '0') = '0'

-- If any Assignments Types are defined as SendAsRegInPayfile then update RegHours and reset OT and DT
UPDATE td
SET RegHours = (RegHours + OTHours + DTHours), OTHours = 0, DTHours = 0
FROM #tmpAss_TransDate td
INNER JOIN #tmpAssSumm tas
ON td.Client = tas.Client
AND td.GroupCode = tas.GroupCode
AND td.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND td.SSN = tas.SSN
AND td.SiteNo = tas.SiteNo
AND td.DeptNo = tas.DeptNo
WHERE tas.SendAsRegInPayfile = '1'

/*
SELECT '#tmpAssSumm'
SELECT * FROM #tmpAssSumm
SELECT '#tmpAss_TransDate'
SELECT * FROM #tmpAss_TransDate
*/


--PRINT 'After: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)  

-- REG
INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt, VendorReferenceID)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tat.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, 
		ApprovalSource = CASE WHEN tas.AprvlStatus = 'A' AND tas.UserCode = '*VMS' AND tas.AprvlStatus_UserID = 0 THEN 'T' ELSE tas.ApprovalSource END ,
        CASE WHEN tat.ADP_HoursCode = '' THEN @REGPAYCODE ELSE tat.ADP_HoursCode END, tat.RegHours, CASE WHEN tat.Payable = 'Y' THEN tat.RegHours ELSE 0 END, CASE WHEN tat.Billable = 'Y' THEN tat.RegHours ELSE 0 END, tas.VendorReferenceID
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.RegHours <> 0

-- OT
INSERT INTO #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt, VendorReferenceID)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tat.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, 
		ApprovalSource = CASE WHEN tas.AprvlStatus = 'A' AND tas.UserCode = '*VMS' AND tas.AprvlStatus_UserID = 0 THEN 'T' ELSE tas.ApprovalSource END ,
        CASE WHEN tat.ADP_HoursCode = '' THEN @OTPAYCODE ELSE tat.ADP_HoursCode END, tat.OTHours, CASE WHEN tat.Payable = 'Y' THEN tat.OTHours ELSE 0 END, CASE WHEN tat.Billable = 'Y' THEN tat.OTHours ELSE 0 END, tas.VendorReferenceID
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.OTHours <> 0

-- DT
INSERT INTO #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt, VendorReferenceID)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tat.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, 
		ApprovalSource = CASE WHEN tas.AprvlStatus = 'A' AND tas.UserCode = '*VMS' AND tas.AprvlStatus_UserID = 0 THEN 'T' ELSE tas.ApprovalSource END ,
        CASE WHEN tat.ADP_HoursCode = '' THEN @DTPAYCODE ELSE tat.ADP_HoursCode END, tat.DTHours, CASE WHEN tat.Payable = 'Y' THEN tat.DTHours ELSE 0 END, CASE WHEN tat.Billable = 'Y' THEN tat.DTHours ELSE 0 END, tas.VendorReferenceID
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.DTHours <> 0

-- DOLLARS
INSERT INTO #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt, VendorReferenceID)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tat.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, 
		ApprovalSource = CASE WHEN tas.AprvlStatus = 'A' AND tas.UserCode = '*VMS' AND tas.AprvlStatus_UserID = 0 THEN 'T' ELSE tas.ApprovalSource END ,
        tat.ADP_EarningsCode, 0, CASE WHEN tat.Payable = 'Y' THEN tat.Dollars ELSE 0 END, CASE WHEN tat.Billable = 'Y' THEN tat.Dollars ELSE 0 END, tas.VendorReferenceID
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.Dollars <> 0

IF (@RecordType IN ('C', 'S'))
BEGIN


    /*SELECT  *
    INTO    #CompletePayCodeSet 
    FROM    TimeHistory.dbo.ufnGetTransDatePayCode(t.PayrollPeriodEndDate,DATEADD(DAY, -6,t.PayrollPeriodEndDate))*/



	CREATE TABLE #TransDatePayCode  
	(  
	  PayrollPeriodEndDate DATETIME,
	  TransDate DATETIME,
	  PayCode VARCHAR(50)
	);

	DECLARE @csr_PPED DATETIME

	DECLARE ppedCursor CURSOR STATIC FOR
	SELECT DISTINCT PayrollPeriodEndDate
	FROM #tmpAssSumm
	ORDER BY PayrollPeriodEndDate
	OPEN ppedCursor

	FETCH NEXT FROM ppedCursor
	INTO @csr_PPED

	WHILE @@FETCH_STATUS = 0
	BEGIN	

		INSERT INTO #TransDatePayCode(PayrollPeriodEndDate, TransDate, PayCode)
		SELECT @csr_PPED, a.TransDate, a.Paycode
		FROM TimeHistory.dbo.ufnGetTransDatePayCode(@csr_PPED,DATEADD(DAY, -6,@csr_PPED)) a

		FETCH NEXT FROM ppedCursor
		INTO @csr_PPED
	END
	CLOSE ppedCursor
	DEALLOCATE ppedCursor

	--SELECT '#TransDatePayCode'
	--SELECT * FROM #TransDatePayCode
	
	--SELECT '#tmpAssSumm'
	--SELECT * FROM #tmpAssSumm tas

	--SELECT '#tmpUploadExport BEFORE'
	--SELECT * FROM #tmpUploadExport	

	--SELECT 'CompletePayCodeSet'
	--SELECT * FROM #CompletePayCodeSet  -- GG

	-- This will only insert missing REG, OT, DT that are not already insert in #tmpUploadExport above.
    INSERT  INTO #tmpUploadExport
            ( Client ,
              GroupCode ,
              PayrollPeriodEndDate ,
              weDate ,
              SSN ,
              SiteNo ,
              DeptNo ,
              AssignmentNo ,
              TransDate ,
              LateApprovals ,
              SnapshotDateTime ,
              AttachmentName ,
              WorkState ,
              ApproverName ,
              ApproverEmail ,
              ApprovalStatus ,
              ApprovalDateTime ,
              TimeSource ,
              ApprovalSource ,
              PayCode ,
              WorkedHours ,
              PayAmt ,
              BillAmt ,
              VendorReferenceID
			)
            SELECT  DISTINCT Client = tas.Client,
                    GroupCode = tas.GroupCode,
                    PayrollPeriodEndDate = tas.PayrollPeriodEndDate,
                    weDate = CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101),
                    SSN = tas.SSN,
                    SiteNo = tas.SiteNo,
                    DeptNo = tas.DeptNo,
                    AssignmentNo = tas.AssignmentNo,
                    TransDate = cps.TransDate ,
                    LateApprovals = tas.LateApprovals,
                    SnapshotDateTime = tas.SnapshotDateTime ,
                    AttachmentName = tas.AttachmentName ,
                    WorkState = tas.WorkState,
                    ApproverName = tas.ApproverName,
                    ApproverEmail = tas.ApproverEmail,
                    ApprovalStatus = tas.ApprovalStatus,
                    ApprovalDateTime = tas.ApprovalDateTime,
                    TimeSource = tas.TimeSource,
                    ApprovalSource = CASE WHEN tas.AprvlStatus = 'A' AND tas.UserCode = '*VMS' AND tas.AprvlStatus_UserID = 0 THEN 'T' ELSE tas.ApprovalSource END,
                    PayCode = cps.Paycode ,
                    WorkedHours = 0 ,
                    PayAmt = 0 ,
                    BillAmt = 0 ,
                    VendorReferenceID = tas.VendorReferenceID
            FROM    #tmpAssSumm tas			
			LEFT JOIN #TransDatePayCode cps
			ON cps.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
            LEFT JOIN #tmpUploadExport b 
			ON tas.Client = b.Client
            AND tas.GroupCode = b.GroupCode
			AND tas.SSN = b.SSN
            AND tas.PayrollPeriodEndDate = b.PayrollPeriodEndDate
            AND tas.SiteNo = b.SiteNo
            AND tas.DeptNo = b.DeptNo
			AND b.TransDate = cps.TransDate
			AND b.PayCode = cps.PayCode
			WHERE b.TransDate IS NULL	 

	--SELECT '#tmpUploadExport AFTER'
	--SELECT * FROM #tmpUploadExport	

	--This will only insert those Adjustment code with 0 that were part of the week that was opened 
    INSERT  INTO #tmpUploadExport
            ( Client ,
              GroupCode ,
              PayrollPeriodEndDate ,
              weDate ,
              SSN ,
              SiteNo ,
              DeptNo ,
              AssignmentNo ,
              TransDate ,
              LateApprovals ,
              SnapshotDateTime ,
              AttachmentName ,
              WorkState ,
              ApproverName ,
              ApproverEmail ,
              ApprovalStatus ,
              ApprovalDateTime ,
              TimeSource ,
              ApprovalSource ,
              PayCode ,
              WorkedHours ,
              PayAmt ,
              BillAmt ,
              VendorReferenceID
            )
            SELECT DISTINCT cpa.Client,
                    cpa.GroupCode,
                    cpa.PayrollPeriodEndDate,
                    weDate = CONVERT(VARCHAR(10), t.PayrollPeriodEndDate, 101),
                    cpa.SSN ,
                    cpa.SiteNo ,
                    cpa.DeptNo ,
                    AssignmentNo = t.AssignmentNo ,
                    cpaadj.TransDate ,
                    LateApprovals = t.LateApprovals,
                    SnapshotDateTime = t.SnapshotDateTime,
                    AttachmentName = t.AttachmentName ,
                    WorkState = t.WorkState,
                    ApproverName = t.ApproverName,
                    ApproverEmail = t.ApproverEmail,
                    ApprovalStatus = t.ApprovalStatus,
                    ApprovalDateTime = t.ApprovalDateTime,
                    TimeSource = t.TimeSource,
                    ApprovalSource = CASE WHEN t.AprvlStatus = 'A' AND t.UserCode = '*VMS' AND t.AprvlStatus_UserID = 0 THEN 'T' ELSE t.ApprovalSource END,
                    PayCode = CASE WHEN adjs.AdjustmentType = 'H' THEN adjs.ADP_HoursCode ELSE adjs.ADP_EarningsCode END,
                    WorkedHours = 0 ,
                    PayAmt = 0 ,
                    BillAmt = 0 ,
                    VendorReferenceID = t.VendorReferenceID
            FROM    [dbo].[tblWTE_Spreadsheet_ClosedPeriodAdjustment] cpa WITH(NOLOCK)
            INNER JOIN [dbo].[tblWTE_Spreadsheet_ClosedPeriodAdjustment_Details] cpaadj WITH(NOLOCK)
			ON cpa.RecordID = cpaadj.CPAId
			AND cpaadj.ClockAdjustmentNo NOT IN ('1', '8', '$', '@')
            INNER JOIN TimeCurrent..tblAdjCodes adjs WITH(NOLOCK)
			ON adjs.Client = cpa.Client
            AND adjs.GroupCode = cpa.GroupCode
            AND adjs.ClockAdjustmentNo = cpaadj.ClockAdjustmentNo
			INNER JOIN #tmpAssSumm t
			ON t.Client = cpa.Client
			AND t.GroupCode = cpa.GroupCode
			AND t.SSN = cpa.SSN
			AND t.SiteNo = cpa.SiteNo
			AND t.DeptNo = cpa.DeptNo
			AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
			AND NOT EXISTS (SELECT 1
							FROM #tmpUploadExport tue
							WHERE tue.Client = cpa.Client
							AND tue.GroupCode = cpa.GroupCode
							AND tue.SSN = cpa.SSN
							AND tue.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
							AND tue.SiteNo = cpa.SiteNo
							AND tue.Deptno = cpa.DeptNo
							AND tue.PayCode = CASE WHEN adjs.AdjustmentType = 'H' THEN adjs.ADP_HoursCode ELSE adjs.ADP_EarningsCode END
							AND tue.TransDate = cpaadj.TransDate)
			WHERE cpa.Status <> '4'

	--SELECT '#tmpUploadExport AFTER2'
	--SELECT * FROM #tmpUploadExport				
END;

-- "DELETE" out any blank entries
UPDATE udf
SET Client = 'MPO1', SpreadsheetAssignmentID = SpreadsheetAssignmentID * -1
FROM timehistory..tblTimeHistDetail_UDF udf
INNER JOIN (SELECT DISTINCT udf.client, udf.groupcode, udf.ssn, udf.Payrollperiodenddate, udf.siteno, udf.deptno, udf.transdate
			FROM #tmpAssSumm tas
			INNER JOIN timehistory..tblTimeHistDetail_UDF udf
			ON udf.client = tas.Client
			AND udf.groupcode = tas.GroupCode
			AND udf.ssn = tas.SSN
			AND udf.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
			AND udf.SiteNo = tas.SiteNo
			AND udf.DeptNo = tas.DeptNo
			INNER JOIN timecurrent..tblUDF_FieldDefs fd
			ON fd.FieldID = udf.FieldID
			INNER JOIN timecurrent..tblUDF_Templates t
			ON t.TemplateID = fd.TemplateID			
			AND udf.FieldID = t.ValidationFieldId
			AND ISNULL(udf.FieldValue, '') in ('','Nan')) AS tmp
ON udf.Client = tmp.Client
AND udf.GroupCode = tmp.GroupCode
AND udf.Payrollperiodenddate = tmp.Payrollperiodenddate
AND udf.SSN = tmp.SSN
AND udf.SiteNo = tmp.SiteNo
AND udf.DeptNo = tmp.DeptNo
AND udf.TransDate = tmp.TransDate

UPDATE timehistory..tbltimehistdetail_udf
SET Client = 'MPO3'
WHERE RecordID IN (
SELECT udf.RecordID
FROM timehistory..tbltimehistdetail_udf udf (NOLOCK)
INNER JOIN timehistory..tblemplsites_depts esd (NOLOCK)
ON esd.client = udf.Client
AND esd.groupcode = udf.GroupCode
AND esd.ssn = udf.SSN
AND esd.siteno = udf.SiteNo
AND esd.DeptNo = udf.DeptNo
AND esd.PayrollPeriodEndDate = udf.Payrollperiodenddate
AND esd.PayRecordsSent IS NULL
WHERE udf.client = 'mpow'
AND udf.FieldID IN (1229,1230,1231,1248)
AND udf.Payrollperiodenddate > GETDATE() - 31
AND NOT EXISTS (SELECT 1
				FROM timehistory..tbltimehistdetail_udf udf2
				WHERE udf2.client = esd.Client
				AND udf2.groupcode = esd.GroupCode
				AND udf2.ssn = esd.SSN
				AND udf2.siteno = esd.SiteNo
				AND udf2.deptno = esd.DeptNo
				AND udf2.Payrollperiodenddate = esd.PayrollPeriodEndDate
				AND udf2.TransDate = udf.Transdate
				AND udf2.FieldID = 1248))

-- This is to handle French preferent entering commas instead of periods in the UDF hours column
UPDATE udf
SET FieldValue = REPLACE(FieldValue, ',', '.')
FROM timecurrent..tblUDF_Templates t
INNER JOIN timecurrent..tblUDF_FieldDefs fd
ON fd.TemplateID = t.TemplateID
INNER JOIN timehistory..tbltimehistdetail_udf udf
ON udf.client = 'mpow'
AND udf.FieldID = fd.FieldID
AND udf.Payrollperiodenddate > '1/1/2016'
AND udf.FieldValue LIKE '%,%'
WHERE t.client = 'mpow'
AND t.ValidationFieldId = fd.FieldID

UPDATE udf
SET FieldValue = REPLACE(fieldValue, ' ', '')
FROM timecurrent..tblUDF_Templates t
INNER JOIN timecurrent..tblUDF_FieldDefs fd
ON fd.TemplateID = t.TemplateID
INNER JOIN timehistory..tbltimehistdetail_udf udf
ON udf.client = 'mpow'
AND udf.FieldID = fd.FieldID
AND udf.Payrollperiodenddate > '1/1/2016'
AND udf.FieldValue LIKE '% %'
WHERE t.client = 'mpow'
AND t.ValidationFieldId = fd.FieldID

INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt, VendorReferenceID,
                              CRF1_Name, CRF1_Value,
                              CRF2_Name, CRF2_Value,
                              CRF3_Name, CRF3_Value,
                              CRF4_Name, CRF4_Value,
                              CRF5_Name, CRF5_Value,
                              CRF6_Name, CRF6_Value)
SELECT  Client, GroupCode, PayrollPeriodEndDate, CONVERT(VARCHAR(10), PayrollPeriodEndDate, 101), SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
        SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
        'CRF' AS PayCode, Value0 AS WorkedHours, Value0 AS PayAmt, Value0 AS BillAmt, VendorReferenceID,
        Name1, Value1,
        Name2, Value2,
        Name3, Value3,
        Name4, Value4,
        Name5, Value5,
        Name6, Value6
FROM (                              
      SELECT tmp.Client, tmp.GroupCode, tmp.PayrollPeriodEndDate, tmp.SSN, tmp.SiteNo, tmp.DeptNo, tmp.AssignmentNo, tmp.TransDate, tmp.LateApprovals,
             tmp.SnapshotDateTime, tmp.AttachmentName, tmp.WorkState, tmp.ApproverName, tmp.ApproverEmail, tmp.ApprovalStatus, tmp.ApprovalDateTime, tmp.TimeSource, tmp.ApprovalSource, tmp.VendorReferenceID,           
             MAX(CASE WHEN rownum = 1 THEN FieldName END) AS name0,
             MAX(CASE WHEN rownum = 1 THEN FieldValue END) AS value0,
             SUM(CASE WHEN rownum = 1 THEN HoursFieldIndicator END) AS HrsInd0,
             MAX(CASE WHEN rownum = 2 THEN FieldName END) AS Name1,
             MAX(CASE WHEN rownum = 2 THEN FieldValue END) AS Value1,    
             SUM(CASE WHEN rownum = 2 THEN HoursFieldIndicator END) AS HrsInd1,
             MAX(CASE WHEN rownum = 3 THEN FieldName END) AS Name2,
             MAX(CASE WHEN rownum = 3 THEN FieldValue END) AS Value2,
             SUM(CASE WHEN rownum = 3 THEN HoursFieldIndicator END) AS HrsInd2,
             MAX(CASE WHEN rownum = 4 THEN FieldName END) AS Name3,
             MAX(CASE WHEN rownum = 4 THEN FieldValue END) AS Value3,
             SUM(CASE WHEN rownum = 4 THEN HoursFieldIndicator END) AS HrsInd3,
             MAX(CASE WHEN rownum = 5 THEN FieldName END) AS Name4,
             MAX(CASE WHEN rownum = 5 THEN FieldValue END) AS Value4,       
             SUM(CASE WHEN rownum = 5 THEN HoursFieldIndicator END) AS HrsInd4,
             MAX(CASE WHEN rownum = 6 THEN FieldName END) AS Name5,
             MAX(CASE WHEN rownum = 6 THEN FieldValue END) AS Value5,        
             SUM(CASE WHEN rownum = 6 THEN HoursFieldIndicator END) AS HrsInd5,
             MAX(CASE WHEN rownum = 7 THEN FieldName END) AS Name6,
             MAX(CASE WHEN rownum = 7 THEN FieldValue END) AS Value6,        
             SUM(CASE WHEN rownum = 7 THEN HoursFieldIndicator END) AS HrsInd6
      FROM (SELECT tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, udf.TransDate, tas.LateApprovals,
                   tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource, tas.VendorReferenceID,
                   udf.Position, fd.FieldName, udf.FieldValue, 
                   CASE WHEN fd.FieldID = t.ValidationFieldId THEN 1 ELSE 0 END AS HoursFieldIndicator,
                   rownum = ROW_NUMBER() OVER(PARTITION BY udf.client, udf.groupcode, udf.ssn, udf.siteno, udf.deptno, udf.Payrollperiodenddate, udf.transdate, udf.Position ORDER BY CASE WHEN fd.FieldID = t.ValidationFieldId THEN 0 ELSE 1 END, FieldName)
            FROM #tmpAssSumm tas
            INNER JOIN TimeHistory.dbo.tblTimeHistDetail_UDF udf
            ON udf.Client = tas.Client
            AND udf.GroupCode = tas.GroupCode
            AND udf.Payrollperiodenddate = tas.PayrollPeriodEndDate
            AND udf.SSN = tas.SSN
            AND udf.SiteNo = tas.SiteNo
            AND udf.DeptNo = tas.DeptNo
            INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd WITH(NOLOCK)
            ON fd.FieldID = udf.FieldID
            INNER JOIN TimeCurrent.dbo.tblUDF_Templates t WITH(NOLOCK)
            ON t.TemplateId = fd.TemplateID) AS tmp
      GROUP BY  tmp.Client, tmp.GroupCode, tmp.PayrollPeriodEndDate, tmp.SSN, tmp.SiteNo, tmp.DeptNo, tmp.AssignmentNo, tmp.TransDate, tmp.LateApprovals,
                tmp.SnapshotDateTime, tmp.AttachmentName, tmp.WorkState, tmp.ApproverName, tmp.ApproverEmail, tmp.ApprovalStatus, tmp.ApprovalDateTime, 
                tmp.TimeSource, tmp.ApprovalSource, tmp.VendorReferenceID, tmp.Position
      ) AS tmp2

UPDATE tue
  SET Line1 = '"' + ISNULL(en.FirstName, '') + '"' + @Delim 
            + '"' + ISNULL(en.LastName, '') + '"' + @Delim
            + '"' + ISNULL(en.FileNo, '') + '"' + @Delim
            + '"' + ISNULL(tue.AssignmentNo, '') + '"' + @Delim
            + ISNULL(CONVERT(VARCHAR(8),ISNULL(tue.PayrollPeriodEndDate, ' '), 112), '') + @Delim
            + CONVERT(VARCHAR(8),ISNULL(tue.TransDate, ' '), 112) + @Delim
            + ISNULL(CONVERT (VARCHAR(8), tue.WorkedHours), ' ')  + @Delim
            + '"' + ISNULL(Paycode, ' ') + '"' + @Delim
            + ISNULL(CONVERT (VARCHAR(8), tue.PayAmt), ' ')  + @Delim
            + ISNULL(CONVERT (VARCHAR(8), tue.BillAmt), ' ') + @Delim
            + ''  + @Delim -- Project Code            
            + '"' + ISNULL(ApproverName, '') + '"' + @Delim
            + '"' + ISNULL(ApproverEmail, '')+ '"' + @Delim
            --+ ISNULL(CONVERT(VARCHAR(10), ApprovalDateTime, 101), '') + ' ' + ISNULL(CONVERT(VARCHAR(12), ApprovalDateTime, 108), '') + RIGHT(ISNULL(CONVERT(VARCHAR, ApprovalDateTime, 109), ''), 2) + @Delim
            + ISNULL(CONVERT(VARCHAR(8),ISNULL(tue.ApprovalDateTime, ' '), 112), '') + @Delim
            + '"' + ISNULL(en.PayGroup, '') + '"' + @Delim
            + '"' + ISNULL(TimeSource, '') + '"' + @Delim
            + '"' + ISNULL(ApprovalSource, '') + '"' + @Delim
            + ISNULL(AttachmentName, '') + @Delim
            + ISNULL(ApprovalStatus, '') + @Delim
            + '"' + ISNULL(CRF1_Name, '') + '"' + @Delim + '"' + ISNULL(CRF1_Value, '') + '"' + @Delim -- UDF's
            + '"' + ISNULL(CRF2_Name, '') + '"' + @Delim + '"' + ISNULL(CRF2_Value, '') + '"' + @Delim
            + '"' + ISNULL(CRF3_Name, '') + '"' + @Delim + '"' + ISNULL(CRF3_Value, '') + '"' + @Delim
            + '"' + ISNULL(CRF4_Name, '') + '"' + @Delim + '"' + ISNULL(CRF4_Value, '') + '"' + @Delim
            + '"' + ISNULL(CRF5_Name, '') + '"' + @Delim + '"' + ISNULL(CRF5_Value, '') + '"' + @Delim
            + '"' + ISNULL(CRF6_Name, '') + '"' + @Delim + '"' + ISNULL(CRF6_Value, '') + '"' + @Delim
			+ '"' + ISNULL(VendorReferenceID, '') + '"',
     EmployeeID = en.FileNo,
     EmpName = en.LastName + ',' + en.FirstName
FROM #tmpUploadExport tue
INNER JOIN TimeCurrent..tblEmplNames en
ON en.Client = tue.Client
AND en.GroupCode = tue.GroupCode
AND en.SSN = tue.SSN


/*  
The order of these final 3 steps is VERY IMPORTANT  
1. Update Pay Records Sent  
2. Remove Negatives  
3. Return recordset to VB  
*/  
  
--PRINT 'Before: IDX_tmpUploadExport_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpUploadExport_PK ON #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo)  
--PRINT 'After: IDX_tmpUploadExport_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
  
-- 1. Update Pay Records Sent  
IF (@RecordType <> 'D' AND @TestingFlag IN ('N', '0') )  
BEGIN  
    UPDATE TimeHistory.dbo.tblEmplSites_Depts  
    SET TimeHistory.dbo.tblEmplSites_Depts.PayRecordsSent = u.SnapshotDateTime  
    FROM #tmpUploadExport as u  
    INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds  
    ON th_esds.Client = u.Client  
    AND th_esds.GroupCode = u.GroupCode  
    AND th_esds.PayrollPeriodenddate = u.PayrollPeriodEndDate  
    AND th_esds.SSN = u.SSN  
    AND th_esds.SiteNo = u.SiteNo  
    AND th_esds.DeptNo = u.DeptNo   
    --AND ((th_esds.PayRecordsSent IS NULL) OR (u.LateApprovals = '1'))   Manpower not using Late Approvals
  
    Update TimeCurrent.dbo.tblClosedPeriodAdjs  
    Set TimeCurrent.dbo.tblClosedPeriodAdjs.DateTimeProcessed = ouw.SnapshotDateTime  
    from #tmpUploadExport as ouw  
    Inner Join TimeCurrent.dbo.tblClosedPeriodAdjs cpa  
    on cpa.Client = ouw.Client  
    AND cpa.GroupCode = ouw.Groupcode  
    AND cpa.PayrollPeriodEndDate = ouw.PayrollPeriodEndDate  
    and cpa.SSN = ouw.SSN  
    and cpa.DateTimeProcessed IS NULL             
    --PRINT 'After: PayRecordsSent' + CONVERT(VARCHAR, GETDATE(), 121)      

	-- Change status to '4' indicating records were sent in tblWTE_Spreadsheet_ClosedPeriodAdjustment
	UPDATE  TimeHistory.dbo.tblWTE_Spreadsheet_ClosedPeriodAdjustment
    SET     TimeHistory.dbo.tblWTE_Spreadsheet_ClosedPeriodAdjustment.Status = '4'
    FROM    #tmpUploadExport AS ouw
            INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa 
				 ON cpa.Client = ouw.Client
				AND cpa.GroupCode = ouw.GroupCode
				AND cpa.PayrollPeriodEndDate = ouw.PayrollPeriodEndDate
				AND cpa.SSN = ouw.SSN
				AND cpa.SiteNo = ouw.SiteNo
				AND cpa.DeptNo = ouw.DeptNo
				AND cpa.Status <> '4'
END  
 
-- 3. Return recordset to VB
SELECT *
/* u.GroupCode
 , u.SSN  
 , u.EmployeeID  
 , u.EmpName  
 , '' AS FileBreakID  
 , CONVERT(VARCHAR(8), PayrollPeriodEndDate, 112) AS weDate  
 , u.ApprovalStatus  
 , Line1  
 --, IMAGE_FILE_NAME  -- Returning this will cause a empty image zip file  
 , u.SiteNo  
 , u.DeptNo  
 , u.GroupCode  
 , u.SnapshotDateTime  */
FROM #tmpUploadExport u
ORDER BY  u.GroupCode, 
          u.EmployeeID, 
          u.PayrollPeriodEndDate, 
		  CASE u.Paycode WHEN 'CRF' THEN 1 ELSE 0 END,
		  u.TransDate,
          CASE u.Paycode WHEN @REGPAYCODE THEN 1 WHEN @OTPAYCODE THEN 2 WHEN @DTPayCode THEN 3 WHEN 'CRF' THEN 5 ELSE 4 END

--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         
         
DROP TABLE #tmpAssSumm  
DROP TABLE #tmpAss_TransDate
DROP TABLE #tmpUploadExport  

IF (@RecordType IN ('C', 'S'))
BEGIN
	DROP TABLE #TransDatePayCode
END
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN
