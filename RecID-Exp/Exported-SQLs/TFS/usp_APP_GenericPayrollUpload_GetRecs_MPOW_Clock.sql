Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_MPOW_Clock]
(
  @Client       varchar(4),
  @GroupCode    int,
  @PPED         datetime,
  @PAYRATEFLAG  varchar(4),
  @EMPIDType    varchar(6),
  @REGPAYCODE   varchar(10),
  @OTPAYCODE    varchar(10),
  @DTPAYCODE    varchar(10),
  @PayrollType  varchar(32),
  @IncludeSalary char(1),
  @TestingFlag   char(1) = 'N'
)
AS

SET NOCOUNT ON

DECLARE @PayrollFreq    CHAR(1)
DECLARE @PPED2          DATETIME
DECLARE @Delim          CHAR(1)
DECLARE @Today          DATETIME

SELECT @Today = GETDATE()

Set @Delim = '|'

if @TestingFlag = 'N'
BEGIN
	Exec usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'N'
	if @@error <> 0 
	   return
END

/*  all time gathered here comes from clock (virtual or physical)
  SourceTime values:
        W = web time entry
        I = IVR
        F = Fax-a-roo
        B = Group Time Sheet Branch
        S = Group Time Sheet Sub-vendor
        D = Group Time Sheet Client
        P = PeopleNet Dashboard
        M = Mobile App.
        C = Clock (physical devices)
        X = Interface
        
    SourceApprove Values:        
        W = Web (includes email)
        P = PeopleNet Dashboard
        M = Mobile App.
        F = Fax approval (ASAP)

*/

CREATE TABLE #tmpSummary
(
    Client                VARCHAR(4)
  , GroupCode             INT
  , SSN                   INT          --Required in VB6: GenericPayrollUpload program
  , PayrollPeriodEndDate  DATETIME     --Required in VB6: GenericPayrollUpload program
  , AssignmentNo          VARCHAR(32)
  , ClockAdjustmentNo     VARCHAR(3)   -- Changed ClockAdjustmentNo VARCHAR(1) VARCHAR(3) for #tmpSummary
  , TransDate             DATETIME
  , MaxTHDRecordID        BIGINT  --< MaxTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
  , Total                 NUMERIC(7, 2) -- Hours or Dollars  
  , HoursType             VARCHAR(10) -- REG|OT|DT
  , ApproverName          VARCHAR(40)
  , ApproverEmail         VARCHAR(132)
  , ApprovalDateTime      VARCHAR(14)  --format is: YYYYMMDD HH:MM  
  , DisputeCount          INT 
)

CREATE TABLE #tmpExport
(
    Client        VARCHAR(4)
  , GroupCode     INT
  , PayrollPeriodEndDate DATETIME
  , weDate            VARCHAR(10)  
  , SSN           INT          --Required in VB6: GenericPayrollUpload program
  , EmployeeID    VARCHAR(20)  --Required in VB6: GenericPayrollUpload program
  , EmpName       VARCHAR(120) --Required in VB6: GenericPayrollUpload program
  , SiteNo        INT
  , DeptNo        INT
  , AssignmentNo  VARCHAR(50)
  , TransDate     DATETIME
  , SnapshotDateTime  DATETIME
  , AttachmentName    VARCHAR(200)
  , WorkState         VARCHAR(2)
  , ApproverName  VARCHAR(40)
  , ApproverEmail VARCHAR(132)
  , ApprovalStatus    CHAR(1)
  , ApprovalDateTime  VARCHAR(14)  --format is: YYYYMMDD HH:MM
  , TimeSource    VARCHAR(30)
  , ApprovalSource VARCHAR(30)  
  , PayCode       VARCHAR(32)
  , WorkedHours   NUMERIC(7,2)
  , PayAmount     NUMERIC(7,2)
  , BillAmount    NUMERIC(7,2)  
  , Line1         VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
  , LateApprovals     VARCHAR(1)            
  , FileBreakID   VARCHAR(20)  --The VB6: GenericPayrollUpload program will split apart payfiles on PayGroup from TimeCurrent.dbo.tbl_EmplNames  
  , CRF1_Name         VARCHAR(50) DEFAULT ''
  , CRF1_Value        VARCHAR(512) DEFAULT ''
  , CRF2_Name         VARCHAR(50) DEFAULT ''
  , CRF2_Value        VARCHAR(512) DEFAULT ''
  , CRF3_Name         VARCHAR(50) DEFAULT ''
  , CRF3_Value        VARCHAR(512) DEFAULT ''
  , CRF4_Name         VARCHAR(50) DEFAULT ''
  , CRF4_Value        VARCHAR(512) DEFAULT ''
  , CRF5_Name         VARCHAR(50) DEFAULT ''
  , CRF5_Value        VARCHAR(512) DEFAULT ''
  , CRF6_Name         VARCHAR(50) DEFAULT ''
  , CRF6_Value        VARCHAR(512) DEFAULT ''  
  , VendorReferenceID VARCHAR(100) 
)


INSERT into #tmpSummary ( Client, GroupCode, SSN, PayrollPeriodEndDate, 
                          AssignmentNo, 
                          ClockAdjustmentNo, TransDate, MaxTHDRecordID,
                          Total, HoursType, ApproverName, ApproverEmail, ApprovalDateTime, DisputeCount)
SELECT Client, GroupCode, SSN, PayrollPeriodEndDate, 
                          AssignmentNo, 
                          ClockAdjustmentNo, TransDate, MaxTHDRecordID,
                          Total, HoursType, '' AS ApproverName, '' AS ApproverEmail, NULL AS ApprovalDateTime, DisputeCount
FROM (
      SELECT 	
            Client = hd.Client
          , GroupCode = hd.GroupCode
          , SSN = hd.ssn
          , hd.Payrollperiodenddate
          , AssignmentNo = CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                  THEN CASE WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
                                            THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                      THEN 'MISSING' 
                                                      ELSE hd.costID 
                                                 END 
                                            ELSE ed.AssignmentNo
                                       END 
                                  ELSE edh.AssignmentNo
                             END
          , ClockAdjustmentNo = CASE WHEN ISNULL(hd.ClockAdjustmentNo, '') IN ('', '8', '@') THEN '1' ELSE hd.ClockAdjustmentNo END
          , TransDate = hd.TransDate          
          , MaxTHDRecordID = MAX(hd.RecordID)
          , SUM(RegHours) AS REG 
          , SUM(OT_hours) AS OT
          , SUM(DT_hours) AS DT
          , SUM(Dollars) AS Dollars
          , SUM(CASE WHEN hd.ClockAdjustmentNo IN ('@','$') THEN 1 ELSE 0 END) AS DisputeCount
          FROM TimeHistory.dbo.tblTimeHistDetail AS hd
          LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed
              ON	ed.Client = hd.Client
              AND	ed.GroupCode = hd.GroupCode
              AND	ed.SSN = hd.SSN
              AND ed.Department = hd.DeptNo
          LEFT JOIN TimeHistory.dbo.tblEmplNames_Depts AS edh
              ON	edh.Client = hd.Client
              AND	edh.GroupCode = hd.GroupCode
              AND	edh.SSN = hd.SSN
              AND edh.Department = hd.DeptNo
              AND edh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
          WHERE	hd.Client = @Client 
              AND hd.GroupCode = @GroupCode 
              AND	hd.PayrollPeriodEndDate = @PPED
          GROUP BY 
            hd.Client
          , hd.GroupCode
          , hd.ssn
          , hd.Payrollperiodenddate
          , CASE WHEN LTRIM(ISNULL(edh.AssignmentNo, '')) = '' 
                                  THEN CASE WHEN LTRIM(ISNULL(ed.AssignmentNo, '')) = '' 
                                            THEN CASE WHEN ISNULL(hd.CostID, '') = '' 
                                                      THEN 'MISSING' 
                                                      ELSE hd.costID 
                                                 END 
                                            ELSE ed.AssignmentNo
                                       END 
                                  ELSE edh.AssignmentNo
                             END
          , hd.ClockAdjustmentNo
          , hd.TransDate
      ) AS tmp
UNPIVOT
    (Total FOR HoursType IN (Reg, OT, DT, Dollars)) AS unpvt
WHERE Total <> 0

-- Set Approver information.
--
UPDATE t
    SET t.ApproverName = isnull(CASE WHEN bkp.RecordId IS NOT NULL
                                       THEN bkp.LastName + '; ' + bkp.FirstName  
                                       ELSE (CASE   WHEN LEN(t.ApproverName) < 2
                                                    THEN usr.LastName + '; ' + usr.FirstName  
                                                    ELSE t.ApproverName
                                             END)
                                  END,'')
      ,t.ApproverEmail =  isnull(CASE WHEN bkp.RecordId IS NOT NULL
                                        THEN bkp.Email
                                        ELSE(CASE   WHEN LEN(t.ApproverEmail) < 2
                                                    THEN usr.Email
                                                    ELSE t.ApproverEmail
                                             END) 
                                  END,'')
      ,t.ApprovalDateTime = case when THD.AprvlStatus_Date IS NULL then '' else REPLACE(convert(varchar(16), thd.AprvlStatus_Date, 112), '-', '') end 
FROM #tmpSummary t
INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS THD
    ON THD.RecordID = t.MaxTHDRecordID
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval AS bkp
    ON bkp.THDRecordId = t.MaxTHDRecordID
LEFT JOIN TimeCurrent.dbo.tblUser AS usr
    ON usr.UserID = ISNULL(THD.AprvlStatus_UserID, 0)

INSERT into #tmpExport (Client
                      , GroupCode
                      , PayrollPeriodEndDate
                      , weDate
                      , SSN
                      , EmployeeID
                      , EmpName
                      , SiteNo
                      , DeptNo
                      , AssignmentNo
                      , TransDate
                      , SnapshotDateTime
                      , AttachmentName
                      , WorkState
                      , ApproverName
                      , ApproverEmail
                      , ApprovalStatus
                      , ApprovalDateTime
                      , TimeSource
                      , ApprovalSource
                      , PayCode
                      , WorkedHours
                      , PayAmount
                      , BillAmount
                      , Line1
                      , LateApprovals
                      , FileBreakID
                      , CRF1_Name, CRF1_Value
                      , CRF2_Name, CRF2_Value
                      , CRF3_Name, CRF3_Value
                      , CRF4_Name, CRF4_Value
                      , CRF5_Name, CRF5_Value
                      , CRF6_Name, CRF6_Value)
SELECT
      s.Client      
    , s.GroupCode
    , s.PayrollPeriodEndDate
    , weDate = CONVERT(VARCHAR(8), s.Payrollperiodenddate, 112)
    , s.ssn
    , '' AS EmployeeID 
    , '' AS EmpName
    , 0 AS SiteNo
    , 0 AS DeptNo  
    , AssignmentNo = s.AssignmentNo
    , s.TransDate
    , GETDATE() AS SnapshotDateTime
    , '' AS AttachmentName
    , '' AS WorkState
    , s.ApproverName
    , s.ApproverEmail
    , ApprovalStatus = SUM(CASE WHEN s.ApproverName <> '' THEN 1 ELSE 0 END)
    , s.ApprovalDateTime
    , TimeSource = 'C'
    , ApprovalSource = ''
    , PayCode = CASE  WHEN s.HoursType = 'REG' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @REGPAYCODE 
                      WHEN s.HoursType = 'OT' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @OTPAYCODE 
                      WHEN s.HoursType = 'DT' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @DTPAYCODE 
                      ELSE ac.ADP_HoursCode END            
    , WorkedHours = SUM(CASE WHEN ISNULL(s.HoursType, '') = 'Dollars' OR s.ClockAdjustmentNo = '$' THEN 0 ELSE ISNULL(s.Total, 0) END)
    , PayAmount = SUM(CASE WHEN ac.Payable = 'Y' THEN s.Total ELSE 0.0 END)
    , BillAmount = SUM(CASE WHEN ac.Billable = 'Y' THEN s.Total ELSE 0.0 END)
    , Line1 = ''
    , LateApprovals = ''   
    , '' AS FileBreakID
    , '', ''    
    , '', ''
    , '', ''
    , '', ''
    , '', ''
    , '', ''
FROM #tmpSummary s
INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
ON ac.Client = s.Client
AND	ac.GroupCode = s.GroupCode
AND	ac.ClockAdjustmentNo = s.ClockAdjustmentNo
GROUP BY 
          s.Client
        , s.GroupCode
        , s.PayrollPeriodEndDate
        , s.ssn
        , s.AssignmentNo
        , s.TransDate
        --, ac.AdjustmentType 
        , s.ApproverName
        , s.ApproverEmail
        , s.ApprovalDateTime    
        , CASE  WHEN s.HoursType = 'REG' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @REGPAYCODE 
                WHEN s.HoursType = 'OT' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @OTPAYCODE 
                WHEN s.HoursType = 'DT' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @DTPAYCODE 
                ELSE ac.ADP_HoursCode END    
       
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 

UPDATE #tmpExport
SET ApprovalStatus = 1
WHERE ApprovalStatus > 1

UPDATE e
SET ApprovalStatus = 2
FROM #tmpExport e
INNER JOIN #tmpSummary s
ON s.Client = e.Client
AND s.GroupCode = e.GroupCode
AND s.PayrollPeriodEndDate = e.PayrollPeriodEndDate
AND s.SSN = e.SSN
AND s.AssignmentNo = e.AssignmentNo
AND s.DisputeCount > 0
WHERE e.ApprovalStatus = 1

UPDATE e
SET Line1 = '"' + en.FirstName + '"' + @Delim 
          + '"' + en.LastName + '"' + @Delim
          + '"' + en.FileNo + '"' + @Delim
          + '"' + e.AssignmentNo + '"' + @Delim
          + weDate + @Delim
          + CONVERT(VARCHAR(8),ISNULL(e.TransDate, ' '), 112) + @Delim
          + CONVERT (VARCHAR(8), WorkedHours) + @Delim
          + '"' + Paycode + '"' + @Delim
          + CONVERT (VARCHAR(8), PayAmount)  + @Delim
          + CONVERT (VARCHAR(8), BillAmount) + @Delim
          + ''  + @Delim -- Project Code
          + '"' + ApproverName + '"' + @Delim
          + '"' + ApproverEmail + '"' + @Delim
          + CONVERT(VARCHAR(8), e.ApprovalDateTime, 112) + @Delim
          + '"' + 'MP' /*PayFileGroup*/ + '"' + @Delim
          + '"' + TimeSource + '"' + @Delim
          + '"' + ApprovalSource + '"' + @Delim
          + @Delim -- TimeSheetID  -------------------- FIX
          + ApprovalStatus + @Delim
          + '""' + @Delim + '""' + @Delim -- CRF1
          + '""' + @Delim + '""' + @Delim -- CRF2
          + '""' + @Delim + '""' + @Delim -- CRF3
          + '""' + @Delim + '""' + @Delim -- CRF4
          + '""' + @Delim + '""' + @Delim -- CRF5
          + '""' + @Delim + '""'  -- CRF6
   , EmployeeID = en.FileNo
   , EmpName = en.LastName + ', ' +  en.FirstName
   , FileBreakID = ISNULL(en.PayGroup, '')
   , VendorReferenceID = ''
FROM #tmpExport e
INNER JOIN TimeCurrent..tblEmplNames en
ON en.Client = e.Client
AND en.GroupCode = e.GroupCode
AND en.SSN = e.SSN

UPDATE #tmpExport  
SET EmployeeID = '' 
WHERE AssignmentNo = 'MISSING'

SELECT * 
FROM #tmpExport 
ORDER BY CASE WHEN AssignmentNo = 'MISSING'
              THEN '0' 
              ELSE '1' 
         END
       , EMPNAME
       , TransDate
       , PayCode
                      
IF (@TestingFlag IN ('N', '0') )
BEGIN
  UPDATE TimeHistory.dbo.tblEmplNames
  SET TimeHistory.dbo.tblEmplNames.PayRecordsSent = @Today
  FROM TimeHistory.dbo.tblEmplNames en
  INNER JOIN #tmpExport tmp
  ON en.Client = tmp.Client
  AND en.GroupCode = tmp.GroupCode
  AND en.PayrollPeriodEndDate = tmp.weDate
  AND en.SSN = tmp.SSN
END
           
DROP TABLE #tmpExport
RETURN
