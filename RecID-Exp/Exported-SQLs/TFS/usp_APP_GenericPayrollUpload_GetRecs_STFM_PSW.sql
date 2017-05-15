Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_STFM_PSW]
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
  
DECLARE @RecordType         CHAR(1)  
DECLARE @PPEDMinus6         DATETIME  
DECLARE @Today              DATETIME   
DECLARE @ExcludeSubVendors  VARCHAR(1)  
DECLARE @Delim              CHAR(1)  
DECLARE @FaxApprover        INT  
DECLARE @AdditionalApprovalWeeks TINYINT
DECLARE @MinAAWeek DATE
DECLARE @MaxAAWeek DATE;
  
SET @Today = GETDATE()  
SET @PPEDMinus6 = DATEADD(dd, -6, @PPED)  
SET @ExcludeSubVendors = '0' -- Exclude SubVendors from all Unapproved pay files  
SET @Delim = ','  
SET @RecordType = 'F'  -- default to Full (Approved + Unapproved)

SELECT @FaxApprover = UserID   
FROM TimeCurrent.dbo.tblUser WITH(NOLOCK)  
WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER'   
AND Client = @Client  
  
CREATE TABLE #groupLastPPED  
(  
  Client          VARCHAR(4),  
  GroupCode       INT,  
  PPED            DATETIME,  
  LateTimeCutoff  DATETIME  
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
  PPED            DATETIME  
);
CREATE CLUSTERED INDEX CIDX_groupPPED_PK ON #groupPPED
(Client,GroupCode,PPED);

--   (Use @PayrollType parameter in the "payroll type" field of the scheduled job.)  
/*  
  A = Approved Only  
  F = Approved and Unapproved  
  L = Late Time Only   
  P = Employees whose time was approved after it was sent unapproved in the pay file  
  D = Return Client/Group/PPED's that we need to check for disputes in  
  EXPENSES = Expense report file  
*/  
  
INSERT INTO #groupLastPPED(Client, GroupCode, PPED, LateTimeCutoff)  
SELECT cg.Client, cg.GroupCode, ped.PayrollPeriodEndDate, DATEADD(dd, cg.LateTimeEntryWeeks * 7 * -1, ped.PayrollPeriodEndDate)  
FROM TimeCurrent.[dbo].tblClientGroups cg WITH(NOLOCK)  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = [cg].[Client]  
AND ped.GroupCode = [cg].[GroupCode]  
AND ped.PayrollPeriodEndDate BETWEEN @PPEDMinus6 AND @PPED  
AND EXISTS( SELECT 1
            FROM TimeCurrent.dbo.tblEmplNames en
            WHERE en.Client = cg.Client
            AND en.GroupCode = cg.GroupCode
            AND en.PayGroup = @PayrollType)
WHERE cg.Client = @Client  
AND cg.RecordStatus = '1'  
AND cg.IncludeInUpload = '1'  
AND cg.StaffingSetupType = '1'  
  
CREATE INDEX IDX_groupLastPPED_PK ON #groupLastPPED (Client,GroupCode,PPED) INCLUDE (LateTimeCutoff)
  
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
      WeekClosedDateTime = @Today,  
      MaintUserName = 'System',  
      MaintDateTime = @Today  
  FROM TimeHistory.dbo.tblPeriodEndDates ped  
  INNER JOIN #groupLastPPED tmp  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate = tmp.PPED  
      
  -- Let the oldest of the three weeks drop off so that it can't be used anymore on WTE  
  UPDATE ped  
  SET OverrideStatus = '0',  
      MaintUserName = 'System',  
      MaintDateTime = @Today  
  FROM TimeHistory.dbo.tblPeriodEndDates ped  
  INNER JOIN #groupLastPPED tmp  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate = tmp.PPED  
  AND ped.PayrollPeriodEndDate <= tmp.LateTimeCutoff  
  AND ISNULL(ped.OverrideStatus, '') <> '0'    
    
  DECLARE closeCursor CURSOR READ_ONLY  
  FOR SELECT Client, GroupCode, PPED  
      FROM #groupLastPPED  
  
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
INSERT INTO #groupPPED(Client, GroupCode, PPED)  
SELECT ped.Client, ped.GroupCode, ped.PayrollPeriodEndDate  
FROM #groupLastPPED tmp  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode  
AND ped.PayrollPeriodEndDate BETWEEN tmp.LateTimeCutoff AND tmp.PPED   

SELECT @MaxAAWeek = MAX(PPED),@MinAAWeek = MIN(PPED) FROM #groupPPED;

Create Table #tmpAssSumm  
(   
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    SSN               INT,  
    EmployeeID        VARCHAR(50),
    EmpName           VARCHAR(50),
    SiteNo            INT,
    DeptNo            INT, 
    TransCount        INT,   
    ApprovedCount     INT,  
    PayRecordsSent    DATETIME,    
    IVR_Count         INT,   
    WTE_Count         INT,   
    Fax_Count         INT,   
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
    MaxRecordID       BIGINT,  --< MaxTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 11Aug2016 >--
    TimeSource        VARCHAR(1), 
    ApprovalSource    VARCHAR(1), 
)  
  
Create Table #tmpAss_Hours  
(   
    Client                VARCHAR(4),  
    GroupCode             INT,  
    PayrollPeriodEndDate  DATETIME,   
    SSN                   INT,  
    SiteNo                INT,
    DeptNo                INT, 
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
    FileBreakID       VARCHAR(50)                
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
      , EmployeeID
      , EmpName
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
  )  
  SELECT   
       t.Client  
     , t.GroupCode  
     , t.PayrollPeriodEndDate  
     , t.SSN  
     , en.FileNo
     , en.FirstName + ' ' + en.LastName
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
     , SnapshotDateTime = @Today  
     , JobID = 0  
     , AttachmentName = th_esds.RecordID  
     , ApprovalMethodID = ea.ApprovalMethodID  
     , WorkState = ISNULL(ea.WorkState, '')  
     , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
     , MAX(t.RecordID)
  FROM #groupPPED grpped  
  INNER JOIN TimeHistory.dbo.tblTimeHistDetail as t  
  ON t.Client = grpped.Client  
  AND t.Groupcode = grpped.GroupCode  
  AND t.PayrollPeriodEndDate = grpped.PPED  
  INNER JOIN TimeCurrent.dbo.tblEmplNames en  WITH(NOLOCK) 
  ON  en.Client = t.Client  
  AND en.GroupCode = t.GroupCode  
  AND en.SSN = t.SSN 
  AND en.PayGroup = @PayrollType
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
 	WHERE t.Client = @Client
	AND t.PayrollPeriodEndDate >= @MinAAWeek
	AND t.PayrollPeriodEndDate <= @MaxAAWeek
	AND t.[Hours] <> 0
  GROUP BY  
        t.Client  
      , t.GroupCode  
      , t.PayrollPeriodEndDate  
      , t.SSN  
      , en.FileNo
      , en.FirstName + ' ' + en.LastName      
      , t.SiteNo
      , t.DeptNo
      , th_esds.PayRecordsSent
      , ea.AssignmentNo  
      , ea.approvalMethodID  
      , th_esds.RecordID  
      , ISNULL(ea.WorkState, '')  
      , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
  --PRINT 'After: INSERT INTO #tmpAssSumm A, L, F' + CONVERT(VARCHAR, GETDATE(), 121)          
    
  -- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL  
  IF (@RecordType = 'A')  
  BEGIN       
      --PRINT 'Before DELETE FROM #tmpAssSumm WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  
      DELETE FROM #tmpAssSumm WHERE TransCount <> ApprovedCount  
      --PRINT 'After DELETE FROM #tmpAssSumm WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  
  END  

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
                       ELSE 'P'  --PeopleNet Dashboard
                  END
  , ApprovalSource = CASE WHEN FAXApprover_Count > 0 THEN 'F'
                          WHEN Mobile_Approver > 0 THEN 'M'
                          WHEN Web_Approver_Count > 0 THEN 'W'
                          ELSE 'P'   --PeopleNet Dashboard
                     END                       
 
--PRINT 'After: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)  

-- Get the Trans Date and sum to the day level
INSERT INTO #tmpAss_Hours ( Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo,
                            TotalHours, RegHours, OTHours, DTHours, CalcHours)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo,
        SUM(thd.Hours), SUM(thd.RegHours), SUM(thd.OT_Hours), SUM(thd.DT_Hours), SUM(thd.RegHours + thd.OT_Hours + thd.DT_Hours)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo

SELECT '#tmpAss_Hours'
SELECT * FROM #tmpAss_Hours

-- Remove Out of Balance Transactions so as not to hold up the rest of the file  
--DELETE FROM #tmpAss_TransDate WHERE [TotalHours] <> CalcHours  
        
--PRINT 'Before: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)                 
DELETE FROM #tmpAss_Hours  
WHERE TotalHours = 0
AND RegHours = 0
AND OTHours = 0 
AND DTHours = 0

/*
SELECT '#tmpAssSumm'
SELECT * FROM #tmpAssSumm
SELECT '#tmpAss_TransDate'
SELECT * FROM #tmpAss_TransDate
*/

   
--PRINT 'After: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)  
INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, EmployeeID, EmpName, SiteNo, DeptNo, AssignmentNo, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.EmployeeID, tas.EmpName, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        @REGPAYCODE, tat.RegHours, tat.RegHours, tat.RegHours
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_Hours tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.RegHours <> 0

INSERT INTO #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, EmployeeID, EmpName, SiteNo, DeptNo, AssignmentNo, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.EmployeeID, tas.EmpName, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        @OTPAYCODE, tat.OTHours, tat.OTHours, tat.OTHours
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_Hours tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.OTHours <> 0

INSERT INTO #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, EmployeeID, EmpName, SiteNo, DeptNo, AssignmentNo, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.EmployeeID, tas.EmpName, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        @DTPAYCODE, tat.DTHours, tat.DTHours, tat.DTHours
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_Hours tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.DTHours <> 0

/*GroupCode = @GroupCode,
	        SSN, 
	        EmployeeID = FileNo, 
	        EmpName, 
	        PPED = @PPED,
	        AssignmentNo,
          FileBreakID, 
	        Line1 = FileNo + @Delim + case when isnull(AssignmentNo,'') = '' then 'Missing' else AssignmentNo End + @Delim + convert(varchar(12),@PPED,101) + @Delim + PayCode + @Delim + Ltrim(str(Hours,7,2)),
	        Paycode
*/

SELECT 'final select'
SELECT * FROM #tmpUploadExport

UPDATE #tmpUploadExport
SET Line1 = EmployeeID + @Delim + case when isnull(AssignmentNo,'') = '' then 'Missing' else AssignmentNo End + @Delim + convert(varchar(12),PayrollPeriodEndDate,101) + @Delim + PayCode + @Delim + Ltrim(str(PayAmt,7,2))


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
END  
 
-- 3. Return recordset to VB
SELECT *
FROM #tmpUploadExport u
ORDER BY  u.GroupCode, 
          u.EmployeeID, 
          u.PayrollPeriodEndDate, 
          CASE u.Paycode WHEN @REGPAYCODE THEN 1 WHEN @OTPAYCODE THEN 2 WHEN @DTPayCode THEN 3 ELSE 5 END

          
--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         
         
DROP TABLE #tmpAssSumm  
DROP TABLE #tmpAss_Hours
DROP TABLE #tmpUploadExport  
   
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN
