Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_MPOW_PCT_NEW]
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
DECLARE @Now				DATETIME   
DECLARE @Today				DATE
DECLARE @ExcludeSubVendors  VARCHAR(1)  
DECLARE @Delim              CHAR(1)  
DECLARE @FaxApprover        INT  
DECLARE @AdditionalApprovalWeeks TINYINT
DECLARE @MinAAWeek DATE
DECLARE @MaxAAWeek DATE;
  
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
  
CREATE TABLE #groupLastPPED  
(  
  Client          VARCHAR(4),  
  GroupCode       INT,  
  PPED            DATETIME, 
  LateTimeEntryWeeks INT, 
  LateTimeCutoff  DATETIME,
  RecordType		VARCHAR(1)
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
SELECT cg.Client, cg.GroupCode, MAX(ped.PayrollPeriodEndDate), cg.LateTimeEntryWeeks, NULL  
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

-- Default everything to Approved Only
UPDATE #groupLastPPED
SET RecordType = 'A'

IF (@PayrollType = 'F')
BEGIN
	UPDATE #groupLastPPED
	SET RecordType = 'F'
	WHERE (
		   (CASE WHEN DATEPART(dw, PPED) = 2 AND DATEPART(dw, @Today) = 5 THEN 1 ELSE 0 END = 1) -- EOW Monday
		OR (CASE WHEN DATEPART(dw, PPED) = 3 AND DATEPART(dw, @Today) = 6 THEN 1 ELSE 0 END = 1) -- EOW Tuesday
		OR (CASE WHEN DATEPART(dw, PPED) = 4 AND DATEPART(dw, @Today) = 6 THEN 1 ELSE 0 END = 1) -- EOW Wednesday
		OR (CASE WHEN DATEPART(dw, PPED) IN (5,6,7,1) AND DATEPART(dw, @Today) IN (2, 3, 4) THEN 1 ELSE 0 END = 1) -- EOW Wednesday  
		  )
END

UPDATE #groupLastPPED
SET LateTimeCutoff = DATEADD(dd, LateTimeEntryWeeks * 7 * -1, PPED)

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

SELECT * FROM #groupPPED
RETURN


SELECT @MaxAAWeek = MAX(PPED),@MinAAWeek = MIN(PPED) FROM #groupPPED;

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
    MaxRecordID       BIGINT,   --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
    TimeSource        VARCHAR(1), 
    ApprovalSource    VARCHAR(1), 
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
    CRF6_Value        VARCHAR(512) DEFAULT ''                   
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
     , SnapshotDateTime = @Now  
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
	AND pped.RecordType = 'A'
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
INSERT INTO #tmpAss_TransDate ( Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo,
                                TransDate, TotalHours, RegHours, OTHours, DTHours, CalcHours)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo,
        thd.TransDate, SUM(thd.Hours), SUM(thd.RegHours), SUM(thd.OT_Hours), SUM(thd.DT_Hours), SUM(thd.RegHours + thd.OT_Hours + thd.DT_Hours)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo, thd.TransDate

-- Remove Out of Balance Transactions so as not to hold up the rest of the file  
--DELETE FROM #tmpAss_TransDate WHERE [TotalHours] <> CalcHours  
        
--PRINT 'Before: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)                 
DELETE FROM #tmpAss_TransDate  
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

INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tat.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        @REGPAYCODE, tat.RegHours, tat.RegHours, tat.RegHours
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.RegHours <> 0

INSERT INTO #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tat.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        @OTPAYCODE, tat.RegHours, tat.RegHours, tat.RegHours
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.OTHours <> 0

INSERT INTO #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, tat.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        @DTPAYCODE, tat.RegHours, tat.RegHours, tat.RegHours
FROM #tmpAssSumm tas
INNER JOIN #tmpAss_TransDate tat
ON tat.Client = tas.Client
AND tat.GroupCode = tas.GroupCode
AND tat.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND tat.SSN = tas.SSN
AND tat.SiteNo = tas.SiteNo
AND tat.DeptNo = tas.DeptNo
WHERE tat.DTHours <> 0


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

INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode, WorkedHours, PayAmt, BillAmt,
                              CRF1_Name, CRF1_Value,
                              CRF2_Name, CRF2_Value,
                              CRF3_Name, CRF3_Value,
                              CRF4_Name, CRF4_Value,
                              CRF5_Name, CRF5_Value,
                              CRF6_Name, CRF6_Value)
SELECT  Client, GroupCode, PayrollPeriodEndDate, CONVERT(VARCHAR(10), PayrollPeriodEndDate, 101), SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
        SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
        'CRF' AS PayCode, Value0 AS WorkedHours, 0 AS PayAmt, 0 AS BillAmt,
        Name1, Value1,
        Name2, Value2,
        Name3, Value3,
        Name4, Value4,
        Name5, Value5,
        Name6, Value6
FROM (                              
      SELECT tmp.Client, tmp.GroupCode, tmp.PayrollPeriodEndDate, tmp.SSN, tmp.SiteNo, tmp.DeptNo, tmp.AssignmentNo, tmp.TransDate, tmp.LateApprovals,
             tmp.SnapshotDateTime, tmp.AttachmentName, tmp.WorkState, tmp.ApproverName, tmp.ApproverEmail, tmp.ApprovalStatus, tmp.ApprovalDateTime, tmp.TimeSource, tmp.ApprovalSource,              
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
                   tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
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
            INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
            ON fd.FieldID = udf.FieldID
            INNER JOIN TimeCurrent.dbo.tblUDF_Templates t
            ON t.TemplateId = fd.TemplateID) AS tmp
      GROUP BY  tmp.Client, tmp.GroupCode, tmp.PayrollPeriodEndDate, tmp.SSN, tmp.SiteNo, tmp.DeptNo, tmp.AssignmentNo, tmp.TransDate, tmp.LateApprovals,
                tmp.SnapshotDateTime, tmp.AttachmentName, tmp.WorkState, tmp.ApproverName, tmp.ApproverEmail, tmp.ApprovalStatus, tmp.ApprovalDateTime, 
                tmp.TimeSource, tmp.ApprovalSource, tmp.Position
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
            + ISNULL(CONVERT (VARCHAR(8), tue.WorkedHours), ' ')  + @Delim
            + ISNULL(CONVERT (VARCHAR(8), tue.WorkedHours), ' ') + @Delim
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
            + '"' + ISNULL(CRF6_Name, '') + '"' + @Delim + '"' + ISNULL(CRF6_Value, '') + '"',
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
END  
 
-- 3. Return recordset to VB
SELECT */* u.GroupCode
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
          CASE u.Paycode WHEN @REGPAYCODE THEN 1 WHEN @OTPAYCODE THEN 2 WHEN @DTPayCode THEN 3 WHEN 'CRF' THEN 4 ELSE 5 END, 
          u.TransDate

          
--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         
         
DROP TABLE #tmpAssSumm  
DROP TABLE #tmpAss_TransDate
DROP TABLE #tmpUploadExport  
   
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN
