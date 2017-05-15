Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_SNES_Clock]
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
  , ClockAdjustmentNo     VARCHAR(1)
  , TransDate             DATETIME
  , MinTHDRecordID        BIGINT   --< MinTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 10Aug2016 >--
  , Total                 NUMERIC(7, 2) -- Hours or Dollars  
  , HoursType             VARCHAR(10) -- REG|OT|DT
  , ApproverName          VARCHAR(40)
  , ApproverEmail         VARCHAR(132)
  , ApprovalDateTime      VARCHAR(50)  --format is: YYYYMMDD HH:MM  
  , DisputeCount          INT 
  , TimeSheetID			  INT
  , ClientDeptCode2		  VARCHAR(100)
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
  , ApprovalDateTime  VARCHAR(21)  --format is: YYYYMMDD HH:MM
  , TimeSource    VARCHAR(30)
  , ApprovalSource VARCHAR(30)  
  , PayCode       VARCHAR(32)
  , WorkedHours   NUMERIC(7,2)
  , PayAmount     NUMERIC(7,2)
  , BillAmount    NUMERIC(7,2)  
  , Line1         VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
  , LateApprovals     VARCHAR(1)            
  , FileBreakID   VARCHAR(20)  --The VB6: GenericPayrollUpload program will split apart payfiles on PayGroup from TimeCurrent.dbo.tbl_EmplNames  
  , TimeSheetID			  INT
  , ClientDeptCode2		  VARCHAR(100)
  , MinTHDRecordID		  BIGINT  --< MinRecordId data type is changed from  INT to BIGINT by Srinsoft on 10Aug2016 >--
)


INSERT into #tmpSummary ( Client, GroupCode, SSN, PayrollPeriodEndDate, 
                          AssignmentNo, 
                          ClockAdjustmentNo, TransDate, MinTHDRecordID,
                          Total, HoursType, ApproverName, ApproverEmail, ApprovalDateTime, DisputeCount, ClientDeptCode2)
SELECT Client, GroupCode, SSN, PayrollPeriodEndDate, 
                          AssignmentNo, 
                          ClockAdjustmentNo, TransDate, MinTHDRecordID,
                          Total, HoursType, '' AS ApproverName, '' AS ApproverEmail, NULL AS ApprovalDateTime, DisputeCount, ClientDeptCode2
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
          , MinTHDRecordID = MIN(hd.RecordID)
          , SUM(RegHours) AS REG 
          , SUM(OT_hours) AS OT
          , SUM(DT_hours) AS DT
          , SUM(Dollars) AS Dollars
          , SUM(CASE WHEN hd.ClockAdjustmentNo IN ('@','$') THEN 1 ELSE 0 END) AS DisputeCount
		  , gd.ClientDeptCode2
          FROM TimeHistory.dbo.tblTimeHistDetail AS hd
		  INNER JOIN TimeCurrent..tblGroupDepts gd
			  ON gd.Client = hd.Client
			  AND gd.GroupCode = hd.GroupCode
			  AND gd.DeptNo = hd.DeptNo
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
		  , gd.ClientDeptCode2
      ) AS tmp
UNPIVOT
    (Total FOR HoursType IN (Reg, OT, DT, Dollars)) AS unpvt
WHERE Total <> 0

UPDATE #tmpSummary 
SET TimeSheetID = ( SELECT MAX(esd.RecordID)
					FROM TimeHistory..tblTimeHistDetail thd
					INNER JOIN TimeHistory..tblEmplSites_Depts esd
					ON esd.Client = thd.Client
					AND esd.GroupCode = thd.GroupCode
					AND esd.SSN = thd.SSN
					AND esd.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
					WHERE thd.RecordID = #tmpSummary.MinTHDRecordID
					)

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
					  , TimeSheetID
					  , ClientDeptCode2
					  , MinTHDRecordID)
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
    , ApprovalSource = 'W'
    , PayCode = CASE  WHEN s.HoursType = 'REG' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @REGPAYCODE 
                      WHEN s.HoursType = 'OT' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @OTPAYCODE 
                      WHEN s.HoursType = 'DT' AND ac.Worked = 'Y' AND ac.ClockAdjustmentNo IN ('1','$') THEN @DTPAYCODE 
                      ELSE CASE WHEN ISNULL(s.HoursType, '') = 'Dollars' THEN ac.ADP_EarningsCode ELSE ac.ADP_HoursCode END END            
    , WorkedHours = SUM(CASE WHEN ISNULL(s.HoursType, '') = 'Dollars' OR s.ClockAdjustmentNo = '$' THEN 0 ELSE ISNULL(s.Total, 0) END)
    , PayAmount = SUM(CASE WHEN ac.Payable = 'Y' THEN s.Total ELSE 0.0 END)
    , BillAmount = SUM(CASE WHEN ac.Billable = 'Y' THEN s.Total ELSE 0.0 END)
    , Line1 = ''
    , LateApprovals = ''   
    , '' AS FileBreakID
	, s.TimeSheetID
	, s.ClientDeptCode2
	, MIN(MinTHDRecordID)
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
                ELSE CASE WHEN ISNULL(s.HoursType, '') = 'Dollars' THEN ac.ADP_EarningsCode ELSE ac.ADP_HoursCode END END    
		, s.TimeSheetID
		, s.ClientDeptCode2
       
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 

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
	  ,t.ApprovalDateTime = case when THD.AprvlStatus_Date IS NULL then '' else ISNULL(CONVERT(VARCHAR(10), thd.AprvlStatus_Date, 101), '') + ' ' + ISNULL(CONVERT(VARCHAR(12), thd.AprvlStatus_Date, 108), '') + RIGHT(ISNULL(CONVERT(VARCHAR, thd.AprvlStatus_Date, 109), ''), 2) end 	  
FROM #tmpExport t
INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS THD
    ON THD.RecordID = t.MinTHDRecordID
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval AS bkp
    ON bkp.THDRecordId = t.MinTHDRecordID
LEFT JOIN TimeCurrent.dbo.tblUser AS usr
    ON usr.UserID = ISNULL(THD.AprvlStatus_UserID, 0)

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
SET Line1 = TimeHistory.dbo.fn_PadVarchar('T', 1) + 
			TimeHistory.dbo.fn_PadVarchar(ISNULL(en.FirstName, ''), 20) +  
            TimeHistory.dbo.fn_PadVarchar(ISNULL(en.LastName, ''), 20) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(en.FileNo, ''), 20) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.AssignmentNo, ''), 32) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT(VARCHAR(10), ISNULL(e.PayrollPeriodEndDate, ' '), 101), ''), 10) + 
            TimeHistory.dbo.fn_PadVarchar(CONVERT(VARCHAR(10), ISNULL(e.TransDate, ' '), 101), 10) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT (VARCHAR(8), e.WorkedHours), ''), 8) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.Paycode, ''), 10) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT (VARCHAR(8), e.PayAmount), ' '), 8) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT (VARCHAR(8), e.BillAmount), ' '), 8) + 
            TimeHistory.dbo.fn_PadVarchar('', 32)  +  -- Project Code            
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.ApproverName, ''), 40) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.ApproverEmail, ''), 132) + 
            TimeHistory.dbo.fn_PadVarchar(e.ApprovalDateTime, 21) + 
            TimeHistory.dbo.fn_PadVarchar('', 10) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.TimeSource, ''), 1) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.ApprovalSource, ''), 1) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.TimeSheetID, ''), 12) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(e.ApprovalStatus, ''), 1) + 
			TimeHistory.dbo.fn_PadVarchar(ISNULL(e.ClientDeptCode2, ''), 100) -- Department (clocks only)
   , EmployeeID = en.FileNo
   , EmpName = en.LastName + ', ' +  en.FirstName
   , FileBreakID = ISNULL(en.PayGroup, '')
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
ORDER BY EmployeeID
		,AssignmentNo
		,PayrollPeriodEndDate
		,TransDate
		,CASE WHEN Paycode = @REGPAYCODE THEN 1 WHEN Paycode = @OTPAYCODE THEN 2 WHEN Paycode = @DTPayCode THEN 3 ELSE 5 END
		
                      
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
