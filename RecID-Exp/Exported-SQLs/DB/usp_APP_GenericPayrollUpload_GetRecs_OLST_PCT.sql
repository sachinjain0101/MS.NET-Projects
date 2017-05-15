CREATE PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_OLST_PCT]
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
--Removed ALL but 1 "DECLARE" to make this a collapsible region
DECLARE @RecordType         CHAR(1)  
,@PPEDMinus6         DATETIME  
,@PPEDCursor         DATETIME   
,@LateTimeEntryWeeks INT  
,@LateTimeCutoff     DATETIME  
,@PayrollFreq        CHAR(1)  
,@Today              DATETIME   
,@RestrictStateList  varchar_list_tbltype  
,@ExcludeSubVendors  VARCHAR(1)  
,@ShiftZeroCount     INT  
,@CalcBalanceCnt     INT  
,@grpOTMult          NUMERIC(15,10)  
,@prOTMult           NUMERIC(15,10)  
,@OTMult             NUMERIC(15,10)  
,@Delim              CHAR(1)  
,@SSN                INT  
,@ProjectGroupCode   INT   
,@ProjectPPED        DATETIME   
,@AssignmentNo       VARCHAR(32)  
,@TransDate          DATETIME  
,@ProjectNum         VARCHAR(60)  
,@Hours              NUMERIC(7,2)  
,@WorkedHours        NUMERIC(7,2)  
,@RecordId           INT  
,@TotalRegHours      NUMERIC(7,2)  
,@TotalOT_Hours      NUMERIC(7,2)  
,@TotalDT_Hours      NUMERIC(7,2)  
,@TotalProjectLines  INT   
,@LoopCounter        INT   
,@MinProjectId       INT   
,@ProjectHours       NUMERIC(7,2)  
,@RegBalance         NUMERIC(7,2)  
,@OTBalance          NUMERIC(7,2)  
,@DTBalance          NUMERIC(7,2)  
,@ADJBalance         NUMERIC(7,2)  
,@RegAvailable       NUMERIC(7,2)  
,@OTAvailable        NUMERIC(7,2)  
,@DTAvailable        NUMERIC(7,2)  
,@ADJAvailable       NUMERIC(7,2)  
,@ProjectRemaining   NUMERIC(7,2)  
,@TimeSheetLevel     VARCHAR(1)  
,@FaxApprover        INT  
,@GenerateImages     VARCHAR(1)  
,@AdditionalFields   VARCHAR(1)  
,@MailMessage        VARCHAR(8000)  
,@MailToNegs         VARCHAR(500)  
,@MailToOOB          VARCHAR(500)  
,@GroupName          VARCHAR(200)  
,@NegTransDate       DATETIME   
,@NegHours           NUMERIC(7,2)  
,@crlf               CHAR(2)  
,@oobGroupCode       INT  
,@oobPayrollPeriodEndDate DATETIME  
,@oobSSN             INT  
,@oobAssignmentNo    VARCHAR(100)  
,@oobHours           NUMERIC(7, 2)  
,@oobCalcHours       NUMERIC(7, 2)  
,@AdditionalApprovalWeeks TINYINT
,@MinAAWeek DATE
,@MaxAAWeek DATE;

SELECT @AdditionalApprovalWeeks = AdditionalApprovalWeeks
FROM TimeCurrent.dbo.tblClients WHERE Client = @Client;
  
IF UPPER(ISNULL(@PayrollType,'')) LIKE '%EXPENSE%'  
BEGIN  
  EXEC TimeHistory.dbo.usp_APP_OlstUPL_GetExpenses  @Client, @GroupCode, @PPED  
 RETURN  
END  
--Removed ALL but 1 "SET" to make this a collapsible region  
SELECT @Today = GETDATE()  
,@PPEDMinus6 = DATEADD(dd, -6, @PPED)  
,@ExcludeSubVendors = '0' -- Exclude SubVendors from all Unapproved pay files  
,@Delim = ','  
,@RecordType = LEFT(@PayrollType, 1)  -- default to Approved  
,@GenerateImages = '0'  
,@AdditionalFields = '0'  
,@crlf = char(13) + char(10)  
,@MailMessage = ''  
  
IF (@TestingFlag IN ('N', '0'))  
BEGIN  
  SET @MailToNegs = 'TIMECAPTURE@adeccona.com, appemails@peoplenet.com'  
  SET @MailToOOB = 'server@peoplenet.com'  
END  
ELSE  
BEGIN  
  SET @MailToNegs = 'gary.gordon@peoplenet.com; TIMECAPTURE@adeccona.com' 
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
  
  
/*  Adecco payfile  "Line 1" values/formatting:  
  
 1  - SOURCE: I ? Ivr, T ? Timeclock, N ? Individual Web, G ? Web Group, V ? Web Vendor Group, W - WorkCard  
 2  - SSN: 9 digit Employee SSN or last four digits of SSN with leading zeros for IVR, Zero for Timeclock  
 3  - EMP ID: Employee ID for IVR, Zero for TimeClock  
 4  - OFFICE ID: Employee Office Id  
 5  - ASMT ID: Assignment Id  
 6  - WEEK END DATE: Week Worked Date in mm/dd/yy or mm/dd/yyyy  
 7  - DAY WORKED: Mon ? 1, Tue ? 2, Wed ? 3, Thu ? 4, Fri ? 5, Sat ? 6, Sun ? 7  (If TimeClock, zero)  
 8  - DATE WORKED: Zero/Null if IVR, Date Worked if TimeClock in mm/dd/yy or mm/dd/yyyy  
 9  - HOURS WORKED: Hours worked on the day  
 10 - TOTAL HOURS: Total Hours Worked  
 11 - TRC: Time Recording Code (REG/OT/DBL/HOL/VAC only)  
 12 - PROJECT CODE: Alphanumeric max length 12 or Empty  
 13 - FLAT PAY AMOUNT: Flat Pay Amount or Empty  
 14 - CONFIRMATION: Confirmation Number (IVR/Web) or Empty  
 15 - AUTH STATUS: Online Authorization Status (0 ? No Response, 1 ? Approved, 2 ? Approved W/Changes) or Empty  
 16 - AUTH CONF: Online Authorization Confirmation Number or Empty  
 17 - VENDOR INVOICE: Vendor Invoice Number for Subs or Empty  
 18 - AUTH DATE: Online Authorization Date or Empty  
 19 - AUTH EMAIL: Online Authorizer email address or Empty  
 20 - FLAT BILL AMOUNT: Flat Bill Amount or Empty  
 21 - CUSTOMER ID: Empty or Customer Id if timesheet has Time Tracking Id or Xref Tracking Id  
 22 - TIME TRACKING ID: Empty or Time Tracking Id  
 23 - XREF TRACKING ID: Cross Reference Tracking Id  
 24 - EMP DISPLAY NAME: Employee name to be displayed in the batch errors report  
 25 - XREF SYSTEM ID  
*/  
  
INSERT INTO #groupLastPPED(Client, GroupCode, PPED, LateTimeCutoff)  
SELECT cg.Client, cg.GroupCode, ped.PayrollPeriodEndDate, DATEADD(dd, cg.LateTimeEntryWeeks * 7 * -1, ped.PayrollPeriodEndDate)  
FROM TimeCurrent.[dbo].tblClientGroups cg WITH(NOLOCK)  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = [cg].[Client]  
AND ped.GroupCode = [cg].[GroupCode]  
AND ped.PayrollPeriodEndDate BETWEEN @PPEDMinus6 AND @PPED  
WHERE cg.Client = @Client  
AND cg.RecordStatus = '1'  
AND cg.IncludeInUpload = '1'  
AND cg.StaffingSetupType = '1'  
  
CREATE INDEX IDX_groupLastPPED_PK ON #groupLastPPED
(Client,GroupCode,PPED,LateTimeCutoff)
  
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
 
  
IF @RecordType != 'T'
 BEGIN
  -- Fill out the remaining PPED's that need to be included  
  INSERT INTO #groupPPED(Client, GroupCode, PPED)  
  SELECT ped.Client, ped.GroupCode, ped.PayrollPeriodEndDate  
  FROM #groupLastPPED tmp  
  INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate BETWEEN tmp.LateTimeCutoff AND tmp.PPED   
 END
IF @RecordType = 'T'
 BEGIN
  INSERT INTO #groupPPED
  (Client,GroupCode,PPED)  
  SELECT ped.Client,ped.GroupCode,ped.PayrollPeriodEndDate  
  FROM #groupLastPPED tmp  
  INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode
  WHERE
  ped.PayrollPeriodEndDate >= DATEADD(WK,-1*ISNULL(@AdditionalApprovalWeeks,0),tmp.LateTimeCutoff)
  AND ped.PayrollPeriodEndDate < tmp.LateTimeCutoff;
 END

SELECT @MaxAAWeek = MAX(PPED),@MinAAWeek = MIN(PPED) FROM #groupPPED;

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
    EmailOther_Count  INT,   
    Dispute_Count     INT,  
    OtherTxns_Count   INT,  
    AssignmentNo      VARCHAR(50),  
    LateApprovals     INT,  
    SnapshotDateTime  DATETIME,  
    JobID             INT,  
    AttachmentName    VARCHAR(200),  
    ApprovalMethodID  INT,  
    WorkState         VARCHAR(2),  
    IsSubVendor       VARCHAR(1),  
    [Hours]           NUMERIC(7, 2),  
    CalcHours         NUMERIC(7, 2),  
	AssignmentTypeId INT,
	SendAsUnapproved BIT

)  
/*  
--CREATE TABLE #tmpDailyHrs1  
DECLARE @tmpDailyHrs1 TABLE  
(  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    PayrollPeriodEndDate DATETIME,  
    TransDate            DATETIME,  
    SSN                  INT,  
    DeptName             VARCHAR(50),  
    AssignmentNo         VARCHAR(50),  
    BranchID             VARCHAR(32),  
    TotalRegHours        NUMERIC(9,2),  
    TotalOT_Hours        NUMERIC(9,2),  
    TotalDT_Hours        NUMERIC(9,2),  
    PayRate              NUMERIC(5,2),  
    BillRate             NUMERIC(5,2),  
    ApproverName         VARCHAR(100),  
    ApprovalStatus       CHAR(1),  
    ApproverDateTime     DATETIME,  
    MaxRecordID          INT,  
    TimeSheetId          INT,  
    SiteNo               INT,  
    DeptNo               INT,  
    ApprovalMethID       INT  
)  
*/  
CREATE TABLE #tmpDailyHrs  
(  
    RecordID             INT IDENTITY (1, 1) NOT NULL,  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    PayrollPeriodEndDate DATETIME,  
    TransDate            DATETIME,  
    SSN                  INT,  
    DeptName             VARCHAR(50),  
    AssignmentNo         VARCHAR(50),  
    BranchID             VARCHAR(32),  
    TotalRegHours        NUMERIC(9,2),  
    TotalOT_Hours        NUMERIC(9,2),  
    TotalDT_Hours        NUMERIC(9,2),  
    PayRate              NUMERIC(5,2),  
    BillRate             NUMERIC(5,2),  
    ApproverName         VARCHAR(100),  
    ApprovalStatus       CHAR(1),  
    ApproverDateTime     DATETIME,  
    MaxRecordID          BIGINT,  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
    TimeSheetId          INT,  
    SiteNo               INT,  
    DeptNo               INT,  
    ApprovalMethodID     INT,  
    NoHours              CHAR(1),
    ADP_ClockAdjustmentNo        VARCHAR(50)
)  
CREATE CLUSTERED INDEX IDX_tmpDailyHrs_RecordID ON #tmpDailyHrs(RecordId)  
  
-- Create Weekly Total File.  
CREATE TABLE #tmpTotHrs  
(  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    SSN                  INT,  
    DeptName             VARCHAR(50),  
    AssignmentNo         VARCHAR(50),  
    BranchID             VARCHAR(32),  
    PayrollPeriodEndDate DATETIME,  
    TotalWeeklyHours     NUMERIC(9,2),  
    SiteNo               INT,  
    DeptNo               INT  
)  
  
CREATE TABLE #tmpWorkedSummary  
(  
    RecordId             INT IDENTITY,  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    PayrollPeriodEndDate DATETIME,    
    TransDate            DATETIME,    
    SSN                  INT,   
    FileNo               VARCHAR(100),  
    AssignmentNo         VARCHAR(100),    
    BranchID             VARCHAR(100),  
    DeptName             VARCHAR(100),  
    TotalRegHours        NUMERIC(7,2),    
    TotalOT_Hours        NUMERIC(7,2),    
    TotalDT_Hours        NUMERIC(7,2),   
    TotalWeeklyHours     NUMERIC(7,2),  
    ApproverName         VARCHAR(100),  
    ApproverDateTime     DATETIME,  
    ApprovalID           INT,  
    ApprovalStatus       VARCHAR(100),  
    DayWorked            VARCHAR(100),  
    FlatPay              NUMERIC(7,2),  
    FlatBill             NUMERIC(7,2),  
    EmplName             VARCHAR(100),  
    PayRate              NUMERIC(7,2),  
    BillRate             NUMERIC(7,2),  
    [Source]             VARCHAR(1),  
    SnapshotDateTime     DATETIME,  
    ProjectCode          VARCHAR(32),  
    JobID                INT,  
    AttachmentName       VARCHAR(200),  
    SiteNo               INT,  
    DeptNo               INT,  
    ApprovalMethodID     INT,  
    NoHours              CHAR(1),  
    WeekendingDate       DATETIME,  
    LateApproval         CHAR(1),
    ADP_ClockAdjustmentNo        VARCHAR(50)
)  
CREATE CLUSTERED INDEX IDX_tmpWorkedSummary_RecordID ON #tmpWorkedSummary(RecordId)  
  
-- Summarize the project information incase it has duplicates  
CREATE TABLE #tmpProjectSummary  
(  
    RecordId              INT IDENTITY,  
    GroupCode             INT,  
    PayrollPeriodEndDate  DATETIME,  
    SSN                   INT,   
    AssignmentNo          VARCHAR(100),   
    TransDate             DATETIME,   
    ProjectNum            VARCHAR(60),   
    [Hours]               NUMERIC(7,2)  
)   
CREATE CLUSTERED INDEX IDX_tmpProjectSummary_RecordID ON #tmpProjectSummary(RecordId)  
  
--PRINT 'RecordType: ' + @RecordType  
IF (@RecordType IN ('A','L','F'))  
BEGIN  
    --PRINT 'Before: INSERT INTO #tmpSSNs' + CONVERT(VARCHAR, GETDATE(), 121)  
    INSERT INTO #tmpSSNs  
    (  
          Client  
        , GroupCode  
        , PayrollPeriodEndDate  
        , SSN  
        , PayRecordsSent  
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
        , LateApprovals  
        , SnapshotDateTime  
        , JobID  
        , AttachmentName  
        , ApprovalMethodID  
        , WorkState  
        , IsSubVendor  
        , [Hours]  
        , CalcHours  
 	    , AssignmentTypeId
	    , SendAsUnapproved
   )  
    SELECT   
         t.Client  
       , t.GroupCode  
       , t.PayrollPeriodEndDate  
       , t.SSN  
       , PayRecordsSent = ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')  
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
       , LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/2050') THEN 1 ELSE 0 END)  
       , SnapshotDateTime = @Today  
       , JobID = 0  
       , AttachmentName = th_esds.RecordID  
       , ApprovalMethodID = ea.ApprovalMethodID  
       , WorkState = ISNULL(ea.WorkState, '')  
       , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
       , SUM(t.Hours)  
       , SUM(t.RegHours + t.OT_Hours + t.DT_Hours)  
	   , ISNULL(ea.AssignmentTypeId,0)
	   , 0
    FROM #groupPPED grpped  
    INNER JOIN TimeHistory.dbo.tblTimeHistDetail as t  
    ON t.Client = grpped.Client  
    AND t.Groupcode = grpped.GroupCode  
    AND t.PayrollPeriodEndDate = grpped.PPED  
    INNER JOIN TimeHistory.dbo.tblEmplNames as en WITH(NOLOCK) 
    ON  en.Client = t.Client   
    AND en.GroupCode = t.GroupCode   
    AND en.SSN = t.SSN  
    AND en.PayrollPeriodenddate = t.PayrollPeriodenddate  
    INNER JOIN TimeCurrent.dbo.tblEmplAssignments as ea  WITH(NOLOCK) 
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
    --AND ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970') = '1/1/1970'  
    LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)  
    ON a.client = ea.Client  
    AND a.GroupCode = ea.GroupCode  
    AND a.Agency = ea.AgencyNo          
   	WHERE
		t.Client = @Client
		AND t.PayrollPeriodEndDate >= @MinAAWeek
		AND t.PayrollPeriodEndDate <= @MaxAAWeek
		AND t.[Hours] <> 0
    GROUP BY  
          t.Client  
        , t.GroupCode  
        , t.PayrollPeriodEndDate  
        , t.SSN  
        , ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')  
        , ea.AssignmentNo  
        , ea.approvalMethodID  
        , th_esds.RecordID  
        , ISNULL(ea.WorkState, '')  
        , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
        , ISNULL(ea.AssignmentTypeId,0)
    --PRINT 'After: INSERT INTO #tmpSSNs A, L, F' + CONVERT(VARCHAR, GETDATE(), 121)          
      
    -- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL  
    IF (@RecordType = 'A')  
    BEGIN       
		UPDATE ssn
		SET SendAsUnapproved = cat.SendAsUnapprovedInPayfile
		FROM #tmpSSNs ssn
		INNER JOIN TimeCurrent..tblClients_AssignmentType cat
		ON cat.Client = @Client
		AND cat.AssignmentTypeID = ssn.AssignmentTypeID
 
        --PRINT 'Before DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  
        DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount AND SendAsUnapproved = 0 
        --PRINT 'After DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount: ' + CONVERT(VARCHAR, GETDATE(), 121)  
    END  
      
    -- Remove records that have already been sent, but are not Late Approval  
    --PRINT 'Before DELETE FROM #tmpSSNs WHERE PayRecordsSent <> ''1/1/1970'' AND LateApprovals = 0: ' + CONVERT(VARCHAR, GETDATE(), 121)  
    DELETE FROM #tmpSSNs WHERE PayRecordsSent <> '1/1/1970' AND LateApprovals = 0  
    --PRINT 'After DELETE FROM #tmpSSNs WHERE PayRecordsSent <> ''1/1/1970'' AND LateApprovals = 0: ' + CONVERT(VARCHAR, GETDATE(), 121)         
END
IF @RecordType = 'T'
BEGIN
	INSERT INTO #tmpSSNs  
	(  
		 Client  
		,GroupCode  
		,PayrollPeriodEndDate  
		,SSN  
		,PayRecordsSent  
		,AssignmentNo  
		,TransCount  
		,ApprovedCount  
		,AprvlStatus_Date  
		,IVR_Count  
		,WTE_Count  
		,Fax_Count  
		,FaxApprover_Count  
		,EmailClient_Count  
		,EmailOther_Count  
		,Dispute_Count  
		,OtherTxns_Count  
		,LateApprovals  
		,SnapshotDateTime  
		,JobID  
		,AttachmentName  
		,ApprovalMethodID  
		,WorkState  
		,IsSubVendor  
		,[Hours]  
		,CalcHours  
	)
	SELECT 
	 t.Client
	,t.GroupCode
	,t.PayrollPeriodEndDate
	,t.SSN
	,PayRecordsSent = COALESCE(th_esds.PayRecordsSent,en.PayRecordsSent,'1/1/1970')
	,ea.AssignmentNo
	,TransCount = SUM(1)
	,ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)
	,AprvlStatus_Date = MAX(t.AprvlStatus_Date)
	,IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)
	,WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END)
	,Fax_Count = SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)
	,FaxApprover_Count = SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID, 0) = @FaxApprover THEN 1 ELSE 0 END)
	,EmailClient_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
	,EmailOther_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END)
	,Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END)
	,OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END)
	,LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > COALESCE(th_esds.PayRecordsSent,en.PayRecordsSent,'1/1/2050') THEN 1 ELSE 0 END)
	,SnapshotDateTime = @Today
	,JobID = 0
	,AttachmentName = th_esds.RecordID
	,ApprovalMethodID = ea.ApprovalMethodID
	,WorkState = ISNULL(ea.WorkState, '')
	,IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
	,[Hours] = SUM(t.[Hours])
	,CalcHours = SUM(t.RegHours + t.OT_Hours + t.DT_Hours)
	FROM #groupPPED grpped
	INNER JOIN TimeHistory.dbo.tblTimeHistDetail as t WITH (NOLOCK)
	ON  t.Client = grpped.Client
	AND t.Groupcode = grpped.GroupCode
	AND t.PayrollPeriodEndDate = grpped.PPED
	INNER JOIN TimeHistory.dbo.tblEmplNames as en WITH (NOLOCK)
	ON  en.Client = t.Client 
	AND en.GroupCode = t.GroupCode
	AND en.PayrollPeriodenddate = t.PayrollPeriodenddate
	AND en.SSN = t.SSN
	INNER JOIN TimeCurrent.dbo.tblEmplAssignments as ea WITH (NOLOCK)
	ON  ea.Client = t.Client
	AND ea.Groupcode = t.Groupcode
	AND ea.SSN = t.SSN
	AND ea.DeptNo = t.DeptNo
	INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds WITH (NOLOCK)
	ON  th_esds.Client = t.Client
	AND th_esds.GroupCode = t.GroupCode
	AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
	AND th_esds.SSN = t.SSN
	AND th_esds.SiteNo = t.SiteNo
	AND th_esds.DeptNo = t.DeptNo
	LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)
	ON a.client = ea.Client
	AND a.GroupCode = ea.GroupCode
	AND a.Agency = ea.AgencyNo
	WHERE
	t.Client = @Client
	AND t.PayrollPeriodEndDate >= @MinAAWeek
	AND t.PayrollPeriodEndDate <= @MaxAAWeek
	AND t.[Hours] <> 0
	AND (
		(th_esds.PayRecordsSent IS NOT NULL AND t.AprvlStatus_Date > th_esds.PayRecordsSent)
		OR
		(en.PayRecordsSent IS NOT NULL AND t.AprvlStatus_Date > en.PayRecordsSent)
			)
	GROUP BY
	 t.Client
	,t.GroupCode
	,t.PayrollPeriodEndDate
	,t.SSN
	,COALESCE(th_esds.PayRecordsSent,en.PayRecordsSent,'1/1/1970')
	,ea.AssignmentNo
	,ea.approvalMethodID
	,th_esds.RecordID
	,ISNULL(ea.WorkState, '')
	,CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
	HAVING
	SUM(1) = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)
END

/*ELSE IF (@RecordType = 'P')  
BEGIN  
    INSERT INTO #tmpSSNs( GroupCode  
                        , SSN  
                        , PayRecordsSent  
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
                        , LateApprovals  
                        , SnapshotDateTime  
                        , JobID  
                        , AttachmentName  
                        , ApprovalMethodID  
                        , WorkState  
                        , IsSubVendor)  
    SELECT  t.GroupCode  
          , t.SSN  
          , PayRecordsSent = ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')  
          , ea.AssignmentNo  
          , TransCount = SUM(1)  
          , ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)  
          , AprvlStatus_Date = MAX(isnull(t.AprvlStatus_Date, '1/2/1970'))  
          , IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)  
          , WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END)  
          , Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)  
          , FaxApprover_Count =  SUM(CASE WHEN t.AprvlStatus_UserID = @FaxApprover THEN 1 ELSE 0 END)  
          , EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)  
          , EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END)  
          , Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END)  
          , OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END)  
          , LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/2050') THEN 1 ELSE 0 END)  
          , SnapshotDateTime = @Today  
          , JobID = 0  
          , AttachmentName = th_esds.RecordID  
          , ApprovalMethodID = ea.ApprovalMethodID  
          , WorkState = ISNULL(ea.WorkState, '')  
          , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
    FROM @groupPPED grpped  
    INNER JOIN TimeHistory.dbo.tblEmplNames as en  
    ON en.Client = grpped.Client  
    AND en.Groupcode = grpped.GroupCode  
    AND en.PayrollPeriodEndDate = grpped.PPED  
    INNER JOIN TimeHistory.dbo.tblTimeHistDetail t  
    ON  t.Client = en.Client  
    AND t.GroupCode = en.GroupCode  
    AND t.SSN = en.SSN  
    AND t.PayrollPeriodEndDate = en.PayrollPeriodEndDate  
    AND t.Hours <> 0  
    INNER JOIN TimeCurrent..tblEmplAssignments as ea  
    ON  ea.Client = t.Client  
    AND ea.Groupcode = t.Groupcode  
    AND ea.SSN = t.SSN  
    AND ea.DeptNo =  t.DeptNo  
    INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds  
    ON  th_esds.Client = t.Client  
    AND th_esds.GroupCode = t.GroupCode  
    AND th_esds.SSN = t.SSN  
    AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
    AND th_esds.SiteNo = t.SiteNo  
    AND th_esds.DeptNo = t.DeptNo       
    LEFT JOIN TimeCurrent..tblAgencies a  
    ON  a.Client = ea.Client  
    AND a.GroupCode = ea.GroupCode  
    AND a.Agency = ea.AgencyNo           
    WHERE ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970') <> '1/1/1970'  
    GROUP BY  t.GroupCode  
            , t.SSN  
            , ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')  
            , ea.AssignmentNo  
            , ea.ApprovalMethodID  
            , th_esds.RecordID  
            , ISNULL(ea.WorkState, '')  
            , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
          
    -- Delete all non-late approvals  
    DELETE FROM #tmpSSNs WHERE LateApprovals = 0  
  
    -- Only late approvals left at this point, delete if all records are not approved  
    DELETE FROM #tmpSSNs WHERE ApprovedCount <> TransCount  
END  
ELSE  
BEGIN  
    RETURN  
END*/  
  
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
  SELECT @MailMessage = @MailMessage + 'Out of balance condition for the assignments above.  These assignments have been omitted from the Adecco payfile and will not be included until they are calculated correctly.'  
  
 INSERT INTO Scheduler.dbo.tblEmail ( Client, GroupCode, SiteNo, TemplateName, MailFrom, MailTo, MailCC,   
                                   MailSubject, MailMessage, Source)  
  VALUES( @Client, NULL, NULL, NULL, 'support@peoplenet.com', @MailToOOB, NULL,  
          'Adecco Payfile Out of Balance', @MailMessage, 'GenericPayrollUpload')  
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
SELECT  thd.Client  
      , thd.GroupCode  
      , thd.PayrollPeriodEndDate  
      , thd.TransDate  
      , thd.SSN  
      , deptName = ''   
      , AssignmentNo = isnull(ea.AssignmentNo, 'MISSING')  
      , BranchID = isnull(ea.BranchID, 'MISSING')  
      , TotalRegHours = Sum(thd.RegHours)  
      , TotalOT_Hours = Sum(thd.OT_Hours)  
      , TotalDT_Hours = Sum(thd.DT_Hours)  
      , PayRate = COALESCE(th_ESD.PayRate,tc_ESD.PayRate,0.00)
      , BillRate = COALESCE(th_ESD.BillRate,tc_ESD.BillRate,0.00)
      , ApproverName = cast('' as varchar(50))  
      , ApprovalStatus = cast('' as char(1))  
      , ApproverDateTime = max( isnull(thd.AprvlStatus_Date, @Today))  
      , MaxRecordID = MAX(thd.RecordID)  
      , TimeSheetId = tc_ESD.RecordID  
      , SiteNo = thd.SiteNo  
      , DeptNo = thd.DeptNo  
      , ApprovalMethID = s.ApprovalMethodID  
      , NoHours = '0'
      , ADP_ClockAdjustmentNo = CASE WHEN tcAC.ClockAdjustmentNo IN ('','1','$','@','8') THEN '' ELSE tcAC.ClockAdjustmentNo END
FROM #tmpSSNs as s  
INNER JOIN TimeHistory.dbo.tblTimeHistDetail as thd  
ON thd.Client = s.Client
AND thd.GroupCode = s.GroupCode
AND thd.PayrollPeriodEndDate = s.PayrollPeriodEndDate
AND thd.SSN = s.SSN 
INNER JOIN TimeCurrent.dbo.tblEmplAssignments as ea  WITH(NOLOCK) 
ON  ea.Client = thd.Client  
AND ea.Groupcode = thd.Groupcode  
AND ea.SSN = thd.SSN  
AND ea.DeptNo =  thd.DeptNo
AND ea.AssignmentNo = s.AssignmentNo
INNER JOIN TimeHistory.dbo.tblEmplSites_Depts as th_ESD  WITH(NOLOCK) 
ON  th_ESD.Client = thd.Client  
AND th_ESD.Groupcode = thd.Groupcode  
AND th_ESD.PayrollPeriodenddate = thd.PayrollPeriodenddate  
AND th_ESD.SSN = thd.SSN  
AND th_ESD.SiteNo = thd.SiteNo  
AND th_ESD.DeptNo =  thd.DeptNo
INNER JOIN TimeCurrent.dbo.tblEmplSites_Depts tc_ESD  WITH(NOLOCK) 
ON  tc_ESD.Client = thd.Client
AND tc_ESD.GroupCode = thd.GroupCode
AND tc_ESD.SSN = thd.SSN
AND tc_ESD.SiteNo = thd.SiteNo
AND tc_ESD.DeptNo = thd.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes AS tcAC 
ON tcAC.Client = thd.Client
AND tcAC.GroupCode = thd.GroupCode
AND tcAC.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('','@') THEN '1' ELSE thd.ClockAdjustmentNo END
LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)  
ON  a.Client = thd.Client  
AND a.GroupCode = thd.GroupCode  
AND a.Agency = thd.AgencyNo  
WHERE
thd.Client = @Client
AND a.ExcludeFromPayFile IS NULL OR a.ExcludeFromPayFile <> '1'  --UBrown CHANGE TO SARGABLE SYNTAX
AND ((tcAC.ADP_EarningsCode > '' OR tcAC.ADP_HoursCode > '') OR tcAC.ClockAdjustmentNo IN ('','1','$','@','8'))
GROUP BY  thd.Client  
        , thd.GroupCode  
        , thd.PayrollPeriodEndDate  
        , thd.TransDate  
        , thd.SSN                  
        , COALESCE(th_ESD.PayRate,tc_ESD.PayRate,0.00)
        , COALESCE(th_ESD.BillRate,tc_ESD.BillRate,0.00)   -- CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode2,'') <> '' then gd.CLientDeptCode2 else '' end) ELSE 'N/A' END,  
        , ISNULL(ea.AssignmentNo, 'MISSING')  
        , ISNULL(ea.BranchID, 'MISSING')  
        , tc_ESD.RecordID  
        , thd.SiteNo  
        , thd.DeptNo  
        , S.ApprovalMethodID
        , CASE WHEN tcAC.ClockAdjustmentNo IN ('','1','$','@','8') THEN '' ELSE tcAC.ClockAdjustmentNo END
--PRINT 'After: #tmpDailyHrs' + CONVERT(VARCHAR, GETDATE(), 121)  
        
--PRINT 'Before: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)                 
DELETE FROM #tmpDailyHrs  
WHERE TotalRegHours = 0.00   
AND TotalOT_Hours = 0.00   
AND TotalDT_Hours = 0.00  
AND NoHours = '0'  
--PRINT 'After: Delete 0''s' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: IDX_tmpDailyHrs ' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpDailyHrs_MaxRecordID ON #tmpDailyHrs(MaxRecordID)  
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
INNER JOIN TimeHistory.dbo.tblTimeHistDetail as thd  
ON thd.RecordID = tmpDailyHrs.MaxRecordID  
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval bkp  WITH(NOLOCK) 
ON bkp.THDRecordId = tmpDailyHrs.MaxRecordID  
LEFT JOIN TimeCurrent.dbo.tblUser as Usr  WITH(NOLOCK) 
ON usr.UserID = ISNULL(thd.AprvlStatus_UserID,0)  
WHERE NoHours = '0'  
--PRINT 'After: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  

--PRINT 'Before: #tmpTotHrs' + CONVERT(VARCHAR, GETDATE(), 121)      
INSERT INTO #tmpTotHrs  
SELECT  Client  
      , GroupCode  
      , SSN  
      , DeptName  
      , AssignmentNo  
      , BranchID  
      , PayrollPeriodenddate  
      , SUM(TotalRegHours + TotalOT_Hours + TotalDT_Hours)  
      , SiteNo  
      , DeptNo  
FROM #tmpDailyHrs  
GROUP BY  Client  
        , GroupCode  
        , SSN  
        , DeptName  
        , AssignmentNo  
        , BranchID  
        , PayrollPeriodenddate  
        , SiteNo  
        , DeptNo  
--PRINT 'After: #tmpTotHrs' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: IDX_tmpTotHrs_PK ' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpTotHrs_PK ON #tmpTotHrs(Client, GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo)  
--PRINT 'After: IDX_tmpTotHrs_PK ' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: #tmpWorkedSummary' + CONVERT(VARCHAR, GETDATE(), 121)  
INSERT INTO #tmpWorkedSummary  
(   Client  
  , GroupCode  
  , PayrollPeriodEndDate  
  , TransDate  
  , SSN  
  , FileNo  
  , AssignmentNo  
  , BranchID  
  , DeptName  
  , TotalRegHours  
  , TotalOT_Hours  
  , TotalDT_Hours  
  , TotalWeeklyHours  
  , ApproverName  
  , ApproverDateTime  
  , ApprovalID  
  , ApprovalStatus  
  , DayWorked  
  , FlatPay  
  , FlatBill  
  , EmplName  
  , PayRate  
  , BillRate  
  , Source  
  , JobID  
  , AttachmentName  
  , SiteNo  
  , DeptNo  
  , ApprovalMethodID  
  , NoHours  
  , LateApproval
  , ADP_ClockAdjustmentNo)  
SELECT  TTD.Client  
      , TTD.GroupCode  
      , TTD.PayrollPeriodEndDate  
      , TTD.TransDate  
      , TTD.SSN  
      , EN.FileNo  
      , TTD.AssignmentNo  
      , TTD.BranchID  
      , TTD.DeptName  
      , TTD.TotalRegHours  
      , TTD.TotalOT_Hours  
      , TTD.TotalDT_Hours  
      , TTH.TotalWeeklyHours  
      , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.ApproverName ELSE '' END  
      , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.ApproverDateTime ELSE NULL END  
      , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.MaxRecordID ELSE 0 END AS ApprovalID  
      , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount AND (tmpSSN.OtherTxns_Count + tmpSSN.Dispute_Count = 0) THEN '1'  
             WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount AND (tmpSSN.OtherTxns_Count + tmpSSN.Dispute_Count > 0) THEN '2'  
             ELSE '0' END  
      , CAST('' AS VARCHAR) AS DayWorked, 0.00 AS FlatPay  
      , 0.00 AS FlatBill  
      , en.LastName + '; ' + en.FirstName AS EmplName  
      , TTD.PayRate  
      , TTD.BillRate  
      , 'H'  
      , 0  
      , TTD.TimeSheetId  
      , TTD.SiteNo  
      , TTD.DeptNo  
      , TTD.ApprovalMethodID  
      , TTD.NoHours  
      , CASE WHEN tmpSSN.LateApprovals > 0 THEN '1' ELSE '0' END  
      , TTD.ADP_ClockAdjustmentNo
FROM #tmpDailyHrs AS TTD  
INNER JOIN #tmpTotHrs AS TTH  
ON  TTD.Client = TTH.Client  
AND TTD.GroupCode = TTH.GroupCode  
AND TTD.SSN = TTH.SSN  
AND TTD.AssignmentNo = TTH.AssignmentNo  
AND TTD.PayrollPeriodEndDate = TTH.PayrollPeriodEndDate  
INNER JOIN TimeCurrent.dbo.tblEmplNames AS en  WITH(NOLOCK)
ON  EN.Client = TTD.Client  
AND en.Groupcode = TTD.GroupCode  
AND en.SSN = TTD.SSN  
INNER JOIN #tmpSSNs as tmpSSN  
ON tmpSSN.GroupCode = TTD.GroupCode  
AND tmpSSN.PayrollPeriodEndDate = TTD.PayrollPeriodEndDate  
AND tmpSSN.SSN = TTD.SSN  
AND tmpSSN.AssignmentNo = TTD.AssignmentNo  
ORDER BY  TTD.GroupCode  
        , TTD.SSN  
        , TTD.BranchID  
        , TTD.AssignmentNo  
        , TTD.DeptName  
        , TTD.PayrollPeriodEndDate  
        , TTD.TransDate  
        , TTD.SiteNo  
        , TTD.DeptNo  
        , TTD.ApprovalMethodID  
        , TTD.NoHours  
--PRINT 'After: #tmpWorkedSummary' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: IDX_tmpWorkedSummary_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpWorkedSummary_PK ON #tmpWorkedSummary(GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo)  
--PRINT 'After: IDX_tmpWorkedSummary_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
--PRINT 'Before: #tmpProjectSummary' + CONVERT(VARCHAR, GETDATE(), 121)  
INSERT INTO #tmpProjectSummary  
(     GroupCode  
    , PayrollPeriodEndDate  
    , SSN  
    , AssignmentNo  
    , TransDate  
    , ProjectNum  
    , [Hours]  
)  
SELECT   
      pr.GroupCode  
    , pr.PayrollPeriodEndDate  
    , pr.SSN  
    , ea.AssignmentNo  
    , pr.TransDate  
    , LEFT(pr.ProjectNum, 60)
    , SUM(pr.Hours) AS [Hours]  
FROM #tmpTotHrs AS s  
INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea  WITH(NOLOCK)
ON ea.Client = s.Client  
AND ea.GroupCode = s.GroupCode  
AND ea.SSN = s.SSN  
AND ea.SiteNo = s.SiteNo  
AND ea.DeptNo = s.DeptNo  
INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_Project AS pr  WITH(NOLOCK)
ON pr.Client = ea.Client  
AND pr.GroupCode = s.GroupCode  
AND pr.PayrollPeriodEndDate = s.PayrollPeriodEndDate  
AND pr.SSN = ea.SSN  
AND pr.SiteNo = ea.SiteNo  
AND pr.DeptNo = ea.DeptNo  
GROUP BY  pr.GroupCode  
        , pr.PayrollPeriodEndDate  
        , pr.SSN  
        , ea.AssignmentNo  
        , pr.TransDate  
        , pr.ProjectNum  
--PRINT 'After: #tmpProjectSummary' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: IDX_tmpProjectSummary_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpProjectSummary_PK ON #tmpProjectSummary(GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo, TransDate)  
--PRINT 'After: IDX_tmpProjectSummary_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
  
--PRINT 'Before: Project Breakout' + CONVERT(VARCHAR, GETDATE(), 121)  
IF EXISTS(SELECT 1 FROM #tmpProjectSummary)  
BEGIN   
    -- Process the projects and merge it in with the time data  
    DECLARE workedCursor CURSOR READ_ONLY  
    FOR SELECT   
          RecordId  
        , TotalRegHours  
        , TotalOT_Hours  
        , TotalDT_Hours  
        , SSN  
        , GroupCode  
        , PayrollPeriodEndDate  
        , AssignmentNo  
        , TransDate  
    FROM #tmpWorkedSummary  
    ORDER BY   
          GroupCode  
        , PayrollPeriodEndDate  
        , SSN  
        , TransDate  
        , AssignmentNo    
    OPEN workedCursor  
        FETCH NEXT FROM workedCursor  
        INTO   
              @RecordId  
            , @TotalRegHours  
            , @TotalOT_Hours  
            , @TotalDT_Hours  
            , @SSN  
            , @ProjectGroupCode  
            , @ProjectPPED  
            , @AssignmentNo  
            , @TransDate  
    WHILE (@@fetch_status <> -1)  
    BEGIN  
        IF (@@fetch_status <> -2)  
        BEGIN         
            SELECT @LoopCounter = 1  
            SELECT @MinProjectId = 0  
            SELECT @RegBalance = @TotalRegHours  
            SELECT @OTBalance = @TotalOT_Hours  
            SELECT @DTBalance = @TotalDT_Hours  
              
            SELECT @TotalProjectLines = COUNT(*)  
            FROM #tmpProjectSummary  
            WHERE GroupCode = @ProjectGroupCode  
            AND PayrollPeriodEndDate = @ProjectPPED  
            AND SSN = @SSN  
            AND TransDate = @TransDate  
            AND AssignmentNo = @AssignmentNo  
            AND [Hours] <> 0          
              
            IF (@TotalProjectLines > 0)  
            BEGIN                             
                SELECT @MinProjectId = MIN(RecordId)  
                FROM #tmpProjectSummary  
                WHERE GroupCode = @ProjectGroupCode  
                    AND PayrollPeriodEndDate = @ProjectPPED  
                    AND SSN = @SSN  
                    AND TransDate = @TransDate  
                    AND AssignmentNo = @AssignmentNo  
                    AND [Hours] <> 0  
                    AND RecordId > @MinProjectId  
      
                SELECT @ProjectNum = ProjectNum,  
                       @ProjectHours = [Hours]  
                FROM #tmpProjectSummary  
                WHERE recordid = @MinProjectId  
                  
-- BEGIN Balance Calculator                       
                SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END  
                SELECT @ProjectRemaining = @ProjectHours - @RegAvailable  
                SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END  
                SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable           
                SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END  
                SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable - @DTAvailable  
                SELECT @ADJAvailable = CASE WHEN @ProjectRemaining > @ADJBalance THEN @ADJBalance ELSE @ProjectRemaining END  
  
                SET @RegBalance = @RegBalance - @RegAvailable  
                SET @OTBalance = @OTBalance - @OTAvailable  
                SET @DTBalance = @DTBalance - @DTAvailable  
                SET @ADJBalance =@ADJBalance - @ADJAvailable  
                --for   
-- END Balance Calculator         
                              
                UPDATE #tmpWorkedSummary  
                    SET TotalRegHours = @RegAvailable,  
                        TotalOT_Hours = @OTAvailable,  
                        TotalDT_Hours = @DTAvailable,  
                        DeptName = @ProjectNum  
                WHERE RecordId = @RecordId  
                                          
                -- Create additional pay file transactions that we will assign the project numbers too  
                WHILE (@LoopCounter <= @TotalProjectLines - 1)  
                BEGIN  
                    SELECT @MinProjectId = MIN(RecordId)  
                    FROM #tmpProjectSummary  
                    WHERE GroupCode = @ProjectGroupCode  
                        AND PayrollPeriodEndDate = @ProjectPPED  
                        AND SSN = @SSN  
                        AND TransDate = @TransDate  
                        AND AssignmentNo = @AssignmentNo  
                        AND Hours <> 0  
                        AND RecordId > @MinProjectId  
                      
                    SELECT @ProjectNum = ProjectNum,  
                                 @ProjectHours = Hours  
                    FROM #tmpProjectSummary  
                    WHERE recordid = @MinProjectId  
                      
-- BEGIN Balance Calculator                       
                    SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END  
                    SELECT @ProjectRemaining = @ProjectHours - @RegAvailable  
                    SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END  
                    SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable           
                    SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END  
  
                    SET @RegBalance = @RegBalance - @RegAvailable  
                    SET @OTBalance = @OTBalance - @OTAvailable  
                    SET @DTBalance = @DTBalance - @DTAvailable            
-- END Balance Calculator                 
                                  
                    INSERT INTO #tmpWorkedSummary  
                    (     Client  
                        , GroupCode  
                        , PayrollPeriodEndDate  
                        , TransDate  
                        , SSN  
                        , FileNo  
                        , AssignmentNo  
                        , BranchID  
                        , DeptName  
                        , TotalRegHours  
                        , TotalOT_Hours  
                        , TotalDT_Hours  
                        , TotalWeeklyHours  
                        , ApproverName  
                        , ApproverDateTime  
                        , ApprovalID  
                        , ApprovalStatus  
                        , DayWorked  
                        , FlatPay  
                        , FlatBill  
                        , EmplName  
                        , PayRate  
                        , BillRate  
                        , [Source]  
                        , JobID  
                        , AttachmentName  
                        , SiteNo  
                        , DeptNo  
                        , [ApprovalMethodID]  
                        , NoHours  
                        , LateApproval  
                        , ADP_ClockAdjustmentNo
                    )  
                    SELECT  
                          Client  
                        , GroupCode  
                        , PayrollPeriodEndDate  
                        , TransDate  
                        , SSN  
                        , FileNo  
                        , AssignmentNo  
                        , BranchID  
                        , @ProjectNum  
                        , @RegAvailable  
                        , @OTAvailable  
                        , @DTAvailable  
                        , TotalWeeklyHours  
                        , ApproverName  
                        , ApproverDateTime  
                        , ApprovalID  
                        , ApprovalStatus  
                        , DayWorked  
                        , FlatPay  
                        , FlatBill  
                        , EmplName  
                        , PayRate  
                        , BillRate  
                        , 'O'  
                        , 0  
                        , '0'  
                        , SiteNo  
                        , DeptNo  
                        , ApprovalMethodID  
                        , NoHours  
                        , LateApproval  
                        , ADP_ClockAdjustmentNo
                    FROM #tmpWorkedSummary  
                    WHERE RecordId = @RecordId  
                  
                    SELECT @LoopCounter = @LoopCounter + 1  
                 END   
  
                IF (@RegBalance > 0 OR @OTBalance > 0 OR @DTBalance > 0)  
                BEGIN  
                    INSERT INTO #tmpWorkedSummary  
                    (     Client  
                        , GroupCode  
                        , PayrollPeriodEndDate  
                        , TransDate  
                        , SSN  
                        , FileNo  
                        , AssignmentNo  
                        , BranchID  
                        , DeptName  
                        , TotalRegHours  
                        , TotalOT_Hours  
                        , TotalDT_Hours  
                        , TotalWeeklyHours  
                        , ApproverName  
                        , ApproverDateTime  
                        , ApprovalID  
                        , ApprovalStatus  
                   , DayWorked  
                        , FlatPay  
                        , FlatBill  
                        , EmplName  
                        , PayRate  
                        , BillRate  
                        , [Source]  
                        , JobID  
                        , AttachmentName  
                        , SiteNo  
                        , DeptNo  
                        , ApprovalMethodID  
                        , NoHours  
                        , LateApproval  
                        , ADP_ClockAdjustmentNo
                    )  
                    SELECT  
                          Client  
                        , GroupCode  
                        , PayrollPeriodEndDate  
                        , TransDate  
                        , SSN  
                        , FileNo  
                        , AssignmentNo  
                        , BranchID  
                        , ''  
                        , @RegBalance  
                        , @OTBalance  
                        , @DTBalance  
                        , TotalWeeklyHours  
                        , ApproverName  
                        , ApproverDateTime  
                        , ApprovalID  
                        , ApprovalStatus  
                        , DayWorked  
                        , FlatPay  
                        , FlatBill  
                        , EmplName  
                        , PayRate  
                        , BillRate  
                        , 'O'  
                        , 0  
                        , '0'  
                        , SiteNo  
                        , DeptNo  
                        , ApprovalMethodID  
                        , NoHours  
                        , LateApproval  
                        , ADP_ClockAdjustmentNo
                    FROM #tmpWorkedSummary  
                    WHERE RecordId = @RecordId                
                END  
            END  
              
        END  
        FETCH NEXT FROM workedCursor INTO   
              @RecordId  
            , @TotalRegHours  
            , @TotalOT_Hours  
            , @TotalDT_Hours  
            , @SSN  
            , @ProjectGroupCode  
            , @ProjectPPED  
            , @AssignmentNo  
            , @TransDate  
  
    END  
    CLOSE workedCursor  
    DEALLOCATE workedCursor  
END  
--PRINT 'After: Project Breakout' + CONVERT(VARCHAR, GETDATE(), 121)  
  --PRINT 'Before: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)  
UPDATE tmpWorkedSummary  
SET [Source] =  CASE  WHEN tmpSSNs.ApprovalMethodId=11  THEN '3'  
                      ELSE CASE WHEN tmpSSNs.IVR_Count > 0 AND tmpSSNs.FaxApprover_Count > 0 THEN 'X'  
                           ELSE CASE WHEN tmpSSNs.WTE_Count > 0 AND tmpSSNs.FaxApprover_Count > 0 THEN 'Y'  
                                ELSE CASE WHEN tmpSSNs.IVR_Count > 0 THEN 'F'  
                                     ELSE CASE WHEN tmpSSNs.WTE_Count > 0 THEN 'H'   
                                          ELSE CASE WHEN tmpSSNs.Fax_Count > 0 THEN 'Q'   
                                               ELSE CASE WHEN tmpSSNs.EmailClient_Count > 0 THEN 'D'  
                                                    ELSE CASE WHEN tmpSSNs.EmailOther_Count > 0 THEN 'J'                                          
                                                         ELSE tmpWorkedSummary.[Source]  
                                                         END  
                                                    END  
                                               END  
                                          END  
                                     END  
                                END  
                           END  
                      END  
                               
    ,SnapshotDateTime = tmpSSNs.SnapshotDateTime  
FROM #tmpWorkedSummary AS tmpWorkedSummary  
INNER JOIN #tmpSSNs AS tmpSSNs  
ON tmpSSNs.GroupCode = tmpWorkedSummary.GroupCode  
AND tmpSSNs.PayrollPeriodEndDate = tmpWorkedSummary.PayrollPeriodEndDate  
AND tmpSSNs.SSN = tmpWorkedSummary.SSN  
AND tmpSSNs.AssignmentNo = tmpWorkedSummary.AssignmentNo  
--PRINT 'After: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)  
--PRINT 'Before: REG' + CONVERT(VARCHAR, GETDATE(), 121)  
INSERT INTO #tmpUploadExport  
    SELECT  
          SSN  = CONVERT(INT, SSN)  
        , EmployeeID = CONVERT(VARCHAR(20), ISNULL(FileNo, ''))  
        , EmpName = ISNULL(EmplName, ' ')  
        , FileBreakID = ''  
        , weDate = PayrollPeriodEndDate  
        , Approval = CASE WHEN ApprovalStatus = '0' THEN '0' ELSE '1' END          
        , Line1 =   
           CONVERT(VARCHAR,[Source]) + @Delim +  
           '000000000' + @Delim + -- 'FROM_DATE'  
           FileNo + @Delim + -- 'TO_DATE'  
           BranchID + @Delim + -- 'OFFICEID'  
           CONVERT(VARCHAR, AssignmentNo) + @Delim + -- 'ASMTID'  
           CONVERT(VARCHAR(10), TimeCurrent.dbo.fn_GetNextDaysDate(PayrollPeriodEndDate, 1), 101)   + @Delim + --'WEEK_END_DATE'   
            --ISNULL(CONVERT (VARCHAR(1), (ABS( CASE WHEN (7 - DATEDIFF(DAY, PayrollPeriodEndDate, TransDate)) = 0 THEN '7'   
            --                                     ELSE 7- ABS(DATEDIFF(DAY, PayrollPeriodEndDate, TransDate))END))), '') + @Delim  + -- 'DAYWORKED'  
            '' + @Delim  + -- 'DAYWORKED'  
            CONVERT(VARCHAR(10), TransDate, 101) + @Delim +   --  'DATEWORKED'  
            CONVERT(VARCHAR(12), TotalRegHours) + @Delim +   --  'HOURSWORKED'  
            CONVERT(VARCHAR(12), TotalWeeklyHours) + @Delim +   --  'TOTALHOURS'  
            @REGPAYCODE + @Delim +   --  'TRC'  
            LTRIM(RTRIM(REPLACE(DeptName, @Delim, ''))) + @Delim +   -- 'PROJECTCODE'  
            '' + @Delim +   -- 'FLAT_PAY_AMT'  
            '' + @Delim +   -- 'CONFIRMATION#'  
            ISNULL(CONVERT(VARCHAR,ApprovalStatus), '') + @Delim +   -- 'AUTH_STATUS'  
            --ISNULL((LEFT(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, ApproverDateTime, 121), '-', ''), ':', ''), ' ', ''), 14)), '') + @Delim +  -- 'AUTH_CONF#'  
            CAST(ApprovalID AS VARCHAR) + @Delim + -- 'AUTH_CONF#'  
            '' + @Delim +  -- 'VENDOR_INV#'  
            ISNULL(CONVERT(VARCHAR(10), ApproverDateTime, 101), '') + @Delim +  -- 'AUTH_DATE'  
            ISNULL(CONVERT(VARCHAR(50), ApproverName), '') + @Delim +  --  'AUTH_EMAIL'  
            '' + @Delim +  -- 'FLAT_BILL_AMT'  
            '' + @Delim +  -- 'CUSTOMERID'  
            '' + @Delim +  -- 'TIME_TRACKINGID'  
            '' + @Delim +  -- 'XREF_TRACKINGID'  
            CONVERT(VARCHAR, EmplName) + @Delim +  -- 'EMPLOYEE_NAME'
						'' + @Delim +  -- 'XREF_SYSTEMID'  
						CAST(CAST(BillRate AS DECIMAL(6,2)) AS VARCHAR(6)) + @Delim +  -- 'VMS_BILL_RATE'
						'' + @Delim +  -- 'VMS_VENDOR_PAY_RATE'
						CONVERT(VARCHAR, FileNo) + -- 'EMPLID'
            CASE WHEN @AdditionalFields = '0' THEN ''  
                                              ELSE
																								CASE WHEN @GenerateImages = '1' THEN @Delim + CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112) + RIGHT(AttachmentName, 7) + '00' ELSE '' END -- 'IMAGE_FILE_NAME'  
                                              END  
        ,  PayCode = @REGPAYCODE  
        ,  IMAGE_FILE_NAME = CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112) + RIGHT(AttachmentName,7)  
                                                                               + CASE WHEN @RecordType = 'P'   
                                                                                     THEN '01'  
                                                                                     ELSE '00' END  
        ,  SiteNo  
        ,  DeptNo  
        ,  GroupCode  
        ,  @RecordType  
        ,  SnapshotDateTime  
        ,  GenerateImage = CASE WHEN sm.MethodCode IN('APBAS', 'ATACH', 'FAXAP') AND @GenerateImages = '1' THEN 1 ELSE 0 END  
        ,  AssignmentNo  
        ,  TransDate  
        ,  LateApproval  
        ,  [Hours] = TotalRegHours  
        ,  CustomerID = ''  
        ,  BranchID  
 ,  TRCCode = @REGPAYCODE  
        ,  ProjectCode = DeptName     
FROM #tmpWorkedSummary AS tmpWorkedSummary  
LEFT JOIN TimeCurrent.dbo.tblStaffing_Methods sm  WITH(NOLOCK)
ON sm.RecordId = tmpWorkedSummary.ApprovalMethodID   
WHERE ((TotalRegHours <> 0) OR (NoHours = '1')) AND ADP_ClockAdjustmentNo IN ('','1','$','@','8')
--PRINT 'After: REG' + CONVERT(VARCHAR, GETDATE(), 121)  
--PRINT 'Before: OT' + CONVERT(VARCHAR, GETDATE(), 121)  
INSERT INTO #tmpUploadExport  
SELECT DISTINCT
				SSN  = CONVERT(INT,tmpWorkedSummary.SSN)  
      , EmployeeID = CONVERT(VARCHAR(20), ISNULL(FileNo, ''))  
      , EmpName = ISNULL(EmplName, ' ')  
      , FileBreakID = ''  
      , weDate = PayrollPeriodEndDate  
      , Approval = CASE WHEN approvalstatus = '0' THEN '0' ELSE '1' END  
      , Line1 =  
					CONVERT(VARCHAR, [Source]) + @Delim +  
          '000000000' + @Delim + -- 'FROM_DATE'  
          FileNo + @Delim + -- 'TO_DATE'  
          BranchID  + @Delim + -- 'OFFICEID'  
          CONVERT(VARCHAR,tmpWorkedSummary.AssignmentNo) + @Delim + -- 'ASMTID'  
          CONVERT(VARCHAR(10), TimeCurrent.dbo.fn_GetNextDaysDate(PayrollPeriodEndDate, 1), 101) + @Delim + --'WEEK_END_DATE'   
        --ISNULL(CONVERT (VARCHAR(1), (ABS( CASE WHEN (7 - DATEDIFF(DAY, PayrollPeriodEndDate, TransDate)) = 0 THEN '7'   
        --                                     ELSE 7- ABS(DATEDIFF(DAY, PayrollPeriodEndDate, TransDate))END))), '') + @Delim  + -- 'DAYWORKED'  
        '' + @Delim  + -- 'DAYWORKED'  
          CONVERT(VARCHAR(10), TransDate, 101) + @Delim +   --  'DATEWORKED'  
          CONVERT(VARCHAR(12), TotalOT_Hours) + @Delim +   --  'HOURSWORKED'  
          CONVERT(VARCHAR(12), TotalWeeklyHours) + @Delim +   --  'TOTALHOURS'  
          @OTPAYCODE + @Delim +   -- 'TRC'  
          LTRIM(RTRIM(REPLACE(DeptName, @Delim, ''))) + @Delim +   -- 'PROJECTCODE'  
          '' + @Delim +   -- 'FLAT_PAY_AMT'  
          '' + @Delim +   -- 'CONFIRMATION#'  
          ISNULL(CONVERT(VARCHAR,ApprovalStatus), '') + @Delim +   -- 'AUTH_STATUS'  
          --ISNULL((LEFT(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, ApproverDateTime, 121), '-', ''), ':', ''), ' ', ''), 14)), '') + @Delim +  -- 'AUTH_CONF#'  
          CAST(ApprovalID AS VARCHAR) + @Delim + -- 'AUTH_CONF#'  
          '' + @Delim +  -- 'VENDOR_INV#'  
          ISNULL(CONVERT(VARCHAR(10), ApproverDateTime, 101), '') + @Delim +  -- 'AUTH_DATE'  
          ISNULL(CONVERT(VARCHAR(50), ApproverName), '') + @Delim +  --  'AUTH_EMAIL'  
          '' + @Delim +  -- 'FLAT_BILL_AMT'  
          '' + @Delim +  -- 'CUSTOMERID'  
          '' + @Delim +  -- 'TIME_TRACKINGID'  
          '' + @Delim +  -- 'XREF_TRACKINGID'  
          CONVERT(VARCHAR, EmplName) + @Delim +  -- 'EMPLOYEE_NAME'
					'' + @Delim +  -- 'XREF_SYSTEMID'  
					ISNULL(CAST(CAST(CAST(tmpWorkedSummary.BillRate AS DECIMAL(6,2)) * CAST(ISNULL(tcESD.BillingOvertimeCalcFactor,1.50) AS DECIMAL(6,2))AS DECIMAL(6,2)) AS VARCHAR(10)),'') + @Delim +  -- 'VMS_BILL_RATE'
					'' + @Delim +  -- 'VMS_VENDOR_PAY_RATE'  
					CONVERT(VARCHAR, FileNo) + -- 'EMPLID'
          CASE WHEN @AdditionalFields = '0' THEN ''  
                                            ELSE
																							CASE WHEN @GenerateImages = '1' THEN @Delim + CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112) + RIGHT(AttachmentName, 7) + '00' ELSE '' END -- 'IMAGE_FILE_NAME'
                                            END  
       , PayCode = @OTPAYCODE  
       , IMAGE_FILE_NAME = CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112)  + RIGHT(AttachmentName,7)  
                                                                            + CASE WHEN @RecordType = 'P'   
                                                                                   THEN '01'  
                                                                                   ELSE '00' END  
       ,tmpWorkedSummary.SiteNo  
			 ,tmpWorkedSummary.DeptNo  
       ,tmpWorkedSummary.GroupCode  
       , @RecordType  
       , SnapshotDateTime  
       , GenerateImage = CASE WHEN sm.MethodCode IN ('APBAS', 'ATACH', 'FAXAP') AND @GenerateImages = '1' THEN 1 ELSE 0 END  
       ,tmpWorkedSummary.AssignmentNo  
       , TransDate  
       , LateApproval  
       , [Hours] = TotalOT_Hours  
       , CustomerID = ''  
       , BranchID  
       , TRCCode = @REGPAYCODE  
       , ProjectCode = DeptName          
FROM #tmpWorkedSummary AS tmpWorkedSummary  
LEFT JOIN TimeCurrent.dbo.tblStaffing_Methods sm  WITH(NOLOCK)
ON sm.RecordId = tmpWorkedSummary.ApprovalMethodID
LEFT JOIN TimeCurrent.dbo.tblEmplSites_Depts tcESD WITH(NOLOCK)
ON tcESD.Client = tmpWorkedSummary.Client
AND tcESD.GroupCode = tmpWorkedSummary.GroupCode
AND tcESD.SiteNo = tmpWorkedSummary.SiteNo
AND tcESD.DeptNo = tmpWorkedSummary.DeptNo
AND tcESD.SSN = tmpWorkedSummary.SSN
--AND tcESD.AssignmentNo = tmpWorkedSummary.AssignmentNo
WHERE (TotalOT_Hours <> 0) AND ADP_ClockAdjustmentNo IN ('','1','$','@','8')
--PRINT 'After: OT' + CONVERT(VARCHAR, GETDATE(), 121)  
--PRINT 'Before: DT' + CONVERT(VARCHAR, GETDATE(), 121)  
INSERT INTO #tmpUploadExport  
    SELECT  
          SSN  = CONVERT(INT, SSN)  
        , EmployeeID = CONVERT(VARCHAR(20), ISNULL(FileNo, ''))  
        , EmpName = ISNULL(EmplName, ' ')  
        , FileBreakID = ''  
        , weDate = PayrollPeriodEndDate  
        , Approval = CASE WHEN [approvalstatus] = '0' THEN '0' ELSE '1' END  
        , [Line1] =   
            ISNULL(CONVERT(VARCHAR, [Source]), '') + @Delim +  
            '000000000' + @Delim + -- 'FROM_DATE'  
            FileNo + @Delim + -- 'TO_DATE'  
            BranchID + @Delim + -- 'OFFICEID'  
            CASE WHEN ISNULL(AssignmentNo, '') = '' THEN 'MISSING' ELSE AssignmentNo END + @Delim + -- 'ASMTID'  
            ISNULL(CONVERT(VARCHAR(10), TimeCurrent.dbo.fn_GetNextDaysDate(PayrollPeriodEndDate, 1), 101), '') + @Delim + --'WEEK_END_DATE'   
            --ISNULL(CONVERT (VARCHAR(1), (ABS( CASE WHEN (7 - DATEDIFF(DAY, PayrollPeriodEndDate, TransDate)) = 0 THEN '7'   
            --                                     ELSE 7- ABS(DATEDIFF(DAY, PayrollPeriodEndDate, TransDate))END))), '') + @Delim  + -- 'DAYWORKED'  
            '' + @Delim  + -- 'DAYWORKED'  
            ISNULL(CONVERT(VARCHAR(10), TransDate, 101), '')  + @Delim +   --  'DATEWORKED'  
            ISNULL(CONVERT(VARCHAR(12), TotalDT_Hours), '') + @Delim +   --  'HOURSWORKED'  
            ISNULL(CONVERT(VARCHAR(12), TotalWeeklyHours), '') + @Delim +   --  'TOTALHOURS'  
            ISNULL(@DTPAYCODE, '') + @Delim +   -- 'TRC'  
            LTRIM(RTRIM(REPLACE(DeptName, @Delim, ''))) + @Delim +   -- 'PROJECTCODE'  
            '' + @Delim +   -- 'FLAT_PAY_AMT'  
            '' + @Delim +   -- 'CONFIRMATION#'  
            ISNULL(CONVERT(VARCHAR, ApprovalStatus), '') + @Delim +   -- 'AUTH_STATUS'  
            --ISNULL((LEFT(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, ApproverDateTime, 121), '-', ''), ':', ''), ' ', ''), 14)), '') + @Delim +  -- 'AUTH_CONF#'  
            CAST(ApprovalID AS VARCHAR) + @Delim + -- 'AUTH_CONF#'  
            '' + @Delim +  -- 'VENDOR_INV#'  
            ISNULL(CONVERT(VARCHAR(10), ApproverDateTime, 101), '') + @Delim +  -- 'AUTH_DATE'  
            ISNULL(CONVERT(VARCHAR(50), ApproverName), '')   + @Delim +  --  'AUTH_EMAIL'  
            '' + @Delim +  -- 'FLAT_BILL_AMT'  
            '' + @Delim +  -- 'CUSTOMERID'  
            '' + @Delim +  -- 'TIME_TRACKINGID'  
            '' + @Delim +  -- 'XREF_TRACKINGID'  
            ISNULL(CONVERT(VARCHAR, EmplName), '') + @Delim +  -- 'EMPLOYEE_NAME'
						'' + @Delim +  -- 'XREF_SYSTEMID'  
            ISNULL(CAST(CAST(CAST(BillRate AS DECIMAL(6,2)) * 2.0 AS DECIMAL(6,2)) AS VARCHAR(6)),'') + @Delim +  -- 'VMS_BILL_RATE'  
            '' + @Delim +  -- 'VMS_VENDOR_PAY_RATE'  
            CONVERT(VARCHAR, FileNo) + -- 'EMPLID'
            CASE WHEN @AdditionalFields = '0' THEN ''  
                                              ELSE   
																								CASE WHEN @GenerateImages = '1' THEN @Delim + CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112) + RIGHT(AttachmentName, 7) + '00' ELSE '' END -- 'IMAGE_FILE_NAME'  
                                              END  
         , PayCode = @DTPAYCODE  
         , IMAGE_FILE_NAME = CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112) + RIGHT(AttachmentName,7)  
                                                                              + CASE WHEN @RecordType = 'P'   
                                                                                     THEN '01'  
                                                                                     ELSE '00' END  
         , SiteNo  
         , DeptNo  
         , GroupCode  
         , @RecordType  
         , SnapshotDateTime  
         , GenerateImage = CASE WHEN sm.MethodCode IN ('APBAS', 'ATACH', 'FAXAP') AND @GenerateImages = '1' THEN 1 ELSE 0 END  
         , AssignmentNo  
         , TransDate  
         , LateApproval  
         , [Hours] = TotalDT_Hours  
         , CustomerID = ''  
         , BranchID  
         , TRCCode = @REGPAYCODE  
         , ProjectCode = DeptName            
FROM #tmpWorkedSummary AS tmpWorkedSummary  
LEFT JOIN TimeCurrent.dbo.tblStaffing_Methods sm  WITH(NOLOCK)
ON sm.RecordId = tmpWorkedSummary.ApprovalMethodID  
WHERE (TotalDT_Hours <> 0) AND ADP_ClockAdjustmentNo IN ('','1','$','@','8')
--PRINT 'After: DT' + CONVERT(VARCHAR, GETDATE(), 121)  
--PRINT 'Before: ADT_EarningsCode' + CONVERT(VARCHAR, GETDATE(), 121)  
INSERT INTO #tmpUploadExport  
    SELECT  
          SSN  = CONVERT(INT, SSN)  
        , EmployeeID = CONVERT(VARCHAR(20), ISNULL(FileNo, ''))  
        , EmpName = ISNULL(EmplName, ' ')  
        , FileBreakID = ''  
        , weDate = PayrollPeriodEndDate  
        , Approval = CASE WHEN [approvalstatus] = '0' THEN '0' ELSE '1' END  
        , [Line1] =   
            ISNULL(CONVERT(VARCHAR, [Source]), '') + @Delim +  
            '000000000' + @Delim + -- 'FROM_DATE'  
            FileNo + @Delim + -- 'TO_DATE'  
            BranchID + @Delim + -- 'OFFICEID'  
            CASE WHEN ISNULL(AssignmentNo, '') = '' THEN 'MISSING' ELSE AssignmentNo END + @Delim + -- 'ASMTID'  
            ISNULL(CONVERT(VARCHAR(10), TimeCurrent.dbo.fn_GetNextDaysDate(PayrollPeriodEndDate, 1), 101), '') + @Delim + --'WEEK_END_DATE'   
            --ISNULL(CONVERT (VARCHAR(1), (ABS( CASE WHEN (7 - DATEDIFF(DAY, PayrollPeriodEndDate, TransDate)) = 0 THEN '7'   
            --                                     ELSE 7- ABS(DATEDIFF(DAY, PayrollPeriodEndDate, TransDate))END))), '') + @Delim  + -- 'DAYWORKED'  
            '' + @Delim  + -- 'DAYWORKED'  
            ISNULL(CONVERT(VARCHAR(10), TransDate, 101), '')  + @Delim +   --  'DATEWORKED'  
            ISNULL(CONVERT(VARCHAR(12), TotalRegHours), '') + @Delim +   --  'HOURSWORKED'  
            ISNULL(CONVERT(VARCHAR(12), TotalWeeklyHours), '') + @Delim +   --  'TOTALHOURS'  
            ISNULL(tcAC.ADP_HoursCode, '') + @Delim +   -- 'TRC'  
            LTRIM(RTRIM(REPLACE(DeptName, @Delim, ''))) + @Delim +   -- 'PROJECTCODE'  
            '' + @Delim +   -- 'FLAT_PAY_AMT'  
            '' + @Delim +   -- 'CONFIRMATION#'  
            ISNULL(CONVERT(VARCHAR, ApprovalStatus), '') + @Delim +   -- 'AUTH_STATUS'  
            --ISNULL((LEFT(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, ApproverDateTime, 121), '-', ''), ':', ''), ' ', ''), 14)), '') + @Delim +  -- 'AUTH_CONF#'  
            CAST(ApprovalID AS VARCHAR) + @Delim + -- 'AUTH_CONF#'  
            '' + @Delim +  -- 'VENDOR_INV#'  
            ISNULL(CONVERT(VARCHAR(10), ApproverDateTime, 101), '') + @Delim +  -- 'AUTH_DATE'  
            ISNULL(CONVERT(VARCHAR(50), ApproverName), '')   + @Delim +  --  'AUTH_EMAIL'  
            '' + @Delim +  -- 'FLAT_BILL_AMT'  
            '' + @Delim +  -- 'CUSTOMERID'  
            '' + @Delim +  -- 'TIME_TRACKINGID'  
            '' + @Delim +  -- 'XREF_TRACKINGID'  
            ISNULL(CONVERT(VARCHAR, EmplName), '') + @Delim +  -- 'EMPLOYEE_NAME'
						'' + @Delim +  -- 'XREF_SYSTEMID'  
            ISNULL(CAST(CAST(CAST(BillRate AS DECIMAL(6,2)) * 2.0 AS DECIMAL(6,2)) AS VARCHAR(6)),'') + @Delim +  -- 'VMS_BILL_RATE'  
            '' + @Delim +  -- 'VMS_VENDOR_PAY_RATE'  
            CONVERT(VARCHAR, FileNo) + -- 'EMPLID'
            CASE WHEN @AdditionalFields = '0' THEN ''  
                                              ELSE   
																								CASE WHEN @GenerateImages = '1' THEN @Delim + CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112) + RIGHT(AttachmentName, 7) + '00' ELSE '' END -- 'IMAGE_FILE_NAME'  
                                              END  
         , PayCode = tcAC.ADP_HoursCode
         , IMAGE_FILE_NAME = CONVERT(VARCHAR(10), PayrollPeriodEndDate, 112) + RIGHT(AttachmentName,7)  
                                                                              + CASE WHEN @RecordType = 'P'   
                                                                                     THEN '01'  
                                                                                     ELSE '00' END  
         , SiteNo  
         , DeptNo  
         , tmpWorkedSummary.GroupCode  
         , @RecordType  
         , SnapshotDateTime  
         , GenerateImage = CASE WHEN sm.MethodCode IN ('APBAS', 'ATACH', 'FAXAP') AND @GenerateImages = '1' THEN 1 ELSE 0 END  
         , AssignmentNo  
         , TransDate  
         , LateApproval  
         , [Hours] = TotalRegHours  
         , CustomerID = ''  
         , BranchID  
         , TRCCode = ADP_ClockAdjustmentNo  
         , ProjectCode = DeptName            
FROM #tmpWorkedSummary AS tmpWorkedSummary  
INNER JOIN TimeCurrent.dbo.tblAdjCodes AS tcAC 
ON tcAC.Client = tmpWorkedSummary.Client
AND tcAC.GroupCode = tmpWorkedSummary.GroupCode
AND tcAC.ClockAdjustmentNo = tmpWorkedSummary.ADP_ClockAdjustmentNo
LEFT JOIN TimeCurrent.dbo.tblStaffing_Methods sm  WITH(NOLOCK)
ON sm.RecordId = tmpWorkedSummary.ApprovalMethodID  
WHERE tcAC.ADP_HoursCode > ''
--PRINT 'After: ADT_EarningsCode' + CONVERT(VARCHAR, GETDATE(), 121) 

/*  
The order of these final 3 steps is VERY IMPORTANT  
1. Update Pay Records Sent  
2. Remove Negatives  
3. Return recordset to VB  
*/  

  
--PRINT 'Before: IDX_tmpUploadExport_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpUploadExport_PK ON #tmpUploadExport(GroupCode, weDate, SSN, SiteNo, DeptNo)  
--PRINT 'After: IDX_tmpUploadExport_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
  
-- 1. Update Pay Records Sent  
IF (@RecordType <> 'D' AND @TestingFlag IN ('N', '0') )  
BEGIN  
    UPDATE TimeHistory.dbo.tblEmplSites_Depts  
    SET TimeHistory.dbo.tblEmplSites_Depts.PayRecordsSent = u.SnapshotDateTime  
    FROM #tmpUploadExport as u  
    INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds  
    ON th_esds.Client = @Client  
    AND th_esds.GroupCode = u.GroupCode  
    AND th_esds.PayrollPeriodenddate = u.weDate  
    AND th_esds.SSN = u.SSN  
    AND th_esds.SiteNo = u.SiteNo  
    AND th_esds.DeptNo = u.DeptNo  
    -- For Late Approvals (P), it is ok to overwrite the original date/time that the records were  
    -- sent in the file per Kim Phillips as this is what Talx currently do.  Also, it would be assumed  
    -- that the date/time is Tuesday at 4:00pm as there would have been unapproved time and this is the  
    -- only time that it could have been sent  
    AND ((th_esds.PayRecordsSent IS NULL) OR (u.LateApproval = '1'))  
  
    Update TimeCurrent.dbo.tblClosedPeriodAdjs  
    Set TimeCurrent.dbo.tblClosedPeriodAdjs.DateTimeProcessed = ouw.SnapshotDateTime  
    from #tmpUploadExport as ouw  
    Inner Join TimeCurrent.dbo.tblClosedPeriodAdjs cpa  
    on cpa.Client = @Client  
    AND cpa.GroupCode = ouw.Groupcode  
    AND cpa.PayrollPeriodEndDate = ouw.weDate  
    and cpa.SSN = ouw.SSN  
    and cpa.DateTimeProcessed IS NULL             
    --PRINT 'After: PayRecordsSent' + CONVERT(VARCHAR, GETDATE(), 121)      
END  
  
-- 2. Handle Negatives 
DECLARE negCursor CURSOR READ_ONLY  
FOR SELECT cg.GroupName, ue.AssignmentNo, ue.TransDate, ue.[Hours]  
   FROM #tmpUploadExport ue  
   INNER JOIN TimeCurrent.dbo.tblClientGroups cg WITH(NOLOCK)  
   ON cg.Client = @Client  
   AND cg.GroupCode = ue.GroupCode  
   WHERE ue.[Hours] < 0  
  
OPEN negCursor  
  
FETCH NEXT FROM negCursor INTO @GroupName, @AssignmentNo, @NegTransDate, @NegHours  
WHILE (@@fetch_status <> -1)  
BEGIN  
  IF (@@fetch_status <> -2)  
  BEGIN  
    SET @MailMessage = @MailMessage + 'Branch: ' + @GroupName + '; Assignment: ' + @AssignmentNo + '; Date: ' + CONVERT(VARCHAR, @NegTransDate, 101) + '; Hours: ' + CAST(@NegHours AS VARCHAR) + @crlf + @crlf  
  END  
  FETCH NEXT FROM negCursor INTO @GroupName, @AssignmentNo, @NegTransDate, @NegHours  
END  
CLOSE negCursor  
DEALLOCATE negCursor    
  

IF (@MailMessage <> '')  
BEGIN  
  SELECT @MailMessage = @MailMessage + @crlf  
  SELECT @MailMessage = @MailMessage + 'Negative hours were submitted for pay/bill processing from your PeopleNet system on the SSN and Assignment# above. Adecco''s Timex system does not accept negative hours for an employee.  The associate''s weekly record was removed from the PeopleNet pay file for processing.' + @crlf + @crlf  
  SELECT @MailMessage = @MailMessage + 'You must submit a correction or pay/bill adjustment to Branch Services for ALL hours worked by this associate and assignment# in order for time to be processed for this individual.'  
  
 INSERT INTO Scheduler.dbo.tblEmail ( Client, GroupCode, SiteNo, TemplateName, MailFrom, MailTo, MailCC,   
                                   MailSubject, MailMessage, Source)  
  VALUES( @Client, NULL, NULL, NULL, 'support@peoplenet.com', @MailToNegs, NULL,  
          'Employees with negative hours removed from pay file', @MailMessage, 'GenericPayrollUpload')  
END  

-- 3. Return recordset to VB  --  PUT BACK IN  
SELECT  SSN  
      , EmployeeID  
      , EmpName  
      , FileBreakID  
      , CONVERT(VARCHAR(8), weDate, 112) AS weDate  
      , Approval  
      , Line1  
      --, IMAGE_FILE_NAME  -- Returning this will cause a empty image zip file  
      , SiteNo  
      , DeptNo  
      , GroupCode  
      , Filter  
      , SnapshotDateTime  
      --, GenerateImage  
FROM #tmpUploadExport  
WHERE [Hours] > 0  
ORDER BY  CustomerID,  
          BranchID,  
          AssignmentNo,  
          weDate,  
          TransDate,  
          TRCCode,  
          ProjectCode  
/* This is the order by requested by Adecco:  
    Customer Id(21), *Time Tracking Id(22),* Office Id(4), Assignment Id(5), Week End Date(6), Date Worked(8), TRC (11), Project Code(12), *Confirmation Number(14)* 
      
   Customer ID, Time Tracking ID and Confirmation Number are currently passed as blank  
*/  
           
--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         
         
DROP TABLE #tmpSSNs  
DROP TABLE #tmpProjectSummary  
DROP TABLE #tmpDailyHrs  
DROP TABLE #tmpTotHrs  
DROP TABLE #tmpWorkedSummary  
DROP TABLE #tmpUploadExport  
   
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN
