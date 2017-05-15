CREATE PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_MPOW_PCT_LateApproval]
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

DECLARE
 @RecordType CHAR(1) = LEFT(@PayrollType, 1)
,@PPEDMinus6 DATETIME = DATEADD(dd, -6, @PPED)
,@Now DATETIME = GETDATE()
,@Today DATE = GetDate() 
,@ExcludeSubVendors VARCHAR(1) = '0' -- Exclude SubVendors from all Unapproved pay files
,@Delim CHAR(1) = '|'
,@FaxApprover INT
,@AdditionalApprovalWeeks TINYINT
,@MinAAWeek DATE
,@MaxAAWeek DATE
,@AdditionalVMSLateTimeEntryWks TINYINT
,@VMSRangeStart DATE
,@VMSRangeEnd DATE
,@AdditionalCPALateTimeEntryWks INT
,@CPARangeStart DATE
,@CPARangeEnd DATE;

SELECT @FaxApprover = UserID   
FROM TimeCurrent.dbo.tblUser WITH(NOLOCK)  
WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER'   
AND Client = @Client

SELECT @AdditionalVMSLateTimeEntryWks = ISNULL(AdditionalLateTimeEntryWks, 0)
FROM TimeCurrent.dbo.tblClients_AssignmentType
WHERE Client = @Client AND AssignmentTypeID = 1 AND RefreshCode = 'V';

SELECT @AdditionalCPALateTimeEntryWks = ISNULL(AdditionalCPAWeeks, 0)
FROM TimeCurrent.dbo.tblClients
WHERE Client = @Client

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

IF EXISTS
(
	SELECT * FROM tempdb.dbo.sysobjects
	WHERE id = object_id(N'tempdb.dbo.#groupCPAWks')
)
DROP TABLE #groupCPAWks;
CREATE TABLE #groupCPAWks  
(  
  Client CHAR(4)
 ,GroupCode INT
 ,PPED DATE
 ,RecordType CHAR(1)
);
  
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

-- VMS Late Time Entry Temp Tables
INSERT INTO #groupALTEWks(Client,GroupCode,PPED,RecordType)  
SELECT ped.Client,ped.GroupCode,ped.PayrollPeriodEndDate,tmp.RecordType
FROM #groupLastPPED tmp
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode
WHERE ped.PayrollPeriodEndDate < tmp.LateTimeCutoff
AND ped.PayrollPeriodEndDate >= DATEADD(WK,-1*ISNULL(@AdditionalVMSLateTimeEntryWks,0),tmp.LateTimeCutoff);

CREATE UNIQUE NONCLUSTERED INDEX uncixALTEW ON #groupALTEWks
(Client,GroupCode,PPED);
CREATE STATISTICS statALTEW_PPED ON #groupALTEWks
(PPED) WITH FULLSCAN;

SELECT @VMSRangeStart = MIN(PPED),@VMSRangeEnd = MAX(PPED) FROM #groupALTEWks;

-- CPA Late Time Entry Tables
INSERT INTO #groupCPAWks(Client,GroupCode,PPED,RecordType)  
SELECT ped.Client,ped.GroupCode,ped.PayrollPeriodEndDate,tmp.RecordType
FROM #groupLastPPED tmp
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode
WHERE ped.PayrollPeriodEndDate < tmp.LateTimeCutoff
AND ped.PayrollPeriodEndDate >= DATEADD(WK,-1*ISNULL(@AdditionalCPALateTimeEntryWks,0),tmp.LateTimeCutoff);

CREATE UNIQUE NONCLUSTERED INDEX uncixCPAW ON #groupCPAWks
(Client,GroupCode,PPED);
CREATE STATISTICS statCPAW_PPED ON #groupCPAWks
(PPED) WITH FULLSCAN;

SELECT @CPARangeStart = MIN(PPED),@CPARangeEnd = MAX(PPED) FROM #groupCPAWks;

Create Table #tmpAssSumm  
(   
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    SSN               INT,  
    SiteNo            INT,
    DeptNo            INT, 
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
    MaxRecordID       BIGINT,  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
    TimeSource        VARCHAR(1), 
    ApprovalSource    VARCHAR(1), 
	VendorReferenceID VARCHAR(100),
	AssignmentTypeID  INT,
	ExcludeFromPayfile	BIT,
	SendAsRegInPayfile	BIT,
	SendAsUnapproved	BIT,
 Brand VARCHAR(32)
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
    TotalHours            NUMERIC(7, 2),  
    RegHours              NUMERIC(7, 2),  
    OTHours               NUMERIC(7, 2),  
    DTHours               NUMERIC(7, 2),  
    CalcHours             NUMERIC(7, 2)
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
    LateApprovals     INT,
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
  
IF (@RecordType = 'L')  
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
   , Brand
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
     , Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END)  
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
	 , ea.Brand
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
  INNER JOIN TimeHistory.dbo.tblEmplNames th_en  WITH(NOLOCK) 
  ON  th_en.Client = t.Client  
  AND th_en.GroupCode = t.GroupCode  
  AND th_en.SSN = t.SSN  
  AND th_en.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
  LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)  
  ON a.client = ea.Client  
  AND a.GroupCode = ea.GroupCode  
  AND a.Agency = ea.AgencyNo          
 	WHERE t.Client = @Client
	AND t.PayrollPeriodEndDate >= @MinAAWeek
	AND t.PayrollPeriodEndDate <= @MaxAAWeek
	AND t.[Hours] <> 0
	AND t.AprvlStatus_Date > th_esds.PayRecordsSent
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
 ,AssignmentTypeID,Brand
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
 ,Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END)
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
 ,ea.Brand
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
 INNER JOIN TimeCurrent.dbo.tblClients_AssignmentType tcCAT
 ON tcCAT.Client = ea.Client
 AND tcCAT.AssignmentTypeID = ea.AssignmentTypeID
 LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)
 ON a.client = ea.Client  
 AND a.GroupCode = ea.GroupCode  
 AND a.Agency = ea.AgencyNo
 WHERE t.Client = @Client
 AND t.GroupCode < 100000
 AND t.PayrollPeriodEndDate BETWEEN @VMSRangeStart AND @VMSRangeEnd
 AND t.[Hours] <> 0
 AND t.AprvlStatus_Date > th_esds.PayRecordsSent 
 AND tcCAT.AssignmentTypeID = 1 AND tcCAT.RefreshCode = 'V'
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

--INSERT CPA LateTimeEntryRecords
 INSERT INTO #tmpAssSumm  
 (
  Client,GroupCode,PayrollPeriodEndDate,SSN,SiteNo,DeptNo,PayRecordsSent,AssignmentNo
 ,TransCount,ApprovedCount,ApprovalDateTime,IVR_Count,WTE_Count,Fax_Count,DLT_Count
 ,FaxApprover_Count,EmailClient_Count,EmailOther_Count,Dispute_Count,OtherTxns_Count
 ,LateApprovals,Client_Count ,Branch_Count ,SubVendorAgency_Count,Interface_Count
 ,Mobile_Count,Mobile_Approver,Web_Approver_Count,Clock_Count,SnapshotDateTime,JobID
 ,AttachmentName,ApprovalMethodID,WorkState,IsSubVendor,MaxRecordID,VendorReferenceID
 ,AssignmentTypeID,Brand
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
 ,Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END)
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
 ,ea.Brand
 FROM #groupCPAWks grpped
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
 LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)
 ON a.client = ea.Client  
 AND a.GroupCode = ea.GroupCode  
 AND a.Agency = ea.AgencyNo
 INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
 ON  cpa.Client = t.Client  
 AND cpa.GroupCode = t.GroupCode  
 AND cpa.SSN = t.SSN  
 AND cpa.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
 AND cpa.SiteNo = t.SiteNo  
 AND cpa.DeptNo = t.DeptNo  
 WHERE t.Client = @Client
 AND t.GroupCode < 100000
 AND t.PayrollPeriodEndDate BETWEEN @CPARangeStart AND @CPARangeEnd
 AND t.[Hours] <> 0
 AND t.AprvlStatus_Date > th_esds.PayRecordsSent 
 AND NOT EXISTS (SELECT 1
				 FROM #tmpAssSumm ass
				 WHERE ass.Client = t.Client
				 AND ass.GroupCode = t.GroupCode
				 AND ass.SSN = t.SSN
				 AND ass.SiteNo = t.SiteNo
				 AND ass.DeptNo = t.DeptNo
				 AND ass.PayrollPeriodEndDate = t.PayrollPeriodEndDate)
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
  
	-- Summarize Assignment Types
	UPDATE ass
	SET ExcludeFromPayfile = cat.ExcludeFromPayfile,
		SendAsRegInPayfile = cat.SendAsRegInPayfile,
		SendAsUnapproved = cat.SendAsUnapprovedInPayfile
	FROM #tmpAssSumm ass
	INNER JOIN TimeCurrent..tblClients_AssignmentType cat
	ON cat.Client = @Client
	AND cat.AssignmentTypeID = ass.AssignmentTypeID

	-- Remove AssignmentTypes that should not be included in pay file
	DELETE FROM #tmpAssSumm
	WHERE ExcludeFromPayfile = '1'
 
END

 
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
                         END                      
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
 
--PRINT 'After: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)  

-- Get the Trans Date and sum to the day level
INSERT INTO #tmpAss_TransDate ( Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ADP_HoursCode,
                                TransDate, TotalHours, RegHours, OTHours, DTHours, CalcHours)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo, adjs.ADP_HoursCode,
        thd.TransDate, SUM(thd.Hours), SUM(thd.RegHours), SUM(thd.OT_Hours), SUM(thd.DT_Hours), SUM(thd.RegHours + thd.OT_Hours + thd.DT_Hours)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
INNER JOIN TimeCurrent..tblAdjCodes adjs 
ON	adjs.Client = thd.Client
AND adjs.GroupCode = thd.GroupCode
AND adjs.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('','1', '8', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo, adjs.ADP_HoursCode, thd.TransDate

-- Remove Out of Balance Transactions so as not to hold up the rest of the file  
--DELETE FROM #tmpAss_TransDate WHERE [TotalHours] <> CalcHours  
        
--PRINT 'Before: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)                 
DELETE FROM #tmpAss_TransDate  
WHERE TotalHours = 0
AND RegHours = 0
AND OTHours = 0 
AND DTHours = 0

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


INSERT INTO #tmpUploadExport
(Client,GroupCode,PayrollPeriodEndDate,SSN,SiteNo,DeptNo,AssignmentNo,SnapshotDateTime,AttachmentName,ApproverName
,ApproverEmail,ApprovalDateTime,ApprovalSource,ApprovalStatus,FileBreakID
,Line1
,EmployeeID
,EmpName)
SELECT DISTINCT
 tas.Client,tas.GroupCode,tas.PayrollPeriodEndDate,tas.SSN,tas.SiteNo,tas.DeptNo,tas.AssignmentNo,tas.SnapshotDateTime,tas.AttachmentName
,tas.ApproverName,tas.ApproverEmail,tas.ApprovalDateTime,tas.ApprovalSource,tas.ApprovalStatus,FileBreakID = 'LateApproval_' + tas.Brand
,Line1 =
			'"' + ISNULL(en.FirstName, '') + '"' + @Delim  --FirstName
			+ '"' + ISNULL(en.LastName, '') + '"' + @Delim  --LastName
			+ '"' + ISNULL(en.FileNo, '') + '"' + @Delim  --EmployeeID
			+ '"' + ISNULL(tas.AssignmentNo, '') + '"' + @Delim  --AssignmentNumber
			+ ISNULL(CONVERT(VARCHAR(8),ISNULL(tas.PayrollPeriodEndDate, ' '), 112), '') + @Delim  --WeekEndingDate
			+ ISNULL(tas.AttachmentName, '') + @Delim  --TimeSheetID         
			+ '"' + ISNULL(tas.ApproverName, '') + '"' + @Delim  --ApproverName
			+ '"' + ISNULL(tas.ApproverEmail, '')+ '"' + @Delim  --ApproverEmail
			+ ISNULL(CONVERT(VARCHAR(8),ISNULL(tas.ApprovalDateTime, ' '), 112), '') + @Delim  --ApprovalDateTime
			+ '"' + ISNULL(tas.ApprovalSource, '') + '"' + @Delim  --ApprovalSource
			+ ISNULL(tas.ApprovalStatus, '') + @Delim  --ApprovalStatus
			+ ISNULL(CONVERT (VARCHAR(8), SUM( tat.TotalHours)), ' ')  + @Delim  --TotalHours
			+ ISNULL(tas.TimeSource, '') -- Time Source
			,EmployeeID = en.FileNo
			,EmpName = en.LastName + ',' + en.FirstName
FROM #tmpAssSumm tas
INNER JOIN TimeCurrent.dbo.tblEmplNames en
ON en.Client = tas.Client
AND en.GroupCode = tas.GroupCode
AND en.SSN = tas.SSN
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tas.LateApprovals > 0
GROUP BY
 tas.Client,tas.GroupCode,tas.PayrollPeriodEndDate,tas.SSN,tas.SiteNo,tas.DeptNo,tas.AssignmentNo,tas.SnapshotDateTime,tas.AttachmentName
,tas.ApproverName,tas.ApproverEmail,tas.ApprovalDateTime,tas.ApprovalSource,tas.ApprovalStatus
,en.FirstName,en.LastName,en.FileNo,tas.Brand,tas.TimeSource;

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
END  

-- 3. Return recordset to VB
SELECT *
FROM #tmpUploadExport
ORDER BY
		 FileBreakID
		,GroupCode		
		,EmployeeID
		,PayrollPeriodEndDate
		,CASE Paycode WHEN @REGPAYCODE THEN 1 WHEN @OTPAYCODE THEN 2 WHEN @DTPayCode THEN 3 WHEN 'CRF' THEN 4 ELSE 5 END
		,TransDate

          
--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         
         
DROP TABLE #tmpAssSumm  
DROP TABLE #tmpAss_TransDate
DROP TABLE #tmpUploadExport  
   
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN

