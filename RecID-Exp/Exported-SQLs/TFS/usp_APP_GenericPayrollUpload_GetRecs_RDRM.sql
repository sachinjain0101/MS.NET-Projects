Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_RDRM]  
(   
  @Client         char(4),  
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
DECLARE @PPEDCursor         DATETIME   
DECLARE @LateTimeEntryWeeks INT  
DECLARE @LateTimeCutoff     DATETIME  
DECLARE @PayrollFreq        CHAR(1)  
DECLARE @Today              DATETIME   
DECLARE @RestrictStateList  varchar_list_tbltype  
DECLARE @ExcludeSubVendors  VARCHAR(1)  
DECLARE @FaxApprover        INT  
DECLARE @MailMessage        VARCHAR(8000)  
DECLARE @MailToNegs         VARCHAR(500)  
DECLARE @MailToOOB          VARCHAR(500)  
DECLARE @crlf               CHAR(2)  
DECLARE @oobGroupCode       INT  
DECLARE @oobPayrollPeriodEndDate DATETIME  
DECLARE @oobSSN             INT  
DECLARE @oobAssignmentNo    VARCHAR(100)  
DECLARE @oobHours           NUMERIC(7, 2)  
DECLARE @oobCalcHours       NUMERIC(7, 2)   
DECLARE @MailToExcluded     VARCHAR(500)

/* Problem with Harmony where these values are getting inserted into a numeric field.  This should be removed when that issue is fixed.*/
update timehistory..tblTimeHistDetail_UDF 
set fieldvalue = '0.00'
where FieldValue in ('undefined','nan')
and Client = 'rdrm'

-- Mark assignments with missing Events as being sent already
/*UPDATE esd
SET PayRecordsSent = '5/1/2014', ExcludeFromUpload_DateTime = '5/1/2014'
FROM TimeHistory..tblTimeHistDetail thd WITH (NOLOCK)
INNER JOIN TimeHistory..tblEmplSites_Depts esd WITH (NOLOCK)
ON thd.Client = esd.Client
AND thd.GroupCode = esd.GroupCode
AND thd.ssn = esd.ssn
AND thd.SiteNo = esd.SiteNo
AND thd.DeptNo = esd.DeptNo
AND thd.PayrollPeriodEndDate = esd.Payrollperiodenddate
AND esd.PayRecordsSent IS NULL
LEFT JOIN TimeHistory..tblTimeHistDetail_UDF thdu WITH (NOLOCK)
ON thd.Client = thdu.Client
AND thd.GroupCode = thdu.GroupCode
AND thd.SiteNo = thdu.SiteNo
AND thd.DeptNo = thdu.DeptNo
AND thd.SSN = thdu.SSN
AND thd.PayrollPeriodEndDate = thdu.Payrollperiodenddate
AND thdu.FieldID = 1058
WHERE thd.Client = 'rdrm'
AND thd.GroupCode IN (139,145,136,142,138,144,137,143,135,141,134,140)
AND thd.PayrollPeriodEndDate > '2/1/2014'
AND thd.AprvlStatus IN ('A','L')
AND thdu.RecordID IS NULL*/

SET @Today = GETDATE()  
SET @PPEDMinus6 = DATEADD(dd, -6, @PPED)  
SET @ExcludeSubVendors = '0' -- Exclude SubVendors from all Unapproved pay files  
SET @RecordType = LEFT(@PayrollType, 1)  -- default to Approved  
SET @crlf = char(13) + char(10)  
SET @MailMessage = ''  
  
IF (@TestingFlag IN ('N', '0'))  
BEGIN  
  SET @MailToNegs = 'appemails@peoplenet.com'  
  SET @MailToOOB = 'server@peoplenet.com'  
  SET @MailToExcluded = 'David.Larrier@randstadusa.com; Michael.Wilcher@peoplenet.com; charmaine.burke@randstadsourceright.com; jim.moore@peoplenet.com; Dan.Pruitt@peoplenet.com;jennifer.collins@randstadsourceright.com;christine.mason@randstadsourceright.com;kevin.moran@randstadsourceright.com;staci.boone@randstadsourceright.com;courtney.house@randstadsourceright.com;amber.neill@randstadsourceright.com;isaac.yu@randstadsourceright.com;'
END  
ELSE  
BEGIN  
  SET @MailToNegs = 'appemails@peoplenet.com' 
  SET @MailToOOB = 'gary.gordon@peoplenet.com'  
  SET @MailToExcluded = 'gary.gordon@peoplenet.com'
END  
  
SELECT @FaxApprover = UserID   
FROM TimeCurrent.dbo.tblUser WITH(NOLOCK)  
WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER'   
AND Client = @Client  
  
CREATE TABLE #groupLastPPED  
(  
  Client                  VARCHAR(4),  
  GroupCode               INT,  
  PPED                    DATETIME,  
  LateTimeCutoff          DATETIME,
  AdditionalApprovalWeeks INT 
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
*/  
  
INSERT INTO #groupLastPPED(Client, GroupCode, PPED, LateTimeCutoff, AdditionalApprovalWeeks)  
SELECT cg.Client, cg.GroupCode, ped.PayrollPeriodEndDate, DATEADD(dd, cg.LateTimeEntryWeeks * 7 * -1, ped.PayrollPeriodEndDate), ISNULL(c.AdditionalApprovalWeeks, 0)
FROM TimeCurrent.[dbo].tblClientGroups cg WITH(NOLOCK)  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = cg.Client
AND ped.GroupCode = cg.GroupCode
AND ped.PayrollPeriodEndDate BETWEEN @PPEDMinus6 AND @PPED  
INNER JOIN TimeCurrent.dbo.tblClients c WITH(NOLOCK)  
ON c.Client = cg.Client
WHERE cg.Client = @Client  
--AND cg.GroupCode = 104
AND cg.RecordStatus = '1'  
AND cg.IncludeInUpload = '1'  
AND cg.StaffingSetupType = '1'    
CREATE INDEX IDX_groupLastPPED_PK ON #groupLastPPED(Client, GroupCode, PPED)  
  
-- Close out "Last Week"  
IF (@RecordType = 'F' AND @TestingFlag = 'N')  
BEGIN  
  DECLARE @CloseClient varchar(4)  
  DECLARE @CloseGroupCode int   
  DECLARE @ClosePPED datetime   
    
  -- Close the current week and make it available for Late Time Entry  
  /* Going to leave the recent weeks fully open for RDRM  
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
  AND ped.PayrollPeriodEndDate = tmp.PPED*/
      
  -- Let the oldest of the late time entry weeks drop off so that it can't be used anymore on WTE  
  UPDATE ped  
  SET OverrideStatus = '0',  
      Status = 'C',
      MaintUserName = 'System',  
      MaintDateTime = @Today  
  FROM TimeHistory.dbo.tblPeriodEndDates ped  
  INNER JOIN #groupLastPPED tmp  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate <= tmp.LateTimeCutoff  
  AND (ISNULL(ped.OverrideStatus, '') <> '0' OR Status <> 'C')
    
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
INNER JOIN TimeHistory..tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode  
AND ped.PayrollPeriodEndDate BETWEEN DATEADD(ww, -1 * ISNULL(tmp.AdditionalApprovalWeeks, 0), DATEADD(dd, -7, tmp.LateTimeCutoff)) AND tmp.PPED    
CREATE INDEX IDX_groupPPED_PK ON #groupPPED(Client, GroupCode, PPED)  

IF (@RecordType = 'D')
BEGIN
	SELECT  1 as SSN,
					'' as EmployeeID,  
					'' as EmpName, 
					GroupCode,
					PPED AS weDate,
					Line1 = ''
	FROM #groupPPED	
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
    AprvlStatus_Date  DATETIME,  
    IVR_Count         INT,   
    WTE_Count         INT,   
    Fax_Count         INT,   
    FaxApprover_Count INT,    
    EmailClient_Count INT,  
    EmailOther_Count  INT,   
    Dispute_Count     INT,  
    OtherTxns_Count   INT,  
    AssignmentNo      VARCHAR(50),  
    SnapshotDateTime  DATETIME,  
    JobID             INT,  
    AttachmentName    VARCHAR(200),  
    ApprovalMethodID  INT,  
    WorkState         VARCHAR(2),  
    IsSubVendor       VARCHAR(1),  
    [Hours]           NUMERIC(14, 2),  
    CalcHours         NUMERIC(14, 2),
    EmpName           VARCHAR(100)
)  
      
CREATE TABLE #tmpDailyHrs  
(  
    RecordID             INT IDENTITY (1, 1) NOT NULL,  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    SiteNo               INT,  
    DeptNo               INT,      
    SSN                  INT,  
    BusinessUnit         VARCHAR(10),
    PayrollPeriodEndDate DATETIME,  
    CustID               VARCHAR(100),
    TransDate            DATETIME,      
    OrderPoint           VARCHAR(50),  
    FileNo               VARCHAR(50),  
    AssignmentNo         VARCHAR(50),      
    PayRate              NUMERIC(14, 2),  
    BillRate             NUMERIC(14, 2),
    TotalHours           NUMERIC(14, 2),   
    MaxTHDRecordID       BIGINT,  --< MaxTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 10Aug2016 >--
    ApproverName         VARCHAR(200),
    SnapshotDateTime     DATETIME,
    EmpName              VARCHAR(100) 
)  
CREATE CLUSTERED INDEX IDX_tmpDailyHrs_RecordID ON #tmpDailyHrs(RecordId)  

CREATE TABLE #tmpDailyDetails  
(  
    RecordID             INT IDENTITY (1, 1) NOT NULL,  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    SiteNo               INT,  
    DeptNo               INT,      
    SSN                  INT,  
    BusinessUnit         VARCHAR(10),
    PayrollPeriodEndDate DATETIME,  
    CustID               VARCHAR(100),
    TransDate            DATETIME,      
    OrderPoint           VARCHAR(50),  
    FileNo               VARCHAR(50),  
    AssignmentNo         VARCHAR(50),      
    PayRate              NUMERIC(14, 2),  
    BillRate             NUMERIC(14, 2),
    TotalHours           NUMERIC(14, 2),   
    MaxTHDRecordID       BIGINT,  --< MaxTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 10Aug2016 >--
    ApproverName         VARCHAR(200),
    Brand                VARCHAR(20),
    Sales                NUMERIC(14, 2),
    CoOp                 VARCHAR(20),
    Event                VARCHAR(20),
    Season               VARCHAR(20),
    SnapshotDateTime     DATETIME,
    EmpName              VARCHAR(100)
)

CREATE TABLE #tmpUDFSummary  
(  
    RecordId              INT IDENTITY,  
    Client                VARCHAR(4),
    GroupCode             INT,  
    SSN                   INT,   
    SiteNo                INT,
    DeptNo                INT,
    PayrollPeriodEndDate  DATETIME,  
    TransDate             DATETIME,   
    THD_GroupingID        INT,
    Brand                 VARCHAR(100),
    BrandHours            NUMERIC(14, 2),   
    Sales                 NUMERIC(14, 2),
    Event                 VARCHAR(100),
    CoOp                  VARCHAR(100),
    Season                VARCHAR(100) 
)   

--PRINT 'RecordType: ' + @RecordType  
IF (@RecordType IN ('A', 'L', 'F'))  
BEGIN  
    --PRINT 'Before: INSERT INTO #tmpSSNs' + CONVERT(VARCHAR, GETDATE(), 121)  
    INSERT INTO #tmpSSNs  
    (  
          Client  
        , GroupCode  
        , PayrollPeriodEndDate  
        , SSN  
        , AssignmentNo  
        , TransCount  
        , ApprovedCount  
        , AprvlStatus_Date  
        , IVR_Count  
        , WTE_Count  
        , Fax_Count  
        , FaxApprover_Count  
        , EmailClient_Count  
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
        , EmpName
    )  
    SELECT   
         t.Client  
       , t.GroupCode  
       , t.PayrollPeriodEndDate  
       , t.SSN  
       , ea.AssignmentNo  
       , TransCount = SUM(1)  
       , ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)  
       , AprvlStatus_Date = MAX(isnull(t.AprvlStatus_Date,'1/2/1970'))  
       , IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)  
       , WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END)  
       , Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)  
       , FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID, 0) = @FaxApprover THEN 1 ELSE 0 END)  
       , EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)  
       , EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END)  
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
       , en.LastName + ', ' + en.FirstName
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
    AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'
    LEFT JOIN timecurrent..tblAgencies a WITH(NOLOCK)  
    ON a.client = ea.Client  
    AND a.GroupCode = ea.GroupCode  
    AND a.Agency = ea.AgencyNo          
    WHERE t.Hours <> 0  
    GROUP BY  
          t.Client  
        , t.GroupCode  
        , t.PayrollPeriodEndDate  
        , t.SSN  
        , ea.AssignmentNo  
        , ea.approvalMethodID  
        , th_esds.RecordID  
        , ISNULL(ea.WorkState, '')  
        , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
        , en.LastName + ', ' + en.FirstName
    --PRINT 'After: INSERT INTO #tmpSSNs A, L, F' + CONVERT(VARCHAR, GETDATE(), 121)          
      
    -- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL  
    IF (@RecordType IN ('A','F'))  
    BEGIN       
      --PRINT 'Before DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  
      DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount  
      --PRINT 'After DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  
    END       
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
          'Payfile Out of Balance', @MailMessage, 'GenericPayrollUpload')  
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
   
INSERT INTO #tmpDailyHrs 
SELECT  thd.Client,
        thd.GroupCode,
        thd.SiteNo,
        thd.DeptNo,
        thd.SSN,
        'RELBU',  -- Business Unit
        thd.PayrollPeriodEndDate,
        LEFT(groups.RFR_UniqueID + SPACE(15), 15), -- CustID
        thd.TransDate,
        LEFT(sites.CompanyID + SPACE(10), 10), -- Order Point
        RIGHT(SPACE(11) + empls.FileNo, 11),
        ea.AssignmentNo,        
        ISNULL(thd.PayRate,0),         
        ISNULL(thd.BillRate,0),        
        SUM(thd.Hours),
        MAX(thd.RecordID),
        '' AS ApproverName,
        s.SnapshotDateTime,
        s.EmpName
	      --Flag_CoOp = TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'COOP'),
	      --Flag_Event = TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'EVNT'),
	      --Flag_Season = TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'SESN'),
	      --Flag_Brand = TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'BRND'),
	      --Flag_Sales = TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'SALES')
FROM #groupPPED grpped
INNER JOIN TimeHistory..tblTimeHistDetail thd
ON thd.Client = grpped.Client
  AND thd.GroupCode = grpped.GroupCode
  AND thd.PayrollPeriodEndDate = grpped.PPED
  AND thd.Hours <> 0
INNER JOIN TimeCurrent..tblEmplAssignments as ea  WITH(NOLOCK) 
ON  ea.Client = thd.Client  
  AND ea.Groupcode = thd.Groupcode  
  AND ea.SSN = thd.SSN  
  AND ea.DeptNo =  thd.DeptNo    
INNER JOIN #tmpSSNs as s  
ON s.GroupCode = thd.GroupCode  
  AND s.PayrollPeriodEndDate = thd.PayrollPeriodEndDate  
  AND s.SSN = thd.SSN  
  AND s.AssignmentNo = ea.AssignmentNo    
INNER JOIN TimeCurrent..tblClientGroups groups
ON groups.Client = thd.Client
  AND groups.GroupCode = thd.GroupCode
INNER JOIN TimeCurrent..tblEmplNames empls
ON empls.Client = thd.Client
  AND empls.GroupCode = thd.GroupCode
  AND empls.SSN = thd.SSN
INNER JOIN TimeCurrent..tblGroupDepts depts
ON depts.Client = thd.Client
  AND depts.GroupCode = thd.GroupCode
  AND depts.DeptNo = thd.DeptNo
INNER JOIN TimeCurrent..tblSiteNames sites
ON sites.Client = thd.Client
  AND sites.GroupCode = thd.GroupCode
  AND sites.SiteNo = thd.SiteNo  
LEFT JOIN TimeCurrent..tblAgencies a WITH(NOLOCK)  
ON  a.Client = thd.Client  
  AND a.GroupCode = thd.GroupCode  
  AND a.Agency = thd.AgencyNo    
WHERE ISNULL(a.ExcludeFromPayFile, '0') <> '1' 
GROUP BY  thd.Client,
          thd.GroupCode,
          thd.SiteNo,
          thd.DeptNo,
          thd.SSN,
          thd.PayrollPeriodEndDate,
          LEFT(groups.RFR_UniqueID + SPACE(15), 15), -- CustID
          thd.TransDate,
          LEFT(sites.CompanyID + SPACE(10), 10), -- Order Point
          RIGHT(SPACE(11) + empls.FileNo, 11),
          ea.AssignmentNo,
          ISNULL(thd.PayRate,0),
          ISNULL(thd.BillRate,0),
          s.SnapshotDateTime,
          s.EmpName/*,
          TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'COOP'),
          TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'EVNT'),
	        TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'SESN'),
	        TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'BRND'),
	        TimeHistory.dbo.fn_PATE_IsFieldActive(@Client, grpped.GroupCode, 'SALES')*/
ORDER BY thd.PayrollPeriodEndDate, LEFT(groups.RFR_UniqueID + SPACE(15), 15), RIGHT(SPACE(11) + empls.FileNo, 11), thd.TransDate
OPTION (FORCE ORDER)

--PRINT 'Before: IDX_tmpDailyHrs ' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpDailyHrs_MaxRecordID ON #tmpDailyHrs(MaxTHDRecordID)  
CREATE INDEX IDX_tmpDailyHrs_PK ON #tmpDailyHrs(Client, GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo)  
--PRINT 'After: IDX_tmpDailyHrs ' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  
UPDATE tmpDailyHrs  
SET ApproverName = CASE  WHEN bkp.RecordId IS NOT NULL   
                         THEN bkp.Email  
                         ELSE CASE WHEN ISNULL(usr.Email,'') = ''   
                                   THEN (CASE WHEN ISNULL(usr.LastName,'') = ''   
                                              THEN ISNULL(usr.LogonName,'')   
                                              ELSE LEFT(usr.LastName + '; ' + ISNULL(usr.FirstName,''),50)   
                                         END)  
                                   ELSE LEFT(usr.Email,50)   
                              END  
                    END  
FROM #tmpDailyHrs AS tmpDailyHrs  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.RecordID = tmpDailyHrs.MaxTHDRecordID  
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp  WITH(NOLOCK) 
ON bkp.THDRecordId = tmpDailyHrs.MaxTHDRecordID  
LEFT JOIN TimeCurrent..tblUser as Usr  WITH(NOLOCK) 
ON usr.UserID = ISNULL(thd.AprvlStatus_UserID,0)  
--PRINT 'After: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  

--SELECT * FROM #tmpDailyHrs

/*Msg 8114, Level 16, State 5, Procedure usp_APP_GenericPayrollUpload_GetRecs_RDRM, Line 561
Error converting data type varchar to numeric.
Warning: Null value is eliminated by an aggregate or other SET operation.*/

INSERT INTO #tmpUDFSummary( Client, GroupCode, SSN, SiteNo, DeptNo, PayrollPeriodEndDate, TransDate, 
                            THD_GroupingID, 
                            Brand, 
                            BrandHours,   
                            Sales,
                            Event)
SELECT DISTINCT thd_udf.Client, thd_udf.GroupCode, thd_udf.SSN, thd_udf.SiteNo, thd_udf.DeptNo, thd_udf.Payrollperiodenddate, thd_udf.TransDate,
                thd_udf.POSITION,
                MAX(CASE WHEN fd_brnd.FieldName = 'BRND' THEN thd_udf.FieldValue END) AS Brand,
                SUM(CASE WHEN fd_brnd_hrs.FieldName = 'BRND_HRS' THEN CAST(CASE thd_udf.FieldValue WHEN '' THEN '0' ELSE REPLACE(REPLACE(thd_udf.FieldValue, ',', ''), 'NaN', '0') END AS NUMERIC(14, 2)) END) AS BrandHours,
                SUM(CASE WHEN fd_sales.FieldName = 'SALES' THEN CAST(CASE thd_udf.FieldValue WHEN '' THEN '0' ELSE REPLACE(REPLACE(thd_udf.FieldValue, ',', ''), 'NaN', '0') END AS NUMERIC(14, 2)) END) AS Sales,
                MAX(CASE WHEN fd_event.FieldName = 'EVNT' THEN thd_udf.FieldValue END) AS Event
FROM #tmpDailyHrs dlyHrs
INNER JOIN TimeHistory..tblTimeHistDetail_UDF thd_udf
ON thd_udf.Client = dlyHrs.Client
AND thd_udf.GroupCode = dlyHrs.GroupCode
AND thd_udf.SSN = dlyHrs.SSN
AND thd_udf.SiteNo = dlyHrs.SiteNo
AND thd_udf.DeptNo = dlyHrs.DeptNo
AND thd_udf.PayrollPeriodEndDate = dlyHrs.PayrollPeriodEndDate
AND thd_udf.TransDate = dlyHrs.TransDate
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_brnd
ON fd_brnd.FieldID = thd_udf.FieldID
AND fd_brnd.FieldName = 'BRND'
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_brnd_hrs
ON fd_brnd_hrs.FieldID = thd_udf.FieldID
AND fd_brnd_hrs.FieldName = 'BRND_HRS'
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_sales
ON fd_sales.FieldID = thd_udf.FieldID
AND fd_sales.FieldName = 'SALES'
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_event
ON fd_event.FieldID = thd_udf.FieldID
AND fd_event.FieldName = 'EVNT'
WHERE thd_udf.Position IS NOT NULL 
GROUP BY thd_udf.Client, thd_udf.GroupCode, thd_udf.SSN, thd_udf.SiteNo, thd_udf.DeptNo, thd_udf.Payrollperiodenddate, thd_udf.TransDate,
                thd_udf.Position
ORDER BY thd_udf.Client, thd_udf.GroupCode, thd_udf.SSN, thd_udf.SiteNo, thd_udf.DeptNo, thd_udf.TransDate

UPDATE summ
SET CoOp = udf.FieldValue
FROM #tmpUDFSummary summ
INNER JOIN TimeHistory.dbo.tblTimeHistDetail_UDF udf
ON udf.Client = summ.Client
AND udf.GroupCode = summ.GroupCode
AND udf.SSN = summ.SSN
AND udf.SiteNo = summ.SiteNo
AND udf.DeptNo = summ.DeptNo
AND udf.PayrollPeriodEndDate = summ.PayrollPeriodEndDate
AND udf.TransDate = summ.TransDate
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.FieldID = udf.FieldID
WHERE fd.FieldName = 'COOP' 

UPDATE summ
SET Season = udf.FieldValue
FROM #tmpUDFSummary summ
INNER JOIN TimeHistory.dbo.tblTimeHistDetail_UDF udf
ON udf.Client = summ.Client
AND udf.GroupCode = summ.GroupCode
AND udf.SSN = summ.SSN
AND udf.SiteNo = summ.SiteNo
AND udf.DeptNo = summ.DeptNo
AND udf.PayrollPeriodEndDate = summ.PayrollPeriodEndDate
AND udf.TransDate = summ.TransDate
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.FieldID = udf.FieldID
WHERE fd.FieldName = 'SESN' 

--SELECT * FROM #tmpUDFSummary

INSERT INTO #tmpDailyDetails(Client, GroupCode, SiteNo, DeptNo, SSN, BusinessUnit, PayrollPeriodEndDate, EmpName,
       CustID, TransDate, OrderPoint, FileNo, AssignmentNo, PayRate, BillRate, 
       MaxTHDRecordID, ApproverName, SnapshotDateTime,
       Brand, 
       TotalHours,
       Sales,
       Event,
       CoOp,
       Season)    
SELECT dlyHrs.Client, dlyHrs.GroupCode, dlyHrs.SiteNo, dlyHrs.DeptNo, dlyHrs.SSN, dlyHrs.BusinessUnit, dlyHrs.PayrollPeriodEndDate, dlyHrs.EmpName,
       dlyHrs.CustID, dlyHrs.TransDate, dlyHrs.OrderPoint, dlyHrs.FileNo, dlyHrs.AssignmentNo, dlyHrs.PayRate, dlyHrs.BillRate, 
       dlyHrs.MaxTHDRecordID, dlyHrs.ApproverName, dlyHrs.SnapshotDateTime,
       ISNULL(summ.Brand, '') AS Brand, 
       ISNULL(summ.BrandHours, dlyHrs.TotalHours) AS BrandHours,
       ISNULL(summ.sales, NULL) AS Sales,
       ISNULL(summ.EVENT, '') AS Event,
       ISNULL(summ.CoOp, '') AS CoOp,
       ISNULL(summ.Season, '') AS Season
FROM #tmpDailyHrs dlyHrs
LEFT JOIN #tmpUDFSummary summ
ON summ.Client = dlyHrs.Client
AND summ.GroupCode = dlyHrs.GroupCode
AND summ.SSN = dlyHrs.SSN
AND summ.SiteNo = dlyHrs.SiteNo
AND summ.DeptNo = dlyHrs.DeptNo
AND summ.TransDate = dlyHrs.TransDate

--SELECT * FROM #tmpDailyDetails
              
IF (ISNULL(@PAYRATEFLAG, '') <> 'DUPE')
BEGIN
  DECLARE @EmailMessage VARCHAR(8000)
  DECLARE @Curs_CustID VARCHAR(50)
  DECLARE @Curs_FileNo VARCHAR(50)
  DECLARE @Curs_orderpoint VARCHAR(50)
  DECLARE @Curs_TransDate DATETIME 
  DECLARE @Curs_Cnt INT
  DECLARE @Curs_Brand VARCHAR(20)

  SET @EmailMessage = ''
  -- Send email for ones to exclude
  DECLARE excludeCursor CURSOR FOR
  SELECT DISTINCT CustID, FileNo, orderpoint, TransDate, Brand, count(*) AS Cnt
              from #tmpDailyDetails
              group by CustID, FileNo, orderpoint, TransDate, Brand
              having count(*) > 1
  OPEN excludeCursor

  FETCH NEXT FROM excludeCursor
  INTO @Curs_CustID, @Curs_FileNo, @Curs_orderpoint, @Curs_TransDate, @Curs_Brand, @Curs_Cnt

  WHILE @@FETCH_STATUS = 0
  BEGIN	

    SET @EmailMessage = @EmailMessage + 'CustID: ' + LTRIM(RTRIM(@Curs_CustID)) + '; EmplID: ' + @Curs_FileNo + '; Location: ' + @Curs_orderpoint + '; @Date: ' + CONVERT(VARCHAR, @Curs_TransDate, 101) + @crlf + @crlf
	  FETCH NEXT FROM excludeCursor
	  INTO @Curs_CustID, @Curs_FileNo, @Curs_orderpoint, @Curs_TransDate, @Curs_Brand, @Curs_Cnt
  END
  CLOSE excludeCursor
  DEALLOCATE excludeCursor	

  IF (@EmailMessage <> '')
  BEGIN
    SET @EmailMessage = 'The following talent have duplicate records and have been excluded from the pay file:' + @crlf + @crlf + @crlf + @EmailMessage
    
    EXEC Scheduler..usp_Email_SendDirect @Client, 0, 0, @MailToExcluded, 'DoNotReply@PeopleNet-us.com', 'PeopleNet',
																		     '', '', 'Excluded Payfile Talent', @EmailMessage, '', 0, '', 1		  																		   
  END

  DELETE dd
  FROM #tmpDailyDetails dd
  INNER JOIN (SELECT DISTINCT CustID, FileNo, orderpoint, TransDate, Brand, count(*) AS Cnt
              from #tmpDailyDetails
              group by CustID, FileNo, orderpoint, TransDate, Brand
              having count(*) > 1) AS tmp
  ON dd.CustID = tmp.CustID
  AND dd.FileNo = tmp.FileNo
END

-- 1. Update Pay Records Sent  
IF (@RecordType <> 'D' AND @TestingFlag IN ('N', '0') )  
BEGIN  
    UPDATE TimeHistory..tblEmplSites_Depts  
    SET TimeHistory..tblEmplSites_Depts.PayRecordsSent = u.SnapshotDateTime  
    FROM #tmpDailyDetails as u  
    INNER JOIN TimeHistory..tblEmplSites_Depts th_esds  
    ON th_esds.Client = @Client  
    AND th_esds.GroupCode = u.GroupCode  
    AND th_esds.PayrollPeriodenddate = u.PayrollPeriodEndDate  
    AND th_esds.SSN = u.SSN  
    AND th_esds.SiteNo = u.SiteNo  
    AND th_esds.DeptNo = u.DeptNo   
    AND th_esds.PayRecordsSent IS NULL
END  

DELETE FROM #tmpDailyDetails WHERE TotalHours = 0

SELECT  dtl.SSN,
        dtl.FileNo AS EmployeeID,  
        dtl.EmpName, 
        CONVERT(VARCHAR(8), dtl.PayrollPeriodEndDate, 112) AS weDate,
        dtl.BusinessUnit AS BUSINESS_UNIT,
        REPLACE(UPPER(CONVERT(varchar(11), dtl.PayrollPeriodEndDate, 106)), ' ', '-') AS PAY_END_DT,
        LEFT(dtl.CustID + SPACE(15), 15) AS CUST_ID,
        REPLACE(UPPER(CONVERT(varchar(11), dtl.TransDate, 106)), ' ', '-') AS DATE_WRK,
        LEFT(dtl.OrderPoint + SPACE(10), 10) AS RNA_ORDER_POINT,
        RIGHT(SPACE(11) + dtl.FileNo, 11) AS EMPLID,
        RIGHT('00000000000000' + REPLACE(CAST(dtl.TotalHours * 10000 AS VARCHAR), '.00', ''), 14) AS RNA_TOT_HRS,
        RIGHT('0000000000' + REPLACE(CAST(dtl.PayRate * 10000 AS VARCHAR), '.00', ''), 10) AS VI_PAY_RATE,
        RIGHT('0000000000' + REPLACE(CAST(dtl.BillRate * 10000 AS VARCHAR), '.00', ''), 10) AS RATE_AMOUNT,
        RIGHT('0000000000' + REPLACE(CAST(ISNULL(dtl.Sales, 0) * 100 AS VARCHAR), '.00', ''), 10) AS RNA_SALES_AMT,
	      RIGHT(SPACE(1) + CASE WHEN IsNull(dtl.CoOp, '') IN ('', 'N', '0', '000') THEN 'N' ELSE 'Y' END, 1) as CO_OP,
        RIGHT(SPACE(4) + IsNull(dtl.Event, SPACE(4)), 4) AS RNA_EVENT_CD,
        RIGHT(SPACE(3) + IsNull(dtl.Season, SPACE(3)), 3) AS RNA_SEASON_CD,
        RIGHT(SPACE(4) + IsNull(dtl.Brand, SPACE(4)), 4) AS RNA_BRAND_NO,
	      RIGHT('000' + CASE WHEN IsNull(dtl.CoOp, '') IN ('', 'N', '0', '000') THEN '000' ELSE dtl.CoOp END, 3) as RNA_STORE_SHARE,
	      Line1 = dtl.BusinessUnit + 
                REPLACE(UPPER(CONVERT(varchar(11), dtl.PayrollPeriodEndDate, 106)), ' ', '-') + 
                LEFT(dtl.CustID + SPACE(15), 15) + 
                REPLACE(UPPER(CONVERT(varchar(11), dtl.TransDate, 106)), ' ', '-') + 
                LEFT(dtl.OrderPoint + SPACE(10), 10) + 
                RIGHT(SPACE(11) + dtl.FileNo, 11) +
                RIGHT('00000000000000' + REPLACE(CAST(dtl.TotalHours * 10000 AS VARCHAR), '.00', ''), 14) + 
                RIGHT('0000000000' + REPLACE(CAST(dtl.PayRate * 10000 AS VARCHAR), '.00', ''), 10) + 
                RIGHT('0000000000' + REPLACE(CAST(dtl.BillRate * 10000 AS VARCHAR), '.00', ''), 10) + 
                RIGHT('0000000000' + REPLACE(CAST(ISNULL(dtl.Sales, 0) * 100 AS VARCHAR), '.00', ''), 10) + 
	              RIGHT(SPACE(1) + CASE WHEN IsNull(dtl.CoOp, '') IN ('', 'N', '0', '000') THEN 'N' ELSE 'Y' END, 1) + 
                RIGHT(SPACE(4) + IsNull(dtl.Event, SPACE(4)), 4) + 
                RIGHT(SPACE(3) + IsNull(dtl.Season, SPACE(3)), 3) + 
                RIGHT(SPACE(4) + IsNull(dtl.Brand, SPACE(4)), 4) + 
	              RIGHT('000' + CASE WHEN IsNull(dtl.CoOp, '') IN ('', 'N', '0', '000') THEN '000' ELSE dtl.CoOp END, 3)
FROM #tmpDailyDetails dtl          
ORDER BY dtl.PayrollPeriodEndDate, dtl.CustID, dtl.FileNo, dtl.Brand, dtl.TransDate
                   
--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         

DROP TABLE #tmpSSNs  
DROP TABLE #tmpDailyHrs  
DROP TABLE #tmpDailyDetails
DROP TABLE #tmpUDFSummary
   
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN
