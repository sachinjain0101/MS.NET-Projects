-- Create PROCEDURE usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_OLD
-- Create Procedure usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_OLD
-- Create Procedure usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_OLD
-- Create Procedure usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_OLD
-- Create PROCEDURE usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_OLD
-- Create Procedure usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_OLD

/*  

      CHANGES 5/15/2012 - Testing still required
      
1. Return OT and DT For OT Overrides
2. Delete 0 hours transactions

*/


/*
begin transaction
--Exec timehistory..usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_GG2 'KELL', 1055, '3/10/2013', '3/10/2013', '', '', 'R', 'O', 'D', 'F', 'N', 'Y'
Exec timehistory..usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData 'KELL', 3288, '2/24/2013', '2/24/2013', '', '', 'R', 'O', 'D', 'F', 'N', 'Y'
rollback

select * from timehistory..tblemplsites_depts
where client = 'kell'
and groupcode = 110
and ssn = 6132
and payrollperiodenddate = '5/6/2012'

update timehistory..tblemplsites_depts
set payrecordssent = NULL
where client = 'kell'
and groupcode = 110
and ssn = 6132
and payrollperiodenddate = '5/6/2012'


EXEC TimeHistory.dbo.usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData @Client, @GroupCode, @PPEDCursor, @PPEDCursor, @PayrollType, @REGPAYCODE, @OTPAYCODE, @DTPAYCODE 	

select * from timehistory..tbltimehistdetail where client = 'kell' order by recordid
*/




/*
BEGIN TRANSACTION

UPDATE timehistory..tblEmplSites_Depts
SET PayRecordsSent = getdate()
WHERE Client = 'KELL'
AND PayrollPeriodEndDate  IN ('6/3/2012', '5/27/2012', '5/20/2012')
and groupcode in (106, 108)

UPDATE timehistory..tblEmplSites_Depts
SET PayRecordsSent = NULL
WHERE Client = 'KELL'
AND PayrollPeriodEndDate = '6/3/2012'
AND ((GroupCode = 108 AND SSN = 57599 AND DeptNo = 7) OR
     (GroupCode = 108 AND SSN = 29514 AND DeptNo = 32) OR
     (GroupCode = 106 AND SSN = 46146 AND DeptNo = 1)
     )
     
UPDATE timehistory..tblEmplSites_Depts
SET PayRecordsSent = NULL
WHERE Client = 'KELL'
AND PayrollPeriodEndDate = '5/27/2012'
AND ((GroupCode = 108 AND SSN = 57599 AND DeptNo = 7) OR
     (GroupCode = 108 AND SSN = 29514 AND DeptNo = 32) OR
     (GroupCode = 108 AND SSN = 97972 AND DeptNo = 25) OR -- Scott - Larry Brooks     
     (GroupCode = 108 AND SSN = 44056 AND DeptNo = 30)  -- Scott - Lajeryl Cooper      
     )     
     
UPDATE timehistory..tblEmplSites_Depts
SET PayRecordsSent = NULL
WHERE Client = 'KELL'
AND PayrollPeriodEndDate = '5/20/2012'
AND ((GroupCode = 108 AND SSN = 57599 AND DeptNo = 7) OR
     (GroupCode = 108 AND SSN = 97972 AND DeptNo = 25) OR -- Scott - Larry Brooks 
     (GroupCode = 108 AND SSN = 44056 AND DeptNo = 30)  -- Scott - Lajeryl Cooper 
     )
 

Exec usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData 'KELL', 108, '6/3/2012', '6/3/2012', '', '', 'R', 'O', 'D', 'F', 'N', 'Y' 
Exec usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData 'KELL', 106, '6/3/2012', '6/3/2012', '', '', 'R', 'O', 'D', 'F', 'N', 'Y' 
Exec usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData 'KELL', 108, '5/27/2012', '5/27/2012', '', '', 'R', 'O', 'D', 'F', 'N', 'Y' 
Exec usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData 'KELL', 108, '5/20/2012', '5/20/2012', '', '', 'R', 'O', 'D', 'F', 'N', 'Y' 

ROLLBACK


BEGIN TRANSACTION
update timehistory..tblemplsites_Depts set payrecordssent = NULL where client = 'kell' and groupcode = 1055 and payrollperiodenddate = '4/21/2013'
Exec TimeHistory..usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_GG 'KELL', 1055, '4/21/2013', '4/21/2013', '', '', 'R', 'O', 'D', 'F', 'N', 'Y'
ROLLBACK

*/
Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData_OLD]
(
  @Client         varchar(4),
  @GroupCode      int,
  @PPED           datetime,
  @PPED2          DATETIME,
  @PAYRATEFLAG    varchar(4),
  @EMPIDType      varchar(6),
  @REGPAYCODE	    varchar(10),
  @OTPAYCODE	    varchar(10),
  @DTPAYCODE	    varchar(10),
  @PayrollType    varchar(80),
  @IncludeSalary  char(1),
  @TestingFlag    char(1) = 'N'
) AS

SET NOCOUNT ON
SET ANSI_WARNINGS OFF

DECLARE @PayrollFreq        VARCHAR(1)
DECLARE @Delim              CHAR(1)
DECLARE @FaxApprover        INT
DECLARE @Today              DATETIME 
DECLARE @PunchWeekDay       INT
DECLARE @PunchInTime        DATETIME
DECLARE @PunchOutTime       DATETIME
DECLARE @SummaryRecordID    INT 
DECLARE @PunchRecordID      INT
DECLARE @TotalIOHours       NUMERIC(7,2)
DECLARE @ErrNum             INT
DECLARE @ErrMsg             VARCHAR(2000)
DECLARE @Prev_RecordID      INT 
DECLARE @Prev_BranchID      VARCHAR(100)
DECLARE @Prev_EmployeeID    VARCHAR(100)
DECLARE @Prev_weDate        VARCHAR(10)
DECLARE @Prev_AssignmentNo  VARCHAR(100)
DECLARE @LI_RecordID        INT 
DECLARE @LI_BranchID        VARCHAR(100)
DECLARE @LI_EmployeeID      VARCHAR(100)
DECLARE @LI_weDate          VARCHAR(10)
DECLARE @LI_AssignmentNo    VARCHAR(100)

SET @Delim = ';'
SET @PPED2 = @PPED    
SET @Today = GETDATE()

-- First check to see if this is bi-weekly.
SELECT @PayrollFreq = PayrollFreq 
FROM TimeCurrent..tblClientGroups 
WHERE Client = @Client 
AND GroupCode = @GroupCode

SELECT @FaxApprover = UserID 
FROM TimeCurrent.dbo.tblUser 
WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER' 
AND Client = @Client

if @PayrollFreq = 'B' 
BEGIN
  Set @PPED2 = dateadd(day, -7, @PPED)
END

/*if @TestingFlag = 'N'
BEGIN
  if @PayrollFreq = 'B'
  BEGIN
  	Exec [TimeHistory].[dbo].usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'Y'
  	      IF @@ERROR <> 0
  	        RETURN
          IF @@ERROR <> 0
          BEGIN
            SET @ErrNum = ERROR_MESSAGE()
            SET @ErrMsg = ERROR_MESSAGE()          
            RAISERROR (@ErrNum, @ErrMsg, 1) 
            RETURN            
          END
  END
  ELSE
  BEGIN
  	Exec [TimeHistory].[dbo].usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'N'
        IF @@ERROR <> 0
  	      RETURN  	
          IF @@ERROR <> 0
          BEGIN
            SET @ErrNum = ERROR_MESSAGE()
            SET @ErrMsg = ERROR_MESSAGE()          
            RAISERROR (@ErrNum, @ErrMsg, 1) 
            RETURN            
          END
  END
END*/

Create Table #tmpExport
(
    SSN                INT          --Required in VB6: GenericPayrollUpload program
  , EmployeeID         VARCHAR(100)  --Required in VB6: GenericPayrollUpload program
  , EmpName            VARCHAR(100) --Required in VB6: GenericPayrollUpload program
  , FileBreakID        VARCHAR(20)  --The VB6: GenericPayrollUpload program will split apart payfiles on PayGroup from TimeCurrent.dbo.tbl_EmplNames
  , weDate             VARCHAR(10)  --Required in VB6: GenericPayrollUpload program
  , AssignmentNo       VARCHAR(100)
  , Last4SSN           VARCHAR(10)
  , CollectFrmt        VARCHAR(20)
  , ReportingInt       VARCHAR(10)
  , BranchID           VARCHAR(100)
  , GroupID            VARCHAR(100)
  , TimesheetDate      VARCHAR(10)
  , SunHrs             VARCHAR(15) -- NUMERIC(15,2)
  , MonHrs             VARCHAR(15) -- NUMERIC(15,2)
  , TueHrs             VARCHAR(15) -- NUMERIC(15,2)
  , WedHrs             VARCHAR(15) -- NUMERIC(15,2)
  , ThuHrs             VARCHAR(15) -- NUMERIC(15,2)
  , FriHrs             VARCHAR(15) -- NUMERIC(15,2)
  , SatHrs             VARCHAR(15) -- NUMERIC(15,2)
  , SunCnt             INT
  , MonCnt             INT
  , TueCnt             INT
  , WedCnt             INT
  , ThuCnt             INT
  , FriCnt             INT
  , SatCnt             INT
  , TotalHrs           NUMERIC(15, 2)
  , TotalAssignmentHrs NUMERIC(15, 2)
  , TimeType           VARCHAR(4)
  , Confirmation       VARCHAR(10)
  , TransType          VARCHAR(1)
  , Individual         VARCHAR(1)
  , [Timestamp]        VARCHAR(20)
  , ExpenseMiles       VARCHAR(10) --NUMERIC(9,2)
  , ExpenseDollars     VARCHAR(10) --NUMERIC(9,2)
  , [Status]           VARCHAR(3)
  , Optional1          VARCHAR(100)
  , Optional2          VARCHAR(100)
  , Optional3          VARCHAR(100)
  , Optional4          VARCHAR(100)
  , Optional5          VARCHAR(100)
  , Optional6          VARCHAR(100)
  , Optional7          VARCHAR(100)
  , Optional8          VARCHAR(100)
  , Optional9          VARCHAR(100)
  , [AuthTimestamp]    VARCHAR(20)
  , [ApprovalUserID]   INT 
  , [AuthEmail]        VARCHAR(100)
  , [AuthConfirmNo]    VARCHAR(6)
  , [AuthComments]     VARCHAR(255)
  , WorkRules          VARCHAR(4)
  , Rounding           VARCHAR(1)
  , WeekEndDay         VARCHAR(1)
  , IVR_Count          INT
  , WTE_Count          INT
  , SiteNo             INT
  , DeptNo             INT
  , SortSequence       NUMERIC(8, 3)
  , Line1              VARCHAR(1500)
  , GroupCode          INT
  , RecordID           INT IDENTITY
  , PayrollType        VARCHAR(50)  
  , SnapshotDateTime   DATETIME    
  , MaxTHDRecordID     BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >-- 
)

Create Table #tmpAssignments
( 
    SSN               INT,
    SiteNo            INT,
    DeptNo            INT, 
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
    LateApprovals     INT,
    SnapshotDateTime  DATETIME,
    JobID             INT,
    AttachmentName    VARCHAR(200),
    ApprovalMethodID  INT,
    OTOverride        INT,
    Last5SSN          VARCHAR(10)
)

IF (@PayrollType IN ('A', 'F', 'L'))
BEGIN
    INSERT INTO #tmpAssignments
    (
          SSN
        , SiteNo
        , DeptNo
        , PayRecordsSent
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
        , OTOverride
        , Last5SSN
    )
    SELECT 
         t.SSN
       , t.SiteNo
       , t.DeptNo
       , PayRecordsSent = ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')
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
       , LateApprovals = 0
       , SnapshotDateTime = @Today
       , JobID = 0
       , AttachmentName = th_esds.RecordID
       , ApprovalMethodID = ea.ApprovalMethodID
       , OTOverride = SUM(CASE WHEN ot_ov.RecordID IS NOT NULL OR 
                                    ISNULL(ag.ClientAgencyCode, '') <> '' OR 
                                    (ea.BranchID IN ('35C3','3547') AND ea.ClientID = '01327464') OR  -- Force all of Nissan to send OT
                                    ea.WorkState = 'PR' -- Force all of Puerto Rico to send OT
                               THEN 1 ELSE 0 END
                          )
       , Last5SSN = ( SELECT TOP 1 SSN
                      FROM TimeCurrent.dbo.tblRFR_Empls rfr
                      WHERE rfr.Client = @Client
                      AND rfr.RFR_GroupID = tc_cg.RFR_UniqueID
                      AND rfr.RFR_UniqueID = tc_en.FileNo)       
    FROM TimeHistory..tblTimeHistDetail as t
    INNER JOIN TimeCurrent..tblClientGroups as tc_cg
        ON  tc_cg.Client = t.Client 
        AND tc_cg.GroupCode = t.GroupCode     
    INNER JOIN TimeCurrent..tblEmplNames as tc_en
        ON  tc_en.Client = t.Client 
        AND tc_en.GroupCode = t.GroupCode 
        AND tc_en.SSN = t.SSN    
    INNER JOIN TimeHistory..tblEmplNames as en
        ON  en.Client = t.Client 
        AND en.GroupCode = t.GroupCode 
        AND en.SSN = t.SSN
        AND en.PayrollPeriodenddate = t.PayrollPeriodenddate
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
        --AND ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970') = '1/1/1970'
    LEFT JOIN TimeHistory.dbo.tblWTE_Timesheets ts
        ON ts.EmployeeID = tc_en.RecordID
        AND ts.TimesheetEndDate = t.PayrollPeriodEndDate
    LEFT JOIN TimeHistory..tblWTE_Spreadsheet_Assignments ts_a
        ON ts_a.TimesheetId = ts.RecordId
        AND ts_a.SiteNo = t.SiteNo
        AND ts_a.DeptNo = t.DeptNo
    LEFT JOIN TimeHistory..tblWTE_Spreadsheet_OTOverrides ot_ov
        ON ot_ov.SpreadsheetAssignmentID = ts_a.RecordId       
    LEFT JOIN TimeCurrent.dbo.tblAgencies ag
        ON ag.Client = t.Client
        AND ag.GroupCode = t.GroupCode
        AND ag.Agency = ea.AgencyNo 
    WHERE   t.Client = @Client
        AND t.Groupcode = @GroupCode
        AND t.PayrollPeriodEndDate IN(@PPED, @PPED2)
    GROUP BY
          t.SSN
        , t.SiteNo
        , t.DeptNo
        , ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970')
        , ea.ApprovalMethodID
        , th_esds.RecordID
        , tc_cg.RFR_UniqueID
        , tc_en.FileNo        
 -- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL
    IF (@PayrollType = 'A')
    BEGIN     
        DELETE FROM #tmpAssignments WHERE TransCount <> ApprovedCount
    END
END
ELSE
BEGIN
  RETURN
END

INSERT INTO #tmpExport
SELECT 	
    [SSN]            = hd.ssn
  , [EmployeeID]     = en.FileNo
  , [EmpName]        = en.LastName + ';' + en.FirstName
  , [FileBreakID]    = ISNULL(en.PayGroup, '')
  , [weDate]         = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [AssignmentNo]   = SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
  , [Last4SSN]       = RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
  , [CollectFrmt]    = '42'
  , [ReportingInt]   = '1'
  , [BranchId]       = ea.BranchId
  , [GroupID]        = '0'
  , [TimesheetDate]  = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [SunHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then CASE WHEN ta.OTOverride = '0' THEN hd.HOURS ELSE hd.RegHours END ELSE 0 end))
  , [MonHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then CASE WHEN ta.OTOverride = '0' THEN hd.HOURS ELSE hd.RegHours END ELSE 0 end))
  , [TueHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then CASE WHEN ta.OTOverride = '0' THEN hd.HOURS ELSE hd.RegHours END ELSE 0 end))
  , [WedHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then CASE WHEN ta.OTOverride = '0' THEN hd.HOURS ELSE hd.RegHours END ELSE 0 end))
  , [ThuHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then CASE WHEN ta.OTOverride = '0' THEN hd.HOURS ELSE hd.RegHours END ELSE 0 end))
  , [FriHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then CASE WHEN ta.OTOverride = '0' THEN hd.HOURS ELSE hd.RegHours END ELSE 0 end))
  , [SatHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then CASE WHEN ta.OTOverride = '0' THEN hd.HOURS ELSE hd.RegHours END ELSE 0 end))
  , [SunCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then 1 ELSE 0 end)
  , [MonCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then 1 ELSE 0 end)
  , [TueCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then 1 ELSE 0 end)
  , [WedCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then 1 ELSE 0 end)
  , [ThuCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then 1 ELSE 0 end)
  , [FriCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then 1 ELSE 0 end)
  , [SatCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then 1 ELSE 0 end)  
  , [TotalHrs]       = SUM(CASE WHEN ta.OTOverride = 0 THEN hd.HOURS ELSE hd.RegHours END)
  , [TotalAssignmentHrs] = SUM(hd.HOURS)
  , [TimeType]       = @REGPAYCODE
  , [Confirmation]   = ''
  , [TransType]      = ''
  , [Individual]     = ''
  , [Timestamp]      = CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101) + ' ' + CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
  , [ExpenseMiles]   = ''
  , [ExpenseDollars] = ''
  , [Status]         = CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
  , [Optional1]      = RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5) -- SSN5-9
  , [Optional2]      = CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
  , [Optional3]      = ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
  , [Optional4]      = '2.0' -- BILLING-DT-FACTOR
  , [Optional5]      = ISNULL(ea.WorkState, '') -- WORK-STATE
  , [Optional6]      = '' -- SYSTEM-ID
  --, [Optional7]      = CASE WHEN ISNULL(ea.BillToCode, '') = '' THEN ISNULL(ac.ADP_HoursCode, '') ELSE ISNULL(ea.BillToCode, '') END -- Pay/Bill Code
  , [Optional7]      = CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN LTRIM(RTRIM(ISNULL(ea.BillToCode, ''))) ELSE ISNULL(ac.ADP_HoursCode, '') END -- Pay/Bill Code
  , [Optional8]      = '' -- WR-APPLIED
  , [Optional9]      = '' -- FILLER
  , [AuthTimestamp]  = CONVERT(VARCHAR(10), MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE hd.PayrollPeriodEndDate END), 101)+' '+ CONVERT (VARCHAR(10),MAX (CASE  WHEN  ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE  hd.PayrollPeriodEndDate END ), 108)
  , [ApprovalUserID] = MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_UserID, 0) ELSE  0 END ) 
  , [AuthEmail]      = ''
  , [AuthConfirmNo]  = ''
  , [AuthComments]   = ''
  , [WorkRules]      = ISNULL(pr.PayFileCode, '0001')
  , [Rounding]       = CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
  , [WeekEndDay]     = CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
  , [IVR_Count]      = ta.IVR_Count
  , [WTE_Count]      = ta.WTE_Count
  , [SiteNo]         = ea.SiteNo
  , [DeptNo]         = ea.DeptNo
  , [SortSequence]   = 0.0
  , [Line1]          = ''
  , [GroupCode]      = en.GroupCode
  , PayrollType      = @PayrollType
  , SnapshotDateTime = ta.SnapshotDateTime
  , MaxTHDRecordID   = MAX(hd.RecordID)
FROM TimeHistory.dbo.tblTimeHistDetail as hd
INNER JOIN #tmpAssignments ta
ON ta.SSN = hd.SSN
AND ta.SiteNo = hd.SiteNo
AND ta.DeptNo = hd.DeptNo  
INNER JOIN TimeCurrent.dbo.tblEmplNames as en
ON  en.Client = hd.Client
AND en.GroupCode = hd.GroupCode
AND en.SSN = hd.SSN
INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea
ON  hd.Client = ea.Client
AND hd.GroupCode = ea.GroupCode
AND hd.SSN = ea.SSN
AND hd.SiteNo = ea.SiteNo
AND hd.DeptNo = ea.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames enh
ON  hd.Client = enh.Client
AND hd.GroupCode = enh.GroupCode
AND hd.SSN = enh.SSN
AND hd.PayrollPeriodEndDate = enh.PayrollPeriodEndDate  
INNER JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
ON  ed.Client = hd.Client
AND	ed.GroupCode = hd.GroupCode
AND	ed.SSN = hd.SSN
AND ed.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
ON  edh.Client = hd.Client
AND edh.GroupCode = hd.GroupCode
AND edh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND edh.SSN = hd.SSN
AND edh.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplSites_Depts as esdh
ON  esdh.Client = hd.Client
AND esdh.GroupCode = hd.GroupCode
AND esdh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND esdh.SSN = hd.SSN
AND esdh.DeptNo = hd.DeptNo    
AND esdh.SiteNo = hd.SiteNo
INNER JOIN TimeCurrent.dbo.tblEmplSites_Depts as esd
ON  esd.Client = hd.Client
AND esd.GroupCode = hd.GroupCode
AND esd.SSN = hd.SSN
AND esd.DeptNo = hd.DeptNo    
AND esd.SiteNo = hd.SiteNo    
INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
ON  ac.Client = hd.Client
AND	ac.GroupCode = hd.GroupCode
-- GG - We want to leave the $ code in here so that it will subtract off the reg hours (it gets added back as a separate line item later on)
AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8', '@', '$') THEN '1' ELSE hd.ClockAdjustmentNo END
LEFT JOIN TimeCurrent.dbo.tblAgencies as ag
ON  ag.Client = en.Client
AND ag.GroupCode = en.GroupCode 
AND ag.Agency = en.AgencyNo 
LEFT JOIN TimeCurrent..tblPayRules pr
ON pr.RecordID = enh.PayRuleID
LEFT JOIN TimeCurrent..tblEntryRoundingRules err
ON err.RecordId = ea.EntryRounding
WHERE hd.Client = @Client 
AND hd.GroupCode = @GroupCode 
AND hd.PayrollPeriodEndDate in(@PPED, @PPED2)
--AND ISNULL(enh.PayRecordsSent, '1/1/1900') = '1/1/1900'
AND isnull(ag.ExcludeFromPayFile, '0') <> '1'
GROUP BY  hd.ssn
        , en.FileNo
        , en.LastName + ';' + en.FirstName
        , ISNULL(en.PayGroup, '')
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
        , RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
        , RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5)
        , ea.BranchId
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101)+' '+CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
        , CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
        , CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
        , ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
        , ISNULL(ea.WorkState, '') -- WORK-STATE
        , ISNULL(pr.PayFileCode, '0001')
        , CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
        , CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
        , ta.IVR_Count
        , ta.WTE_Count
        , ea.SiteNo
        , ea.DeptNo
        , en.GroupCode
        , ta.SnapshotDateTime
        , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN LTRIM(RTRIM(ISNULL(ea.BillToCode, ''))) ELSE ISNULL(ac.ADP_HoursCode, '') END
         
-- OT
INSERT INTO #tmpExport
SELECT 	
    [SSN]            = hd.ssn
  , [EmployeeID]     = en.FileNo
  , [EmpName]        = en.LastName + ';' + en.FirstName
  , [FileBreakID]    = ISNULL(en.PayGroup, '')
  , [weDate]         = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [AssignmentNo]   = SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
  , [Last4SSN]       = RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
  , [CollectFrmt]    = '42'
  , [ReportingInt]   = '1'
  , [BranchId]       = ea.BranchId
  , [GroupID]        = '0'
  , [TimesheetDate]  = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [SunHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then hd.OT_Hours ELSE 0 end))
  , [MonHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then hd.OT_Hours ELSE 0 end))
  , [TueHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then hd.OT_Hours ELSE 0 end))
  , [WedHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then hd.OT_Hours ELSE 0 end))
  , [ThuHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then hd.OT_Hours ELSE 0 end))
  , [FriHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then hd.OT_Hours ELSE 0 end))
  , [SatHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then hd.OT_Hours ELSE 0 end))
  , [SunCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then 1 ELSE 0 end)
  , [MonCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then 1 ELSE 0 end)
  , [TueCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then 1 ELSE 0 end)
  , [WedCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then 1 ELSE 0 end)
  , [ThuCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then 1 ELSE 0 end)
  , [FriCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then 1 ELSE 0 end)
  , [SatCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then 1 ELSE 0 end)  
  , [TotalHrs]       = SUM(CASE WHEN ta.OTOverride >= 1 THEN hd.OT_Hours ELSE 0 END)
  , [TotalAssignmentHrs] = SUM(hd.HOURS)
  , [TimeType]       = @OTPAYCODE
  , [Confirmation]   = ''
  , [TransType]      = ''
  , [Individual]     = ''
  , [Timestamp]      = CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101) + ' ' + CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
  , [ExpenseMiles]   = ''
  , [ExpenseDollars] = ''
  , [Status]         = CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
  , [Optional1]      = RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5) -- SSN5-9
  , [Optional2]      = CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
  , [Optional3]      = ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
  , [Optional4]      = '2.0' -- BILLING-DT-FACTOR
  , [Optional5]      = ISNULL(ea.WorkState, '') -- WORK-STATE
  , [Optional6]      = '' -- SYSTEM-ID
  , [Optional7]      = CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN LTRIM(RTRIM(ISNULL(ea.BillToCode, ''))) ELSE ISNULL(ac.ADP_HoursCode, '') END -- Pay/Bill Code 
  , [Optional8]      = '' -- WR-APPLIED
  , [Optional9]      = '' -- FILLER
  , [AuthTimestamp]  = CONVERT(VARCHAR(10), MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE hd.PayrollPeriodEndDate END), 101)+' '+ CONVERT (VARCHAR(10),MAX (CASE  WHEN  ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE  hd.PayrollPeriodEndDate END ), 108)
  , [ApprovalUserID] = MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_UserID, 0) ELSE  0 END ) 
  , [AuthEmail]      = ''
  , [AuthConfirmNo]  = ''
  , [AuthComments]   = ''
  , [WorkRules]      = ISNULL(pr.PayFileCode, '0001')
  , [Rounding]       = CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
  , [WeekEndDay]     = CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
  , [IVR_Count]      = ta.IVR_Count
  , [WTE_Count]      = ta.WTE_Count
  , [SiteNo]         = ea.SiteNo
  , [DeptNo]         = ea.DeptNo
  , [SortSequence]   = 0.0
  , [Line1]          = ''
  , [GroupCode]      = en.GroupCode
  , PayrollType      = @PayrollType
  , SnapshotDateTime = ta.SnapshotDateTime
  , MaxTHDRecordID   = MAX(hd.RecordID)
FROM TimeHistory.dbo.tblTimeHistDetail as hd
INNER JOIN #tmpAssignments ta
ON ta.SSN = hd.SSN
AND ta.SiteNo = hd.SiteNo
AND ta.DeptNo = hd.DeptNo  
AND ta.OTOverride > 0
INNER JOIN TimeCurrent.dbo.tblEmplNames as en
ON  en.Client = hd.Client
AND en.GroupCode = hd.GroupCode
AND en.SSN = hd.SSN
INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea
ON  hd.Client = ea.Client
AND hd.GroupCode = ea.GroupCode
AND hd.SSN = ea.SSN
AND hd.SiteNo = ea.SiteNo
AND hd.DeptNo = ea.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames enh
ON  hd.Client = enh.Client
AND hd.GroupCode = enh.GroupCode
AND hd.SSN = enh.SSN
AND hd.PayrollPeriodEndDate = enh.PayrollPeriodEndDate  
INNER JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
ON  ed.Client = hd.Client
AND	ed.GroupCode = hd.GroupCode
AND	ed.SSN = hd.SSN
AND ed.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
ON  edh.Client = hd.Client
AND edh.GroupCode = hd.GroupCode
AND edh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND edh.SSN = hd.SSN
AND edh.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplSites_Depts as esdh
ON  esdh.Client = hd.Client
AND esdh.GroupCode = hd.GroupCode
AND esdh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND esdh.SSN = hd.SSN
AND esdh.DeptNo = hd.DeptNo    
AND esdh.SiteNo = hd.SiteNo
INNER JOIN TimeCurrent.dbo.tblEmplSites_Depts as esd
ON  esd.Client = hd.Client
AND esd.GroupCode = hd.GroupCode
AND esd.SSN = hd.SSN
AND esd.DeptNo = hd.DeptNo    
AND esd.SiteNo = hd.SiteNo    
INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
ON  ac.Client = hd.Client
AND	ac.GroupCode = hd.GroupCode
-- GG - We want to leave the $ code in here so that it will subtract off the reg hours (it gets added back as a separate line item later on)
AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8', '@', '$') THEN '1' ELSE hd.ClockAdjustmentNo END
LEFT JOIN TimeCurrent.dbo.tblAgencies as ag
ON  ag.Client = en.Client
AND ag.GroupCode = en.GroupCode 
AND ag.Agency = en.AgencyNo 
LEFT JOIN TimeCurrent..tblPayRules pr
ON pr.RecordID = enh.PayRuleID
LEFT JOIN TimeCurrent..tblEntryRoundingRules err
ON err.RecordId = ea.EntryRounding
WHERE hd.Client = @Client 
AND hd.GroupCode = @GroupCode 
AND hd.PayrollPeriodEndDate in(@PPED, @PPED2)
--AND ISNULL(enh.PayRecordsSent, '1/1/1900') = '1/1/1900'
AND isnull(ag.ExcludeFromPayFile, '0') <> '1'
AND hd.OT_Hours > 0
GROUP BY  hd.ssn
        , en.FileNo
        , en.LastName + ';' + en.FirstName
        , ISNULL(en.PayGroup, '')
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
        , RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
        , RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5)
        , ea.BranchId
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101)+' '+CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
        , CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
        , CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
        , ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
        , ISNULL(ea.WorkState, '') -- WORK-STATE
        , ISNULL(pr.PayFileCode, '0001')
        , CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
        , CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
        , ta.IVR_Count
        , ta.WTE_Count
        , ea.SiteNo
        , ea.DeptNo
        , en.GroupCode
        , ta.SnapshotDateTime     
        , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN LTRIM(RTRIM(ISNULL(ea.BillToCode, ''))) ELSE ISNULL(ac.ADP_HoursCode, '') END 
        
-- DT
INSERT INTO #tmpExport
SELECT 	
    [SSN]            = hd.ssn
  , [EmployeeID]     = en.FileNo
  , [EmpName]        = en.LastName + ';' + en.FirstName
  , [FileBreakID]    = ISNULL(en.PayGroup, '')
  , [weDate]         = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [AssignmentNo]   = SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
  , [Last4SSN]       = RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
  , [CollectFrmt]    = '42'
  , [ReportingInt]   = '1'
  , [BranchId]       = ea.BranchId
  , [GroupID]        = '0'
  , [TimesheetDate]  = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [SunHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then hd.DT_Hours ELSE 0 end))
  , [MonHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then hd.DT_Hours ELSE 0 end))
  , [TueHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then hd.DT_Hours ELSE 0 end))
  , [WedHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then hd.DT_Hours ELSE 0 end))
  , [ThuHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then hd.DT_Hours ELSE 0 end))
  , [FriHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then hd.DT_Hours ELSE 0 end))
  , [SatHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then hd.DT_Hours ELSE 0 end))
  , [SunCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then 1 ELSE 0 end)
  , [MonCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then 1 ELSE 0 end)
  , [TueCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then 1 ELSE 0 end)
  , [WedCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then 1 ELSE 0 end)
  , [ThuCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then 1 ELSE 0 end)
  , [FriCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then 1 ELSE 0 end)
  , [SatCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then 1 ELSE 0 end)  
  , [TotalHrs]       = SUM(CASE WHEN ta.OTOverride >= 1 THEN hd.DT_Hours ELSE 0 END)
  , [TotalAssignmentHrs] = SUM(hd.HOURS)
  , [TimeType]       = @DTPAYCODE
  , [Confirmation]   = ''
  , [TransType]      = ''
  , [Individual]     = ''
  , [Timestamp]      = CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101) + ' ' + CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
  , [ExpenseMiles]   = ''
  , [ExpenseDollars] = ''
  , [Status]         = CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
  , [Optional1]      = RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5) -- SSN5-9
  , [Optional2]      = CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
  , [Optional3]      = ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
  , [Optional4]      = '2.0' -- BILLING-DT-FACTOR
  , [Optional5]      = ISNULL(ea.WorkState, '') -- WORK-STATE
  , [Optional6]      = '' -- SYSTEM-ID
  , [Optional7]      = CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN LTRIM(RTRIM(ISNULL(ea.BillToCode, ''))) ELSE ISNULL(ac.ADP_HoursCode, '') END -- Pay/Bill Code
  , [Optional8]      = '' -- WR-APPLIED
  , [Optional9]      = '' -- FILLER
  , [AuthTimestamp]  = CONVERT(VARCHAR(10), MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE hd.PayrollPeriodEndDate END), 101)+' '+ CONVERT (VARCHAR(10),MAX (CASE  WHEN  ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE  hd.PayrollPeriodEndDate END ), 108)
  , [ApprovalUserID] = MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_UserID, 0) ELSE  0 END ) 
  , [AuthEmail]      = ''
  , [AuthConfirmNo]  = ''
  , [AuthComments]   = ''
  , [WorkRules]      = ISNULL(pr.PayFileCode, '0001')
  , [Rounding]       = CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
  , [WeekEndDay]     = CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
  , [IVR_Count]      = ta.IVR_Count
  , [WTE_Count]      = ta.WTE_Count
  , [SiteNo]         = ea.SiteNo
  , [DeptNo]         = ea.DeptNo
  , [SortSequence]   = 0.0
  , [Line1]          = ''
  , [GroupCode]      = en.GroupCode
  , PayrollType      = @PayrollType
  , SnapshotDateTime = ta.SnapshotDateTime
  , MaxTHDRecordID   = MAX(hd.RecordID)
FROM TimeHistory.dbo.tblTimeHistDetail as hd
INNER JOIN #tmpAssignments ta
ON ta.SSN = hd.SSN
AND ta.SiteNo = hd.SiteNo
AND ta.DeptNo = hd.DeptNo  
AND ta.OTOverride > 0
INNER JOIN TimeCurrent.dbo.tblEmplNames as en
ON  en.Client = hd.Client
AND en.GroupCode = hd.GroupCode
AND en.SSN = hd.SSN
INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea
ON  hd.Client = ea.Client
AND hd.GroupCode = ea.GroupCode
AND hd.SSN = ea.SSN
AND hd.SiteNo = ea.SiteNo
AND hd.DeptNo = ea.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames enh
ON  hd.Client = enh.Client
AND hd.GroupCode = enh.GroupCode
AND hd.SSN = enh.SSN
AND hd.PayrollPeriodEndDate = enh.PayrollPeriodEndDate  
INNER JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
ON  ed.Client = hd.Client
AND	ed.GroupCode = hd.GroupCode
AND	ed.SSN = hd.SSN
AND ed.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
ON  edh.Client = hd.Client
AND edh.GroupCode = hd.GroupCode
AND edh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND edh.SSN = hd.SSN
AND edh.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplSites_Depts as esdh
ON  esdh.Client = hd.Client
AND esdh.GroupCode = hd.GroupCode
AND esdh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND esdh.SSN = hd.SSN
AND esdh.DeptNo = hd.DeptNo    
AND esdh.SiteNo = hd.SiteNo
INNER JOIN TimeCurrent.dbo.tblEmplSites_Depts as esd
ON  esd.Client = hd.Client
AND esd.GroupCode = hd.GroupCode
AND esd.SSN = hd.SSN
AND esd.DeptNo = hd.DeptNo    
AND esd.SiteNo = hd.SiteNo    
INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
ON  ac.Client = hd.Client
AND	ac.GroupCode = hd.GroupCode
-- GG - We want to leave the $ code in here so that it will subtract off the reg hours (it gets added back as a separate line item later on)
AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8', '@', '$') THEN '1' ELSE hd.ClockAdjustmentNo END
LEFT JOIN TimeCurrent.dbo.tblAgencies as ag
ON  ag.Client = en.Client
AND ag.GroupCode = en.GroupCode 
AND ag.Agency = en.AgencyNo 
LEFT JOIN TimeCurrent..tblPayRules pr
ON pr.RecordID = enh.PayRuleID
LEFT JOIN TimeCurrent..tblEntryRoundingRules err
ON err.RecordId = ea.EntryRounding
WHERE hd.Client = @Client 
AND hd.GroupCode = @GroupCode 
AND hd.PayrollPeriodEndDate in(@PPED, @PPED2)
--AND ISNULL(enh.PayRecordsSent, '1/1/1900') = '1/1/1900'
AND isnull(ag.ExcludeFromPayFile, '0') <> '1'
AND hd.DT_Hours > 0
GROUP BY  hd.ssn
        , en.FileNo
        , en.LastName + ';' + en.FirstName
        , ISNULL(en.PayGroup, '')
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
        , RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
        , RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5)
        , ea.BranchId
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101)+' '+CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
        , CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
        , CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
        , ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
        , ISNULL(ea.WorkState, '') -- WORK-STATE
        , ISNULL(pr.PayFileCode, '0001')
        , CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
        , CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
        , ta.IVR_Count
        , ta.WTE_Count
        , ea.SiteNo
        , ea.DeptNo
        , en.GroupCode
        , ta.SnapshotDateTime     
        , CASE WHEN ISNULL(ac.ADP_HoursCode, '') = '' THEN LTRIM(RTRIM(ISNULL(ea.BillToCode, ''))) ELSE ISNULL(ac.ADP_HoursCode, '') END     
        
INSERT INTO #tmpExport
SELECT 	
    [SSN]            = hd.ssn
  , [EmployeeID]     = en.FileNo
  , [EmpName]        = en.LastName + ';' + en.FirstName
  , [FileBreakID]    = ISNULL(en.PayGroup, '')
  , [weDate]         = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [AssignmentNo]   = SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
  , [Last4SSN]       = RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
  , [CollectFrmt]    = '42'
  , [ReportingInt]   = '1'
  , [BranchId]       = ea.BranchId
  , [GroupID]        = '0'
  , [TimesheetDate]  = CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
  , [SunHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then hd.Hours * -1 ELSE 0 end))
  , [MonHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then hd.Hours * -1 ELSE 0 end))
  , [TueHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then hd.Hours * -1 ELSE 0 end))
  , [WedHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then hd.Hours * -1 ELSE 0 end))
  , [ThuHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then hd.Hours * -1 ELSE 0 end))
  , [FriHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then hd.Hours * -1 ELSE 0 end))
  , [SatHrs]         = CONVERT(VARCHAR(15), SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then hd.Hours * -1 ELSE 0 end))
  , [SunCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 1 then 1 ELSE 0 end)
  , [MonCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 2 then 1 ELSE 0 end)
  , [TueCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 3 then 1 ELSE 0 end)
  , [WedCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 4 then 1 ELSE 0 end)
  , [ThuCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 5 then 1 ELSE 0 end)
  , [FriCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 6 then 1 ELSE 0 end)
  , [SatCnt]         = SUM(Case when datepart(WEEKDAY,hd.TransDate) = 7 then 1 ELSE 0 end)  
  , [TotalHrs]       = SUM(hd.Hours) * -1
  , [TotalAssignmentHrs] = SUM(hd.Hours)
  , [TimeType]       = @REGPAYCODE
  , [Confirmation]   = ''
  , [TransType]      = ''
  , [Individual]     = ''
  , [Timestamp]      = CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101) + ' ' + CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
  , [ExpenseMiles]   = ''
  , [ExpenseDollars] = ''
  , [Status]         = CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
  , [Optional1]      = RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5) -- SSN5-9
  , [Optional2]      = CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
  , [Optional3]      = ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
  , [Optional4]      = '2.0' -- BILLING-DT-FACTOR
  , [Optional5]      = ISNULL(ea.WorkState, '') -- WORK-STATE
  , [Optional6]      = '' -- SYSTEM-ID
  , [Optional7]      = '19' -- DISPUTED-PB-CD       PAY ONLY CODE "19"
  , [Optional8]      = '' -- WR-APPLIED
  , [Optional9]      = '' -- FILLER
  , [AuthTimestamp]  = CONVERT(VARCHAR(10), MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE hd.PayrollPeriodEndDate END), 101)+' '+ CONVERT (VARCHAR(10),MAX (CASE  WHEN  ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE  hd.PayrollPeriodEndDate END ), 108)
  , [ApprovalUserID] = MAX(CASE WHEN ISNULL (hd.AprvlStatus,'') IN ('A', 'L') THEN  ISNULL (hd.AprvlStatus_UserID, 0) ELSE  0 END ) 
  , [AuthEmail]      = ''
  , [AuthConfirmNo]  = ''
  , [AuthComments]   = ''
  , [WorkRules]      = ISNULL(pr.PayFileCode, '0001')
  , [Rounding]       = CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
  , [WeekEndDay]     = CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
  , [IVR_Count]      = ta.IVR_Count
  , [WTE_Count]      = ta.WTE_Count
  , [SiteNo]         = ea.SiteNo
  , [DeptNo]         = ea.DeptNo
  , [SortSequence]   = 0.0
  , [Line1]          = ''
  , [GroupCode]      = en.GroupCode
  , PayrollType      = @PayrollType
  , SnapshotDateTime = ta.SnapshotDateTime
  , MaxTHDRecordID   = MAX(hd.RecordID)
FROM TimeHistory.dbo.tblTimeHistDetail as hd
INNER JOIN #tmpAssignments ta
ON ta.SSN = hd.SSN
AND ta.SiteNo = hd.SiteNo
AND ta.DeptNo = hd.DeptNo  
INNER JOIN TimeCurrent.dbo.tblEmplNames as en
ON  en.Client = hd.Client
AND en.GroupCode = hd.GroupCode
AND en.SSN = hd.SSN
INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea
ON  hd.Client = ea.Client
AND hd.GroupCode = ea.GroupCode
AND hd.SSN = ea.SSN
AND hd.SiteNo = ea.SiteNo
AND hd.DeptNo = ea.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames enh
ON  hd.Client = enh.Client
AND hd.GroupCode = enh.GroupCode
AND hd.SSN = enh.SSN
AND hd.PayrollPeriodEndDate = enh.PayrollPeriodEndDate  
INNER JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
ON  ed.Client = hd.Client
AND	ed.GroupCode = hd.GroupCode
AND	ed.SSN = hd.SSN
AND ed.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
ON  edh.Client = hd.Client
AND edh.GroupCode = hd.GroupCode
AND edh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND edh.SSN = hd.SSN
AND edh.Department = hd.DeptNo
INNER JOIN TimeHistory.dbo.tblEmplSites_Depts as esdh
ON  esdh.Client = hd.Client
AND esdh.GroupCode = hd.GroupCode
AND esdh.PayrollPeriodenddate = hd.PayrollPeriodenddate
AND esdh.SSN = hd.SSN
AND esdh.DeptNo = hd.DeptNo    
AND esdh.SiteNo = hd.SiteNo
INNER JOIN TimeCurrent.dbo.tblEmplSites_Depts as esd
ON  esd.Client = hd.Client
AND esd.GroupCode = hd.GroupCode
AND esd.SSN = hd.SSN
AND esd.DeptNo = hd.DeptNo    
AND esd.SiteNo = hd.SiteNo    
INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
ON  ac.Client = hd.Client
AND	ac.GroupCode = hd.GroupCode
AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8', '@') THEN '1' ELSE hd.ClockAdjustmentNo END
LEFT JOIN TimeCurrent.dbo.tblAgencies as ag
ON  ag.Client = en.Client
AND ag.GroupCode = en.GroupCode 
AND ag.Agency = en.AgencyNo 
LEFT JOIN TimeCurrent..tblPayRules pr
ON pr.RecordID = enh.PayRuleID
LEFT JOIN TimeCurrent..tblEntryRoundingRules err
ON err.RecordId = ea.EntryRounding
WHERE hd.Client = @Client 
AND hd.GroupCode = @GroupCode 
AND hd.PayrollPeriodEndDate in(@PPED, @PPED2)
--AND ISNULL(enh.PayRecordsSent, '1/1/1900') = '1/1/1900'
AND isnull(ag.ExcludeFromPayFile, '0') <> '1'
AND hd.ClockAdjustmentNo = '$' -- Pay only transactions
AND hd.Hours < 0 -- We don't want to do this for positive disputes
GROUP BY  hd.ssn
        , en.FileNo
        , en.LastName + ';' + en.FirstName
        , ISNULL(en.PayGroup, '')
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , SUBSTRING(ea.AssignmentNo, CHARINDEX('-', ea.AssignmentNo) + 1, LEN(ea.AssignmentNo))
        , RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR), 4)
        , RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR), 5)
        , ea.BranchId
        , CONVERT(VARCHAR(10), hd.Payrollperiodenddate, 101)
        , CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 101)+' '+CONVERT(VARCHAR(10), hd.PayrollPeriodEndDate, 108)
        , CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
        , CONVERT (VARCHAR,RIGHT(hd.ssn, 5)) -- SSN5-9
        , CAST(ISNULL(esdh.BillRate, 0) AS VARCHAR) -- BILLING-RATE
        , ISNULL(esd.BillingOvertimeCalcFactor, 1.5) -- BILLING-OT-FACTOR
        , ISNULL(ea.WorkState, '') -- WORK-STATE
        , ISNULL(pr.PayFileCode, '0001')
        , CASE WHEN ISNULL(err.TYPE, '') = 'R' THEN '1' ELSE '' END
        , CONVERT(VARCHAR(3), DATEPART(WEEKDAY, hd.PayrollPeriodEndDate))
        , ta.IVR_Count
        , ta.WTE_Count
        , ea.SiteNo
        , ea.DeptNo
        , en.GroupCode
        , ta.SnapshotDateTime        

DELETE FROM #tmpExport       
WHERE SunHrs IN ('0', '0.00')
AND MonHrs IN ('0', '0.00')
AND TueHrs IN ('0', '0.00')
AND WedHrs IN ('0', '0.00')
AND ThuHrs IN ('0', '0.00')
AND FriHrs IN ('0', '0.00')
AND SatHrs IN ('0', '0.00')
AND TotalHrs IN ('0', '0.00')

-- Remove 0 hours from days that have no transactions.  We want to keep the 0 if the transactions were all voided or disputed

UPDATE #tmpExport
SET SunHrs = CASE WHEN SunCnt = 0 THEN '' ELSE SunHrs END,
    MonHrs = CASE WHEN MonCnt = 0 THEN '' ELSE MonHrs END,
    TueHrs = CASE WHEN TueCnt = 0 THEN '' ELSE TueHrs END,
    WedHrs = CASE WHEN WedCnt = 0 THEN '' ELSE WedHrs END,
    ThuHrs = CASE WHEN ThuCnt = 0 THEN '' ELSE ThuHrs END,
    FriHrs = CASE WHEN FriCnt = 0 THEN '' ELSE FriHrs END,
    SatHrs = CASE WHEN SatCnt = 0 THEN '' ELSE SatHrs END
                
DECLARE LineItemCursor CURSOR READ_ONLY
FOR SELECT RecordID, BranchID, EmployeeID, weDate, AssignmentNo
    FROM #tmpExport tmp
    ORDER BY  tmp.SSN, 
              tmp.AssignmentNo, 
              CASE WHEN tmp.Optional7 <> '' THEN 1 ELSE 0 END, 
              CASE WHEN tmp.TimeType = @REGPAYCODE THEN 0 
                   WHEN tmp.TimeType = @OTPAYCODE THEN 1 
                   WHEN tmp.TimeType = @DTPAYCODE THEN 2 
                   ELSE 3 END
OPEN LineItemCursor
FETCH NEXT FROM LineItemCursor INTO @LI_RecordID, @LI_BranchID, @LI_EmployeeID, @LI_weDate, @LI_AssignmentNo

WHILE @@FETCH_STATUS = 0
BEGIN	
  --PRINT 'Line Item Cursor: ' + ISNULL(CAST(@LI_RecordID AS VARCHAR), '')
  IF (ISNULL(@Prev_BranchID, '') <> @LI_BranchID OR 
      ISNULL(@Prev_EmployeeID, '') <> @LI_EmployeeID OR 
      ISNULL(@Prev_weDate, '') <> @LI_weDate OR 
      ISNULL(@Prev_AssignmentNo, '') <> @LI_AssignmentNo)
  BEGIN
    --PRINT 'processing punches'
    DECLARE PunchCursor CURSOR READ_ONLY
    FOR SELECT DATEPART(dw, thd.TransDate), InTime, OutTime, tmp.RecordID
        FROM #tmpExport tmp
        INNER JOIN TimeHistory..tblTimeHistDetail thd
        ON thd.Client = @Client 
        AND thd.GroupCode = @GroupCode 
        AND thd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND thd.SSN = tmp.SSN
        AND thd.SiteNo = tmp.SiteNo
        AND thd.DeptNo = tmp.DeptNo
        AND NOT (ISNULL(thd.InTime, '1899-12-30 00:00:00.000') = '1899-12-30 00:00:00.000' AND ISNULL(thd.OutTime, '1899-12-30 00:00:00.000') = '1899-12-30 00:00:00.000')
        AND thd.Hours <> 0
        WHERE tmp.RecordID = @LI_RecordID
        ORDER BY dbo.punchdatetime2(thd.TransDate, thd.InDay, thd.InTime) ASC
    OPEN PunchCursor
    FETCH NEXT FROM PunchCursor INTO @PunchWeekDay, @PunchInTime, @PunchOutTime, @SummaryRecordID

    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @PunchRecordID = NULL
      SET @TotalIOHours = NULL
       
      SELECT TOP 1 @PunchRecordID = tmp2.RecordID
      FROM #tmpExport tmp
      INNER JOIN #tmpExport tmp2
      ON tmp2.SSN = tmp.SSN
      AND tmp2.SiteNo = tmp.SiteNo
      AND tmp2.DeptNo = tmp.DeptNo
      AND tmp2.TimeType = 'IO'
      AND CASE @PunchWeekDay  WHEN 1 THEN tmp2.SunHrs
                              WHEN 2 THEN tmp2.MonHrs
                              WHEN 3 THEN tmp2.TueHrs
                              WHEN 4 THEN tmp2.WedHrs
                              WHEN 5 THEN tmp2.ThuHrs
                              WHEN 6 THEN tmp2.FriHrs
                              WHEN 7 THEN tmp2.SatHrs END = ''
      WHERE tmp.RecordID = @SummaryRecordID
      ORDER BY tmp2.RecordID
      
      IF (@PunchRecordID IS NULL)
      BEGIN
      --PRINT 'insert'
      
        /*SELECT @TotalIOHours = SUM(te2.TotalHrs)
        FROM #tmpExport te1
        INNER JOIN #tmpExport te2
        ON te2.AssignmentNo = te1.AssignmentNo
        AND te2.BranchID = te1.BranchID
        AND te2.weDate = te1.weDate        
        AND te2.TimeType IN (@REGPAYCODE, @OTPAYCODE, @DTPAYCODE)
        WHERE te1.RecordID = @SummaryRecordID*/
        
        INSERT INTO #tmpExport (SSN, EmployeeID, EmpName, FileBreakID, weDate, AssignmentNo, Last4SSN, CollectFrmt, ReportingInt, BranchID, GroupID, TimesheetDate, 
                                SunHrs, MonHrs, TueHrs, WedHrs, ThuHrs, FriHrs, SatHrs, TotalHrs, TotalAssignmentHrs,  
                                TimeType, Confirmation, TransType, Individual, [Timestamp], ExpenseMiles, ExpenseDollars, [Status], Optional1, Optional2, Optional3, Optional4, Optional5, Optional6, Optional7, Optional8, Optional9, [AuthTimestamp], [ApprovalUserID], [AuthEmail], [AuthConfirmNo], [AuthComments], WorkRules, Rounding, WeekEndDay, IVR_Count, WTE_Count, SiteNo, DeptNo, SortSequence, Line1, GroupCode, PayrollType, SnapshotDateTime, MaxTHDRecordID)
        SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, AssignmentNo, Last4SSN, CollectFrmt, ReportingInt, BranchID, GroupID, TimesheetDate, 
                SunHrs = '', MonHrs = '', TueHrs = '', WedHrs = '', ThuHrs = '', FriHrs = '', SatHrs = '', TotalAssignmentHrs, TotalAssignmentHrs, 
                TimeType = 'IO', Confirmation, TransType, Individual, [Timestamp], ExpenseMiles, ExpenseDollars, [Status], Optional1, Optional2, Optional3, Optional4, Optional5, Optional6, Optional7, Optional8, Optional9, [AuthTimestamp], [ApprovalUserID], [AuthEmail], [AuthConfirmNo], [AuthComments], WorkRules, Rounding, WeekEndDay, IVR_Count, WTE_Count, SiteNo, DeptNo, SortSequence, Line1, GroupCode, PayrollType, SnapshotDateTime, MaxTHDRecordID
        FROM #tmpExport
        WHERE RecordID = @SummaryRecordID
        SET @PunchRecordID = SCOPE_IDENTITY()
      END
      
      IF (@PunchWeekDay = 1)
      BEGIN
      --PRINT 'update day 1'
        UPDATE #tmpExport 
        SET SunHrs = REPLACE((LEFT(CONVERT(VARCHAR(5), @PunchInTime, 108), 5) + '_' + LEFT(CONVERT(VARCHAR(5), @PunchOutTime, 108), 5)), ':', '')
        WHERE RecordID = @PunchRecordID      
      END
      
      IF (@PunchWeekDay = 2)
      BEGIN
      --PRINT 'update day 2'
        UPDATE #tmpExport 
        SET MonHrs = REPLACE((LEFT(CONVERT(VARCHAR(5), @PunchInTime, 108), 5) + '_' + LEFT(CONVERT(VARCHAR(5), @PunchOutTime, 108), 5)), ':', '')
        WHERE RecordID = @PunchRecordID      
      END
      
      IF (@PunchWeekDay = 3)
      BEGIN
      --PRINT 'update day 3'
        UPDATE #tmpExport 
        SET TueHrs = REPLACE((LEFT(CONVERT(VARCHAR(5), @PunchInTime, 108), 5) + '_' + LEFT(CONVERT(VARCHAR(5), @PunchOutTime, 108), 5)), ':', '')
        WHERE RecordID = @PunchRecordID      
      END
      
      IF (@PunchWeekDay = 4)
      BEGIN
      --PRINT 'update day 4'
        UPDATE #tmpExport 
        SET WedHrs = REPLACE((LEFT(CONVERT(VARCHAR(5), @PunchInTime, 108), 5) + '_' + LEFT(CONVERT(VARCHAR(5), @PunchOutTime, 108), 5)), ':', '')
        WHERE RecordID = @PunchRecordID      
      END
      
      IF (@PunchWeekDay = 5)
      BEGIN
      --PRINT 'update day 5'
        UPDATE #tmpExport 
        SET ThuHrs = REPLACE((LEFT(CONVERT(VARCHAR(5), @PunchInTime, 108), 5) + '_' + LEFT(CONVERT(VARCHAR(5), @PunchOutTime, 108), 5)), ':', '')
        WHERE RecordID = @PunchRecordID      
      END
      
      IF (@PunchWeekDay = 6)
      BEGIN
      --PRINT 'update day 6'
        UPDATE #tmpExport 
        SET FriHrs = REPLACE((LEFT(CONVERT(VARCHAR(5), @PunchInTime, 108), 5) + '_' + LEFT(CONVERT(VARCHAR(5), @PunchOutTime, 108), 5)), ':', '')
        WHERE RecordID = @PunchRecordID      
      END
      
      IF (@PunchWeekDay = 7)
      BEGIN
      --PRINT 'update day 7'
        UPDATE #tmpExport 
        SET SatHrs = REPLACE((LEFT(CONVERT(VARCHAR(5), @PunchInTime, 108), 5) + '_' + LEFT(CONVERT(VARCHAR(5), @PunchOutTime, 108), 5)), ':', '')
        WHERE RecordID = @PunchRecordID      
      END                                    
      FETCH NEXT FROM PunchCursor INTO @PunchWeekDay, @PunchInTime, @PunchOutTime, @SummaryRecordID
    END
    CLOSE PunchCursor
    DEALLOCATE PunchCursor
    
    SET @Prev_BranchID = @LI_BranchID
    SET @Prev_EmployeeID = @LI_EmployeeID
    SET @Prev_weDate = @LI_weDate
    SET @Prev_AssignmentNo = @LI_AssignmentNo
      
  END
  FETCH NEXT FROM LineItemCursor INTO @LI_RecordID, @LI_BranchID, @LI_EmployeeID, @LI_weDate, @LI_AssignmentNo
END
CLOSE LineItemCursor
DEALLOCATE LineItemCursor
                   
UPDATE #tmpExport
  SET #tmpExport.AuthEmail =  CASE WHEN bkp.RecordID IS NOT NULL THEN bkp.Email
                              ELSE  CASE WHEN #tmpExport.ApprovalUserID <> 0 
                                    THEN (SELECT CASE WHEN ISNULL(Email, '') = '' THEN LEFT(FirstName + ' ' + LastName, 100) ELSE Email END
                                          FROM TimeCurrent.dbo.tblUser 
                                          WHERE UserID = #tmpExport.ApprovalUserID)  
                                    ELSE 'NO APPROVER EMAIL' 
                                    END
                              END
    , #tmpExport.TransType =  CASE WHEN #tmpExport.IVR_Count > 0 THEN 'I'
                              ELSE CASE WHEN #tmpExport.WTE_Count > 0 THEN 'W'
                                        ELSE 'W' END
                              END
FROM #tmpExport
INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd
ON thd.RecordID = #tmpExport.MaxTHDRecordID
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp
ON bkp.THDRecordId = #tmpExport.MaxTHDRecordID
LEFT JOIN TimeCurrent..tblUser as Usr
ON usr.UserID = isnull(thd.AprvlStatus_UserID,0)
                  

UPDATE #tmpExport
SET Line1= AssignmentNo
    + @Delim + Last4SSN
    + @Delim + CollectFrmt
    + @Delim + ReportingInt 
    + @Delim + BranchID 
    + @Delim + GroupID 
    + @Delim + TimesheetDate
    + @Delim + CASE WHEN MonHrs IN ('0', '0.00', '0000', '') THEN '' WHEN TimeType = 'IO' THEN MonHrs ELSE RIGHT('0000' + REPLACE(MonHrs, '.', ''), 4) END
    + @Delim + CASE WHEN TueHrs IN ('0', '0.00', '0000', '') THEN '' WHEN TimeType = 'IO' THEN TueHrs ELSE RIGHT('0000' + REPLACE(TueHrs, '.', ''), 4) END 
    + @Delim + CASE WHEN WedHrs IN ('0', '0.00', '0000', '') THEN '' WHEN TimeType = 'IO' THEN WedHrs ELSE RIGHT('0000' + REPLACE(WedHrs, '.', ''), 4) END
    + @Delim + CASE WHEN ThuHrs IN ('0', '0.00', '0000', '') THEN '' WHEN TimeType = 'IO' THEN ThuHrs ELSE RIGHT('0000' + REPLACE(ThuHrs, '.', ''), 4) END 
    + @Delim + CASE WHEN FriHrs IN ('0', '0.00', '0000', '') THEN '' WHEN TimeType = 'IO' THEN FriHrs ELSE RIGHT('0000' + REPLACE(FriHrs, '.', ''), 4) END 
    + @Delim + CASE WHEN SatHrs IN ('0', '0.00', '0000', '') THEN '' WHEN TimeType = 'IO' THEN SatHrs ELSE RIGHT('0000' + REPLACE(SatHrs, '.', ''), 4) END  
    + @Delim + CASE WHEN SunHrs IN ('0', '0.00', '0000', '') THEN '' WHEN TimeType = 'IO' THEN SunHrs ELSE RIGHT('0000' + REPLACE(SunHrs, '.', ''), 4) END 
    + @Delim + RIGHT('0000' + REPLACE(CAST(TotalHrs AS VARCHAR), '.', ''), CASE WHEN TotalHrs >= 100 THEN 5 ELSE 4 END)
    + @Delim + TimeType 
    + @Delim + Confirmation      
    + @Delim + TransType         
    + @Delim + Individual        
    + @Delim + [Timestamp]       
    + @Delim + ExpenseMiles      
    + @Delim + ExpenseDollars    
    + @Delim + [Status]          
    + @Delim + Optional1         
    + @Delim + Optional2         
    + @Delim + Optional3         
    + @Delim + Optional4         
    + @Delim + Optional5         
    + @Delim + Optional6       
    + @Delim + Optional7       
    + @Delim + Optional8       
    + @Delim + Optional9       
    + @Delim + AuthTimestamp
    + @Delim + AuthEmail       
    + @Delim + AuthConfirmNo   
    + @Delim + AuthComments
    + @Delim + WorkRules         
    + @Delim + Rounding          
    + @Delim + WeekEndDay
  
SELECT  SSN
      , EmployeeID
      , EmpName
      , FileBreakID
      , weDate
      , AssignmentNo
      , SiteNo
      , DeptNo
      , Line1
      , GroupCode
      , PayrollType
      , SnapshotDateTime
      , TimeType
FROM #tmpExport 
ORDER BY SSN, AssignmentNo, CASE TimeType WHEN 'R' THEN 1 WHEN 'O' THEN 2 WHEN 'D' THEN 3 WHEN 'IO' THEN 4 END
 
DROP TABLE #tmpExport
DROP TABLE #tmpAssignments

RETURN

