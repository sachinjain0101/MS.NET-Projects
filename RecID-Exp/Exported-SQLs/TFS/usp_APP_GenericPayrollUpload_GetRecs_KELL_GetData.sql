Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData]
(
  @Client CHAR(4)
 ,@GroupCode INT
 ,@PPED DATETIME
 ,@PPED2 DATETIME
 ,@PAYRATEFLAG VARCHAR(4)
 ,@EMPIDType VARCHAR(6)
 ,@REGPAYCODE VARCHAR(10)
 ,@OTPAYCODE VARCHAR(10)
 ,@DTPAYCODE VARCHAR(10)
 ,@PayrollType VARCHAR(80)
 ,@IncludeSalary CHAR(1)
 ,@TestingFlag CHAR(1) = 'N'
) AS
SET NOCOUNT ON;
DECLARE
 @Delim CHAR(1) = ';'
,@FaxApprover INT
,@XXPAYCODE VARCHAR(10) = '_XX_XX_XX_'
,@AdditionalCPAWks int;

SELECT @FaxApprover = UserID 
FROM TimeCurrent.dbo.tblUser 
WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER' 
AND Client = @Client;

IF @PayrollType IN ('C', 'S')
BEGIN
    SELECT  @AdditionalCPAWks = AdditionalCPAWeeks
    FROM    TimeCurrent..tblClients
    WHERE   Client = @Client
END

CREATE TABLE #tmpGroupCodeDates (Client CHAR(4),GroupCode INT,PPED DATE,isVMS TINYINT);
INSERT INTO #tmpGroupCodeDates
SELECT cg.Client,cg.GroupCode,PPED = ped.PayrollPeriodEndDate,0
FROM TimeCurrent.dbo.tblClientGroups cg WITH(NOLOCK)
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)
ON ped.Client = cg.Client
AND ped.GroupCode = cg.GroupCode
WHERE
cg.Client = @Client
AND cg.StaffingSetupType = '1'
AND cg.RecordStatus = '1'
AND cg.IncludeInUpload = '1'
AND ped.PayrollPeriodEndDate BETWEEN DATEADD(WEEK,- cg.LateTimeEntryWeeks,DATEADD(DAY,-6,CONVERT(date, getdate()))) AND GETDATE()
AND ped.PayrollPeriodEndDate < CAST(GETDATE() AS DATE);



;WITH  vmsweeks AS (
 SELECT DISTINCT a.client,a.GroupCode,CASE WHEN @PayrollType NOT IN ('C', 'S') THEN cat.AdditionalLateTimeEntryWks ELSE @AdditionalCPAWks END AS AdditionalLateTimeEntryWks
 FROM TimeCurrent..tblEmplAssignments a
 INNER JOIN TimeCurrent.dbo.tblClients_AssignmentType cat 
	ON cat.Client = a.Client 
	AND cat.AssignmentTypeID = a.AssignmentTypeID 
	AND cat.AdditionalLateTimeEntryWks > 0
 AND a.client = @client
 )
 
 
 ,rawpped AS ( 
				SELECT  cg.Client
					  , cg.GroupCode
					  , PPED = ped.PayrollPeriodEndDate
				FROM    TimeCurrent.dbo.tblClientGroups cg WITH ( NOLOCK )
				INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH ( NOLOCK ) ON ped.Client = cg.Client AND ped.GroupCode = cg.GroupCode
				INNER JOIN vmsweeks v ON v.Client = cg.Client AND v.GroupCode = cg.GroupCode
				WHERE   cg.Client = @client
				 AND cg.StaffingSetupType = '1' 
				 AND cg.RecordStatus = '1' 
				 AND cg.IncludeInUpload = '1' 
				 AND ped.PayrollPeriodEndDate BETWEEN DATEADD(WEEK , -(v.AdditionalLateTimeEntryWks+cg.LateTimeEntryWeeks),dateadd(day,-6,GETDATE())) AND DATEADD(WEEK,-(cg.LateTimeEntryWeeks+1),GETDATE())
 ) 
INSERT INTO #tmpGroupCodeDates  
SELECT DISTINCT thd.client,THD.GroupCode,THD.PayrollPeriodEndDate ,1
FROM Timehistory.dbo.tblTimeHistDetail THD WITH (NOLOCK) 
INNER JOIN rawpped r 
	ON r.Client = THD.Client 
	   AND r.GroupCode = THD.GroupCode 
	   AND r.PPED = thd.PayrollPeriodEndDate 
	   AND THD.UserCode = '*vms'

CREATE TABLE #tmpTHD
(
   RecordID BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
  ,Client CHAR(4)
  ,GroupCode INT
  ,SSN INT
  ,PayrollPeriodEndDate DATETIME
  ,SiteNo INT  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 09Aug2016 >--
  ,DeptNo INT  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 09Aug2016 >--
  ,TransDate DATETIME
  ,InDay TINYINT
  ,InTime DATETIME
  ,OutTime DATETIME
  ,[Hours] NUMERIC(5,2)
  ,ClockAdjustmentNo VARCHAR(3)--> Srinsoft Changed ClockAdjustmentNo CHAR(1) VARCHAR(3) for #tmpTHD on 02/17/2016--<
  ,RegHours NUMERIC(5,2)
  ,OT_Hours NUMERIC(5,2)
  ,DT_Hours NUMERIC(5,2)
  ,AprvlStatus CHAR(1)
  ,AprvlStatus_UserID INT
  ,AprvlStatus_Date DATETIME
  ,UserCode VARCHAR(5)
  ,OutUserCode VARCHAR(5)
  ,isVMS tinyint
)
INSERT INTO #tmpTHD
SELECT
 THD.RecordID
,THD.Client
,THD.GroupCode
,THD.SSN
,THD.PayrollPeriodEndDate
,THD.SiteNo
,THD.DeptNo
,THD.TransDate
,THD.InDay
,THD.InTime
,THD.OutTime
,THD.[Hours]
,THD.ClockAdjustmentNo
,THD.RegHours
,THD.OT_Hours
,THD.DT_Hours
,THD.AprvlStatus
,THD.AprvlStatus_UserID
,THD.AprvlStatus_Date
,THD.UserCode
,THD.OutUserCode
,GCD.isVMS
FROM TimeHistory.dbo.tblTimeHistDetail THD --WITH (NOLOCK)
INNER JOIN #tmpGroupCodeDates GCD
ON GCD.Client = THD.Client
AND GCD.GroupCode = THD.GroupCode
AND GCD.PPED = THD.PayrollPeriodEndDate;

CREATE TABLE #tmpAssignments
( 
   SSN INT
  ,SiteNo INT
  ,DeptNo INT 
  ,TransCount TINYINT 
  ,ApprovedCount SMALLINT
  ,PayRecordsSent DATETIME NOT NULL
  ,AprvlStatus_Date DATETIME
  ,IVR_Count TINYINT
  ,WTE_Count TINYINT
  ,Fax_Count TINYINT
  ,DLT_Count TINYINT
  ,FaxApprover_Count TINYINT  
  ,EmailClient_Count TINYINT
  ,EmailOther_Count TINYINT 
  ,Dispute_Count TINYINT
  ,OtherTxns_Count TINYINT
  ,LateApprovals TINYINT
  ,JobID INT
  ,AttachmentName VARCHAR(200)
  ,ApprovalMethodID INT
  ,OTOverride TINYINT
  ,Last5SSN VARCHAR(10)
  ,AgencyName VARCHAR(200) NOT NULL
  ,SiteState VARCHAR(5)
  ,BranchID VARCHAR(50)
  ,ClientID VARCHAR(50)
  ,EntryRounding INT
  ,AssignmentNo VARCHAR(100)
  ,BillingRate VARCHAR(100) NOT NULL
  ,WorkState VARCHAR(100) NOT NULL
  ,PayOnly VARCHAR(1) NOT NULL
  ,BPO VARCHAR(1) NOT NULL
  ,GroupCode INT NOT NULL
  ,PPED DATE NOT NULL
  ,AssignmentTypeID INT
  ,ExcludeFromPayfile BIT
  ,SendAsRegInPayfile BIT
  ,SendAsUnapproved BIT
);

IF @PayrollType IN ('A','F','L')
BEGIN
  INSERT INTO #tmpAssignments
  (
   SSN
  ,SiteNo
  ,DeptNo
  ,PayRecordsSent
  ,TransCount
  ,ApprovedCount
  ,AprvlStatus_Date
  ,IVR_Count
  ,WTE_Count
  ,Fax_Count
  ,DLT_Count
  ,FaxApprover_Count
  ,EmailClient_Count
  ,EmailOther_Count
  ,Dispute_Count
  ,OtherTxns_Count
  ,LateApprovals
  ,JobID
  ,AttachmentName
  ,ApprovalMethodID
  ,OTOverride
  ,Last5SSN
  ,AgencyName
  ,SiteState        
  ,BranchID
  ,ClientID
  ,EntryRounding
  ,AssignmentNo
  ,BillingRate
  ,WorkState
  ,PayOnly
  ,BPO
  ,GroupCode
  ,PPED
  ,AssignmentTypeID
  )
  SELECT 
   t.SSN
  ,t.SiteNo
  ,t.DeptNo
  ,PayRecordsSent = ISNULL(th_esds.PayRecordsSent,'19700101')
  ,TransCount = SUM(1)
  ,ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)
  ,AprvlStatus_Date = MAX(ISNULL(t.AprvlStatus_Date,'19700102'))
  ,IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)
  ,WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE','VTS') THEN 1 ELSE 0 END)
  ,Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)
  ,DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1 ELSE 0 END)
  ,FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID,0) = @FaxApprover THEN 1 ELSE 0 END)
  ,EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
  ,EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA','COR','AGE')) THEN 1 ELSE 0 END)
  ,Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$','@') THEN 1 ELSE 0 END)
  ,OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$','@','') AND ISNULL(t.UserCode,'') NOT IN ('WTE','COR','FAX','EML','SYS') AND ISNULL(t.OutUserCode,'') NOT in ('CLI','BRA','COR','AGE') THEN 1 ELSE 0 END)
  ,LateApprovals = 0
  ,JobID = 0
  ,AttachmentName = th_esds.RecordID
  ,ApprovalMethodID = ea.ApprovalMethodID
  ,OTOverride = 0
  ,LastSSN = (SELECT TOP 1 SSN FROM TimeCurrent.dbo.tblRFR_Empls rfr WITH(NOLOCK) WHERE rfr.Client = @Client AND rfr.RFR_GroupID = tc_cg.RFR_UniqueID AND rfr.RFR_UniqueID = tc_en.FileNo)
  ,AgencyName = ISNULL(ag.ClientAgencyCode,'')
  ,SiteState = ea.WorkState           
  ,BranchID = ea.BranchId
  ,ClientID = ea.ClientID
  ,ea.EntryRounding
  ,AssignmentNo = SUBSTRING(ea.AssignmentNo,CHARINDEX('-',ea.AssignmentNo) + 1,LEN(ea.AssignmentNo))
  ,BillingRate = CAST(ISNULL(th_esds.BillRate,0) AS VARCHAR) -- BILLING-RATE
  ,WorkState = ISNULL(ea.WorkState,'') -- WORK-STATE
  ,PayOnly = CASE WHEN ISNULL(ea.PayOnly,'N') = '' THEN 'N' ELSE ISNULL(ea.PayOnly,'N') END
  ,BPO = CASE WHEN ISNULL(ea.BPO,'N') = '' THEN 'N' ELSE ISNULL(ea.BPO,'N') END
  ,t.GroupCode
  ,PPED = t.PayrollPeriodEndDate
  ,AssignmentTypeID = ea.AssignmentTypeID
  FROM #tmpTHD t
  INNER JOIN TimeCurrent.dbo.tblClientGroups tc_cg WITH(NOLOCK)
  ON  tc_cg.Client = t.Client 
  AND tc_cg.GroupCode = t.GroupCode     
  INNER JOIN TimeCurrent.dbo.tblEmplNames tc_en WITH(NOLOCK)
  ON  tc_en.Client = t.Client 
  AND tc_en.GroupCode = t.GroupCode 
  AND tc_en.SSN = t.SSN    
  INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea WITH(NOLOCK)
  ON  ea.Client = t.Client
  AND ea.Groupcode = t.Groupcode
  AND ea.SSN = t.SSN
  AND ea.DeptNo =  t.DeptNo
  INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds WITH(NOLOCK)
  ON  th_esds.Client = t.Client
  AND th_esds.GroupCode = t.GroupCode
  AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
  AND th_esds.SSN = t.SSN
  AND th_esds.SiteNo = t.SiteNo
  AND th_esds.DeptNo = t.DeptNo
  INNER JOIN TimeCurrent.dbo.tblAdjCodes ac WITH(NOLOCK)
  ON ac.Client = t.Client
  AND ac.GroupCode = t.GroupCode
  AND ac.ClockAdjustmentNo = CASE WHEN t.ClockAdjustmentNo IN ('','8','@','$') THEN '1' ELSE t.ClockAdjustmentNo END
  LEFT JOIN TimeCurrent.dbo.tblAgencies ag WITH(NOLOCK)
  ON ag.Client = t.Client
  AND ag.GroupCode = t.GroupCode
  AND ag.Agency = ea.AgencyNo
  LEFT JOIN TimeCurrent.dbo.tblClients_AssignmentType cat
  ON cat.AssignmentTypeID = ea.AssignmentTypeID
  AND cat.Client = ea.Client
  LEFT JOIN TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
  ON t.Client = cpa.Client
  AND t.GroupCode = cpa.GroupCode
  AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
  AND t.SSN = cpa.SSN
  AND t.SiteNo = cpa.SiteNo
  AND t.DeptNo = cpa.DeptNo 
  AND cpa.Status <> '4'  
  WHERE
  (th_esds.PayRecordsSent IS NULL OR th_esds.PayRecordsSent = '19700101')
  AND (ac.ADP_HoursCode IS NULL OR ac.ADP_HoursCode NOT IN ('26','572','581','584'))
  AND (t.isVMS = 0 OR (t.isVMS = 1 AND cat.AdditionalLateTimeEntryWks > 0))
  AND cpa.RecordID IS NULL
  GROUP BY
   t.SSN
  ,t.SiteNo
  ,t.DeptNo
  ,ISNULL(th_esds.PayRecordsSent,'19700101')
  ,ea.ApprovalMethodID
  ,th_esds.RecordID
  ,tc_cg.RFR_UniqueID
  ,tc_en.FileNo
  ,ISNULL(ag.ClientAgencyCode,'')
  ,ea.WorkState
  ,ea.BranchId
  ,ea.ClientID
  ,ea.EntryRounding
  ,SUBSTRING(ea.AssignmentNo,CHARINDEX('-',ea.AssignmentNo) + 1,LEN(ea.AssignmentNo))
  ,ISNULL(th_esds.BillRate,0)
  ,ISNULL(ea.WorkState,'')
  ,CASE WHEN ISNULL(ea.PayOnly,'N') = '' THEN 'N' ELSE ISNULL(ea.PayOnly,'N') END
  ,CASE WHEN ISNULL(ea.BPO,'N') = '' THEN 'N' ELSE ISNULL(ea.BPO,'N') END
  ,t.GroupCode,t.PayrollPeriodEndDate,ea.AssignmentTypeID,cat.SendAsUnapprovedInPayfile
  HAVING
    ((CASE WHEN @PayrollType IN ('A', 'C') THEN SUM(1)
      ELSE SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)
    END = SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)) OR cat.SendAsUnapprovedInPayfile = '1')
  --OPTION (MAXDOP 1);
END
ELSE IF (@PayrollType IN ('C', 'S'))
BEGIN
  INSERT INTO #tmpAssignments
  (
   SSN
  ,SiteNo
  ,DeptNo
  ,PayRecordsSent
  ,TransCount
  ,ApprovedCount
  ,AprvlStatus_Date
  ,IVR_Count
  ,WTE_Count
  ,Fax_Count
  ,DLT_Count
  ,FaxApprover_Count
  ,EmailClient_Count
  ,EmailOther_Count
  ,Dispute_Count
  ,OtherTxns_Count
  ,LateApprovals
  ,JobID
  ,AttachmentName
  ,ApprovalMethodID
  ,OTOverride
  ,Last5SSN
  ,AgencyName
  ,SiteState        
  ,BranchID
  ,ClientID
  ,EntryRounding
  ,AssignmentNo
  ,BillingRate
  ,WorkState
  ,PayOnly
  ,BPO
  ,GroupCode
  ,PPED
  ,AssignmentTypeID
  )
  SELECT 
   t.SSN
  ,t.SiteNo
  ,t.DeptNo
  ,PayRecordsSent = ISNULL(th_esds.PayRecordsSent,'19700101')
  ,TransCount = SUM(1)
  ,ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)
  ,AprvlStatus_Date = MAX(ISNULL(t.AprvlStatus_Date,'19700102'))
  ,IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)
  ,WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE','VTS') THEN 1 ELSE 0 END)
  ,Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)
  ,DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1 ELSE 0 END)
  ,FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID,0) = @FaxApprover THEN 1 ELSE 0 END)
  ,EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
  ,EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA','COR','AGE')) THEN 1 ELSE 0 END)
  ,Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$','@') THEN 1 ELSE 0 END)
  ,OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$','@','') AND ISNULL(t.UserCode,'') NOT IN ('WTE','COR','FAX','EML','SYS') AND ISNULL(t.OutUserCode,'') NOT in ('CLI','BRA','COR','AGE') THEN 1 ELSE 0 END)
  ,LateApprovals = 0
  ,JobID = 0
  ,AttachmentName = th_esds.RecordID
  ,ApprovalMethodID = ea.ApprovalMethodID
  ,OTOverride = 0
  ,LastSSN = (SELECT TOP 1 SSN FROM TimeCurrent.dbo.tblRFR_Empls rfr WITH(NOLOCK) WHERE rfr.Client = @Client AND rfr.RFR_GroupID = tc_cg.RFR_UniqueID AND rfr.RFR_UniqueID = tc_en.FileNo)
  ,AgencyName = ISNULL(ag.ClientAgencyCode,'')
  ,SiteState = ea.WorkState           
  ,BranchID = ea.BranchId
  ,ClientID = ea.ClientID
  ,ea.EntryRounding
  ,AssignmentNo = SUBSTRING(ea.AssignmentNo,CHARINDEX('-',ea.AssignmentNo) + 1,LEN(ea.AssignmentNo))
  ,BillingRate = CAST(ISNULL(th_esds.BillRate,0) AS VARCHAR) -- BILLING-RATE
  ,WorkState = ISNULL(ea.WorkState,'') -- WORK-STATE
  ,PayOnly = CASE WHEN ISNULL(ea.PayOnly,'N') = '' THEN 'N' ELSE ISNULL(ea.PayOnly,'N') END
  ,BPO = CASE WHEN ISNULL(ea.BPO,'N') = '' THEN 'N' ELSE ISNULL(ea.BPO,'N') END
  ,t.GroupCode
  ,PPED = t.PayrollPeriodEndDate
  ,AssignmentTypeID = ea.AssignmentTypeID
  FROM #tmpTHD t
  INNER JOIN TimeCurrent.dbo.tblClientGroups tc_cg WITH(NOLOCK)
  ON  tc_cg.Client = t.Client 
  AND tc_cg.GroupCode = t.GroupCode     
  INNER JOIN TimeCurrent.dbo.tblEmplNames tc_en WITH(NOLOCK)
  ON  tc_en.Client = t.Client 
  AND tc_en.GroupCode = t.GroupCode 
  AND tc_en.SSN = t.SSN    
  INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea WITH(NOLOCK)
  ON  ea.Client = t.Client
  AND ea.Groupcode = t.Groupcode
  AND ea.SSN = t.SSN
  AND ea.DeptNo =  t.DeptNo
  INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds WITH(NOLOCK)
  ON  th_esds.Client = t.Client
  AND th_esds.GroupCode = t.GroupCode
  AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
  AND th_esds.SSN = t.SSN
  AND th_esds.SiteNo = t.SiteNo
  AND th_esds.DeptNo = t.DeptNo
  INNER JOIN TimeCurrent.dbo.tblAdjCodes ac WITH(NOLOCK)
  ON ac.Client = t.Client
  AND ac.GroupCode = t.GroupCode
  AND ac.ClockAdjustmentNo = CASE WHEN t.ClockAdjustmentNo IN ('','8','@','$') THEN '1' ELSE t.ClockAdjustmentNo END
  LEFT JOIN TimeCurrent.dbo.tblAgencies ag WITH(NOLOCK)
  ON ag.Client = t.Client
  AND ag.GroupCode = t.GroupCode
  AND ag.Agency = ea.AgencyNo
  LEFT JOIN TimeCurrent.dbo.tblClients_AssignmentType cat
  ON cat.AssignmentTypeID = ea.AssignmentTypeID
  AND cat.Client = ea.Client
  LEFT JOIN TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
  ON t.Client = cpa.Client
  AND t.GroupCode = cpa.GroupCode
  AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
  AND t.SSN = cpa.SSN
  AND t.SiteNo = cpa.SiteNo
  AND t.DeptNo = cpa.DeptNo 
  AND cpa.Status <> '4'
  WHERE
	(th_esds.PayRecordsSent IS NULL OR th_esds.PayRecordsSent = '19700101')
	AND (ac.ADP_HoursCode IS NULL OR ac.ADP_HoursCode NOT IN ('26','572','581','584'))
	AND (t.isVMS = 0 OR (t.isVMS = 1 AND cat.AdditionalLateTimeEntryWks > 0))
	AND EXISTS (SELECT 1
				FROM TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
				WHERE t.Client = cpa.Client
				AND t.GroupCode = cpa.GroupCode
				AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
				AND t.SSN = cpa.SSN
				AND t.SiteNo = cpa.SiteNo
				AND t.DeptNo = cpa.DeptNo
				AND cpa.Status <> '4')
  GROUP BY
   t.SSN
  ,t.SiteNo
  ,t.DeptNo
  ,ISNULL(th_esds.PayRecordsSent,'19700101')
  ,ea.ApprovalMethodID
  ,th_esds.RecordID
  ,tc_cg.RFR_UniqueID
  ,tc_en.FileNo
  ,ISNULL(ag.ClientAgencyCode,'')
  ,ea.WorkState
  ,ea.BranchId
  ,ea.ClientID
  ,ea.EntryRounding
  ,SUBSTRING(ea.AssignmentNo,CHARINDEX('-',ea.AssignmentNo) + 1,LEN(ea.AssignmentNo))
  ,ISNULL(th_esds.BillRate,0)
  ,ISNULL(ea.WorkState,'')
  ,CASE WHEN ISNULL(ea.PayOnly,'N') = '' THEN 'N' ELSE ISNULL(ea.PayOnly,'N') END
  ,CASE WHEN ISNULL(ea.BPO,'N') = '' THEN 'N' ELSE ISNULL(ea.BPO,'N') END
  ,t.GroupCode,t.PayrollPeriodEndDate,ea.AssignmentTypeID,cat.SendAsUnapprovedInPayfile
  HAVING
    ((CASE @PayrollType
      WHEN 'A' THEN SUM(1)
      ELSE SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)
    END = SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)) OR cat.SendAsUnapprovedInPayfile = '1')
END
ELSE
BEGIN
  RETURN;
END

--SELECT * FROM #tmpAssignments

UPDATE ass
SET ExcludeFromPayfile = cat.ExcludeFromPayfile,
	SendAsRegInPayfile = cat.SendAsRegInPayfile,
	SendAsUnapproved = cat.SendAsUnapprovedInPayfile
FROM #tmpAssignments ass
INNER JOIN TimeCurrent..tblClients_AssignmentType cat
ON cat.Client = @Client
AND cat.AssignmentTypeID = ass.AssignmentTypeID

DELETE FROM #tmpAssignments
WHERE ExcludeFromPayfile = '1'

DELETE ass
FROM #tmpAssignments ass
WHERE ass.TransCount <> ass.ApprovedCount  
AND @PayrollType IN ('A', 'C') --IN ('A', 'L')
AND ISNULL(ass.SendAsUnapproved, '0') = '0'

;WITH DoesOTOEXists AS
(
  SELECT DISTINCT sa.SSN,sa.GroupCode,PPED = ts.TimesheetEndDate
  FROM TimeHistory.dbo.tblWTE_Timesheets ts WITH(NOLOCK)
  INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_Assignments sa WITH(NOLOCK)
  ON ts.RecordId = sa.TimesheetId
  INNER JOIN (SELECT DISTINCT Client,GroupCode FROM #tmpGroupCodeDates) gcd
  ON gcd.Client = sa.Client
  AND gcd.GroupCode = sa.GroupCode
  WHERE EXISTS
  (
    SELECT 1 FROM TimeHistory.dbo.tblWTE_Spreadsheet_OTOverrides
    WHERE SpreadsheetAssignmentId = sa.RecordId
  )
)
UPDATE T SET
OTOverride = 1
FROM #tmpAssignments T
LEFT JOIN DoesOTOEXists D
ON D.SSN = T.SSN
AND D.GroupCode = T.GroupCode
AND D.PPED = T.PPED
WHERE D.SSN IS NOT NULL
OR T.AgencyName <> ''
OR (T.BranchID IN ('35C3','3547') AND T.ClientID = '01327464')
OR T.SiteState = 'PR';

CREATE TABLE #tmpBaseData
(
   RecordID BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
  ,TransDate DATE
  ,[Hours] NUMERIC(5,2)
  ,RegHours NUMERIC(5,2)
  ,OT_Hours NUMERIC(5,2)
  ,DT_Hours NUMERIC(5,2)
  ,AprvlStatus VARCHAR(1)
  ,AprvlStatus_Date DATE
  ,AprvlStatus_UserID INT
  ,ClockAdjustmentNo VARCHAR(3) --> Srinsoft Changed ClockAdjustmentNo VARCHAR(1) VARCHAR(3) for #tmpTHD on 02/17/2016--<
  ,OTOverride TINYINT
  ,SSN INT
  ,EmployeeID VARCHAR(100)
  ,EmpName VARCHAR(100)
  ,FileBreakID VARCHAR(20)
  ,weDate VARCHAR(10)
  ,AssignmentNo VARCHAR(100)
  ,Last4SSN VARCHAR(10)
  ,CollectFrmt VARCHAR(20)
  ,ReportingInt VARCHAR(10)
  ,BranchID VARCHAR(100)
  ,GroupID VARCHAR(100)
  ,TimesheetDate VARCHAR(10)
  ,TimeType VARCHAR(10)
  ,Confirmation VARCHAR(10)
  ,TransType VARCHAR(1)
  ,Individual VARCHAR(1)
  ,[Timestamp] VARCHAR(20)
  ,ExpenseMiles VARCHAR(10)
  ,ExpenseDollars VARCHAR(10)
  ,[Status] VARCHAR(3)
  ,Optional1 VARCHAR(100)
  ,Optional2 VARCHAR(100)
  ,Optional3 VARCHAR(100)
  ,Optional4 VARCHAR(100)
  ,Optional5 VARCHAR(100)
  ,Optional6 VARCHAR(100)
  ,Optional7 VARCHAR(100)
  ,Optional8 VARCHAR(100)
  ,Optional9 VARCHAR(100)
  ,AuthTimeStamp DATETIME
  ,ApprovalUserID INT 
  ,AuthEmail VARCHAR(100)
  ,AuthConfirmNo VARCHAR(6)
  ,AuthComments VARCHAR(255)
  ,WorkRules VARCHAR(4)
  ,Rounding VARCHAR(1)
  ,WeekEndDay VARCHAR(1)
  ,IVR_Count TINYINT
  ,WTE_Count TINYINT
  ,SiteNo INT
  ,DeptNo INT
  ,SortSequence NUMERIC(8,3)
  ,Line1 VARCHAR(1500)
  ,GroupCode INT
  ,PayrollType VARCHAR(50)     
  ,PayOnly VARCHAR(1)
  ,BPO VARCHAR(1) 
  ,DisputedCode VARCHAR(10)
  ,tintDayOfWeek TINYINT
  ,InDay TINYINT
  ,InTime TIME
  ,OutTime TIME
  ,TotalHrs NUMERIC(15,2)
  ,IsGTS BIT
  ,AssignmentTypeID INT
  ,ExcludeFromPayfile BIT
  ,SendAsRegInPayfile BIT
  ,SendAsUnapproved BIT
  ,DLT_Count BIT
)

INSERT INTO #tmpBaseData
SELECT DISTINCT
 hd.RecordID
,hd.TransDate
,hd.[Hours]
,hd.RegHours
,hd.OT_Hours
,hd.DT_Hours
,hd.AprvlStatus
,hd.AprvlStatus_Date
,hd.AprvlStatus_UserID
,hd.ClockAdjustmentNo
,ta.OTOverride
,SSN = hd.ssn
,EmployeeID = en.FileNo
,EmpName = en.LastName + ';' + en.FirstName
,FileBreakID = ISNULL(en.PayGroup,'')
,weDate = CONVERT(VARCHAR(10),hd.PayrollPeriodEndDate,101)
,ta.AssignmentNo
,Last4SSN = RIGHT('0000' + CAST(ta.Last5SSN AS VARCHAR),4)
,CollectFrmt  = '42'
,ReportingInt = '1'
,ta.BranchId
,GroupID = '0'
,TimesheetDate = CONVERT(VARCHAR(10),hd.PayrollPeriodEndDate,101)
,TimeType =
  CASE
    WHEN ac.ClockAdjustmentNo = '1' THEN @XXPAYCODE
    WHEN cg.RFR_UniqueId LIKE '65%' AND ac.ClockAdjustmentNo = 'A' THEN @XXPAYCODE
    ELSE ac.ADP_HoursCode
  END
,Confirmation = ''
,TransType = ''
,Individual = ''
,[Timestamp] = CONVERT(VARCHAR(10),hd.PayrollPeriodEndDate,101) + ' ' + CONVERT(VARCHAR(10),hd.PayrollPeriodEndDate,108)
,ExpenseMiles = ''
,ExpenseDollars = ''
,[Status] = CASE WHEN ta.TransCount = ta.ApprovedCount THEN '2' ELSE '0' END
,Optional1 = RIGHT('00000' + CAST(ta.Last5SSN AS VARCHAR),5) -- SSN5-9
,Optional2 = ta.BillingRate
,Optional3 = ISNULL(esd.BillingOvertimeCalcFactor,1.5) -- BILLING-OT-FACTOR
,Optional4 = '2.0' -- BILLING-DT-FACTOR
,Optional5 = ta.WorkState
,Optional6 = '' -- SYSTEM-ID
,Optional7 = CASE WHEN cg.RFR_UniqueId LIKE '65%' AND ac.ClockAdjustmentNo = 'A' THEN ac.ADP_HoursCode ELSE '' END -- Pay/Bill Code
,Optional8 = '' -- WR-APPLIED
,Optional9 = '' -- FILLER
,AuthTimeStamp = CASE WHEN ISNULL(hd.AprvlStatus,'') IN ('A','L') THEN ISNULL(hd.AprvlStatus_Date,hd.PayrollPeriodEndDate) ELSE hd.PayrollPeriodEndDate END
,ApprovalUserID = CASE WHEN ISNULL(hd.AprvlStatus,'') IN ('A','L') THEN ISNULL(hd.AprvlStatus_UserID,0) ELSE 0 END
,AuthEmail = ''
,AuthConfirmNo = ''
,AuthComments = ''
,WorkRules = ISNULL(pr.PayFileCode,'0001')
,Rounding = CASE WHEN ISNULL(err.TYPE,'') = 'R' THEN '1' ELSE '' END
,WeekEndDay = CONVERT(VARCHAR(3),DATEPART(WEEKDAY,hd.PayrollPeriodEndDate))
,IVR_Count = ta.IVR_Count
,WTE_Count = ta.WTE_Count
,SiteNo = hd.SiteNo
,DeptNo = hd.DeptNo
,SortSequence = 0.0
,Line1 = ''
,GroupCode = en.GroupCode
,PayrollType = @PayrollType
,ta.PayOnly
,ta.BPO
,DisputedCode = 'N'
,tintDayOfWeek = DATEPART(DW,hd.TransDate)
,hd.InDay
,hd.InTime
,hd.OutTime
,TotalHrs = SUM(hd.[Hours]) OVER (PARTITION BY hd.SSN,hd.SiteNo,hd.DeptNo)
,IsGTS = CASE WHEN (ta.EmailClient_Count + ta.EmailOther_Count) > 0 THEN 1 ELSE 0 END
,ta.AssignmentTypeID
,ta.ExcludeFromPayfile
,ta.SendAsRegInPayfile
,ta.SendAsUnapproved
,ta.DLT_Count
FROM #tmpTHD hd
INNER JOIN #tmpAssignments ta
ON ta.SSN = hd.SSN
AND ta.SiteNo = hd.SiteNo
AND ta.DeptNo = hd.DeptNo
AND ta.GroupCode = hd.GroupCode
AND ta.PPED = hd.PayrollPeriodEndDate
INNER JOIN TimeCurrent.dbo.tblEmplNames en WITH(NOLOCK)
ON  en.Client = hd.Client
AND en.GroupCode = hd.GroupCode
AND en.SSN = hd.SSN
INNER JOIN TimeHistory.dbo.tblEmplNames enh WITH(NOLOCK)
ON  hd.Client = enh.Client
AND hd.GroupCode = enh.GroupCode
AND hd.SSN = enh.SSN
AND hd.PayrollPeriodEndDate = enh.PayrollPeriodEndDate  
INNER JOIN TimeCurrent.dbo.tblEmplSites_Depts esd WITH(NOLOCK)
ON  esd.Client = hd.Client
AND esd.GroupCode = hd.GroupCode
AND esd.SSN = hd.SSN
AND esd.DeptNo = hd.DeptNo
AND esd.SiteNo = hd.SiteNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac  WITH(NOLOCK)
ON ac.Client = hd.Client
AND	ac.GroupCode = hd.GroupCode
AND	ac.ClockAdjustmentNo = CASE WHEN ISNULL(hd.ClockAdjustmentNo,'') IN ('','8','@','$') THEN '1' ELSE hd.ClockAdjustmentNo END
INNER JOIN TimeCurrent.dbo.tblClientGroups cg
ON cg.Client = hd.Client
AND cg.GroupCode = hd.GroupCode
LEFT JOIN TimeCurrent.dbo.tblAgencies ag WITH(NOLOCK)
ON  ag.Client = en.Client
AND ag.GroupCode = en.GroupCode
AND ag.Agency = en.AgencyNo
LEFT JOIN TimeCurrent.dbo.tblPayRules pr WITH(NOLOCK)
ON pr.RecordID = enh.PayRuleID
LEFT JOIN TimeCurrent.dbo.tblEntryRoundingRules err WITH(NOLOCK)
ON err.RecordId = ta.EntryRounding
WHERE
enh.PayRecordsSent IS NULL
AND (ag.ExcludeFromPayFile IS NULL OR ag.ExcludeFromPayFile <> '1')
AND (ac.ADP_HoursCode IS NULL OR ac.ADP_HoursCode NOT IN ('26','572','581','584'))
--OPTION (MAXDOP 1);

UPDATE #tmpBaseData
SET RegHours = (RegHours + OT_Hours + DT_Hours), OT_Hours = 0, DT_Hours = 0
WHERE SendAsRegInPayfile = '1'

--SELECT * FROM #tmpBaseData

CREATE TABLE #tmpExport
(
   SSN INT
  ,EmployeeID VARCHAR(100)
  ,EmpName VARCHAR(100)
  ,FileBreakID VARCHAR(20)
  ,weDate VARCHAR(10)
  ,AssignmentNo VARCHAR(100)
  ,Last4SSN VARCHAR(10)
  ,CollectFrmt VARCHAR(20)
  ,ReportingInt VARCHAR(10)
  ,BranchID VARCHAR(100)
  ,GroupID VARCHAR(100)
  ,TimesheetDate VARCHAR(10)
  ,SunHrs VARCHAR(15)
  ,MonHrs VARCHAR(15)
  ,TueHrs VARCHAR(15)
  ,WedHrs VARCHAR(15)
  ,ThuHrs VARCHAR(15)
  ,FriHrs VARCHAR(15)
  ,SatHrs VARCHAR(15)
  ,SunCnt TINYINT
  ,MonCnt TINYINT
  ,TueCnt TINYINT
  ,WedCnt TINYINT
  ,ThuCnt TINYINT
  ,FriCnt TINYINT
  ,SatCnt TINYINT
  ,TotalHrs NUMERIC(15,2)
  ,TotalAssignmentHrs NUMERIC(15,2)
  ,TimeType VARCHAR(4)
  ,Confirmation VARCHAR(10)
  ,TransType VARCHAR(1)
  ,Individual VARCHAR(1)
  ,[Timestamp] VARCHAR(20)
  ,ExpenseMiles VARCHAR(10)
  ,ExpenseDollars VARCHAR(10)
  ,[Status] VARCHAR(3)
  ,Optional1 VARCHAR(100)
  ,Optional2 VARCHAR(100)
  ,Optional3 VARCHAR(100)
  ,Optional4 VARCHAR(100)
  ,Optional5 VARCHAR(100)
  ,Optional6 VARCHAR(100)
  ,Optional7 VARCHAR(100)
  ,Optional8 VARCHAR(100)
  ,Optional9 VARCHAR(100)
  ,AuthTimeStamp VARCHAR(20)
  ,ApprovalUserID INT 
  ,AuthEmail VARCHAR(100)
  ,AuthConfirmNo VARCHAR(6)
  ,AuthComments VARCHAR(255)
  ,WorkRules VARCHAR(4)
  ,Rounding VARCHAR(1)
  ,WeekEndDay VARCHAR(1)
  ,IVR_Count TINYINT
  ,WTE_Count TINYINT
  ,SiteNo INT
  ,DeptNo INT
  ,SortSequence NUMERIC(8,3)
  ,Line1 VARCHAR(1500)
  ,GroupCode INT
  ,RecordID INT IDENTITY
  ,PayrollType VARCHAR(50)    
  ,MaxTHDRecordID BIGINT  --< MaxTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
  ,PayOnly VARCHAR(1)
  ,BPO VARCHAR(1) 
  ,DisputedCode VARCHAR(10)
  ,IsGTS BIT
  ,ForOrderBy TINYINT
  ,DLT_Count TINYINT
);

INSERT INTO #tmpExport
-- REG
SELECT
 SSN,EmployeeID,EmpName
,FileBreakID,weDate,AssignmentNo
,Last4SSN,CollectFrmt,ReportingInt
,BranchID,GroupID,TimesheetDate
,SunHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN CASE WHEN OTOverride = '0' THEN [Hours] ELSE RegHours END ELSE 0 END))
,MonHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN CASE WHEN OTOverride = '0' THEN [Hours] ELSE RegHours END ELSE 0 END))
,TueHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN CASE WHEN OTOverride = '0' THEN [Hours] ELSE RegHours END ELSE 0 END))
,WedHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN CASE WHEN OTOverride = '0' THEN [Hours] ELSE RegHours END ELSE 0 END))
,ThuHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN CASE WHEN OTOverride = '0' THEN [Hours] ELSE RegHours END ELSE 0 END))
,FriHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN CASE WHEN OTOverride = '0' THEN [Hours] ELSE RegHours END ELSE 0 END))
,SatHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN CASE WHEN OTOverride = '0' THEN [Hours] ELSE RegHours END ELSE 0 END))
,SunCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN 1 ELSE 0 END)
,MonCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN 1 ELSE 0 END)
,TueCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN 1 ELSE 0 END)
,WedCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN 1 ELSE 0 END)
,ThuCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN 1 ELSE 0 END)
,FriCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN 1 ELSE 0 END)
,SatCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN 1 ELSE 0 END)
,TotalHrs = SUM(CASE WHEN OTOverride = 0 THEN [Hours] ELSE RegHours END)
,TotalAssignmentHrs = SUM([Hours])
,TimeType = CASE TimeType WHEN @XXPAYCODE THEN @REGPAYCODE ELSE TimeType END
,Confirmation,TransType,Individual
,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
,Optional1,Optional2,Optional3
,Optional4,Optional5,Optional6
,Optional7,Optional8,Optional9
,AuthTimeStamp = CONVERT(VARCHAR(10),MAX(AuthTimeStamp),101)+' '+ CONVERT(VARCHAR(10),MAX(AuthTimeStamp),108)
,ApprovalUserID = MAX(ApprovalUserID)
,AuthEmail,AuthConfirmNo,AuthComments
,WorkRules,Rounding,WeekEndDay
,IVR_Count,WTE_Count,SiteNo,DeptNo
,SortSequence,Line1
,GroupCode,PayrollType
,MaxTHDRecordID = MAX(RecordID)
,PayOnly,BPO,DisputedCode,IsGTS
,ForOrderBy = ROW_NUMBER() OVER (PARTITION BY SSN,EmployeeID,BranchID,weDate,AssignmentNo ORDER BY CASE TimeType WHEN @XXPAYCODE THEN 0 ELSE 1 END,MAX(RecordID))
,DLT_Count
FROM #tmpBaseData
GROUP BY
 SSN,EmployeeID,EmpName
,FileBreakID,weDate,AssignmentNo
,Last4SSN,CollectFrmt,ReportingInt
,BranchID,GroupID,TimesheetDate
,CASE TimeType WHEN @XXPAYCODE THEN @REGPAYCODE ELSE TimeType END
,Confirmation,TransType,Individual
,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
,Optional1,Optional2,Optional3
,Optional4,Optional5,Optional6
,Optional7,Optional8,Optional9
,AuthEmail,AuthConfirmNo,AuthComments
,WorkRules,Rounding,WeekEndDay
,IVR_Count,WTE_Count,SiteNo,DeptNo
,SortSequence,Line1
,GroupCode,PayrollType
,PayOnly,BPO,DisputedCode,IsGTS,DLT_Count
,CASE TimeType WHEN @XXPAYCODE THEN 0 ELSE 1 END
HAVING SUM(CASE WHEN OTOverride = 0 THEN [Hours] ELSE RegHours END) > 0;

IF EXISTS
(SELECT 1 FROM #tmpBaseData WHERE OTOverride > 0 AND OT_Hours > 0)
  BEGIN
	-- OT
    INSERT INTO #tmpExport
    SELECT
     SSN,EmployeeID,EmpName
    ,FileBreakID,weDate,AssignmentNo
    ,Last4SSN,CollectFrmt,ReportingInt
    ,BranchID,GroupID,TimesheetDate
    ,SunHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN OT_Hours ELSE 0 END))
    ,MonHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN OT_Hours ELSE 0 END))
    ,TueHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN OT_Hours ELSE 0 END))
    ,WedHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN OT_Hours ELSE 0 END))
    ,ThuHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN OT_Hours ELSE 0 END))
    ,FriHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN OT_Hours ELSE 0 END))
    ,SatHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN OT_Hours ELSE 0 END))
    ,SunCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN 1 ELSE 0 END)
    ,MonCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN 1 ELSE 0 END)
    ,TueCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN 1 ELSE 0 END)
    ,WedCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN 1 ELSE 0 END)
    ,ThuCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN 1 ELSE 0 END)
    ,FriCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN 1 ELSE 0 END)
    ,SatCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN 1 ELSE 0 END)
    ,TotalHrs = SUM(CASE WHEN OTOverride >= 1 THEN OT_Hours ELSE 0 END)
    ,TotalAssignmentHrs = SUM([Hours])
    ,TimeType = CASE TimeType WHEN @XXPAYCODE THEN @OTPAYCODE ELSE TimeType END
    ,Confirmation,TransType,Individual
    ,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
    ,Optional1,Optional2,Optional3
    ,Optional4,Optional5,Optional6
    ,Optional7,Optional8,Optional9
    ,AuthTimeStamp = CONVERT(VARCHAR(10),MAX(AuthTimeStamp),101)+' '+ CONVERT(VARCHAR(10),MAX(AuthTimeStamp),108)
    ,ApprovalUserID = MAX(ApprovalUserID)
    ,AuthEmail,AuthConfirmNo,AuthComments
    ,WorkRules,Rounding,WeekEndDay
    ,IVR_Count,WTE_Count,SiteNo,DeptNo
    ,SortSequence,Line1
    ,GroupCode,PayrollType
    ,MaxTHDRecordID = MAX(RecordID)
    ,PayOnly,BPO,DisputedCode,IsGTS
    ,ForOrderBy = 3
	,DLT_Count
    FROM #tmpBaseData
    WHERE
    OTOverride > 0
    AND OT_Hours > 0
    GROUP BY
     SSN,EmployeeID,EmpName
    ,FileBreakID,weDate,AssignmentNo
    ,Last4SSN,CollectFrmt,ReportingInt
    ,BranchID,GroupID,TimesheetDate
    ,CASE TimeType WHEN @XXPAYCODE THEN @OTPAYCODE ELSE TimeType END
    ,Confirmation,TransType,Individual
    ,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
    ,Optional1,Optional2,Optional3
    ,Optional4,Optional5,Optional6
    ,Optional7,Optional8,Optional9
    ,AuthEmail,AuthConfirmNo,AuthComments
    ,WorkRules,Rounding,WeekEndDay
    ,IVR_Count,WTE_Count,SiteNo,DeptNo
    ,SortSequence,Line1
    ,GroupCode,PayrollType
    ,PayOnly,BPO,DisputedCode,IsGTS,DLT_Count
    HAVING SUM(CASE WHEN OTOverride >= 1 THEN OT_Hours ELSE 0 END) > 0;
  END

IF EXISTS
(SELECT 1 FROM #tmpBaseData WHERE OTOverride > 0 AND DT_Hours > 0)
  BEGIN
  -- DT
   INSERT INTO #tmpExport
   SELECT
    SSN,EmployeeID,EmpName
   ,FileBreakID,weDate,AssignmentNo
   ,Last4SSN,CollectFrmt,ReportingInt
   ,BranchID,GroupID,TimesheetDate
   ,SunHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN DT_Hours ELSE 0 END))
   ,MonHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN DT_Hours ELSE 0 END))
   ,TueHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN DT_Hours ELSE 0 END))
   ,WedHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN DT_Hours ELSE 0 END))
   ,ThuHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN DT_Hours ELSE 0 END))
   ,FriHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN DT_Hours ELSE 0 END))
   ,SatHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN DT_Hours ELSE 0 END))
   ,SunCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN 1 ELSE 0 END)
   ,MonCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN 1 ELSE 0 END)
   ,TueCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN 1 ELSE 0 END)
   ,WedCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN 1 ELSE 0 END)
   ,ThuCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN 1 ELSE 0 END)
   ,FriCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN 1 ELSE 0 END)
   ,SatCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN 1 ELSE 0 END)
   ,TotalHrs = SUM(CASE WHEN OTOverride >= 1 THEN DT_Hours ELSE 0 END)
   ,TotalAssignmentHrs = SUM([Hours])
   ,TimeType = CASE TimeType WHEN @XXPAYCODE THEN @DTPAYCODE ELSE TimeType END
   ,Confirmation,TransType,Individual
   ,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
   ,Optional1,Optional2,Optional3
   ,Optional4,Optional5,Optional6
   ,Optional7,Optional8,Optional9
   ,AuthTimeStamp = CONVERT(VARCHAR(10),MAX(AuthTimeStamp),101)+' '+ CONVERT(VARCHAR(10),MAX(AuthTimeStamp),108)
   ,ApprovalUserID = MAX(ApprovalUserID)
   ,AuthEmail,AuthConfirmNo,AuthComments
   ,WorkRules,Rounding,WeekEndDay
   ,IVR_Count,WTE_Count,SiteNo,DeptNo
   ,SortSequence,Line1
   ,GroupCode,PayrollType
   ,MaxTHDRecordID = MAX(RecordID)
   ,PayOnly,BPO,DisputedCode,IsGTS
   ,ForOrderBy = 4
   ,DLT_Count
   FROM #tmpBaseData
   WHERE
   OTOverride > 0
   AND DT_Hours > 0
   GROUP BY
    SSN,EmployeeID,EmpName
   ,FileBreakID,weDate,AssignmentNo
   ,Last4SSN,CollectFrmt,ReportingInt
   ,BranchID,GroupID,TimesheetDate
   ,CASE TimeType WHEN @XXPAYCODE THEN @DTPAYCODE ELSE TimeType END
   ,Confirmation,TransType,Individual
   ,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
   ,Optional1,Optional2,Optional3
   ,Optional4,Optional5,Optional6
   ,Optional7,Optional8,Optional9
   ,AuthEmail,AuthConfirmNo,AuthComments
   ,WorkRules,Rounding,WeekEndDay
   ,IVR_Count,WTE_Count,SiteNo,DeptNo
   ,SortSequence,Line1
   ,GroupCode,PayrollType
   ,PayOnly,BPO,DisputedCode,IsGTS,DLT_Count
   HAVING SUM(CASE WHEN OTOverride >= 1 THEN DT_Hours ELSE 0 END) > 0;
  END

IF EXISTS
(SELECT 1 FROM #tmpBaseData WHERE ClockAdjustmentNo = '$' AND [Hours] < 0)
  BEGIN
  --OTHER REG
    INSERT INTO #tmpExport
    SELECT
     SSN,EmployeeID,EmpName
    ,FileBreakID,weDate,AssignmentNo
    ,Last4SSN,CollectFrmt,ReportingInt
    ,BranchID,GroupID,TimesheetDate
    ,SunHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN [Hours] * -1 ELSE 0 END))
    ,MonHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN [Hours] * -1 ELSE 0 END))
    ,TueHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN [Hours] * -1 ELSE 0 END))
    ,WedHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN [Hours] * -1 ELSE 0 END))
    ,ThuHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN [Hours] * -1 ELSE 0 END))
    ,FriHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN [Hours] * -1 ELSE 0 END))
    ,SatHrs = CONVERT(VARCHAR(15),SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN [Hours] * -1 ELSE 0 END))
    ,SunCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 1 THEN 1 ELSE 0 END)
    ,MonCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 2 THEN 1 ELSE 0 END)
    ,TueCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 3 THEN 1 ELSE 0 END)
    ,WedCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 4 THEN 1 ELSE 0 END)
    ,ThuCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 5 THEN 1 ELSE 0 END)
    ,FriCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 6 THEN 1 ELSE 0 END)
    ,SatCnt = SUM(CASE WHEN DATEPART(WEEKDAY,TransDate) = 7 THEN 1 ELSE 0 END)
    ,TotalHrs = SUM([Hours] * -1)
    ,TotalAssignmentHrs = SUM([Hours])
    ,TimeType = @REGPAYCODE
    ,Confirmation,TransType,Individual
    ,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
    ,Optional1,Optional2,Optional3
    ,Optional4,Optional5,Optional6
    ,Optional7 = '',Optional8,Optional9
    ,AuthTimeStamp = CONVERT(VARCHAR(10),MAX(AuthTimeStamp),101)+' '+ CONVERT(VARCHAR(10),MAX(AuthTimeStamp),108)
    ,ApprovalUserID = MAX(ApprovalUserID)
    ,AuthEmail,AuthConfirmNo,AuthComments
    ,WorkRules,Rounding,WeekEndDay
    ,IVR_Count,WTE_Count,SiteNo,DeptNo
    ,SortSequence,Line1
    ,GroupCode,PayrollType
    ,MaxTHDRecordID = MAX(RecordID)
    ,PayOnly,BPO,DisputedCode = 'Y',IsGTS
    ,ForOrderBy = 2
	,DLT_Count
    FROM #tmpBaseData
    WHERE
    ClockAdjustmentNo = '$'
    AND [Hours] < 0
    GROUP BY
     SSN,EmployeeID,EmpName
    ,FileBreakID,weDate,AssignmentNo
    ,Last4SSN,CollectFrmt,ReportingInt
    ,BranchID,GroupID,TimesheetDate
    ,Confirmation,TransType,Individual
    ,[Timestamp],ExpenseMiles,ExpenseDollars,[Status]
    ,Optional1,Optional2,Optional3
    ,Optional4,Optional5,Optional6
    ,Optional8,Optional9
    ,AuthEmail,AuthConfirmNo,AuthComments
    ,WorkRules,Rounding,WeekEndDay
    ,IVR_Count,WTE_Count,SiteNo,DeptNo
    ,SortSequence,Line1
    ,GroupCode,PayrollType
    ,PayOnly,BPO,IsGTS,DLT_Count
    HAVING SUM([Hours] * -1) <> 0;
  END

UPDATE #tmpExport SET
 SunHrs = CASE WHEN SunCnt = 0 THEN '' ELSE SunHrs END
,MonHrs = CASE WHEN MonCnt = 0 THEN '' ELSE MonHrs END
,TueHrs = CASE WHEN TueCnt = 0 THEN '' ELSE TueHrs END
,WedHrs = CASE WHEN WedCnt = 0 THEN '' ELSE WedHrs END
,ThuHrs = CASE WHEN ThuCnt = 0 THEN '' ELSE ThuHrs END
,FriHrs = CASE WHEN FriCnt = 0 THEN '' ELSE FriHrs END
,SatHrs = CASE WHEN SatCnt = 0 THEN '' ELSE SatHrs END;

UPDATE EX SET
AuthEmail =  
  CASE WHEN bkp.RecordID IS NOT NULL THEN bkp.Email
    ELSE
    CASE WHEN EX.ApprovalUserID <> 0 
      THEN(SELECT CASE WHEN ISNULL(Email,'') = '' THEN LEFT(FirstName + ' ' + LastName,100) ELSE Email END
            FROM TimeCurrent.dbo.tblUser WHERE UserID = EX.ApprovalUserID)  
      ELSE 'NO APPROVER EMAIL' 
    END
  END
,EX.TransType =
  CASE WHEN EX.DLT_Count > 0 THEN 'X'
    ELSE
	  CASE WHEN EX.IVR_Count > 0 THEN 'I'
		ELSE
		CASE WHEN EX.WTE_Count > 0 THEN 'W'
		  ELSE 'W'
		END
	  END
  END
FROM #tmpExport EX
INNER JOIN #tmpBaseData tbd
ON tbd.RecordID = EX.MaxTHDRecordID
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval bkp WITH(NOLOCK)
ON bkp.THDRecordId = EX.MaxTHDRecordID;

IF (@PayrollType IN ('C', 'S'))
BEGIN
	INSERT INTO #tmpExport
	(
	   SSN
	  ,EmployeeID
	  ,EmpName
	  ,FileBreakID
	  ,weDate
	  ,AssignmentNo
	  ,Last4SSN
	  ,CollectFrmt
	  ,ReportingInt
	  ,BranchID
	  ,GroupID
	  ,TimesheetDate
	  ,SunHrs
	  ,MonHrs
	  ,TueHrs
	  ,WedHrs
	  ,ThuHrs
	  ,FriHrs
	  ,SatHrs
	  ,SunCnt
	  ,MonCnt
	  ,TueCnt
	  ,WedCnt
	  ,ThuCnt
	  ,FriCnt
	  ,SatCnt
	  ,TotalHrs
	  ,TotalAssignmentHrs
	  ,TimeType
	  ,Confirmation
	  ,TransType
	  ,Individual
	  ,[Timestamp]
	  ,ExpenseMiles
	  ,ExpenseDollars
	  ,[Status]
	  ,Optional1
	  ,Optional2
	  ,Optional3
	  ,Optional4
	  ,Optional5
	  ,Optional6
	  ,Optional7
	  ,Optional8
	  ,Optional9
	  ,AuthTimeStamp
	  ,ApprovalUserID
	  ,AuthEmail
	  ,AuthConfirmNo
	  ,AuthComments
	  ,WorkRules
	  ,Rounding
	  ,WeekEndDay
	  ,IVR_Count
	  ,WTE_Count
	  ,SiteNo
	  ,DeptNo
	  ,SortSequence
	  ,Line1
	  ,GroupCode
	  ,PayrollType 
	  ,MaxTHDRecordID 
	  ,PayOnly 
	  ,BPO
	  ,DisputedCode
	  ,IsGTS
	  ,ForOrderBy
	  ,DLT_Count
	)
	SELECT te.SSN
		  ,te.EmployeeID
		  ,te.EmpName
		  ,te.FileBreakID
		  ,te.weDate
		  ,te.AssignmentNo
		  ,te.Last4SSN
		  ,te.CollectFrmt
		  ,te.ReportingInt
		  ,te.BranchID
		  ,te.GroupID
		  ,te.TimesheetDate
		  ,SunHrs = 0
		  ,MonHrs = 0
		  ,TueHrs = 0
		  ,WedHrs = 0
		  ,ThuHrs = 0
		  ,FriHrs = 0
		  ,SatHrs = 0
		  ,SunCnt = 1
		  ,MonCnt = 1
		  ,TueCnt = 1
		  ,WedCnt = 1
		  ,ThuCnt = 1
		  ,FriCnt = 1
		  ,SatCnt = 1
		  ,TotalHrs = 0
		  ,TotalAssignmentHrs = 0
		  ,@REGPAYCODE
		  ,te.Confirmation
		  ,te.TransType
		  ,te.Individual
		  ,te.[Timestamp]
		  ,te.ExpenseMiles
		  ,te.ExpenseDollars
		  ,te.[Status]
		  ,te.Optional1
		  ,te.Optional2
		  ,te.Optional3
		  ,te.Optional4
		  ,te.Optional5
		  ,te.Optional6
		  ,te.Optional7
		  ,te.Optional8
		  ,te.Optional9
		  ,te.AuthTimeStamp
		  ,te.ApprovalUserID
		  ,te.AuthEmail
		  ,te.AuthConfirmNo
		  ,te.AuthComments
		  ,te.WorkRules
		  ,te.Rounding
		  ,te.WeekEndDay
		  ,te.IVR_Count
		  ,te.WTE_Count
		  ,te.SiteNo
		  ,te.DeptNo
		  ,te.SortSequence
		  ,te.Line1
		  ,te.GroupCode
		  ,te.PayrollType 
		  ,te.MaxTHDRecordID 
		  ,te.PayOnly 
		  ,te.BPO
		  ,te.DisputedCode
		  ,te.IsGTS
		  ,te.ForOrderBy
		  ,te.DLT_Count
	FROM #tmpExport te
	LEFT JOIN #tmpExport te2
	ON te2.GroupCode = te.GroupCode
	AND te2.SSN = te.SSN
	AND te2.SiteNo = te.SiteNo
	AND te2.DeptNo = te.DeptNo
	AND te2.WeDate = te.weDate
	AND te2.TimeType = @REGPAYCODE
	WHERE te2.RecordID IS NULL

	INSERT INTO #tmpExport
	(
	   SSN
	  ,EmployeeID
	  ,EmpName
	  ,FileBreakID
	  ,weDate
	  ,AssignmentNo
	  ,Last4SSN
	  ,CollectFrmt
	  ,ReportingInt
	  ,BranchID
	  ,GroupID
	  ,TimesheetDate
	  ,SunHrs
	  ,MonHrs
	  ,TueHrs
	  ,WedHrs
	  ,ThuHrs
	  ,FriHrs
	  ,SatHrs
	  ,SunCnt
	  ,MonCnt
	  ,TueCnt
	  ,WedCnt
	  ,ThuCnt
	  ,FriCnt
	  ,SatCnt
	  ,TotalHrs
	  ,TotalAssignmentHrs
	  ,TimeType
	  ,Confirmation
	  ,TransType
	  ,Individual
	  ,[Timestamp]
	  ,ExpenseMiles
	  ,ExpenseDollars
	  ,[Status]
	  ,Optional1
	  ,Optional2
	  ,Optional3
	  ,Optional4
	  ,Optional5
	  ,Optional6
	  ,Optional7
	  ,Optional8
	  ,Optional9
	  ,AuthTimeStamp
	  ,ApprovalUserID
	  ,AuthEmail
	  ,AuthConfirmNo
	  ,AuthComments
	  ,WorkRules
	  ,Rounding
	  ,WeekEndDay
	  ,IVR_Count
	  ,WTE_Count
	  ,SiteNo
	  ,DeptNo
	  ,SortSequence
	  ,Line1
	  ,GroupCode
	  ,PayrollType 
	  ,MaxTHDRecordID 
	  ,PayOnly 
	  ,BPO
	  ,DisputedCode
	  ,IsGTS
	  ,ForOrderBy
	  ,DLT_Count
	)
	SELECT te.SSN
		  ,te.EmployeeID
		  ,te.EmpName
		  ,te.FileBreakID
		  ,te.weDate
		  ,te.AssignmentNo
		  ,te.Last4SSN
		  ,te.CollectFrmt
		  ,te.ReportingInt
		  ,te.BranchID
		  ,te.GroupID
		  ,te.TimesheetDate
		  ,SunHrs = 0
		  ,MonHrs = 0
		  ,TueHrs = 0
		  ,WedHrs = 0
		  ,ThuHrs = 0
		  ,FriHrs = 0
		  ,SatHrs = 0
		  ,SunCnt = 1
		  ,MonCnt = 1
		  ,TueCnt = 1
		  ,WedCnt = 1
		  ,ThuCnt = 1
		  ,FriCnt = 1
		  ,SatCnt = 1
		  ,TotalHrs = 0
		  ,TotalAssignmentHrs = 0
		  ,@OTPAYCODE 
		  ,te.Confirmation
		  ,te.TransType
		  ,te.Individual
		  ,te.[Timestamp]
		  ,te.ExpenseMiles
		  ,te.ExpenseDollars
		  ,te.[Status]
		  ,te.Optional1
		  ,te.Optional2
		  ,te.Optional3
		  ,te.Optional4
		  ,te.Optional5
		  ,te.Optional6
		  ,te.Optional7
		  ,te.Optional8
		  ,te.Optional9
		  ,te.AuthTimeStamp
		  ,te.ApprovalUserID
		  ,te.AuthEmail
		  ,te.AuthConfirmNo
		  ,te.AuthComments
		  ,te.WorkRules
		  ,te.Rounding
		  ,te.WeekEndDay
		  ,te.IVR_Count
		  ,te.WTE_Count
		  ,te.SiteNo
		  ,te.DeptNo
		  ,te.SortSequence
		  ,te.Line1
		  ,te.GroupCode
		  ,te.PayrollType 
		  ,te.MaxTHDRecordID 
		  ,te.PayOnly 
		  ,te.BPO
		  ,te.DisputedCode
		  ,te.IsGTS
		  ,te.ForOrderBy
		  ,te.DLT_Count
	FROM #tmpExport te
	LEFT JOIN #tmpExport te2
	ON te2.GroupCode = te.GroupCode
	AND te2.SSN = te.SSN
	AND te2.SiteNo = te.SiteNo
	AND te2.DeptNo = te.DeptNo
	AND te2.WeDate = te.weDate
	AND te2.TimeType = @OTPAYCODE
	WHERE te2.RecordID IS NULL

	INSERT INTO #tmpExport
	(
	   SSN
	  ,EmployeeID
	  ,EmpName
	  ,FileBreakID
	  ,weDate
	  ,AssignmentNo
	  ,Last4SSN
	  ,CollectFrmt
	  ,ReportingInt
	  ,BranchID
	  ,GroupID
	  ,TimesheetDate
	  ,SunHrs
	  ,MonHrs
	  ,TueHrs
	  ,WedHrs
	  ,ThuHrs
	  ,FriHrs
	  ,SatHrs
	  ,SunCnt
	  ,MonCnt
	  ,TueCnt
	  ,WedCnt
	  ,ThuCnt
	  ,FriCnt
	  ,SatCnt
	  ,TotalHrs
	  ,TotalAssignmentHrs
	  ,TimeType
	  ,Confirmation
	  ,TransType
	  ,Individual
	  ,[Timestamp]
	  ,ExpenseMiles
	  ,ExpenseDollars
	  ,[Status]
	  ,Optional1
	  ,Optional2
	  ,Optional3
	  ,Optional4
	  ,Optional5
	  ,Optional6
	  ,Optional7
	  ,Optional8
	  ,Optional9
	  ,AuthTimeStamp
	  ,ApprovalUserID
	  ,AuthEmail
	  ,AuthConfirmNo
	  ,AuthComments
	  ,WorkRules
	  ,Rounding
	  ,WeekEndDay
	  ,IVR_Count
	  ,WTE_Count
	  ,SiteNo
	  ,DeptNo
	  ,SortSequence
	  ,Line1
	  ,GroupCode
	  ,PayrollType 
	  ,MaxTHDRecordID 
	  ,PayOnly 
	  ,BPO
	  ,DisputedCode
	  ,IsGTS
	  ,ForOrderBy
	  ,DLT_Count
	)
	SELECT te.SSN
		  ,te.EmployeeID
		  ,te.EmpName
		  ,te.FileBreakID
		  ,te.weDate
		  ,te.AssignmentNo
		  ,te.Last4SSN
		  ,te.CollectFrmt
		  ,te.ReportingInt
		  ,te.BranchID
		  ,te.GroupID
		  ,te.TimesheetDate
		  ,SunHrs = 0
		  ,MonHrs = 0
		  ,TueHrs = 0
		  ,WedHrs = 0
		  ,ThuHrs = 0
		  ,FriHrs = 0
		  ,SatHrs = 0
		  ,SunCnt = 1
		  ,MonCnt = 1
		  ,TueCnt = 1
		  ,WedCnt = 1
		  ,ThuCnt = 1
		  ,FriCnt = 1
		  ,SatCnt = 1
		  ,TotalHrs = 0
		  ,TotalAssignmentHrs = 0
		  ,@DTPAYCODE
		  ,te.Confirmation
		  ,te.TransType
		  ,te.Individual
		  ,te.[Timestamp]
		  ,te.ExpenseMiles
		  ,te.ExpenseDollars
		  ,te.[Status]
		  ,te.Optional1
		  ,te.Optional2
		  ,te.Optional3
		  ,te.Optional4
		  ,te.Optional5
		  ,te.Optional6
		  ,te.Optional7
		  ,te.Optional8
		  ,te.Optional9
		  ,te.AuthTimeStamp
		  ,te.ApprovalUserID
		  ,te.AuthEmail
		  ,te.AuthConfirmNo
		  ,te.AuthComments
		  ,te.WorkRules
		  ,te.Rounding
		  ,te.WeekEndDay
		  ,te.IVR_Count
		  ,te.WTE_Count
		  ,te.SiteNo
		  ,te.DeptNo
		  ,te.SortSequence
		  ,te.Line1
		  ,te.GroupCode
		  ,te.PayrollType 
		  ,te.MaxTHDRecordID 
		  ,te.PayOnly 
		  ,te.BPO
		  ,te.DisputedCode
		  ,te.IsGTS
		  ,te.ForOrderBy
		  ,te.DLT_Count
	FROM #tmpExport te
	LEFT JOIN #tmpExport te2
	ON te2.GroupCode = te.GroupCode
	AND te2.SSN = te.SSN
	AND te2.SiteNo = te.SiteNo
	AND te2.DeptNo = te.DeptNo
	AND te2.WeDate = te.weDate
	AND te2.TimeType = @DTPAYCODE
	WHERE te2.RecordID IS NULL
	-- This will only insert missing REG, OT, DT that are not already insert in #tmpUploadExport above.


	--This will only insert those Adjustment code with 0 that were part of the week that was opened 
    /*INSERT  INTO #tmpUploadExport
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
			WHERE cpa.Status <> '4'*/

END;

--SELECT '#tmpExport after C'
--SELECT * FROM #tmpExport

;WITH HrsIOData AS
(
  SELECT
   GroupCode,weDate,SSN,EmployeeID,AssignmentNo,BranchID,SiteNo,DeptNo,TotalHrs,tintDayOfWeek
  ,RankOrder = RANK() OVER
  (
    PARTITION BY GroupCode,weDate,SSN,EmployeeID,AssignmentNo,BranchID,SiteNo,DeptNo,TotalHrs,tintDayOfWeek
    ORDER BY TransDate,
      CASE InDay
        WHEN 7
          THEN CASE tintDayOfWeek WHEN 1 THEN InDay - 7 ELSE InDay END
        WHEN 1
          THEN CASE tintDayOfWeek WHEN 7 THEN InDay + 7 ELSE InDay END
        ELSE InDay
      END,InTime
  )
  ,strIOValue = REPLACE((LEFT(CONVERT(VARCHAR(5),InTime,108),5) + '_' + LEFT(CONVERT(VARCHAR(5),OutTime,108),5)),':','')
  FROM #tmpBaseData
  WHERE NOT (InTime IS NULL AND OutTime IS NULL)
  AND NOT (InTime = '00:00:00.0000000' AND OutTime = '00:00:00.0000000')
  AND [Hours] <> 0
)
,PivotedIOHrs AS
(
  SELECT
   GroupCode,weDate,SSN,EmployeeID,AssignmentNo,BranchID,SiteNo,DeptNo,TotalHrs,RankOrder
  ,SunHrs = [1],MonHrs = [2],TueHrs = [3]
  ,WedHrs = [4],ThuHrs = [5],FriHrs = [6],SatHrs = [7]
  FROM HrsIOData
  PIVOT
  (
    MIN(strIOValue) FOR tintDayOfWeek
    IN ([1],[2],[3],[4],[5],[6],[7])
  ) P
)
,cteResults AS
(
SELECT
ETimeType = E.TimeType,X.RankOrder
,NewRankOrder = DENSE_RANK() OVER 
 (PARTITION BY E.GroupCode,E.weDate,E.SSN,E.EmployeeID,E.AssignmentNo,E.SiteNo,E.DeptNo ORDER BY CASE E.TimeType WHEN 'R' /*@XXPAYCODE*/ THEN 0 ELSE 1 END)
,E.SSN,E.EmployeeID,E.EmpName
,E.FileBreakID,E.weDate,E.AssignmentNo
,E.SiteNo,E.DeptNo
,Line1 = 
					 E.AssignmentNo
+ @Delim + E.Last4SSN
+ @Delim + E.CollectFrmt
+ @Delim + E.ReportingInt
+ @Delim + E.BranchID
+ @Delim + E.GroupID
+ @Delim + E.TimesheetDate
+ @Delim + ISNULL(X.MonHrs,'')
+ @Delim + ISNULL(X.TueHrs,'')
+ @Delim + ISNULL(X.WedHrs,'')
+ @Delim + ISNULL(X.ThuHrs,'')
+ @Delim + ISNULL(X.FriHrs,'')
+ @Delim + ISNULL(X.SatHrs,'')
+ @Delim + ISNULL(X.SunHrs,'')
+ @Delim + RIGHT('0000' + REPLACE(CAST(E.TotalAssignmentHrs AS VARCHAR),'.',''),CASE WHEN E.TotalAssignmentHrs >= 100 THEN 5 ELSE 4 END)
+ @Delim + 'IO'  --TransType
+ @Delim + E.Confirmation
+ @Delim + E.TransType
+ @Delim + E.Individual
+ @Delim + E.[Timestamp]
+ @Delim + E.ExpenseMiles
+ @Delim + E.ExpenseDollars
+ @Delim + E.[Status]
+ @Delim + E.Optional1
+ @Delim + E.Optional2
+ @Delim + E.Optional3
+ @Delim + E.Optional4
+ @Delim + E.Optional5
+ @Delim + E.Optional6
+ @Delim + E.Optional7
+ @Delim + E.Optional8
+ @Delim + E.Optional9
+ @Delim + E.AuthTimestamp
+ @Delim + E.AuthEmail
+ @Delim + E.AuthConfirmNo
+ @Delim + E.AuthComments
+ @Delim + E.WorkRules
+ @Delim + E.Rounding
+ @Delim + E.WeekEndDay
+ @Delim + E.PayOnly
+ @Delim + E.BPO
+ @Delim + E.DisputedCode
,E.GroupCode,E.PayrollType
,SnapshotDateTime = GETDATE()
,TimeType = 'IO'
,IsGTS
FROM
#tmpExport E
INNER JOIN
PivotedIOHrs X
ON X.GroupCode = E.GroupCode
AND X.weDate = E.weDate
AND X.SSN = E.SSN
AND X.EmployeeID = E.EmployeeID
AND X.AssignmentNo = E.AssignmentNo
AND X.BranchID = E.BranchID
AND X.SiteNo = E.SiteNo
AND X.DeptNo = E.DeptNo
WHERE
(
  (E.TimeType = @REGPAYCODE AND E.ForOrderBy = 1)
  OR
  (E.TimeType <> @REGPAYCODE)
)
UNION
SELECT
 ETimeType = '',RankOrder = 0,NewRankOrder = 0
,SSN,EmployeeID,EmpName
,FileBreakID,weDate,AssignmentNo
,SiteNo,DeptNo
,Line1 = 
					 AssignmentNo
+ @Delim + Last4SSN
+ @Delim + CollectFrmt
+ @Delim + ReportingInt
+ @Delim + BranchID
+ @Delim + GroupID
+ @Delim + TimesheetDate
+ @Delim + CASE WHEN MonHrs IN ('0','0.00','0000','') AND @PayrollType NOT IN ('C', 'S') THEN '' ELSE RIGHT('0000' + REPLACE(MonHrs,'.',''),4) END
+ @Delim + CASE WHEN TueHrs IN ('0','0.00','0000','') AND @PayrollType NOT IN ('C', 'S') THEN '' ELSE RIGHT('0000' + REPLACE(TueHrs,'.',''),4) END
+ @Delim + CASE WHEN WedHrs IN ('0','0.00','0000','') AND @PayrollType NOT IN ('C', 'S') THEN '' ELSE RIGHT('0000' + REPLACE(WedHrs,'.',''),4) END
+ @Delim + CASE WHEN ThuHrs IN ('0','0.00','0000','') AND @PayrollType NOT IN ('C', 'S') THEN '' ELSE RIGHT('0000' + REPLACE(ThuHrs,'.',''),4) END
+ @Delim + CASE WHEN FriHrs IN ('0','0.00','0000','') AND @PayrollType NOT IN ('C', 'S') THEN '' ELSE RIGHT('0000' + REPLACE(FriHrs,'.',''),4) END
+ @Delim + CASE WHEN SatHrs IN ('0','0.00','0000','') AND @PayrollType NOT IN ('C', 'S') THEN '' ELSE RIGHT('0000' + REPLACE(SatHrs,'.',''),4) END
+ @Delim + CASE WHEN SunHrs IN ('0','0.00','0000','') AND @PayrollType NOT IN ('C', 'S') THEN '' ELSE RIGHT('0000' + REPLACE(SunHrs,'.',''),4) END
+ @Delim + RIGHT('0000' + REPLACE(CAST(TotalHrs AS VARCHAR),'.',''),CASE WHEN TotalHrs >= 100 THEN 5 ELSE 4 END)
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
+ @Delim + PayOnly
+ @Delim + BPO
+ @Delim + DisputedCode
,GroupCode,PayrollType
,SnapshotDateTime = GETDATE()
,TimeType
,IsGTS
FROM #tmpExport
)
SELECT
 SSN,EmployeeID,EmpName
,FileBreakID,weDate,AssignmentNo
,SiteNo,DeptNo
,Line1
,GroupCode,PayrollType
,SnapshotDateTime
,TimeType
,IsGTS
FROM cteResults
WHERE NewRankOrder IN (0,1);

DROP TABLE #tmpTHD;
DROP TABLE #tmpExport;
DROP TABLE #tmpAssignments;
DROP TABLE #tmpBaseData;

RETURN
