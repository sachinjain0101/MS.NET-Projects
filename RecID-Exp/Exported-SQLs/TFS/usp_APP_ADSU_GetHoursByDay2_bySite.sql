Create PROCEDURE [dbo].[usp_APP_ADSU_GetHoursByDay2_bySite]
( 
  @Client             CHAR(4),
  @GroupCode          INT,
  @PPED               DATETIME ,
  @PPED2              DATETIME,
  @RecordType         CHAR(1),
  @REGPAYCODE         VARCHAR(10),
  @OTPAYCODE          VARCHAR(10),
  @DTPAYCODE          VARCHAR(10),
  @ExcludeSubVendors  VARCHAR(1),
  @RestrictStateList  varchar_list_tbltype READONLY
) 
AS

SET NOCOUNT ON
 --PRINT '-----------------------------------------------------------------------------------------------'
 --PRINT '@Client='+ CASE WHEN @Client IS NULL THEN 'NULL' ELSE @Client END 
 --PRINT '@GroupCode='+ CASE WHEN @GroupCode IS NULL THEN 'NULL' ELSE  CAST(@GroupCode AS VARCHAR(100))  END 
 --PRINT '@PPED='+ CASE WHEN @PPED IS NULL THEN 'NULL' ELSE  CAST(@PPED AS VARCHAR) END 
 --PRINT '@PPED2='+ CASE WHEN @PPED2 IS NULL THEN 'NULL' ELSE  CAST(@PPED2 AS VARCHAR) END 
 --PRINT '@RecordType='+ CASE WHEN @RecordType IS NULL THEN 'NULL' ELSE @RecordType END 
 --PRINT '@REGPAYCODE='+ CASE WHEN @REGPAYCODE IS NULL THEN 'NULL' ELSE @REGPAYCODE END 
 --PRINT '@OTPAYCODE='+ CASE WHEN @OTPAYCODE IS NULL THEN 'NULL' ELSE @OTPAYCODE END 
 --PRINT '@DTPAYCODE='+ CASE WHEN @DTPAYCODE IS NULL THEN 'NULL' ELSE @DTPAYCODE END 
 --PRINT '@ExcludeSubVendors='+ CASE WHEN @ExcludeSubVendors IS NULL THEN 'NULL' ELSE @ExcludeSubVendors END 
 --PRINT '@RestrictStateList:'+ CASE WHEN @RestrictStateList IS NULL THEN 'NULL' ELSE @RestrictStateList END 
/*
DECLARE  @Client char(4)
DECLARE  @GroupCode int
DECLARE  @PPED DateTime
DECLARE  @RecordType char(1)

SET @Client = 'ADSU'
SET @GroupCode = 318
SET @PPED = '02/04/2012'
Set @RecordType = 'A'

DROP TABLE #tmpSSNs
DROP TABLE #tmpDailyHrs
DROP TABLE #tmpTotHrs
DROP TABLE #tmpDailyHrs1
DROP TABLE #tmpWorkedSummary
DROP TABLE #tmpProjectSummary

update timehistory..tblemplsites_depts set payrecordssent = NULL where client = 'absu' and groupcode = 100 and payrollperiodenddate = '2/12/2012'


begin TRANSACTION
DECLARE @Client VARCHAR(4)='ADSU'
DECLARE @Groupcode INT =126 -- 104 --121 --117
DECLARE @PPED DATETIME ='03/04/2012'

UPDATE [TimeHistory]..[tblPeriodEndDates] 
SET [Status]='O' 
WHERE [Client]=@Client AND [GroupCode]=@Groupcode AND [PayrollPeriodEndDate]=@PPED

UPDATE timehistory..tblemplsites_depts
SET  payrecordssent = NULL
WHERE client = @Client AND groupcode = @Groupcode AND payrollperiodenddate = @PPED

EXEC TimeHistory.dbo.usp_APP_ADSU_GetHoursByDay2_bySite @Client, @Groupcode, @PPED, @PPED, 'F', 'REG', 'OT', 'DT'
ROLLBACK

select * from timehistory..tbltimehistdetail where client='ADSU' and payrollperiodenddate='4/1/2012'
*/
DECLARE @ESD_historicalonly_Date datetime = '10/16/2016'

--PRINT 'usp_APP_ADSU_GetHoursByDay2_bySite ' + @Client + ', ' + CAST(@GroupCode AS varchar) + ', ' + CAST(@PPED AS varchar) + ', ' + CONVERT(VARCHAR, GETDATE(), 109) + ', ' + @RecordType 

DECLARE @ShiftZeroCount INT
DECLARE @CalcBalanceCnt INT
DECLARE @grpOTMult      NUMERIC(15,10)
DECLARE @prOTMult       NUMERIC(15,10)
DECLARE @OTMult         NUMERIC(15,10)
DECLARE @Today          DATETIME 
DECLARE @Delim          CHAR(1)

-- Project Related
DECLARE @SSN               INT
DECLARE @AssignmentNo      VARCHAR(32)
DECLARE @TransDate         DATETIME
DECLARE @ProjectNum        VARCHAR(200)
DECLARE @Hours             NUMERIC(7,2)
DECLARE @WorkedHours       NUMERIC(7,2)
DECLARE @RecordId          INT
DECLARE @TotalRegHours     NUMERIC(7,2)
DECLARE @TotalOT_Hours     NUMERIC(7,2)
DECLARE @TotalDT_Hours     NUMERIC(7,2)
DECLARE @TotalProjectLines INT 
DECLARE @LoopCounter       INT 
DECLARE @MinProjectId      INT 
DECLARE @ProjectHours      NUMERIC(7,2)
DECLARE @RegBalance        NUMERIC(7,2)
DECLARE @OTBalance         NUMERIC(7,2)
DECLARE @DTBalance         NUMERIC(7,2)
DECLARE @ADJBalance        NUMERIC(7,2)
DECLARE @RegAvailable      NUMERIC(7,2)
DECLARE @OTAvailable       NUMERIC(7,2)
DECLARE @DTAvailable       NUMERIC(7,2)
DECLARE @ADJAvailable      NUMERIC(7,2)
DECLARE @ProjectRemaining  NUMERIC(7,2)
DECLARE @TimeSheetLevel    VARCHAR(1)
DECLARE @ProjectCode       VARCHAR(32)
DECLARE @FaxApprover INT

--print @Client
--print @GroupCode
--print @PPED

SET @Delim = ','
SET @Today = GETDATE()
SET @FaxApprover = (SELECT UserID FROM TimeCurrent.dbo.tblUser WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER' AND Client = @Client)

Create Table #tmpSSNs
( 
    RecordID          INT IDENTITY (1, 1) NOT NULL,
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
    JobID             BIGINT,  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
    AttachmentName    VARCHAR(200),
    ApprovalMethodID  INT,
    WorkState         VARCHAR(2),
    IsSubVendor       VARCHAR(1),
    UnapprovedSecondaryWorkFlow_Count INT,
    ConsultantType		VARCHAR(10),
    PayfileZipNameComponent VARCHAR(250),
    TimeEntryFreq			VARCHAR(2),
    TH_ESD_RecordID   INT,
    PayfileEOW        DATETIME,
    TransDateStart    DATETIME,
    TransDateEnd      DATETIME,
    NoHours           VARCHAR(1),
    CrossoverWeek     VARCHAR(1),
    AssignmentEndDate DATETIME,
	Filter			  VARCHAR(20)
)

IF (@RecordType IN ('A', 'L', 'F'))
BEGIN
    -- Weekly; and Monthly non-crossover weeks
    INSERT INTO #tmpSSNs
    (
          SSN
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
        , UnapprovedSecondaryWorkFlow_Count
        , ConsultantType
        , PayfileZipNameComponent
        , TimeEntryFreq
        , TH_ESD_RecordID
        , PayfileEOW
        , TransDateStart
        , TransDateEnd
        , NoHours
        , CrossoverWeek
        , AssignmentEndDate
		, Filter
    )
    SELECT 
         t.SSN
       , PayRecordsSent = ISNULL(th_esds.PayRecordsSent, '1/1/1970')
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
       , LateApprovals = 0
       , SnapshotDateTime = @Today
       , JobID = 0
       , AttachmentName = th_esds.RecordID
       , ApprovalMethodID = ea.ApprovalMethodID
       , WorkState = ISNULL(ea.WorkState, '')
       , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
       , UnapprovedSecondaryWorkFlow_Count = SUM(CASE WHEN ISNULL(wf_states.EndState,0) =1 THEN 0 ELSE 1 END  ) -- it can be NULL - no Sec.WorkFlo, 1 - in End State, 0 - Sec.WorkFlo exists but not in End State
       , ea.ConsultantType
       , TCAT.PayfileZipNameComponent
       , ISNULL(tef.Code, '')
       , th_esds.RecordID
       , @PPED
       , DATEADD(dd, -6, @PPED)
       , @PPED
       , '0'
       , '0'
       , ea.EndDate
	   , @RecordType
    FROM TimeHistory..tblTimeHistDetail as t
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
        AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'
    LEFT JOIN TimeCurrent..tblTimeEntryFrequency tef
				ON tef.TimeEntryFreqID = ea.TimeEntryFreqID
    LEFT JOIN timecurrent..tblAgencies a
        ON a.client = ea.Client
        AND a.GroupCode = ea.GroupCode
        AND a.Agency = ea.AgencyNo    
      /* start check if any secondary WF is not in End State*/
    LEFT JOIN TimeCurrent..tblAssignment_Workflowlevel AS ass_wf
		ON ass_wf.EmplSitesDeptsID=th_esds.RecordID    
    LEFT JOIN TimeCurrent..tblApprovalWorkflow_States AS wf_states
		ON wf_states.WorkFlowStateID=ass_wf.CurrentState
		AND wf_states.WorkFlowLevelID=ass_wf.WorkFlowLevelID
		LEFT JOIN TimeCurrent..tblApprovalWorkflow_Level AS TAWL
		ON ass_wf.WorkFlowLevelID = TAWL.WorkFlowLevelID	
		LEFT JOIN TimeCurrent..tblClient_AttachmentTypes AS TCAT
		ON TAWL.ClientAttachmentTypeID = TCAT.RecordId
		--AND EndState=1 
    /* end check if any secondary WF is not in End State*/       
    WHERE   t.Client = @Client
        AND t.Groupcode = @GroupCode
        AND t.PayrollPeriodEndDate = @PPED
        AND t.Hours <> 0
        AND ((ISNULL(tef.Code, '') <> 'CM') OR 
             (ISNULL(tef.Code, '') = 'CM') AND DATEPART(dd, @PPED) NOT BETWEEN 1 AND 6) -- DONT' HANDLE CROSSOVER WEEKS FOR MONTHLY HERE
    GROUP BY
          t.SSN
        , ISNULL(th_esds.PayRecordsSent, '1/1/1970')
        , ea.AssignmentNo
        , ea.approvalMethodID
        , th_esds.RecordID
        , ISNULL(ea.WorkState, '')
        , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
        , ConsultantType
        , TCAT.PayfileZipNameComponent
        , tef.Code
        , ea.EndDate
    
    -- Monthly Crossover weeks
    INSERT INTO #tmpSSNs
    (
          SSN
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
        , UnapprovedSecondaryWorkFlow_Count
        , ConsultantType
        , PayfileZipNameComponent
        , TimeEntryFreq
        , TH_ESD_RecordID
        , PayfileEOW
        , TransDateStart
        , TransDateEnd
        , NoHours
        , CrossoverWeek
        , AssignmentEndDate
		, Filter
    )
    SELECT 
         t.SSN
       , PayRecordsSent = ISNULL(th_esds.PayRecordsSent, '1/1/1970')
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
       , LateApprovals = 0
       , SnapshotDateTime = @Today
       , JobID = 0
       , AttachmentName = th_esds.RecordID
       , ApprovalMethodID = ea.ApprovalMethodID
       , WorkState = ISNULL(ea.WorkState, '')
       , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
       , UnapprovedSecondaryWorkFlow_Count = SUM(CASE WHEN ISNULL(wf_states.EndState,0) =1 THEN 0 ELSE 1 END  ) -- it can be NULL - no Sec.WorkFlo, 1 - in End State, 0 - Sec.WorkFlo exists but not in End State
       , ea.ConsultantType
       , TCAT.PayfileZipNameComponent
       , ISNULL(tef.Code, '')
       , th_esds.RecordID
       , CASE WHEN DATEPART(dd, t.TransDate) > 15 THEN CAST(DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, t.TransDate) + 1, 0)) AS DATE) ELSE @PPED END -- PayfileEOW
       , CASE WHEN DATEPART(dd, t.TransDate) > 15 THEN DATEADD(dd, -6, @PPED) ELSE CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(t.TransDate)-1), t.TransDate), 101) END -- TransDateStart
       , CASE WHEN DATEPART(dd, t.TransDate) > 15 THEN CAST(DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, t.TransDate) + 1, 0)) AS DATE) ELSE @PPED END
       , '0'
       , '1'
       , ea.EndDate
	   , @RecordType
    FROM TimeHistory..tblTimeHistDetail as t
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
        AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'
    INNER JOIN TimeCurrent..tblTimeEntryFrequency tef
				ON tef.TimeEntryFreqID = ea.TimeEntryFreqID
    LEFT JOIN timecurrent..tblAgencies a
        ON a.client = ea.Client
        AND a.GroupCode = ea.GroupCode
        AND a.Agency = ea.AgencyNo    
      /* start check if any secondary WF is not in End State*/
    LEFT JOIN TimeCurrent..tblAssignment_Workflowlevel AS ass_wf
		ON ass_wf.EmplSitesDeptsID=th_esds.RecordID    
    LEFT JOIN TimeCurrent..tblApprovalWorkflow_States AS wf_states
		ON wf_states.WorkFlowStateID=ass_wf.CurrentState
		AND wf_states.WorkFlowLevelID=ass_wf.WorkFlowLevelID
		LEFT JOIN TimeCurrent..tblApprovalWorkflow_Level AS TAWL
		ON ass_wf.WorkFlowLevelID = TAWL.WorkFlowLevelID	
		LEFT JOIN TimeCurrent..tblClient_AttachmentTypes AS TCAT
		ON TAWL.ClientAttachmentTypeID = TCAT.RecordId
		--AND EndState=1 
    /* end check if any secondary WF is not in End State*/       
    WHERE   t.Client = @Client
        AND t.Groupcode = @GroupCode
        AND t.PayrollPeriodEndDate = @PPED
        AND t.Hours <> 0
        AND ((th_esds.PartialPayRecordsFirstWeekTransDate IS NULL AND th_esds.PartialPayRecordsLastWeekTransDate IS NULL) OR
             (th_esds.PartialPayRecordsFirstWeekTransDate IS NOT NULL AND t.TransDate < th_esds.PartialPayRecordsFirstWeekTransDate) OR
             (th_esds.PartialPayRecordsLastWeekTransDate IS NOT NULL AND t.TransDate > th_esds.PartialPayRecordsLastWeekTransDate))
        AND tef.Code = 'CM'
        AND DATEPART(dd, @PPED) BETWEEN 1 AND 6 -- ONLY HANDLE CROSSOVER WEEKS
    GROUP BY
          t.SSN
        , ISNULL(th_esds.PayRecordsSent, '1/1/1970')
        , ea.AssignmentNo
        , ea.approvalMethodID
        , th_esds.RecordID
        , ISNULL(ea.WorkState, '')
        , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
        , ConsultantType
        , TCAT.PayfileZipNameComponent
        , tef.Code        
        , CASE WHEN DATEPART(dd, t.TransDate) > 15 THEN CAST(DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, t.TransDate) + 1, 0)) AS DATE) ELSE @PPED END -- PayfileEOW
        , CASE WHEN DATEPART(dd, t.TransDate) > 15 THEN DATEADD(dd, -6, @PPED) ELSE CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(t.TransDate)-1), t.TransDate), 101) END -- TransDateStart
        , CASE WHEN DATEPART(dd, t.TransDate) > 15 THEN CAST(DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, t.TransDate) + 1, 0)) AS DATE) ELSE @PPED END
        , ea.EndDate
        
        
        --SELECT * FROM #tmpSSns
    -- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL
    IF (@RecordType = 'A')
    BEGIN     
        DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount
    END
--
-- Get the records that "Did Not Work" but have a record in TH..tblEmplSites_depts
    INSERT INTO #tmpSSNs
    (
          SSN
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
        , UnapprovedSecondaryWorkFlow_Count
        , ConsultantType
        , PayfileZipNameComponent
        , TimeEntryFreq
        , TH_ESD_RecordID
        , PayfileEOW
        , TransDateStart
        , TransDateEnd        
        , NoHours
        , AssignmentEndDate
		, Filter
    )
    SELECT esd.SSN
         , PayRecordsSent = ISNULL(esd.PayRecordsSent, '1/1/1970')
         , ea.AssignmentNo
         , TransCount = 1
         , ApprovedCount = 1
         , AprvlStatus_Date = @Today
         , IVR_Count = 0
         , WTE_Count = 1
         , Fax_Count =  0
         , FaxApprover_Count =  0
         , EmailClient_Count = 0
         , EmailOther_Count =  0
         , Dispute_Count = 0
         , OtherTxns_Count = 0
         , LateApprovals = 0
         , SnapshotDateTime = @Today
         , JobID = 0
         , AttachmentName = esd.RecordID
         , ApprovalMethodID = ea.ApprovalMethodID
         , WorkState = ISNULL(ea.WorkState, '')
         , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
         -- This was hardcoded to 0 previously, now I'm trying to count it if it's a Monthly assignment, but still make 0 if not monthly
         , UnapprovedSecondaryWorkFlow_Count = SUM(CASE WHEN ISNULL(wf_states.EndState, 0) = 1 THEN 0 ELSE (CASE WHEN ISNULL(tef.Code, '') = 'CM' THEN 1 ELSE 0 END) END  ) -- it can be NULL - no Sec.WorkFlo, 1 - in End State, 0 - Sec.WorkFlo exists but not in End State
         , ea.ConsultantType
         , TCAT.PayfileZipNameComponent
         , ISNULL(tef.Code, '')
         , esd.RecordID
         , @PPED
         , DATEADD(dd, -6, @PPED)
         , @PPED
         , '1'
         , ea.EndDate
		 , @RecordType
    FROM  TimeHistory..tblEmplSites_Depts as esd
    INNER JOIN TimeCurrent..tblEmplAssignments as ea
        ON  ea.Client = esd.Client
        AND ea.Groupcode = esd.Groupcode
        AND ea.SSN = esd.SSN
        AND ea.SiteNo = esd.SiteNo
        AND ea.DeptNo =  esd.DeptNo
    LEFT JOIN TimeCurrent..tblTimeEntryFrequency tef
				ON tef.TimeEntryFreqID = ea.TimeEntryFreqID        
    LEFT JOIN TimeCurrent..tblAgencies a
        ON  a.Client = ea.Client
        AND a.GroupCode = ea.GroupCode
        AND a.Agency = ea.AgencyNo   
    LEFT JOIN TimeCurrent..tblAssignment_Workflowlevel AS ass_wf
		    ON ass_wf.EmplSitesDeptsID=esd.RecordID    
    LEFT JOIN TimeCurrent..tblApprovalWorkflow_States AS wf_states
		    ON wf_states.WorkFlowStateID=ass_wf.CurrentState
		    AND wf_states.WorkFlowLevelID=ass_wf.WorkFlowLevelID
		LEFT JOIN TimeCurrent..tblApprovalWorkflow_Level AS TAWL
		    ON ass_wf.WorkFlowLevelID = TAWL.WorkFlowLevelID	
		LEFT JOIN TimeCurrent..tblClient_AttachmentTypes AS TCAT
		    ON TAWL.ClientAttachmentTypeID = TCAT.RecordId        
    WHERE   esd.Client = @Client
        AND esd.PayrollPeriodEndDate = @PPED
        AND esd.GroupCode = @GroupCode
        AND esd.NoHours='1'
        AND ISNULL(a.ExcludeFromPayFile,'0') <> '1'      
        AND ISNULL(esd.PayRecordsSent, '1/1/1970') = '1/1/1970'
    GROUP BY esd.SSN
         , ISNULL(esd.PayRecordsSent, '1/1/1970')
         , ea.AssignmentNo
         , esd.RecordID
         , ea.ApprovalMethodID
         , ISNULL(ea.WorkState, '')
         , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
         , ea.ConsultantType
         , ISNULL(tef.Code, '')
         , esd.RecordID   
         , TCAT.PayfileZipNameComponent     
         , ea.EndDate
         
    -- If there are any records where NoHours is set and there is submitted time, then delete the NoHours record
    DELETE t1
    FROM #tmpSSNs t1
    INNER JOIN #tmpSSNs t2
    ON t2.AssignmentNo = t1.AssignmentNo
    --AND t2.PayfileEOW = t1.PayfileEOW
    AND t2.NoHours = '0'
    AND t1.NoHours = '1'
    
END
ELSE IF (@RecordType = 'P')
BEGIN
    INSERT INTO #tmpSSNs
    (
          SSN
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
        , UnapprovedSecondaryWorkFlow_Count
        , ConsultantType
        , PayfileZipNameComponent
        , TimeEntryFreq
        , TH_ESD_RecordID
        , AssignmentEndDate
		, TransDateStart
		, TransDateEnd
        , PayfileEOW
        , CrossoverWeek
		, Filter
    )
    SELECT
          t.SSN
        , PayRecordsSent = ISNULL(th_esds.PayRecordsSent, '1/1/1970')
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
        , LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > ISNULL(th_esds.PayRecordsSent, '1/1/2050') THEN 1 ELSE 0 END)
        , SnapshotDateTime = @Today
        , JobID = 0
        , AttachmentName = th_esds.RecordID
        , ApprovalMethodID = ea.ApprovalMethodID
        , WorkState = ISNULL(ea.WorkState, '')
        , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
        , UnapprovedSecondaryWorkFlow_Count = SUM(CASE WHEN ISNULL(wf_states.EndState, 1) = 1 THEN 0 ELSE 1 END  ) -- it can be NULL - no Sec.WorkFlo, 1 - in End State, 0 - Sec.WorkFlo exists but not in End State
        , ea.ConsultantType
        , TCAT.PayfileZipNameComponent
        , ISNULL(tef.Code, '')
        , th_esds.RecordID
        , ea.EndDate
        , DATEADD(dd, -6, @PPED)
        , @PPED
		, @PPED
		, '0'
		, @RecordType
    FROM TimeHistory.dbo.tblEmplSites_Depts th_esds
    INNER JOIN TimeHistory.dbo.tblTimeHistDetail t
        ON  t.Client = th_esds.Client
        AND t.GroupCode = th_esds.GroupCode
        AND t.SSN = th_esds.SSN
        AND t.SiteNo = th_esds.SiteNo
        AND t.DeptNo = th_esds.DeptNo
        AND t.PayrollPeriodEndDate = th_esds.PayrollPeriodEndDate
        AND t.Hours <> 0
    INNER JOIN TimeCurrent..tblEmplAssignments as ea
        ON  ea.Client = t.Client
        AND ea.Groupcode = t.Groupcode
        AND ea.SSN = t.SSN
        AND ea.DeptNo =  t.DeptNo   
    LEFT JOIN TimeCurrent..tblTimeEntryFrequency tef
				ON tef.TimeEntryFreqID = ea.TimeEntryFreqID        
    LEFT JOIN TimeCurrent..tblAgencies a
        ON  a.Client = ea.Client
        AND a.GroupCode = ea.GroupCode
        AND a.Agency = ea.AgencyNo   
     /* start check if any secondary WF is not in End State*/
    LEFT JOIN TimeCurrent..tblAssignment_Workflowlevel AS ass_wf
		  ON ass_wf.EmplSitesDeptsID=th_esds.RecordID    
    LEFT JOIN TimeCurrent..tblApprovalWorkflow_States AS wf_states
		  ON wf_states.WorkFlowStateID=ass_wf.CurrentState
		  AND wf_states.WorkFlowLevelID=ass_wf.WorkFlowLevelID
		--AND EndState=1 
	  LEFT JOIN TimeCurrent..tblApprovalWorkflow_Level AS TAWL
	    ON ass_wf.WorkFlowLevelID = TAWL.WorkFlowLevelID	
	  LEFT JOIN TimeCurrent..tblClient_AttachmentTypes AS TCAT
	    ON TAWL.ClientAttachmentTypeID = TCAT.RecordId
    /* end check if any secondary WF is not in End State*/
    WHERE   th_esds.Client = @Client
        AND th_esds.Groupcode = @GroupCode
        AND th_esds.PayrollPeriodEndDate = @PPED
        AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') <> '1/1/1970'
    GROUP BY 
          t.SSN
        , ISNULL(th_esds.PayRecordsSent, '1/1/1970')
        , ea.AssignmentNo
        , ea.ApprovalMethodID
        , th_esds.RecordID
        , ISNULL(ea.WorkState, '')
        , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END
        , ea.ConsultantType
        , PayfileZipNameComponent
        , ISNULL(tef.Code, '')
        , ea.EndDate
        
    -- Delete all non-late approvals
    DELETE FROM #tmpSSNs WHERE LateApprovals = 0

    -- Only late approvals left at this point, delete if all records are not approved
    DELETE FROM #tmpSSNs WHERE ApprovedCount <> TransCount
END
ELSE
BEGIN
    RETURN
END

--select * FROM #tmpSSNs

-- If we were passed in a list of states to restrict the output to, then delete all assignments that are not in that list
IF (SELECT COUNT(*)
    FROM @RestrictStateList) > 0
BEGIN
  DELETE FROM #tmpSSNs
  WHERE WorkState NOT IN (SELECT n
                          FROM @RestrictStateList)
  AND TransCount <> ApprovedCount
  --AND UnapprovedSecondaryWorkFlow_Count <> 0  -- there is at least on Sec Work Flo not in an end state
  --AND ConsultantType = 'IC'
END

-- Remove Subvendors from the file
IF (@ExcludeSubVendors = '1')
BEGIN
  DELETE FROM #tmpSSNs
  WHERE IsSubVendor = '1'
  AND TransCount <> ApprovedCount
  -- GG - I don't think we need this Sajjan
  --AND UnapprovedSecondaryWorkFlow_Count <> 0 -- there is at least on Sec Work Flo not in an end state
  --AND ConsultantType = 'IC'
END

IF EXISTS(SELECT 1 FROM #tmpSSNs WHERE TimeEntryFreq = 'CM')
BEGIN
  -- If we find an approved invoice in the same month, then set UnapprovedSecondaryInvoices to 0
  UPDATE ssn1
  SET UnapprovedSecondaryWorkFlow_Count = 0
  FROM #tmpSSNs ssn1
  INNER JOIN TimeHistory..tblEmplSites_Depts th_esd
  ON th_esd.RecordID = ssn1.TH_ESD_RecordID
  INNER JOIN TimeHistory..tblEmplSites_Depts th_esd2
  ON th_esd2.Client = th_esd.Client
  AND th_esd2.GroupCode = th_esd.GroupCode
  AND th_esd2.SSN = th_esd.SSN
  AND th_esd2.SiteNo = th_esd.SiteNo
  AND th_esd2.DeptNo = th_esd.DeptNo
  /*AND ((DATEPART(mm, th_esd2.PayrollPeriodEndDate) = DATEPART(mm, th_esd.PayrollPeriodEndDate) 
        AND DATEPART(yyyy, th_esd2.PayrollPeriodEndDate) = DATEPART(yyyy, th_esd.PayrollPeriodEndDate)) OR (
        DATEPART(mm, th_esd2.PayrollPeriodEndDate) = DATEPART(mm, DATEADD(dd, -6, th_esd.PayrollPeriodEndDate))
        AND DATEPART(yyyy, th_esd2.PayrollPeriodEndDate) = DATEPART(yyyy, DATEADD(dd, -6, th_esd.PayrollPeriodEndDate))
        -- we only want to compare the start of the week for the partial piece at the end        
        AND th_esd.PartialPayRecordsSent IS NULL)
       )*/
  AND DATEPART(mm, th_esd2.PayrollPeriodEndDate) = DATEPART(mm, ssn1.PayfileEOW) 
  AND DATEPART(yyyy, th_esd2.PayrollPeriodEndDate) = DATEPART(yyyy, ssn1.PayfileEOW)
  INNER JOIN TimeCurrent..tblAssignment_Workflowlevel AS ass_wf
	ON ass_wf.EmplSitesDeptsID = th_esd2.RecordID    
  INNER JOIN TimeCurrent..tblApprovalWorkflow_States AS wf_states
	ON wf_states.WorkFlowStateID = ass_wf.CurrentState
	AND wf_states.WorkFlowLevelID = ass_wf.WorkFlowLevelID  
	AND ISNULL(wf_states.EndState, 1) = 1
  WHERE ssn1.TimeEntryFreq = 'CM'
END

--SELECT * FROM #tmpSSns

-- For IC's, do not send in an Unapproved file
DELETE FROM #tmpSSNs
WHERE ConsultantType = 'IC'
AND (UnapprovedSecondaryWorkFlow_Count <> 0 OR
     TransCount <> ApprovedCount)

--SELECT * FROM #tmpSSNs
--
-- Make sure all records got calculated correctly for this cycle.
--
CREATE TABLE #tmpCalcHrs
(
    GroupCode            INT,
    PayrollPeriodenddate DATETIME,
    SSN                  INT,
    TotHours             NUMERIC(9,2),
    TotCalcHrs          NUMERIC(9,2),
)

INSERT INTO #tmpCalcHrs(GroupCode, PayrollPeriodenddate, SSN, TotHours, TotCalcHrs)
SELECT 
      t.GroupCode
    , t.PayrollPeriodEndDate
    , t.SSN
    , TotHours = Sum(t.[Hours])
    , TotCalcHrs = Sum(t.RegHours + t.OT_Hours + t.DT_Hours)
FROM TimeHistory.dbo.tblTimeHistDetail as t
WHERE   t.Client = @Client
    AND t.groupCode = @GroupCode
    AND t.PayrollPeriodEnddate = @PPED
    AND t.SSN IN (SELECT SSN FROM #tmpSSNs)
GROUP BY 
      t.GroupCode
    , t.PayrollPeriodEndDate
    , t.SSN
ORDER BY 
      t.groupCode
    , t.PayrollPeriodEndDate
    , t.SSN

SELECT @CalcBalanceCnt = (SELECT COUNT(*) from #tmpCalcHrs where TotHours <> TotCalcHrs)

Drop Table #tmpCalcHrs

IF @CalcBalanceCnt > 0
BEGIN
    RAISERROR ('Employees exist that are out of balance between worked and calculated.', 16, 1) 
    RETURN
END

CREATE TABLE #tmpDailyHrs1
(
    Client               VARCHAR(4),
    GroupCode            INT,
    PayrollPeriodenddate DATETIME,
    TransDate            DATETIME,
    SSN                  INT,
    DeptName             VARCHAR(50),
    AssignmentNo         VARCHAR(50),
    BranchID             VARCHAR(32),
    TotalRegHours        NUMERIC(9,2),
    TotalOT_Hours        NUMERIC(9,2),
    TotalDT_Hours        NUMERIC(9,2),
    PayRate              NUMERIC(7,2),
    BillRate             NUMERIC(7,2),
    ApproverName         VARCHAR(100),
    ApprovalStatus       CHAR(1),
    ApproverDateTime     DATETIME,
    MaxRecordID          BIGINT,  --< @MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
    TimeSheetId          INT,
    SiteNo               INT,
    DeptNo               INT,
    ApprovalMethID       INT,
    EarnCode             VARCHAR(16)
)
CREATE TABLE #tmpDailyHrs
(
    RecordID             INT IDENTITY (1, 1) NOT NULL,
    Client               VARCHAR(4),
    GroupCode            INT,
    PayrollPeriodenddate DATETIME,
    TransDate            DATETIME,
    SSN                  INT,
    DeptName             VARCHAR(50),
    AssignmentNo         VARCHAR(50),
    BranchID             VARCHAR(32),
    TotalRegHours        NUMERIC(9,2),
    TotalOT_Hours        NUMERIC(9,2),
    TotalDT_Hours        NUMERIC(9,2),
    PayRate              NUMERIC(7,2),
    BillRate             NUMERIC(7,2),
    ApproverName         VARCHAR(100),
    ApprovalStatus       CHAR(1),
    ApproverDateTime     DATETIME,
    MaxRecordID          BIGINT,  --< @MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
    TimeSheetId          INT,
    SiteNo               INT,
    DeptNo               INT,
    ApprovalMethodID     INT,
    EarnCode             VARCHAR(16),
    NoHours              CHAR(1)
)

--
--Get the Daily totals for each SSN, display the weekly total as one of the columns.
-- 
INSERT INTO #tmpDailyHrs1
    SELECT
          thd.Client
        , thd.GroupCode
        , thd.PayrollPeriodEndDate
        , thd.TransDate
        , thd.SSN
        , deptName = '' 
        , AssignmentNo = isnull(ea.AssignmentNo,'MISSING')
        , BranchID = isnull(ea.BranchID,'MISSING')
        , TotalRegHours = SUM(CASE WHEN thd.Dollars > 0 THEN  thd.Dollars ELSE thd.RegHours END)
        , TotalOT_Hours = Sum(thd.OT_Hours)
        , TotalDT_Hours = Sum(thd.DT_Hours)
        , PayRate = isnull(ea.PayRate,0.00)
        , BillRate = isnull(ea.BillRate,0.00)
        , ApproverName = cast('' as varchar(50))
        , ApprovalStatus = cast('' as char(1))
        , ApproverDateTime = max( isnull(thd.AprvlStatus_Date, @Today))
        , MaxRecordID = MAX([thd].[RecordID])
        , [TimeSheetId] = IIF(thd.PayrollPeriodEndDate >= @ESD_historicalonly_Date,ESD.RecordID, [tc_ESD].[RecordID])
	  --, [TimeSheetId] = [tc_ESD].[RecordID]
        , [SiteNo]= [thd].[SiteNo]
        , [DeptNo]=[thd].[DeptNo]
        , ApprovalMethodID=[S].ApprovalMethodID
        , EarnCode = CASE WHEN LTRIM(RTRIM(c_AC.ClockAdjustmentNo)) IN ('1','8','$','@') THEN '' ELSE ISNULL(c_AC.ClockAdjustmentNo,'') END
    FROM TimeHistory..tblTimeHistDetail as thd
    INNER JOIN TimeCurrent..tblEmplAssignments as ea
        ON  ea.Client = thd.Client
        AND ea.Groupcode = thd.Groupcode
        AND ea.SSN = thd.SSN
        AND ea.DeptNo =  thd.DeptNo
    INNER JOIN #tmpSSNs as S
        ON  S.SSN = thd.SSN
        AND ea.AssignmentNo = s.AssignmentNo
    INNER JOIN TimeHistory..tblEmplSites_Depts as esd
        ON  esd.Client = thd.Client
        AND esd.Groupcode = thd.Groupcode
        AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate
        AND esd.SSN = thd.SSN
        AND esd.SiteNo = thd.SiteNo
        AND esd.DeptNo =  thd.DeptNo
    INNER JOIN TimeCurrent..tblGroupDepts gd
        ON  gd.Client = thd.Client
        AND gd.GroupCode = thd.GroupCode     
        AND gd.DeptNo = thd.DeptNo         
    LEFT JOIN TimeCurrent..tblAgencies a
        ON  a.Client = thd.Client
        AND a.GroupCode = thd.GroupCode
        AND a.Agency = thd.AgencyNo
    INNER JOIN TimeCurrent.dbo.tblEmplSites_Depts tc_ESD
        ON  thd.Client = tc_ESD.Client
        AND thd.GroupCode = tc_ESD.GroupCode
        AND thd.SiteNo = tc_ESD.SiteNo
        AND thd.DeptNo = tc_ESD.DeptNo
        AND thd.SSN = tc_ESD.SSN
    LEFT JOIN TimeCurrent.dbo.tblAdjCodes c_AC
        ON c_AC.Client = thd.Client
        AND c_AC.GroupCode = thd.GroupCode
        AND LTRIM(RTRIM(c_AC.ClockAdjustmentNo)) = thd.ClockAdjustmentNo
    WHERE   thd.Client = @Client  
        AND thd.PayrollPeriodEndDate = @PPED
        AND thd.GroupCode = @GroupCode  
        AND ISNULL(a.ExcludeFromPayFile, '0') <> '1'        
        AND thd.TransDate BETWEEN s.TransDateStart and s.TransDateEnd
        AND ((esd.PartialPayRecordsFirstWeekTransDate IS NULL AND esd.PartialPayRecordsLastWeekTransDate IS NULL) OR
             (esd.PartialPayRecordsFirstWeekTransDate IS NOT NULL AND thd.TransDate < esd.PartialPayRecordsFirstWeekTransDate) OR
             (esd.PartialPayRecordsLastWeekTransDate IS NOT NULL AND thd.TransDate > esd.PartialPayRecordsLastWeekTransDate))    
    GROUP BY 
          thd.Client
        , thd.GroupCode
        , thd.SSN
        , thd.PayrollPeriodEndDate
        , thd.TransDate
        , ISNULL(ea.PayRate, 0.00), isnull(ea.BillRate, 0.00)   -- CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode2,'') <> '' then gd.CLientDeptCode2 else '' end) ELSE 'N/A' END,
        , ISNULL(ea.AssignmentNo, 'MISSING')
        , ISNULL(ea.BranchID, 'MISSING')
        ,  IIF(thd.PayrollPeriodEndDate >= @ESD_historicalonly_Date,ESD.RecordID, [tc_ESD].[RecordID])
       -- , [tc_ESD].[RecordID]
	   , [thd].[SiteNo]
        , [thd].[DeptNo]
        , [S].ApprovalMethodID
        , CASE WHEN LTRIM(RTRIM(c_AC.ClockAdjustmentNo)) IN ('1','8','$','@') THEN '' ELSE ISNULL(c_AC.ClockAdjustmentNo,'') END

--select * FROM #tmpDailyHrs1        

 -- Second select is used to combine transaction dates that could not be combined in the prior select 
 -- This helps reduce negative hours processing.
    INSERT INTO #tmpDailyHrs
        SELECT
              Client
            , GroupCode
            , PayrollPeriodenddate
            , TransDate
            , SSN
            , DeptName
            , AssignmentNo
            , BranchID
            , Sum(TotalRegHours)
            , Sum(TotalOT_Hours)
            , Sum(TotalDT_Hours)
            , PayRate
            , BillRate
            , ApproverName
            , ApprovalStatus
            , MAX(ApproverDateTime)
            , MaxRecordID
            , TimeSheetId
            , SiteNo
            , DeptNo
            , ApprovalMethID
            , EarnCode
            , NoHours = '0'
    FROM #tmpDailyHrs1
    GROUP BY 
          Client
        , GroupCode
        , PayrollPeriodenddate
        , TransDate
        , SSN
        , DeptName
        , AssignmentNo
        , BranchID
        , PayRate
        , BillRate
        , ApproverName
        , ApprovalStatus
        , [MaxRecordID] 
        , [TimeSheetId]
        , [SiteNo]
        , [DeptNo]
        , ApprovalMethID
        , EarnCode
--handle the "did not work flag" from "NoHours=1" in TH..tblemplsites_depts by adding a "ZERO" record
--
INSERT INTO #tmpDailyHrs
  SELECT
          esd.Client
        , esd.GroupCode
        , esd.PayrollPeriodEndDate
        , TransDate = MAX(esd.PayrollPeriodEndDate)
        , esd.SSN
        , deptName = '' 
        , AssignmentNo = isnull(ea.AssignmentNo, 'MISSING')
        , BranchID = isnull(ea.BranchID, 'MISSING')
        , TotalRegHours = 0
        , TotalOT_Hours = 0
        , TotalDT_Hours = 0
        , PayRate = isnull(ea.PayRate, 0.00)
        , BillRate = isnull(ea.BillRate, 0.00)
        , ApproverName = ''
        , ApprovalStatus = ''
        , ApproverDateTime = @Today
        , MaxRecordID = MAX(esd.RecordID)
        , TimeSheetId = IIF(esd.PayrollPeriodEndDate >= @ESD_historicalonly_Date,ESD.RecordID, [tc_ESD].[RecordID])
        --, TimeSheetId = [tc_ESD].[RecordID]
	   , SiteNo = esd.SiteNo
        , DeptNo = esd.DeptNo
        , ApprovalMethodID = ea.ApprovalMethodID
        , EarnCode = ''
        , NoHours = [esd].[NoHours]
    FROM  TimeHistory..tblEmplSites_Depts as esd
    INNER JOIN TimeCurrent..tblEmplAssignments as ea
        ON  ea.Client = esd.Client
        AND ea.Groupcode = esd.Groupcode
        AND ea.SSN = esd.SSN
        AND ea.SiteNo = esd.SiteNo
        AND ea.DeptNo = esd.DeptNo
    INNER JOIN TimeCurrent..tblEmplSites_Depts tc_esd
        ON  tc_esd.Client = esd.Client
        AND tc_esd.Groupcode = esd.Groupcode
        AND tc_esd.SSN = esd.SSN
        AND tc_esd.SiteNo = esd.SiteNo
        AND tc_esd.DeptNo = esd.DeptNo        
    LEFT JOIN TimeCurrent..tblAgencies ag
        ON  ag.Client = ea.Client
        AND ag.GroupCode = ea.GroupCode
        AND ag.Agency = ea.AgencyNo
    WHERE   esd.Client = @Client
        AND esd.GroupCode = @GroupCode      
        AND esd.PayrollPeriodEndDate = @PPED
        AND esd.NoHours = '1'
        AND ISNULL(ag.ExcludeFromPayFile, '0') <> '1'      
    GROUP BY 
          esd.Client
        , esd.GroupCode
        , esd.SSN
        , esd.PayrollPeriodEndDate
        , esd.SiteNo
        , esd.DeptNo
        , ea.AssignmentNo
        , ea.BranchId
        , ea.PayRate
        , ea.BillRate
       , IIF(esd.PayrollPeriodEndDate >= @ESD_historicalonly_Date,ESD.RecordID, [tc_ESD].[RecordID])
	   -- , [tc_ESD].[RecordID]
        , ea.ApprovalMethodID
        , [esd].[NoHours]
               
DELETE FROM #tmpDailyHrs
    WHERE TotalRegHours = 0.00 
      AND TotalOT_Hours = 0.00 
      AND TotalDT_Hours = 0.00
      AND NoHours = '0'

UPDATE #tmpDailyHrs
SET #tmpDailyHrs.ApproverName = CASE WHEN bkp.RecordId IS NOT NULL 
                                     THEN bkp.Email
                                     ELSE CASE WHEN ISNULL(usr.Email,'') = '' 
                                               THEN (CASE WHEN ISNULL(usr.LastName,'') = '' 
                                                          THEN ISNULL(usr.LogonName,'') 
                                                          ELSE LEFT(usr.LastName + '; ' + ISNULL(usr.FirstName,''),50) 
                                                     END)
                                               ELSE LEFT(usr.Email,50) 
                                          END
                                END   -- ,  #tmpDailyHrs.ApprovalStatus = thd.AprvlStatus
FROM #tmpDailyHrs
INNER JOIN TimeHistory..tblTimeHistDetail as thd
    ON thd.RecordID = #tmpDailyHrs.MaxRecordID
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp
    ON bkp.THDRecordId = #tmpDailyHrs.MaxRecordID
LEFT JOIN TimeCurrent..tblUser as Usr
    ON usr.UserID = thd.AprvlStatus_UserID
WHERE NoHours = '0'

-- Overwrite the Fax Approver user name
UPDATE tdh
SET ApproverName = Usr.AltUserID
FROM #tmpDailyHrs tdh
INNER JOIN TimeHistory..tblTimeHistDetail as thd (NOLOCK)
    ON thd.RecordID = tdh.MaxRecordID
INNER JOIN TimeCurrent..tblUser as Usr (NOLOCK)
    ON usr.UserID = thd.AprvlStatus_UserID
WHERE tdh.NoHours = '0'
AND Usr.UserID = @FaxApprover

-- Create Weekly Total File.
CREATE TABLE #tmpTotHrs
(
    Client               VARCHAR(4),
    GroupCode            INT,
    SSN                  INT,
    DeptName             VARCHAR(50),
    Assignmentno         VARCHAR(50),
    BranchID             VARCHAR(32),
    PayrollPeriodendDate DATETIME,
    TotalWeeklyHours     NUMERIC(9,2)
)

INSERT INTO #tmpTotHrs
    SELECT 
          Client
        , GroupCode
        , SSN
        , DeptName
        , AssignmentNo
        , BranchID
        , PayrollPeriodenddate
        , SUM(TotalRegHours + TotalOT_Hours + TotalDT_Hours)
    FROM #tmpDailyHrs
    GROUP BY 
          Client
        , GroupCode
        , SSN
        , DeptName
        , AssignmentNo
        , BranchID
        , PayrollPeriodenddate

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
    JobID                BIGINT,  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
    AttachmentName       VARCHAR(200),
    SiteNo               INT,
    DeptNo               INT,
    [ApprovalMethodID]   INT,
    NoHours              CHAR(1),
    PayfileZipNameComponent			        VARCHAR(250),
    PartialPayRecordsLastWeekTransDate	DATE,
    PartialPayRecordsFirstWeekTransDate	DATE,
    weDate											        DATE,
    TimeEntryFreq								        VARCHAR(10),
    IsPartialWeek                       VARCHAR(1),
    LastFullWeek                        DATETIME,
    PayfileEOW                          DATETIME,
    AssignmentEndDate                   DATETIME,
    Filter          VARCHAR(20),
    EarnCode          VARCHAR(16)
)

CREATE INDEX IDX_tmpWorkedSummary ON #tmpWorkedSummary(SSN, AssignmentNo, PayfileEOW) 
CREATE INDEX IDX_tmpSSNs ON #tmpSSNs(SSN, AssignmentNo, PayfileEOW) 

--SELECT * FROM #tmpSSNs
--SELECT * FROM #tmpDailyHrs
--SELECT * FROM #tmpTotHrs

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
    , [JobID]
    , [AttachmentName]
    , [SiteNo]
    , [DeptNo]
    , [ApprovalMethodID]
    , [NoHours]
    , PayfileZipNameComponent
    , TimeEntryFreq
    , PayfileEOW
    , AssignmentEndDate
    , Filter
    , EarnCode
)
SELECT  
      TTD.Client
    , TTD.GroupCode
    , TTD.PayrollPeriodEndDate
    , TTD.TransDate
    , TTD.SSN
    , EN.FileNo
    , TTD.AssignmentNo
    , TTD.BranchID
    , TTD.DeptName
    , TotalRegHours = CASE ISNULL(TTD.EarnCode,'') WHEN '' THEN TTD.TotalRegHours ELSE (TTD.TotalRegHours + TTD.TotalOT_Hours + TTD.TotalDT_Hours) END
    , TotalOT_Hours = CASE ISNULL(TTD.EarnCode,'') WHEN '' THEN TTD.TotalOT_Hours ELSE 0.00 END
    , TotalDT_Hours = CASE ISNULL(TTD.EarnCode,'') WHEN '' THEN TTD.TotalDT_Hours ELSE 0.00 END
    , TTH.TotalWeeklyHours
    , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.ApproverName ELSE '' END
    , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.ApproverDateTime ELSE NULL END
    , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.MaxRecordID ELSE 0 END AS ApprovalID
    , CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount AND (tmpSSN.OtherTxns_Count + tmpSSN.Dispute_Count = 0)
           THEN '1'
           WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount AND (tmpSSN.OtherTxns_Count + tmpSSN.Dispute_Count > 0)
           THEN '2'
           ELSE '0'
      END
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
    , TTD.[ApprovalMethodID]
    , TTD.NoHours
    , tmpSSN.PayfileZipNameComponent
    , tmpSSN.TimeEntryFreq
    , tmpSSN.PayfileEOW
    , tmpSSN.AssignmentEndDate
    , tmpSSN.Filter
    , TTD.EarnCode
FROM #tmpDailyHrs AS TTD
INNER JOIN #tmpTotHrs AS TTH
    ON  TTD.Client = TTH.Client
    AND TTD.GroupCode = TTH.GroupCode
    AND TTD.SSN = TTH.SSN
    AND isnull(TTD.AssignmentNo, '') = isnull(TTH.AssignmentNo, '')
    AND TTD.PayrollPeriodEndDate = TTH.PayrollPeriodEndDate
    AND TTD.DeptName = TTH.DeptName
INNER JOIN TimeCurrent..tblEmplNames AS en
    ON  EN.Client = TTD.Client
    AND en.Groupcode = TTD.GroupCode
    AND en.SSN = TTD.SSN
INNER JOIN #tmpSSNs as tmpSSN
    ON  tmpSSN.SSN = TTD.SSN
    AND tmpSSN.AssignmentNo = TTD.AssignmentNo
WHERE TTD.TransDate BETWEEN tmpSSN.TransDateStart AND tmpSSN.TransDateEnd
ORDER BY 
      TTD.SSN
    , TTD.BranchID
    , TTD.AssignmentNo
    , TTD.DeptName
    , TTD.PayrollPeriodEndDate
    , TTD.TransDate
    , TTD.SiteNo
    , TTD.DeptNo
    , TTD.[ApprovalMethodID]
    , TTD.NoHours

--SELECT * FROM #tmpWorkedSummary

-- Multiple Assignments 101, 1/2/2011
-- Summarize the project information incase it has duplicates

CREATE TABLE #tmpProjectSummary
(
    RecordId     INT IDENTITY,
    SSN          INT, 
    AssignmentNo VARCHAR(100), 
    TransDate    DATETIME, 
    ProjectNum   VARCHAR(100), 
    [Hours]      NUMERIC(7,2)
)        
INSERT INTO #tmpProjectSummary
(     SSN
    , AssignmentNo
    , TransDate
    , ProjectNum
    , [Hours]
)
SELECT 
      pr.SSN
    , ea.AssignmentNo
    , pr.TransDate
    , pr.ProjectNum
    , SUM(pr.Hours) AS [Hours]
FROM TimeHistory.dbo.tblWTE_Spreadsheet_Project AS pr
INNER JOIN TimeCurrent.dbo.tblEmplAssignments AS ea
    ON  ea.Client = pr.Client
    AND ea.GroupCode = pr.GroupCode
    AND ea.SSN = pr.SSN
    AND ea.SiteNo = pr.SiteNo
    AND ea.DeptNo = pr.DeptNo
INNER JOIN #tmpSSNs AS S
    ON  S.SSN = pr.SSN
    AND S.AssignmentNo = ea.AssignmentNo
WHERE   pr.Client = @Client
    AND pr.GroupCode = @GroupCode
    AND pr.PayrollPeriodEndDate = @PPED
    /* GG - Before Projects are turned back on, the following needs to be fixed:
            1. Project Code is hardcoded to blank
            2. The time sheet id is being truncated when a project line is split
    */
    AND 1 = 2
GROUP BY 
      pr.SSN
    , ea.AssignmentNo
    , pr.TransDate
    , pr.ProjectNum

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
        , AssignmentNo
        , TransDate
 --       , ProjectCode  --Phase II needs this
    FROM #tmpWorkedSummary
    ORDER BY 
          SSN
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
            , @AssignmentNo
            , @TransDate
            --, @ProjectCode  --Phase II needs this
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
            WHERE   SSN = @SSN
                AND TransDate = @TransDate
                AND AssignmentNo = @AssignmentNo
                AND [Hours] <> 0        
            
            IF (@TotalProjectLines > 0)
            BEGIN                           
                SELECT @MinProjectId = MIN(RecordId)
                FROM #tmpProjectSummary
                WHERE   SSN = @SSN
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
                    WHERE   SSN = @SSN
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
                        , TimeEntryFreq
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
                        , [ApprovalMethodID]
                        , [NoHours]
                        , TimeEntryFreq
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
                        , [ApprovalMethodID]
                        , NoHours
                        , TimeEntryFreq
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
                        , [ApprovalMethodID]
                        , [NoHours]
                        , TimeEntryFreq
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
            , @AssignmentNo
            , @TransDate

    END
    CLOSE workedCursor
    DEALLOCATE workedCursor
END

UPDATE #tmpWorkedSummary
SET #tmpWorkedSummary.[Source] =
  CASE WHEN tmpSSNs.Fax_Count > 0 THEN 'Q' 
   ELSE CASE WHEN tmpSSNs.ApprovalMethodId = 11  THEN '3'
     ELSE CASE WHEN tmpSSNs.IVR_Count > 0 AND tmpSSNs.FaxApprover_Count > 0 THEN 'X'
       ELSE CASE WHEN tmpSSNs.WTE_Count > 0 AND tmpSSNs.FaxApprover_Count > 0 THEN 'Y'
         ELSE CASE WHEN tmpSSNs.IVR_Count > 0 THEN 'F'
           ELSE CASE WHEN tmpSSNs.WTE_Count > 0 THEN 'H'                                             
             ELSE CASE WHEN tmpSSNs.EmailClient_Count > 0 THEN 'D'
               ELSE CASE WHEN tmpSSNs.EmailOther_Count > 0 THEN 'J'                                        
                 ELSE 'H'
               END
             END
           END
         END
       END
     END
   END
  END
    ,  #tmpWorkedSummary.SnapshotDateTime = tmpSSNs.SnapshotDateTime
FROM #tmpWorkedSummary
INNER JOIN #tmpSSNs AS tmpSSNs
ON tmpSSNs.SSN = #tmpWorkedSummary.SSN
AND tmpSSNs.AssignmentNo = #tmpWorkedSummary.AssignmentNo
AND tmpSSNs.PayfileEOW = #tmpWorkedSummary.PayfileEOW

-- From now on, PayrollPeriodEndDate is the "Time Sheet Week Ending Date", i.e. could be truncated for Monthlies
-- weDate is the actual week ending date from PeopleNet
UPDATE #tmpWorkedSummary
SET weDate = PayrollPeriodEndDate

--SELECT 'tmpWorkedSummary'
--SELECT * FROM #tmpWorkedSummary

/*
PartialPayRecordsFirstWeekTransDate
PartialPayRecordsLastWeekTransDate
*/

-- For monthly assignments, set the Week Ending date to the last day of the month, for the end of the month
IF EXISTS(SELECT 1 FROM #tmpSSNs WHERE TimeEntryFreq = 'CM')
BEGIN
  UPDATE #tmpWorkedSummary
  SET PayrollPeriodEndDate = CAST(DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, #tmpWorkedSummary.TransDate) + 1, 0)) AS DATE),
		  PartialPayRecordsLastWeekTransDate = CAST(DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, #tmpWorkedSummary.TransDate) + 1, 0)) AS DATE),
		  IsPartialWeek = 1
  FROM #tmpWorkedSummary
  INNER JOIN #tmpSSNs as tmpSSNs
  ON tmpSSNs.SSN = #tmpWorkedSummary.SSN
  AND tmpSSNs.AssignmentNo = #tmpWorkedSummary.AssignmentNo
  AND tmpSSNs.TimeEntryFreq = 'CM'
  AND DATEPART(m, #tmpWorkedSummary.TransDate) <> DATEPART(m, #tmpWorkedSummary.PayrollPeriodEndDate)

  -- For monthly assignments, set the Week Ending date to the last day of the month, for the start of the month
  UPDATE #tmpWorkedSummary
  SET PartialPayRecordsFirstWeekTransDate = tmpSSNs.TransDateStart,
		  IsPartialWeek = 1
  FROM #tmpWorkedSummary
  INNER JOIN #tmpSSNs as tmpSSNs
  ON tmpSSNs.SSN = #tmpWorkedSummary.SSN
  AND tmpSSNs.AssignmentNo = #tmpWorkedSummary.AssignmentNo
  AND tmpSSNs.TimeEntryFreq = 'CM'
  AND tmpSSNs.PayfileEOW = #tmpWorkedSummary.PayfileEOW
  AND tmpSSNs.CrossoverWeek = '1'
  AND DATEPART(dd, #tmpWorkedSummary.PayrollPeriodEndDate) <= 15
END

SELECT * FROM #tmpWorkedSummary

DROP TABLE #tmpSSNs
DROP TABLE #tmpDailyHrs
DROP TABLE #tmpTotHrs
DROP TABLE #tmpDailyHrs1
DROP TABLE #tmpWorkedSummary
DROP TABLE #tmpProjectSummary

RETURN
GO

