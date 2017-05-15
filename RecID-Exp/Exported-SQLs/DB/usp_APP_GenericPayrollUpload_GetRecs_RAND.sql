CREATE PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_RAND]  
(   
  @Client         varchar(4),  
  @GroupCode      int,  
  @PPED           DateTime,  
  @PAYRATEFLAG    varchar(4),  
  @EMPIDType      varchar(6),  
  @REGPAYCODE     varchar(10),  
  @OTPAYCODE      varchar(10),  
  @DTPAYCODE      varchar(10),  
  @PayrollType    varchar(32) = '',  
  @IncludeSalary  char(1),  
  @TestingFlag    char(1) = 'N'  
) AS  
  

SET NOCOUNT ON  
  
DECLARE @RecordType         CHAR(1)  
DECLARE @PPEDMinus6         DATETIME  
DECLARE @Today              DATETIME   
DECLARE @RestrictStateList  varchar_list_tbltype  
DECLARE @ExcludeSubVendors  VARCHAR(1)  
DECLARE @Delim              CHAR(1)  
DECLARE @FaxApprover        INT  
DECLARE @GenerateImages     VARCHAR(1)  
DECLARE @MailMessage        VARCHAR(8000)  
DECLARE @MailToNegs         VARCHAR(500)  
DECLARE @MailToOOB          VARCHAR(500)  
DECLARE @GroupName          VARCHAR(200)  
DECLARE @NegTransDate       DATETIME   
DECLARE @NegHours           NUMERIC(7,2)  
DECLARE @crlf               CHAR(2)  
DECLARE @oobGroupCode       INT  
DECLARE @oobPayrollPeriodEndDate DATETIME  
DECLARE @oobSSN             INT  
DECLARE @oobAssignmentNo    VARCHAR(100)  
DECLARE @oobHours           NUMERIC(7, 2)  
DECLARE @oobCalcHours       NUMERIC(7, 2)  
  
IF UPPER(ISNULL(@PayrollType,'')) LIKE '%EXPENSE%'  
BEGIN  
  EXEC TimeHistory.dbo.usp_APP_GenericPayrollUpload_GetRecs_RAND_Expense @Client, @GroupCode, @PPED  
 RETURN  
END  
  
SET @Today = GETDATE()  
SET @PPEDMinus6 = DATEADD(dd, -6, @PPED)  
SET @ExcludeSubVendors = '0' -- Exclude SubVendors from all Unapproved pay files  
SET @Delim = '|'  
SET @RecordType = LEFT(@PayrollType, 1)  -- default to Approved  
SET @GenerateImages = '0'  
SET @crlf = char(13) + char(10)  
SET @MailMessage = ''  
  
IF (@TestingFlag IN ('N', '0'))  
BEGIN  
  SET @MailToNegs = 'appemails@peoplenet.com'  
  SET @MailToOOB = 'server@peoplenet.com'  
END  
ELSE  
BEGIN  
  SET @MailToNegs = 'gary.gordon@peoplenet.com' 
  SET @MailToOOB = 'gary.gordon@peoplenet.com'  
END  
  
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
  
CREATE TABLE #groupPPED  
(  
  Client          VARCHAR(4),  
  GroupCode       INT,  
  PPED            DATETIME  
)  
  
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
WHERE cg.Client = @Client  
AND cg.RecordStatus = '1'  
AND cg.IncludeInUpload = '1'  
AND cg.StaffingSetupType = '1'
AND (ped.PayrollPeriodEndDate BETWEEN @PPEDMinus6 AND @PPED  OR
 CASE WHEN DATEPART(WEEKDAY,ped.PayrollPeriodEndDate) IN (3,4) AND DATEPART(WEEKDAY,@Today) = 6
  THEN ped.PayrollPeriodEndDate END BETWEEN @PPED AND DATEADD(WEEK,1,@PPED))

CREATE INDEX IDX_groupLastPPED_PK ON #groupLastPPED(Client, GroupCode, PPED)  
  
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
      EXEC TimeHistory.dbo.usp_APP_OlstUPL_GetHoursByDay_SendAgencyReports @CloseClient, @CloseGroupCode, @ClosePPED  
   END  
   FETCH NEXT FROM closeCursor INTO @CloseClient, @CloseGroupCode, @ClosePPED  
  END  
  CLOSE closeCursor  
  DEALLOCATE closeCursor    
END  
  
-- Fill out the remaining PPED's that need to be included  
INSERT INTO #groupPPED(Client, GroupCode, PPED)  
SELECT DISTINCT ped.Client, ped.GroupCode, ped.PayrollPeriodEndDate  
FROM #groupLastPPED tmp  
INNER JOIN TimeHistory..tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode  
AND ped.PayrollPeriodEndDate BETWEEN tmp.LateTimeCutoff AND tmp.PPED  
  
CREATE INDEX IDX_groupPPED_PK ON #groupPPED(Client, GroupCode, PPED)  

Create Table #tmpUploadExport  
(  
      SSN              INT           --Required in VB6: GenericPayrollUpload program  
    , EmployeeID       VARCHAR(20)   --Required in VB6: GenericPayrollUpload program  
    , EmpName          VARCHAR(120)  --Required in VB6: GenericPayrollUpload program  
    , FileBreakID      VARCHAR(20)   --The VB6: GenericPayrollUpload program will split apart payfiles on PayGroup from[TimeCurrent].[dbo].tbl_EmplNames  
    , weDate           DATETIME      --Required in VB6: GenericPayrollUpload program  
    , Approval         VARCHAR(1)  
    , Line1            VARCHAR(1000) --Required in VB6: GenericPayrollUpload program  
    , PayCode          VARCHAR(20)  
    , IMAGE_FILE_NAME  VARCHAR(50)  
    , SiteNo           INT  
    , DeptNo           INT  
    , GroupCode        INT  
    , Filter           VARCHAR(1)  
    , SnapshotDateTime DATETIME   
    , GenerateImage    INT  
    , AssignmentNo     VARCHAR(100)  
    , TransDate        DATETIME  
    , LateApproval     CHAR(1)  
    , [Hours]          NUMERIC(7,2)  
    , CustomerID       VARCHAR(50)  
    , BranchID         VARCHAR(50)  
    , TRCCode          VARCHAR(50)  
    , ProjectCode      VARCHAR(100)  
)  
  
--Used to return a list of Groups and PPED's to VB to auto-resolve disputes  
IF (@RecordType = 'D')  
BEGIN  
    INSERT INTO #tmpUploadExport( SSN, EmployeeID, EmpName, FileBreakID, weDate, Approval, Line1, PayCode, IMAGE_FILE_NAME,   
                                  SiteNo, DeptNo, GroupCode, Filter, SnapshotDateTime, GenerateImage, AssignmentNo, TransDate)  
    SELECT 1, '', '', '', PPED, '', '', '', '',   
           0, 0, GroupCode, @RecordType, '', '0', '', PPED  
    FROM #groupPPED  
      
    SELECT  SSN  
          , EmployeeID  
          , EmpName  
          , FileBreakID  
          , CONVERT(VARCHAR(10), weDate, 101) AS weDate  
          , approval  
          , Line1  
          , IMAGE_FILE_NAME  
          , SiteNo  
          , DeptNo  
          , GroupCode  
          , Filter  
          , SnapshotDateTime  
          , GenerateImage  
    FROM #tmpUploadExport  
      
    DROP TABLE #tmpUploadExport  
      
    RETURN         
END  
  
Create Table #tmpSSNs  
(   
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    SSN               INT,   
    TransCount        INT,   
    ApprovedCount     INT,  
    PayRecordsSent    DATETIME,  
    AprvlStatus_Date  DATETIME,  
    IVR_Count         INT,   
    WTE_Count         INT,   
    Fax_Count         INT,   
    FaxApprover_Count INT,    
    EmailClient_Count INT,  
    EmailBranch_Count INT,  
    EmailAgency_Count INT,  
    EmailOther_Count  INT,   
    Dispute_Count     INT,  
    OtherTxns_Count   INT,  
    AssignmentNo      VARCHAR(50),
    EmplID						VARCHAR(50),
    DeptNo						INT,  
    SnapshotDateTime  DATETIME,  
    JobID             INT,  
    AttachmentName    VARCHAR(200),  
    ApprovalMethodID  INT,  
    WorkState         VARCHAR(2),  
    IsSubVendor       VARCHAR(1),  
    [Hours]           NUMERIC(7, 2),  
    CalcHours         NUMERIC(7, 2),
    MobileSubmit			VARCHAR(1),
    PayGroup          VARCHAR(10)
)  
 
CREATE TABLE #tmpDailyHrs  
(  
    RecordID             INT IDENTITY (1, 1) NOT NULL,  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    PayrollPeriodEndDate DATETIME,  
    TransDate            DATETIME,  
    SSN                  INT,  
    ProjectCode          VARCHAR(50),  
    AssignmentNo         VARCHAR(50),  
    BranchID             VARCHAR(32),  
    EmplID							 VARCHAR(50),
    WorkedHours					 NUMERIC(9,2),  
    PayCode							 VARCHAR(50),
    PayAmount						 NUMERIC(9,2),  
    BillAmount					 NUMERIC(9,2),   
    ApproverName         VARCHAR(100),  
    ApproverEmail				 VARCHAR(100),
    ApprovalStatus       VARCHAR(1),  
    ApproverDateTime     DATETIME,  
    MaxRecordID          BIGINT,   --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
    TimeSheetId          INT,  
    SiteNo               INT,  
    DeptNo               INT,  
    TimeSource					 VARCHAR(10),
    ApprovalSource			 VARCHAR(10),
    SnapshotDateTime		 DATETIME,
    TxnType              VARCHAR(1)
)  
CREATE CLUSTERED INDEX IDX_tmpDailyHrs_RecordID ON #tmpDailyHrs(RecordId)    

CREATE TABLE #tmpProjectSummary
(
    RecordID             INT IDENTITY,
    GroupCode            INT,
    PayrollPeriodEndDate DATETIME,
    SSN                  INT, 
    AssignmentNo         VARCHAR(100), 
    DeptNo               INT,
    TransDate            DATETIME, 
    ProjectNum           VARCHAR(100), 
    ProjectHours         NUMERIC(9,2),
    ProjectRecordID      INT       
)      
CREATE CLUSTERED INDEX IDX_tmpProjectSummary_RecordID ON #tmpProjectSummary(RecordId) 
CREATE INDEX IDX_tmpProjectSummary_PK ON #tmpProjectSummary(GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo, TransDate)  
    
--PRINT 'RecordType: ' + @RecordType  
IF (@RecordType IN ('A', 'L', 'F'))  
BEGIN  
--    PRINT 'Before: INSERT INTO #tmpSSNs' + CONVERT(VARCHAR, GETDATE(), 121)  
    INSERT INTO #tmpSSNs  
    (  
          Client  
        , GroupCode  
        , PayrollPeriodEndDate  
        , SSN  
        , PayRecordsSent  
        , AssignmentNo  
        , EmplID
        , DeptNo
        , TransCount  
        , ApprovedCount  
        , AprvlStatus_Date  
        , IVR_Count  
        , WTE_Count  
        , Fax_Count  
        , FaxApprover_Count  
        , EmailClient_Count  
        , EmailBranch_Count  
        , EmailAgency_Count  
        , EmailOther_Count  
        , Dispute_Count  
        , OtherTxns_Count  
        , SnapshotDateTime  
        , JobID  
        , AttachmentName  
        , ApprovalMethodID  
        , WorkState  
        , IsSubVendor  
        , [Hours]  
        , CalcHours 
        , MobileSubmit 
        , PayGroup
    )  
    SELECT   
         t.Client  
       , t.GroupCode  
       , t.PayrollPeriodEndDate  
       , t.SSN  
       , PayRecordsSent = ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')  
       , CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END
       , tc_en.FileNo
       , ea.DeptNo
       , TransCount = SUM(1)  
       , ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)  
       , AprvlStatus_Date = MAX(isnull(t.AprvlStatus_Date,'1/2/1970'))  
       , IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)  
       , WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END)  
       , Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)  
       , FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID, 0) = @FaxApprover THEN 1 ELSE 0 END)  
       , EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)  
       , EmailBranch_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'BRA') THEN 1 ELSE 0 END)  
       , EmailAgency_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'AGE') THEN 1 ELSE 0 END)  
       , EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'COR') THEN 1 ELSE 0 END)  
       , Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END)  
       , OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END)  
       , SnapshotDateTime = @Today  
       , JobID = 0  
       , AttachmentName = th_esds.RecordID  
       , ApprovalMethodID = ea.ApprovalMethodID  
       , WorkState = ISNULL(ea.WorkState, '')  
       , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
       , SUM(t.Hours)  
       , SUM(t.RegHours + t.OT_Hours + t.DT_Hours)  
       , ISNULL(en.Mobile, '0')
       , ISNULL(tc_en.PayGroup, '')
    FROM #groupPPED grpped  
    INNER JOIN TimeHistory..tblTimeHistDetail as t  
    ON t.Client = grpped.Client  
    AND t.Groupcode = grpped.GroupCode  
    AND t.PayrollPeriodEndDate = grpped.PPED  
    INNER JOIN TimeHistory..tblEmplNames as en WITH(NOLOCK) 
    ON  en.Client = t.Client   
    AND en.GroupCode = t.GroupCode   
    AND en.SSN = t.SSN  
    AND en.PayrollPeriodenddate = t.PayrollPeriodenddate
    INNER JOIN TimeCurrent..tblEmplNames as tc_en WITH(NOLOCK) 
    ON  tc_en.Client = t.Client   
    AND tc_en.GroupCode = t.GroupCode   
    AND tc_en.SSN = t.SSN   
    INNER JOIN TimeCurrent..tblEmplAssignments as ea  WITH(NOLOCK) 
    ON  ea.Client = t.Client  
    AND ea.Groupcode = t.Groupcode  
    AND ea.SSN = t.SSN  
    AND ea.DeptNo =  t.DeptNo  
    INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds  WITH(NOLOCK) 
    ON  th_esds.Client = t.Client  
    AND th_esds.GroupCode = t.GroupCode  
    AND th_esds.SSN = t.SSN  
    AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
    AND th_esds.SiteNo = t.SiteNo  
    AND th_esds.DeptNo = t.DeptNo  
    AND ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970') = '1/1/1970'  
    LEFT JOIN timecurrent..tblAgencies a WITH(NOLOCK)  
    ON a.client = ea.Client  
    AND a.GroupCode = ea.GroupCode  
    AND a.Agency = ea.AgencyNo          
    WHERE (t.Hours <> 0 OR t.Dollars <> 0)
    GROUP BY  
          t.Client  
        , t.GroupCode  
        , t.PayrollPeriodEndDate  
        , t.SSN  
        , ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')  
        , CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END
        , ea.DeptNo
        , ea.approvalMethodID  
        , th_esds.RecordID  
        , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
        , tc_en.FileNo
        , ISNULL(ea.WorkState, '')
        , ISNULL(en.Mobile, '0')
        , ISNULL(tc_en.PayGroup, '')
    --PRINT 'After: INSERT INTO #tmpSSNs A, L, F' + CONVERT(VARCHAR, GETDATE(), 121)          
    -- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL    
    DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount      
END   
  
--PRINT 'After populate #tmpSSNs: ' + CONVERT(VARCHAR, GETDATE(), 121)  
--SELECT * FROM #tmpSSNs  
  
-- If we were passed in a list of states to restrict the output to, then delete all assignments that are not in that list  
IF (SELECT COUNT(*)  
    FROM @RestrictStateList) > 0  
BEGIN  
  DELETE FROM #tmpSSNs  
  WHERE WorkState NOT IN (SELECT n  
                          FROM @RestrictStateList)  
  AND TransCount <> ApprovedCount  
END  
--PRINT 'After: RestrictStateList' + CONVERT(VARCHAR, GETDATE(), 121)  
  
-- Remove Subvendors from the file  
IF (@ExcludeSubVendors = '1')  
BEGIN  
  DELETE FROM #tmpSSNs  
  WHERE IsSubVendor = '1'  
  AND TransCount <> ApprovedCount  
END  
--PRINT 'After: ExcludeSubVendors' + CONVERT(VARCHAR, GETDATE(), 121)     
  
-- OUT OF BALANCE  
DECLARE oobCursor CURSOR READ_ONLY  
FOR SELECT GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo, [Hours], CalcHours  
   FROM #tmpSSNs     
   WHERE [Hours] <> CalcHours  
  
OPEN oobCursor  
  
FETCH NEXT FROM oobCursor INTO @oobGroupCode, @oobPayrollPeriodEndDate, @oobSSN, @oobAssignmentNo, @oobHours, @oobCalcHours  
WHILE (@@fetch_status <> -1)  
BEGIN  
  IF (@@fetch_status <> -2)  
  BEGIN        
    SET @MailMessage = @MailMessage + 'GroupCode: ' + CAST(@oobGroupCode AS VARCHAR) + '; PPED: ' + CONVERT(VARCHAR, @oobPayrollPeriodEndDate, 101) + '; SSN: ' + CAST(@oobSSN AS VARCHAR) + '; Assignment: ' + @oobAssignmentNo  
    SET @MailMessage = @MailMessage + '; TotalHours: ' + CAST(@oobHours AS VARCHAR) + '; Calced Hours: ' + CAST(@oobCalcHours AS VARCHAR) + @crlf  
  END  
  FETCH NEXT FROM oobCursor INTO @oobGroupCode, @oobPayrollPeriodEndDate, @oobSSN, @oobAssignmentNo, @oobHours, @oobCalcHours  
END  
CLOSE oobCursor  
DEALLOCATE oobCursor    
  
IF (@MailMessage <> '')  
BEGIN  
  SELECT @MailMessage = @MailMessage + @crlf  
  SELECT @MailMessage = @MailMessage + 'Out of balance condition for the assignments above.  These assignments have been omitted from the payfile and will not be included until they are calculated correctly.'  
  
 INSERT INTO Scheduler..tblEmail ( Client, GroupCode, SiteNo, TemplateName, MailFrom, MailTo, MailCC,   
                                   MailSubject, MailMessage, Source)  
  VALUES( @Client, NULL, NULL, NULL, 'support@peoplenet.com', @MailToOOB, NULL,  
          'Randstad PCT Payfile Out of Balance', @MailMessage, 'GenericPayrollUpload')  
  SET @MailMessage = ''  
END  
  
-- Remove Out of Balance Transactions so as not to hold up the rest of the file  
DELETE FROM #tmpSSNs WHERE [Hours] <> CalcHours  
  
--PRINT 'Before: CREATE INDEX IDX_tmpSSNs_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpSSNs_PK ON #tmpSSNs(GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo)  
--PRINT 'After: CREATE INDEX IDX_tmpSSNs_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--  
--Get the Daily totals for each SSN, display the weekly total as one of the columns.  
--   
--PRINT 'Before: #tmpDailyHrs' + CONVERT(VARCHAR, GETDATE(), 121)  
-- REG
INSERT INTO #tmpDailyHrs (Client,  
													GroupCode,  
													PayrollPeriodEndDate,
													TransDate,
													SSN,
													AssignmentNo,  
													BranchID, 
													EmplID,
													WorkedHours,
													PayCode,
													PayAmount,
													BillAmount,
													ApprovalStatus,
													MaxRecordID,
													TimeSheetId,
													SiteNo,
													DeptNo,
													TimeSource,
													SnapshotDateTime,
													ProjectCode,
													TxnType)
SELECT  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
			, SUM(thd.RegHours)
      , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN @REGPAYCODE ELSE ac.ADP_HoursCode END
      , PayAmount = 0
      , BillAmount = 0 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END 
      , MAX(thd.RecordID)  
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo  
      , 'P' -- Default TimeSource to 'P' Dashboard
      , s.SnapshotDateTime
      , ''
      , 'H'
FROM #groupPPED grpped  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.Client = grpped.Client    
AND thd.GroupCode = grpped.GroupCode     
AND thd.PayrollPeriodEndDate = grpped.PPED  
INNER JOIN #tmpSSNs as s  
ON s.GroupCode = thd.GroupCode  
AND s.PayrollPeriodEndDate = thd.PayrollPeriodEndDate  
AND s.SSN = thd.SSN  
AND s.DeptNo = thd.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN('', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
INNER JOIN TimeCurrent..tblEmplAssignments as ea  WITH(NOLOCK) 
ON  ea.Client = thd.Client  
AND ea.Groupcode = thd.Groupcode  
AND ea.SSN = thd.SSN  
AND ea.DeptNo =  thd.DeptNo  
INNER JOIN TimeHistory..tblEmplSites_Depts as esd  WITH(NOLOCK) 
ON  esd.Client = thd.Client  
AND esd.Groupcode = thd.Groupcode  
AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate  
AND esd.SSN = thd.SSN  
AND esd.SiteNo = thd.SiteNo  
AND esd.DeptNo =  thd.DeptNo  
LEFT JOIN TimeCurrent..tblAgencies a WITH(NOLOCK)  
ON  a.Client = thd.Client  
AND a.GroupCode = thd.GroupCode  
AND a.Agency = thd.AgencyNo  
WHERE ISNULL(a.ExcludeFromPayFile, '0') <> '1'  
AND ac.Worked = 'Y'
AND thd.RegHours <> 0
GROUP BY  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
      , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN @REGPAYCODE ELSE ac.ADP_HoursCode END
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END
      , s.SnapshotDateTime
      
-- OT
INSERT INTO #tmpDailyHrs (Client,  
													GroupCode,  
													PayrollPeriodEndDate,
													TransDate,
													SSN,
													AssignmentNo,  
													BranchID, 
													EmplID,
													WorkedHours,
													PayCode,
													PayAmount,
													BillAmount,
													ApprovalStatus,
													MaxRecordID,
													TimeSheetId,
													SiteNo,
													DeptNo,
													TimeSource,
													SnapshotDateTime,
													ProjectCode,
													TxnType)
SELECT  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
			, SUM(thd.OT_Hours)
      , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN @OTPAYCODE ELSE ac.ADP_HoursCode END  -- GG - Not sure this is correct
      , PayAmount = 0
      , BillAmount = 0 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END 
      , MAX(thd.RecordID)  
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo  
      , 'P' -- Default TimeSource to 'P' Dashboard
      , s.SnapshotDateTime
      , ''
      , 'H'
FROM #groupPPED grpped  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.Client = grpped.Client    
AND thd.GroupCode = grpped.GroupCode     
AND thd.PayrollPeriodEndDate = grpped.PPED  
INNER JOIN #tmpSSNs as s  
ON s.GroupCode = thd.GroupCode  
AND s.PayrollPeriodEndDate = thd.PayrollPeriodEndDate  
AND s.SSN = thd.SSN  
AND s.DeptNo = thd.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN('', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
INNER JOIN TimeCurrent..tblEmplAssignments as ea  WITH(NOLOCK) 
ON  ea.Client = thd.Client  
AND ea.Groupcode = thd.Groupcode  
AND ea.SSN = thd.SSN  
AND ea.DeptNo =  thd.DeptNo  
INNER JOIN TimeHistory..tblEmplSites_Depts as esd  WITH(NOLOCK) 
ON  esd.Client = thd.Client  
AND esd.Groupcode = thd.Groupcode  
AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate  
AND esd.SSN = thd.SSN  
AND esd.SiteNo = thd.SiteNo  
AND esd.DeptNo =  thd.DeptNo  
LEFT JOIN TimeCurrent..tblAgencies a WITH(NOLOCK)  
ON  a.Client = thd.Client  
AND a.GroupCode = thd.GroupCode  
AND a.Agency = thd.AgencyNo  
WHERE ISNULL(a.ExcludeFromPayFile, '0') <> '1'  
AND ac.Worked = 'Y'
AND thd.OT_Hours <> 0
GROUP BY  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
      , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN @OTPAYCODE ELSE ac.ADP_HoursCode END
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END
      , s.SnapshotDateTime      
      
-- DT
INSERT INTO #tmpDailyHrs (Client,  
													GroupCode,  
													PayrollPeriodEndDate,
													TransDate,
													SSN,
													AssignmentNo,  
													BranchID, 
													EmplID,
													WorkedHours,
													PayCode,
													PayAmount,
													BillAmount,
													ApprovalStatus,
													MaxRecordID,
													TimeSheetId,
													SiteNo,
													DeptNo,
													TimeSource,
													SnapshotDateTime,
													ProjectCode,
													TxnType)
SELECT  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
			, SUM(thd.DT_Hours)
      , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN @DTPAYCODE ELSE ac.ADP_HoursCode END
      , PayAmount = 0
      , BillAmount = 0 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END 
      , MAX(thd.RecordID)  
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo  
      , 'P' -- Default TimeSource to 'P' Dashboard
      , s.SnapshotDateTime
      , ''
      , 'H'
FROM #groupPPED grpped  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.Client = grpped.Client    
AND thd.GroupCode = grpped.GroupCode     
AND thd.PayrollPeriodEndDate = grpped.PPED  
INNER JOIN #tmpSSNs as s  
ON s.GroupCode = thd.GroupCode  
AND s.PayrollPeriodEndDate = thd.PayrollPeriodEndDate  
AND s.SSN = thd.SSN  
AND s.DeptNo = thd.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN('', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
INNER JOIN TimeCurrent..tblEmplAssignments as ea  WITH(NOLOCK) 
ON  ea.Client = thd.Client  
AND ea.Groupcode = thd.Groupcode  
AND ea.SSN = thd.SSN  
AND ea.DeptNo =  thd.DeptNo  
INNER JOIN TimeHistory..tblEmplSites_Depts as esd  WITH(NOLOCK) 
ON  esd.Client = thd.Client  
AND esd.Groupcode = thd.Groupcode  
AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate  
AND esd.SSN = thd.SSN  
AND esd.SiteNo = thd.SiteNo  
AND esd.DeptNo =  thd.DeptNo  
LEFT JOIN TimeCurrent..tblAgencies a WITH(NOLOCK)  
ON  a.Client = thd.Client  
AND a.GroupCode = thd.GroupCode  
AND a.Agency = thd.AgencyNo  
WHERE ISNULL(a.ExcludeFromPayFile, '0') <> '1'  
AND ac.Worked = 'Y'
AND thd.DT_Hours <> 0
GROUP BY  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
      , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN @DTPAYCODE ELSE ac.ADP_HoursCode END
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END
      , s.SnapshotDateTime        
      
-- Non-Worked Hours
INSERT INTO #tmpDailyHrs (Client,  
													GroupCode,  
													PayrollPeriodEndDate,
													TransDate,
													SSN,
													AssignmentNo,  
													BranchID, 
													EmplID,
													WorkedHours,
													PayCode,
													PayAmount,
													BillAmount,
													ApprovalStatus,
													MaxRecordID,
													TimeSheetId,
													SiteNo,
													DeptNo,
													TimeSource,
													SnapshotDateTime,
													ProjectCode,
													TxnType)
SELECT  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
			, 0
      , ISNULL(ac.ADP_HoursCode, '')
      , PayAmount = SUM(thd.Hours)
      , BillAmount = SUM(thd.Hours) 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END 
      , MAX(thd.RecordID)  
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo  
      , 'P' -- Default TimeSource to 'P' Dashboard
      , s.SnapshotDateTime
      , ''
      , 'H'
FROM #groupPPED grpped  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.Client = grpped.Client    
AND thd.GroupCode = grpped.GroupCode     
AND thd.PayrollPeriodEndDate = grpped.PPED  
INNER JOIN #tmpSSNs as s  
ON s.GroupCode = thd.GroupCode  
AND s.PayrollPeriodEndDate = thd.PayrollPeriodEndDate  
AND s.SSN = thd.SSN  
AND s.DeptNo = thd.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN('', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
INNER JOIN TimeCurrent..tblEmplAssignments as ea  WITH(NOLOCK) 
ON  ea.Client = thd.Client  
AND ea.Groupcode = thd.Groupcode  
AND ea.SSN = thd.SSN  
AND ea.DeptNo =  thd.DeptNo  
INNER JOIN TimeHistory..tblEmplSites_Depts as esd  WITH(NOLOCK) 
ON  esd.Client = thd.Client  
AND esd.Groupcode = thd.Groupcode  
AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate  
AND esd.SSN = thd.SSN  
AND esd.SiteNo = thd.SiteNo  
AND esd.DeptNo =  thd.DeptNo  
LEFT JOIN TimeCurrent..tblAgencies a WITH(NOLOCK)  
ON  a.Client = thd.Client  
AND a.GroupCode = thd.GroupCode  
AND a.Agency = thd.AgencyNo  
WHERE ISNULL(a.ExcludeFromPayFile, '0') <> '1'  
AND ac.Worked = 'N'
AND thd.Hours <> 0
GROUP BY  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
      , ISNULL(ac.ADP_HoursCode, '')
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END
      , s.SnapshotDateTime        
      
-- Dollars
INSERT INTO #tmpDailyHrs (Client,  
													GroupCode,  
													PayrollPeriodEndDate,
													TransDate,
													SSN,
													AssignmentNo,  
													BranchID, 
													EmplID,
													WorkedHours,
													PayCode,
													PayAmount,
													BillAmount,
													ApprovalStatus,
													MaxRecordID,
													TimeSheetId,
													SiteNo,
													DeptNo,
													TimeSource,
													SnapshotDateTime,
													ProjectCode,
													TxnType)
SELECT  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
			, 0
      , ISNULL(ac.ADP_EarningsCode, '')
      , PayAmount = SUM(thd.Dollars)
      , BillAmount = SUM(thd.Dollars) 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END 
      , MAX(thd.RecordID)  
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo  
      , 'P' -- Default TimeSource to 'P' Dashboard
      , s.SnapshotDateTime
      , ''
      , 'D'
FROM #groupPPED grpped  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.Client = grpped.Client    
AND thd.GroupCode = grpped.GroupCode     
AND thd.PayrollPeriodEndDate = grpped.PPED  
INNER JOIN #tmpSSNs as s  
ON s.GroupCode = thd.GroupCode  
AND s.PayrollPeriodEndDate = thd.PayrollPeriodEndDate  
AND s.SSN = thd.SSN  
AND s.DeptNo = thd.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN('', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
INNER JOIN TimeCurrent..tblEmplAssignments as ea  WITH(NOLOCK) 
ON  ea.Client = thd.Client  
AND ea.Groupcode = thd.Groupcode  
AND ea.SSN = thd.SSN  
AND ea.DeptNo =  thd.DeptNo  
INNER JOIN TimeHistory..tblEmplSites_Depts as esd  WITH(NOLOCK) 
ON  esd.Client = thd.Client  
AND esd.Groupcode = thd.Groupcode  
AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate  
AND esd.SSN = thd.SSN  
AND esd.SiteNo = thd.SiteNo  
AND esd.DeptNo =  thd.DeptNo  
LEFT JOIN TimeCurrent..tblAgencies a WITH(NOLOCK)  
ON  a.Client = thd.Client  
AND a.GroupCode = thd.GroupCode  
AND a.Agency = thd.AgencyNo  
WHERE ISNULL(a.ExcludeFromPayFile, '0') <> '1'  
AND thd.Dollars <> 0
GROUP BY  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , ISNULL(CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END, '')  
      , ISNULL(ea.BranchID, '')  
      , ISNULL(s.EmplID, '')
      , ISNULL(ac.ADP_EarningsCode, '')
      , esd.RecordID  
      , thd.SiteNo  
      , thd.DeptNo 
      , CASE WHEN s.Dispute_Count > 0 THEN '2' ELSE '1' END
      , s.SnapshotDateTime         
--PRINT 'After: #tmpDailyHrs' + CONVERT(VARCHAR, GETDATE(), 121)  
        
--PRINT 'Before: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)                 
DELETE FROM #tmpDailyHrs WHERE WorkedHours = 0 AND PayAmount = 0  
--PRINT 'After: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: IDX_tmpDailyHrs ' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpDailyHrs_MaxRecordID ON #tmpDailyHrs(MaxRecordID)  
CREATE INDEX IDX_tmpDailyHrs_PK ON #tmpDailyHrs(Client, GroupCode, PayrollPeriodEndDate, SSN, DeptNo)  
--PRINT 'After: IDX_tmpDailyHrs ' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  
UPDATE tmpDailyHrs  
SET ApproverName = ISNULL(CASE  WHEN bkp.RecordId IS NOT NULL   
                         THEN LEFT(ISNULL(bkp.FirstName, '') + ' ' + ISNULL(bkp.LastName, ''), 50)
                         ELSE LEFT(ISNULL(usr.FirstName, '') + ' ' + usr.LastName, 50) 
                   END, ''),
    ApproverEmail = ISNULL(CASE WHEN bkp.RecordId IS NOT NULL   
                         THEN bkp.Email  
                         ELSE LEFT(ISNULL(usr.Email, ''), 50)    
                    END, ''),
		ApproverDateTime = thd.AprvlStatus_Date
FROM #tmpDailyHrs AS tmpDailyHrs  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.RecordID = tmpDailyHrs.MaxRecordID  
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp  WITH(NOLOCK) 
ON bkp.THDRecordId = tmpDailyHrs.MaxRecordID  
LEFT JOIN TimeCurrent..tblUser as Usr  WITH(NOLOCK) 
ON usr.UserID = ISNULL(thd.AprvlStatus_UserID,0)  
--PRINT 'After: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)       

--PRINT 'Before: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)  
UPDATE tmpDailyHrs  
SET TimeSource =  CASE WHEN tmpSSNs.IVR_Count > 0 THEN 'I'  
											 ELSE CASE WHEN tmpSSNs.Fax_Count > 0 THEN 'F'  
														ELSE CASE WHEN tmpSSNs.WTE_Count > 0 THEN 'W'   
																 ELSE CASE WHEN tmpSSNs.EmailClient_Count > 0 THEN 'L'  
																			ELSE CASE WHEN tmpSSNs.EmailBranch_Count > 0 THEN 'B'  
																					 ELSE CASE WHEN tmpSSNs.EmailAgency_Count > 0 THEN 'S'  
																								ELSE CASE WHEN tmpSSNs.MobileSubmit = '1' THEN 'M'                                          
																										 ELSE tmpDailyHrs.TimeSource
																										 END  
																								END  
																					 END  
																			END
																 END
													  END  
												END
		, ApprovalSource =  'W' -- Hardcode to Web for now											                                     
FROM #tmpDailyHrs AS tmpDailyHrs  
INNER JOIN #tmpSSNs AS tmpSSNs  
ON tmpSSNs.GroupCode = tmpDailyHrs.GroupCode  
AND tmpSSNs.PayrollPeriodEndDate = tmpDailyHrs.PayrollPeriodEndDate  
AND tmpSSNs.SSN = tmpDailyHrs.SSN  
AND tmpSSNs.DeptNo = tmpDailyHrs.DeptNo  
--PRINT 'After: Source Update' + CONVERT(VARCHAR, GETDATE(), 121) 
 
-- Summarize the project information incase it has duplicates   
INSERT INTO #tmpProjectSummary (GroupCode      
                              , SSN
                              , DeptNo
                              , AssignmentNo
                              , PayrollPeriodEndDate
                              , TransDate
                              , ProjectNum
                              , ProjectHours
                              , ProjectRecordID)
SELECT  pr.GroupCode
      , pr.SSN
      , pr.DeptNo
      , CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END
      , pr.PayrollPeriodEndDate
      , pr.TransDate
      , pr.ProjectNum
      , SUM(pr.Hours)
      , pr.RecordId
FROM #tmpSSNs AS s
INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_Project pr
ON pr.Client = @Client
AND pr.GroupCode = s.GroupCode
AND pr.SSN = s.SSN
AND pr.DeptNo = s.DeptNo
AND pr.PayrollPeriodEndDate = s.PayrollPeriodEndDate
INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea WITH(NOLOCK)
ON ea.Client = pr.Client
AND ea.GroupCode = pr.GroupCode
AND ea.SSN = pr.SSN
AND ea.SiteNo = pr.SiteNo
AND ea.DeptNo = pr.DeptNo
GROUP BY  pr.GroupCode
        , pr.SSN
        , pr.DeptNo
        , CASE WHEN ea.Brand IN ('REL', 'PIC', 'RUS', 'RIS', 'RPO', 'TFL', 'ACC', 'EST') THEN ea.OrderID ELSE ea.AssignmentNo END
        , pr.PayrollPeriodEndDate
        , pr.TransDate
        , pr.ProjectNum
        , pr.RecordId
ORDER BY pr.RecordId

IF EXISTS(SELECT 1 FROM #tmpProjectSummary)
BEGIN

  DECLARE @pr_GroupCode int
  DECLARE @pr_SSN int
  DECLARE @pr_DeptNo int
  DECLARE @pr_AssignmentNo VARCHAR(50)
  DECLARE @pr_PayrollPeriodEndDate datetime
  DECLARE @pr_TransDate datetime
  DECLARE @pr_ProjectNum VARCHAR(100)
  DECLARE @pr_ProjectHours NUMERIC(7, 2)
  DECLARE @pr_ProjectRecordID INT
  
  DECLARE @dly_WorkedHours NUMERIC(7, 2)
  DECLARE @dly_PayCode VARCHAR(20)
  DECLARE @dly_PayAmount NUMERIC(7, 2)
  DECLARE @dly_BillAmount NUMERIC(7, 2)
  DECLARE @dly_RecordID INT 

  DECLARE projectCursor CURSOR FOR
  SELECT GroupCode, SSN, DeptNo, AssignmentNo, PayrollPeriodEndDate, TransDate, ProjectNum, ProjectHours, ProjectRecordID
  FROM #tmpProjectSummary
  WHERE ProjectHours <> 0
  ORDER BY ProjectRecordID
  OPEN projectCursor

  FETCH NEXT FROM projectCursor
  INTO @pr_GroupCode, @pr_SSN, @pr_DeptNo, @pr_AssignmentNo, @pr_PayrollPeriodEndDate, @pr_TransDate, @pr_ProjectNum, @pr_ProjectHours, @pr_ProjectRecordID

  WHILE @@FETCH_STATUS = 0
  BEGIN	
    --PRINT CAST(@pr_TransDate AS VARCHAR) + ' - ' + @pr_ProjectNum + ' - ' + CAST(@pr_ProjectHours AS varchar)
    DECLARE dlyHoursCursor CURSOR FOR
    SELECT WorkedHours, PayCode, PayAmount, BillAmount, RecordID
    FROM #tmpDailyHrs
    WHERE GroupCode = @pr_GroupCode
    AND SSN = @pr_SSN
    AND DeptNo = @pr_DeptNo
    AND PayrollPeriodEndDate = @pr_PayrollPeriodEndDate
    AND TransDate = @pr_TransDate
    AND ISNULL(ProjectCode, '') = ''
    AND TxnType = 'H'
    ORDER BY CASE PayCode WHEN @REGPAYCODE THEN 1
                          WHEN @OTPAYCODE THEN 2
                          WHEN @DTPAYCODE THEN 3
                          ELSE 4 END
    OPEN dlyHoursCursor

    FETCH NEXT FROM dlyHoursCursor
    INTO @dly_WorkedHours, @dly_PayCode, @dly_PayAmount, @dly_BillAmount, @dly_RecordID

    WHILE @@FETCH_STATUS = 0 AND @pr_ProjectHours > 0
    BEGIN	
    
      --PRINT CAST(@dly_WorkedHours AS VARCHAR) + ' - ' + @dly_PayCode + ' - ' + CAST(@dly_PayAmount AS VARCHAR) + ' - ' + CAST(@dly_BillAmount AS VARCHAR)
      
      IF (@pr_ProjectHours = @dly_WorkedHours)
      BEGIN
        UPDATE #tmpDailyHrs
        SET ProjectCode = @pr_ProjectNum
        WHERE RecordID = @dly_RecordID
        
        SET @pr_ProjectHours = 0
      END
      ELSE IF (@pr_ProjectHours < @dly_WorkedHours)
      BEGIN
        UPDATE #tmpDailyHrs
        SET ProjectCode = @pr_ProjectNum,
            WorkedHours = @pr_ProjectHours
        WHERE RecordID = @dly_RecordID        
        
        INSERT INTO #tmpDailyHrs (Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, ProjectCode, AssignmentNo, BranchID, EmplID, WorkedHours, 
                                  PayCode, PayAmount, BillAmount, ApproverName, ApproverEmail, ApprovalStatus, ApproverDateTime, MaxRecordID, 
                                  TimeSheetId, SiteNo, DeptNo, TimeSource, ApprovalSource, SnapshotDateTime, TxnType)
        SELECT  Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, '' AS ProjectCode, AssignmentNo, BranchID, EmplID, WorkedHours = @dly_WorkedHours - @pr_ProjectHours, 
                PayCode, PayAmount, BillAmount, ApproverName, ApproverEmail, ApprovalStatus, ApproverDateTime, MaxRecordID, 
                TimeSheetId, SiteNo, DeptNo, TimeSource, ApprovalSource, SnapshotDateTime, TxnType                            
        FROM #tmpDailyHrs
        WHERE RecordID = @dly_RecordID
        
        SET @pr_ProjectHours = 0
      END     
      ELSE IF (@pr_ProjectHours > @dly_WorkedHours) 
      BEGIN
        UPDATE #tmpDailyHrs
        SET ProjectCode = @pr_ProjectNum
        WHERE RecordID = @dly_RecordID       
        
        SET @pr_ProjectHours = @pr_ProjectHours - @dly_WorkedHours
      END
      ELSE IF (@pr_ProjectHours = @dly_PayAmount)
      BEGIN
        UPDATE #tmpDailyHrs
        SET ProjectCode = @pr_ProjectNum
        WHERE RecordID = @dly_RecordID
        
        SET @pr_ProjectHours = 0
      END
      ELSE IF (@pr_ProjectHours < @dly_PayAmount)
      BEGIN
        UPDATE #tmpDailyHrs
        SET ProjectCode = @pr_ProjectNum,
            PayAmount = @pr_ProjectHours,
            BillAmount = @pr_ProjectHours
        WHERE RecordID = @dly_RecordID        
        
        INSERT INTO #tmpDailyHrs (Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, ProjectCode, AssignmentNo, BranchID, EmplID, WorkedHours, 
                                  PayCode, PayAmount, BillAmount, ApproverName, ApproverEmail, ApprovalStatus, ApproverDateTime, MaxRecordID, 
                                  TimeSheetId, SiteNo, DeptNo, TimeSource, ApprovalSource, SnapshotDateTime, TxnType)
        SELECT  Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, '' AS ProjectCode, AssignmentNo, BranchID, EmplID, WorkedHours, 
                PayCode, PayAmount = @dly_PayAmount - @pr_ProjectHours, BillAmount = @dly_BillAmount - @pr_ProjectHours, ApproverName, ApproverEmail, ApprovalStatus, ApproverDateTime, MaxRecordID, 
                TimeSheetId, SiteNo, DeptNo, TimeSource, ApprovalSource, SnapshotDateTime, TxnType                                  
        FROM #tmpDailyHrs
        WHERE RecordID = @dly_RecordID
        
        SET @pr_ProjectHours = 0
      END    
      ELSE IF (@pr_ProjectHours > @dly_PayAmount) 
      BEGIN
        UPDATE #tmpDailyHrs
        SET ProjectCode = @pr_ProjectNum
        WHERE RecordID = @dly_RecordID       
        
        SET @pr_ProjectHours = @pr_ProjectHours - @dly_PayAmount
      END        

      FETCH NEXT FROM dlyHoursCursor
      INTO @dly_WorkedHours, @dly_PayCode, @dly_PayAmount, @dly_BillAmount, @dly_RecordID
    END
    CLOSE dlyHoursCursor
    DEALLOCATE dlyHoursCursor 

	  FETCH NEXT FROM projectCursor
	  INTO @pr_GroupCode, @pr_SSN, @pr_DeptNo, @pr_AssignmentNo, @pr_PayrollPeriodEndDate, @pr_TransDate, @pr_ProjectNum, @pr_ProjectHours, @pr_ProjectRecordID
  END
  CLOSE projectCursor
  DEALLOCATE projectCursor 

END  -- IF EXISTS(SELECT 1 FROM #tmpProjectSummary) 

/*  
The order of these final 3 steps is VERY IMPORTANT  
1. Update Pay Records Sent  
2. Remove Negatives  
3. Return recordset to VB  
*/  

-- 1. Update Pay Records Sent  
IF (@RecordType <> 'D' AND @TestingFlag IN ('N', '0') )  
BEGIN  
    UPDATE TimeHistory..tblEmplSites_Depts  
    SET TimeHistory..tblEmplSites_Depts.PayRecordsSent = u.SnapshotDateTime  
    FROM #tmpDailyHrs as u  
    INNER JOIN TimeHistory..tblEmplSites_Depts th_esds  
    ON th_esds.Client = @Client  
    AND th_esds.GroupCode = u.GroupCode  
    AND th_esds.PayrollPeriodenddate = u.PayrollPeriodEndDate  
    AND th_esds.SSN = u.SSN  
    AND th_esds.SiteNo = u.SiteNo  
    AND th_esds.DeptNo = u.DeptNo  
    AND th_esds.PayRecordsSent IS NULL
  
    Update TimeCurrent.dbo.tblClosedPeriodAdjs  
    Set TimeCurrent.dbo.tblClosedPeriodAdjs.DateTimeProcessed = ouw.SnapshotDateTime  
    from #tmpDailyHrs as ouw  
    Inner Join TimeCurrent.dbo.tblClosedPeriodAdjs cpa  
    on cpa.Client = @Client  
    AND cpa.GroupCode = ouw.Groupcode  
    AND cpa.PayrollPeriodEndDate = ouw.PayrollPeriodEndDate  
    and cpa.SSN = ouw.SSN  
    and cpa.DateTimeProcessed IS NULL             
   
END  
  
DECLARE @AssignmentNo VARCHAR(50)

-- 2. Handle Negatives  
DECLARE negCursor CURSOR READ_ONLY  
FOR SELECT cg.GroupName, ue.AssignmentNo, ue.TransDate, ue.WorkedHours
   FROM #tmpDailyHrs ue  
   INNER JOIN TimeCurrent.dbo.tblClientGroups cg WITH(NOLOCK)  
   ON cg.Client = @Client  
   AND cg.GroupCode = ue.GroupCode  
   WHERE ue.WorkedHours < 0  
  
OPEN negCursor  
  
FETCH NEXT FROM negCursor INTO @GroupName, @AssignmentNo, @NegTransDate, @NegHours  
WHILE (@@fetch_status <> -1)  
BEGIN  
  IF (@@fetch_status <> -2)  
  BEGIN  
    --PRINT 'negative exists'  
    SET @MailMessage = @MailMessage + 'Branch: ' + @GroupName + '; Assignment: ' + @AssignmentNo + '; Date: ' + CONVERT(VARCHAR, @NegTransDate, 101) + '; Hours: ' + CAST(@NegHours AS VARCHAR) + @crlf + @crlf  
    --PRINT @MailMessage  
  END  
  FETCH NEXT FROM negCursor INTO @GroupName, @AssignmentNo, @NegTransDate, @NegHours  
END  
CLOSE negCursor  
DEALLOCATE negCursor    
  
IF (@MailMessage <> '')  
BEGIN  
  SELECT @MailMessage = @MailMessage + @crlf  
  SELECT @MailMessage = @MailMessage + 'Negative hours were submitted for pay/bill processing from your PeopleNet system on the SSN and Assignment# above. Randstad''s system does not accept negative hours for an employee.  The associate''s weekly record was removed from the PeopleNet pay file for processing.' + @crlf + @crlf  
  SELECT @MailMessage = @MailMessage + 'You must submit a correction or pay/bill adjustment for ALL hours worked by this associate and assignment# in order for time to be processed for this individual.'  
  
 INSERT INTO Scheduler..tblEmail ( Client, GroupCode, SiteNo, TemplateName, MailFrom, MailTo, MailCC,   
                                   MailSubject, MailMessage, Source)  
  VALUES( @Client, NULL, NULL, NULL, 'support@peoplenet.com', @MailToNegs, NULL,  
          'Employees with negative hours removed from pay file', @MailMessage, 'GenericPayrollUpload')  
END  
  
-- 3. Return recordset to VB  --  PUT BACK IN  
SELECT
          SSN  = CONVERT(INT, t.SSN)  
        , EmployeeID = RIGHT(CONVERT(VARCHAR(20), ISNULL(t.EmplID, '')), 9)
        , EmpName = ISNULL(en.LastName, '') + ', ' + ISNULL(en.FirstName, '')
        --, FileBreakID = ''  
        , weDate = t.PayrollPeriodEndDate  
        , Approval = CASE WHEN ApprovalStatus = '0' THEN '0' ELSE '1' END          
        , Line1 =   
           en.FirstName + @Delim +
           en.LastName + @Delim +
           t.EmplID + @Delim + 
           t.AssignmentNo + @Delim +
           CONVERT(VARCHAR, t.PayrollPeriodEndDate, 101) + @Delim +
           CONVERT(VARCHAR, t.TransDate, 101) + @Delim +
           CAST(t.WorkedHours AS VARCHAR) + @Delim +
           t.PayCode + @Delim + 
           CAST(t.PayAmount AS VARCHAR) + @Delim +
           CAST(t.BillAmount AS VARCHAR) + @Delim +
           t.ProjectCode + @Delim + 
           t.ApproverName + @Delim + 
           t.ApproverEmail + @Delim + 
           CONVERT(VARCHAR, t.ApproverDateTime, 101) + ' ' + REPLACE(SUBSTRING(CONVERT(VARCHAR, t.ApproverDateTime, 109), 13, 5), ' ', '0') + RIGHT(t.ApproverDateTime, 2) + @Delim +
           s.PayGroup + @Delim + 
           t.TimeSource + @Delim +
           t.ApprovalSource + @Delim + 
           CAST(t.TimesheetID AS VARCHAR) + @Delim +
           t.ApprovalStatus + @Delim +
           t.BranchID + @Delim +
           CONVERT(VARCHAR, @Today, 101) + ' ' + REPLACE(SUBSTRING(CONVERT(VARCHAR, @Today, 109), 13, 8), ' ', '0') + RIGHT(@Today, 2)
        ,  PayCode = t.PayCode  
        ,  IMAGE_FILE_NAME = CAST(t.TimesheetID AS VARCHAR)
        ,  t.SiteNo  
        ,  t.DeptNo  
        ,  t.GroupCode  
        ,  @RecordType  
        ,  t.SnapshotDateTime  
        ,  GenerateImage = '0'
        ,  t.AssignmentNo  
        ,  t.TransDate  
        ,  WorkedHours
        ,  BranchID             
FROM #tmpDailyHrs t
INNER JOIN TimeCurrent.dbo.tblEmplNames en
ON en.Client = t.Client
AND en.GroupCode = t.GroupCode
AND en.SSN = t.SSN
INNER JOIN #tmpSSNs as s  
ON s.GroupCode = t.GroupCode  
AND s.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
AND s.SSN = t.SSN  
AND s.DeptNo = t.DeptNo
ORDER BY t.GroupCode, t.SSN, t.AssignmentNo, t.TransDate, t.PayCode, t.ProjectCode
           
--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         
         
DROP TABLE #tmpSSNs  
DROP TABLE #tmpProjectSummary  
DROP TABLE #tmpDailyHrs  
   
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN
