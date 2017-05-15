Create PROCEDURE [dbo].[usp_APP_GenericDataExtract_Peoplenet_DLT] (
@AgencyList VARCHAR(100),
@Client varchar(4),
@GroupCode int,
@PPED datetime) AS 

SET NOCOUNT ON 

CREATE TABLE #tmpSummary
(
    GroupCode				INT
  , SSN						INT          --Required in VB6: GenericPayrollUpload program
  , EN_RecordID				INT 
  , LastName				VARCHAR(50)
  , FirstName				VARCHAR(50)
  , PayrollPeriodEndDate	DATE        --Required in VB6: GenericPayrollUpload program
  , TransDate				DATE        --Required in VB6: GenericPayrollUpload program
  , AssignmentNo			VARCHAR(50)
  , AssignmentName			VARCHAR(100)
  , BillRate				NUMERIC(7, 2)
  , TxnCount				INT
  , ApprovedCount			INT 
  , DisputedCount			INT 
  , MinTHDRecordID			BIGINT  --< MinTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >-- 
  , Amount					NUMERIC(7, 2) -- Hours or Dollars  
  , HoursType				VARCHAR(10) -- REG|OT|DT
  , ApproverName			VARCHAR(40)
  , ApproverEmail			VARCHAR(132)
  , ApprovalDateTime		DATETIME
  , ApprovalStatus			VARCHAR(1)
)

INSERT INTO #tmpSummary
(
    GroupCode
  , SSN
  , EN_RecordID				
  , LastName				
  , FirstName				
  , PayrollPeriodEndDate	
  , TransDate				
  , AssignmentNo			
  , AssignmentName			
  , BillRate				
  , TxnCount				
  , ApprovedCount			
  , DisputedCount			
  , MinTHDRecordID			
  , Amount					
  , HoursType)
SELECT	GroupCode
	  , SSN
	  , EN_RecordID				
	  , LastName				
	  , FirstName				
	  , PayrollPeriodEndDate	
	  , TransDate				
	  , AssignmentNo			
	  , AssignmentName			
	  , BillRate				
	  , TxnCount				
	  , ApprovedCount			
	  , DisputedCount			
	  , MinTHDRecordID			
	  , Amount					
	  , HoursType
FROM (
		SELECT	en.GroupCode,
				en.SSN,
				en.RecordID AS EN_RecordID,
				en.LastName,
				en.FirstName,
				thd.PayrollPeriodEndDate,
				thd.TransDate,
				/*CASE	WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
						THEN CASE	WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
									THEN CASE	WHEN ISNULL(thd.CostID,'') = '' 
												THEN ''
												ELSE thd.costID 
												END 
									ELSE ed.AssignmentNo
									END 
						ELSE edh.AssignmentNo
						END AS AssignmentNo,*/
				CASE WHEN ed.RecordID IS NULL THEN ISNULL(ed_primary.RecordID, '') ELSE ed.RecordID END AS AssignmentNo,
				CASE WHEN ed.RecordID IS NULL THEN ISNULL(gd_primary.DeptName_Long, '') ELSE gd.DeptName_Long END AS AssignmentName,
				--gd.DeptName_Long AS AssignmentName,
				CASE WHEN ISNULL(edh.BillRate, 0) = 0 THEN ISNULL(ed.BillRate, 0) ELSE edh.BillRate END AS BillRate,
				SUM(1) AS TxnCount,
				SUM(CASE WHEN thd.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END) AS ApprovedCount,
				SUM(CASE WHEN thd.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END) AS DisputedCount,
				MIN(thd.RecordID) AS MinTHDRecordID,
				SUM(thd.RegHours) AS REG, 
				SUM(thd.OT_hours) AS OT,
				SUM(thd.DT_hours) AS DT,
				SUM(thd.Dollars) AS Dollars
		FROM TimeHistory.dbo.tblTimeHistDetail thd
		INNER JOIN TimeCurrent.dbo.tblEmplNames en
		ON en.Client = thd.Client
		AND en.GroupCode = thd.GroupCode
		AND en.SSN = thd.SSN
		LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
		ON  ed.Client = thd.Client
		AND	ed.GroupCode = thd.GroupCode
		AND	ed.SSN = thd.SSN
		AND ed.Department = thd.DeptNo
		LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed_primary
		ON  ed_primary.Client = thd.Client
		AND	ed_primary.GroupCode = thd.GroupCode
		AND	ed_primary.SSN = thd.SSN
		AND ed_primary.Department = en.PrimaryDept
		INNER JOIN TimeCurrent.dbo.tblGroupDepts gd
		ON gd.Client = thd.Client
		AND gd.GroupCode = thd.GroupCode
		AND gd.DeptNo = thd.DeptNo
		LEFT JOIN TimeCurrent.dbo.tblGroupDepts gd_primary
		ON gd_primary.Client = ed_primary.Client
		AND gd_primary.GroupCode = ed_primary.GroupCode
		AND gd_primary.DeptNo = ed_primary.Department
		LEFT JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
		ON  edh.Client = thd.Client
		AND edh.GroupCode = thd.GroupCode
		AND edh.PayrollPeriodenddate = thd.PayrollPeriodenddate
		AND edh.SSN = thd.SSN
		AND edh.Department = thd.DeptNo
		INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
		ON ac.Client = thd.Client
		AND ac.GroupCode = thd.GroupCode
		AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', ' ') THEN '1' ELSE thd.ClockAdjustmentNo END
		WHERE thd.Client = @Client
		AND thd.GroupCode = @GroupCode
		AND thd.PayrollPeriodEndDate = @PPED
		AND TimeCurrent.dbo.fn_InCSV(@AgencyList, en.AgencyNo, 1) = 1
		AND ac.Worked = 'Y'
		GROUP BY en.GroupCode,
				en.SSN,
				en.FileNo,
				en.RecordID,
				en.LastName,
				en.FirstName,
				thd.PayrollPeriodEndDate,
				thd.TransDate,
				/*CASE	WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
						THEN CASE	WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
									THEN CASE	WHEN ISNULL(thd.CostID,'') = '' 
												THEN ''
												ELSE thd.costID 
												END 
									ELSE ed.AssignmentNo
									END 
						ELSE edh.AssignmentNo
						END,*/
				CASE WHEN ed.RecordID IS NULL THEN ISNULL(ed_primary.RecordID, '') ELSE ed.RecordID END,
				CASE WHEN ed.RecordID IS NULL THEN ISNULL(gd_primary.DeptName_Long, '') ELSE gd.DeptName_Long END,
				--gd.DeptName_Long ,
				CASE WHEN ISNULL(edh.BillRate, 0) = 0 THEN ISNULL(ed.BillRate, 0) ELSE edh.BillRate END) AS tmp
UNPIVOT
    (Amount FOR HoursType IN (Reg, OT, DT, Dollars)) AS unpvt
WHERE Amount <> 0

UPDATE t
    SET t.ApproverName = isnull(CASE WHEN bkp.RecordId IS NOT NULL
                                       THEN bkp.LastName + '; ' + bkp.FirstName  
                                       ELSE usr.LastName + '; ' + usr.FirstName  
                                  END, '')
      ,t.ApproverEmail =  isnull(CASE WHEN bkp.RecordId IS NOT NULL
                                        THEN bkp.Email
                                        ELSE usr.Email
                                  END, '')
      ,t.ApprovalDateTime = case when THD.AprvlStatus_Date IS NULL then NULL else thd.AprvlStatus_Date end 
FROM #tmpSummary t
INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS THD
    ON THD.RecordID = t.MinTHDRecordID
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval AS bkp
    ON bkp.THDRecordId = t.MinTHDRecordID
LEFT JOIN TimeCurrent.dbo.tblUser AS usr
    ON usr.UserID = ISNULL(THD.AprvlStatus_UserID, 0)

UPDATE #tmpSummary
SET ApprovalStatus = CASE	WHEN DisputedCount > 0 THEN 2
							WHEN ApprovedCount = TxnCount THEN 1 
							ELSE 0 END

update #tmpSummary
SET MinTHDRecordID = (	SELECT MIN (MinTHDRecordID)
						FROM #tmpSummary t2
						WHERE t2.GroupCode = t1.GroupCode
						AND t2.SSN = t1.SSN
						AND t2.PayrollPeriodEndDate = t1.PayrollPeriodEndDate
						AND t2.AssignmentNo = t1.AssignmentNo)
FROM #tmpSummary t1

/*
•	EmplID – this is a unique ID for the employee and can just be a record ID. Used by DLT to uniquely identify the employee between files. 
•	LastName
•	FirstName
•	AssignmentNo – this is a unique ID for the “assignment” and can just be a record ID. Used by DLT to uniquely identify the assignment between files.
•	AssignmentName
•	WeekEndingDate
•	TimeEntryDate
•	TimeCode
•	Amount
•	BillRate
•	ApprovalStatus
•	ApprovedDateTime
•	Timesheet ID – Time card id? Can be a record ID. This is used as a reference number to a specific time card by the customer for audit purposes. 
*/
DECLARE @DoubleQuote VARCHAR(1) = '"',
@Delimeter VARCHAR(1) = ','


SELECT	  'EmplID' + @Delimeter 
		+ 'LastName' + @Delimeter
		+ 'FirstName' + @Delimeter
		+ 'AssignmentNo' + @Delimeter
		+ 'AssignmentName' + @Delimeter
		+ 'WeekEndingDate' + @Delimeter
		+ 'TimeEntryDate' + @Delimeter
		+ 'TimeCode' + @Delimeter
		+ 'Amount' + @Delimeter
		+ 'BillRate' + @Delimeter
		+ 'ApprovalStatus' + @Delimeter
		+ 'ApprovedDateTime' + @Delimeter
		+ 'TimesheetID' AS LineOut
		, 0 AS SortOrder
	  ,	GroupCode = 0
	  , SSN = 0
	  , EN_RecordID = 0
	  , LastName = ''
	  , FirstName = ''
	  , PayrollPeriodEndDate = '1/1/1900'
	  , TransDate = '1/1/1900'
	  , AssignmentNo = ''
	  , AssignmentName = ''
	  , BillRate = 0
	  , TxnCount = 0
	  , ApprovedCount = 0 
	  , DisputedCount = 0
	  , MinTHDRecordID = 0 
	  , Amount = 0  
	  , HoursType = ''
	  , ApproverName = ''
	  , ApproverEmail = ''
	  , ApprovalDateTime = '1/1/1900'
	  , ApprovalStatus = ''
UNION
SELECT	TimeHistory.dbo.fn_WrapVarChar(EN_RecordID, @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(LastName, @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(FirstName, @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(AssignmentNo, @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(AssignmentName, @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(CONVERT(VARCHAR, PayrollPeriodEndDate, 101), @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(CONVERT(VARCHAR, TransDate, 101), @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(HoursType, @DoubleQuote) + @Delimeter +
		CAST(Amount AS VARCHAR) + @Delimeter +
		CAST(BillRate AS VARCHAR) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(ApprovalStatus, @DoubleQuote) + @Delimeter +
		TimeHistory.dbo.fn_WrapVarChar(ISNULL(CONVERT(VARCHAR, ApprovalDateTime, 101), '') + ' ' + ISNULL(CONVERT(VARCHAR(12), ApprovalDateTime, 108), '') + RIGHT(ISNULL(CONVERT(VARCHAR, ApprovalDateTime, 109), ''), 2), @DoubleQuote) + @Delimeter +
		CAST(MinTHDRecordID AS VARCHAR) AS LineOut
		, 1 AS SortOrder, *
FROM #tmpSummary
ORDER BY SortOrder, GroupCode, SSN, TransDate, AssignmentNo

DROP TABLE #tmpSummary

--SELECT * FROM timehistory..tbltimehistdetail WHERE RecordID = 1291167097
