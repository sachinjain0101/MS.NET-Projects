CREATE PROCEDURE [dbo].[usp_APP_GenericDataExtract_PNETClockPayfile_PPED]
(
 @Client VARCHAR(4)
,@GroupCode INT
,@PPED DATETIME
) AS

SET NOCOUNT ON;
DECLARE
 @EMPIDType VARCHAR(6) = 'FileNo'
,@REGPAYCODE VARCHAR(10) = 'REG'
,@OTPAYCODE VARCHAR(10) = 'OT'
,@DTPAYCODE VARCHAR(10) = 'DT'
,@PayrollFreq CHAR(1)
,@PPED2 DATE
,@Delim CHAR(1) = '|'
,@WEDate DATE = DATEADD(WEEK,-1,TimeCurrent.dbo.fn_GetNextDaysDate(GETDATE(),1));  --Previous Sunday

-- First check to see if this is bi-weekly.
SELECT @PayrollFreq = PayrollFreq
FROM TimeCurrent..tblClientGroups 
WHERE client = @Client 
AND GroupCode = @GroupCode;

IF @PayrollFreq = 'B' 
	BEGIN
		SET @PPED2 = DATEADD(DD,-7,@WEDate);
	END

CREATE TABLE #tmpExport
(
    SSN           INT          --Required in VB6: GenericPayrollUpload program
  , EmployeeID    VARCHAR(20)  --Required in VB6: GenericPayrollUpload program
  , EmpName       VARCHAR(120) --Required in VB6: GenericPayrollUpload program
  , FileBreakID   VARCHAR(20)  --The VB6: GenericPayrollUpload program will split apart payfiles on PayGroup from TimeCurrent.dbo.tbl_EmplNames
  , weDate        VARCHAR(8)   --Required in VB6: GenericPayrollUpload program
  , AssignmentNo  VARCHAR(32)
  , PayCode       VARCHAR(32)
  , PayAmount     NUMERIC(7,2)
  , BillAmount    NUMERIC(7,2)
  , SourceTime    VARCHAR(30)
  , SourceApprove VARCHAR(30)
  , EmplFirst     VARCHAR(20)
  , EmplLast      VARCHAR(20)
  , TransactDate  VARCHAR(8)
  , ProjectCode   VARCHAR(32)
  , ApproverName  VARCHAR(40)
  , ApproverEmail VARCHAR(132)
  , ApprovalDate  VARCHAR(14)  --format is: YYYYMMDD HH:MM
  , PayFileGroup  VARCHAR(10)
  , PayBillCode   VARCHAR(10)
  , RecordID      BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 04Aug2016 >--
  , AmountType    CHAR(1)       -- Hours, Dollars, etc. ( Units )
  , LineOut       VARCHAR(2000) --Required in VB6: GenericPayrollUpload program
	, DeptCode			VARCHAR(100)
	, DeptName			VARCHAR(50)
	, PayRate				NUMERIC(7,2)
	, BillRate			NUMERIC(7,2)
	, ShiftNo				VARCHAR(3)
)

--regular hours worked
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' THEN @REGPAYCODE
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [PayAmount] = SUM( CASE WHEN [ac].Payable ='Y'
                              THEN [hd].RegHours
                              ELSE 0.0
                         END )
    , [BillAmount] =SUM( CASE WHEN [ac].Billable ='Y'
                              THEN [hd].RegHours
                              ELSE 0.0
                         END )                             
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(8), [hd].[TransDate], 112)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = Max([hd].[RecordID])
    , ac.AdjustmentType 
    , [LineOut]=''
		, DeptCode = GD.ClientDeptCode
		, DeptName = GD.DeptName_Long
		, PayRate	 = [hd].PayRate
		, BillRate = [hd].BillRate
		, ShiftNo =  [hd].ShiftNo
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        Left JOIN TimeHistory.[dbo].[tblEmplNames_Depts] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
        INNER JOIN [TimeHistory]..tblEmplNames as enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN IsNull([hd].ClockAdjustmentNo, '') IN ('', '8') then '1' else [hd].ClockAdjustmentNo END
				INNER JOIN TimeCurrent.dbo.tblGroupDepts GD
						ON GD.Client = hd.Client
						AND GD.GroupCode = hd.GroupCode
						AND GD.DeptNo = hd.DeptNo
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@WEDate, @PPED2)
        AND [hd].RegHours <> 0.00
        AND [ac].[Worked]='Y'
     GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ac.AdjustmentType
		, GD.ClientDeptCode
		, GD.DeptName_Long
		, [hd].PayRate
		, [hd].BillRate
		, [hd].ShiftNo

--regular hours not worked (vacation, pto, sick, holiday, etc.)
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [PayAmount] = SUM( CASE WHEN [ac].Payable ='Y'
                              THEN [hd].RegHours
                              ELSE 0.0
                         END )
    , [BillAmount] =SUM( CASE WHEN [ac].Billable ='Y'
                              THEN [hd].RegHours
                              ELSE 0.0
                         END )                             
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(8), [hd].[TransDate], 112)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = MAX([hd].[RecordID])
    , ac.AdjustmentType 
    , [LineOut]=''
		, DeptCode = GD.ClientDeptCode
		, DeptName = GD.DeptName_Long
		, PayRate	 = [hd].PayRate
		, BillRate = [hd].BillRate
		, ShiftNo =  [hd].ShiftNo
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        Left JOIN TimeHistory.[dbo].[tblEmplNames_Depts] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
        INNER JOIN [TimeHistory]..tblEmplNames as enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN IsNull([hd].ClockAdjustmentNo, '') IN ('', '8') then '1' else [hd].ClockAdjustmentNo END
				INNER JOIN TimeCurrent.dbo.tblGroupDepts GD
						ON GD.Client = hd.Client
						AND GD.GroupCode = hd.GroupCode
						AND GD.DeptNo = hd.DeptNo
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@WEDate, @PPED2)
        AND [hd].RegHours <> 0.00
        AND [ac].[Worked]<>'Y'
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ac.AdjustmentType
		, GD.ClientDeptCode
		, GD.DeptName_Long
		, [hd].PayRate
		, [hd].BillRate
		, [hd].ShiftNo

-- Get the Overtime hours
INSERT INTO #tmpExport
SELECT
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo] 
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' THEN @OTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [PayAmount] = SUM( CASE WHEN [ac].Payable ='Y'
                              THEN [hd].[OT_Hours]
                              ELSE 0.0
                         END )
    , [BillAmount] =SUM( CASE WHEN [ac].Billable ='Y'
                              THEN [hd].[OT_Hours]
                              ELSE 0.0
                         END )                             
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(8), [hd].[TransDate], 112)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
    , [LineOut]=''
		, DeptCode = GD.ClientDeptCode
		, DeptName = GD.DeptName_Long
		, PayRate	 = [hd].PayRate
		, BillRate = [hd].BillRate
		, ShiftNo =  [hd].ShiftNo
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        Left JOIN TimeHistory.[dbo].[tblEmplNames_Depts] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
        INNER JOIN [TimeHistory]..tblEmplNames as enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN IsNull([hd].ClockAdjustmentNo, '') IN ('', '8') then '1' else [hd].ClockAdjustmentNo END
				INNER JOIN TimeCurrent.dbo.tblGroupDepts GD
						ON GD.Client = hd.Client
						AND GD.GroupCode = hd.GroupCode
						AND GD.DeptNo = hd.DeptNo
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@WEDate, @PPED2)
        AND [hd].[OT_Hours] <> 0.00
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' THEN @OTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ac.AdjustmentType
		, GD.ClientDeptCode
		, GD.DeptName_Long
		, [hd].PayRate
		, [hd].BillRate
		, [hd].ShiftNo
   
--Get DoubleTime hours
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo] 
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' THEN @DTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [PayAmount] = SUM( CASE WHEN [ac].Payable ='Y'
                              THEN [hd].[DT_Hours]
                              ELSE 0.0
                         END )
    , [BillAmount] =SUM( CASE WHEN [ac].Billable ='Y'
                              THEN [hd].[DT_Hours]
                              ELSE 0.0
                         END )                             
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(8), [hd].[TransDate], 112)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
    , [LineOut]=''
		, DeptCode = GD.ClientDeptCode
		, DeptName = GD.DeptName_Long
		, PayRate	 = [hd].PayRate
		, BillRate = [hd].BillRate
		, ShiftNo =  [hd].ShiftNo
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        Left JOIN TimeHistory.[dbo].[tblEmplNames_Depts] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
        INNER JOIN [TimeHistory]..tblEmplNames as enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN IsNull([hd].ClockAdjustmentNo, '') IN ('', '8') then '1' else [hd].ClockAdjustmentNo END
				INNER JOIN TimeCurrent.dbo.tblGroupDepts GD
						ON GD.Client = hd.Client
						AND GD.GroupCode = hd.GroupCode
						AND GD.DeptNo = hd.DeptNo
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@WEDate, @PPED2)
        AND [hd].[DT_Hours] <> 0.00
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN @DTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ac.AdjustmentType
		, GD.ClientDeptCode
		, GD.DeptName_Long
		, [hd].PayRate
		, [hd].BillRate
		, [hd].ShiftNo

--Get Dollars if applicable        
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo] 
                       END
    , [PayCode] = ac.ADP_EarningsCode
    , [PayAmount] = SUM( CASE WHEN [ac].Payable ='Y'
                              THEN [hd].[Dollars]
                              ELSE 0.0
                         END )
    , [BillAmount] =SUM( CASE WHEN [ac].Billable ='Y'
                              THEN [hd].[Dollars]
                              ELSE 0.0
                         END )                             
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(8), [hd].[TransDate], 112)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
    , [LineOut]=''
		, DeptCode = GD.ClientDeptCode
		, DeptName = GD.DeptName_Long
		, PayRate	 = [hd].PayRate
		, BillRate = [hd].BillRate
		, ShiftNo =  [hd].ShiftNo
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        Left JOIN TimeHistory.[dbo].[tblEmplNames_Depts] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
        INNER JOIN [TimeHistory]..tblEmplNames as enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN IsNull([hd].ClockAdjustmentNo, '') IN ('', '8') then '1' else [hd].ClockAdjustmentNo END
				INNER JOIN TimeCurrent.dbo.tblGroupDepts GD
						ON GD.Client = hd.Client
						AND GD.GroupCode = hd.GroupCode
						AND GD.DeptNo = hd.DeptNo
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@WEDate, @PPED2)
        AND [hd].[Dollars] <> 0.00
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , ac.ADP_EarningsCode
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ac.AdjustmentType
		, GD.ClientDeptCode
		, GD.DeptName_Long
		, [hd].PayRate
		, [hd].BillRate
		, [hd].ShiftNo
        
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 

UPDATE #tmpExport
    SET #tmpExport.ApproverName = isnull(CASE WHEN [bkp].[RecordId] IS NOT NULL
                                       THEN [bkp].[FirstName] + ' ' + [bkp].[LastName]
                                       ELSE (CASE   WHEN LEN(#tmpExport.ApproverName) < 2
                                                    THEN [usr].[FirstName] + ' ' + [usr].[LastName]
                                                    ELSE #tmpExport.ApproverName
                                             END)
                                  END,'')
      ,#tmpExport.ApproverEmail =  isnull(CASE WHEN [bkp].[RecordId] IS NOT NULL
                                        THEN [bkp].[Email]
                                        ELSE(CASE   WHEN LEN(#tmpExport.[ApproverEmail]) < 2
                                                    THEN [usr].[Email]
                                                    ELSE #tmpExport.[ApproverEmail]
                                             END) 
                                  END,'')
      ,#tmpExport.ApprovalDate = case when THD.AprvlStatus_Date IS NULL then '' else REPLACE(convert(varchar(16), thd.AprvlStatus_Date, 112), '-','') end 
FROM #tmpExport
INNER JOIN [TimeHistory].[dbo].[tblTimeHistDetail] AS THD
    ON [THD].[RecordID] = #tmpExport.RecordID
LEFT JOIN [TimeHistory].[dbo].[tblTimeHistDetail_BackupApproval] AS bkp
    ON [bkp].[THDRecordId] = #tmpExport.RecordID
LEFT JOIN [TimeCurrent].[dbo].[tblUser] AS usr
    ON [usr].[UserID]= ISNULL([THD].[AprvlStatus_UserID],0)

UPDATE #tmpExport
  Set LineOut = EmplFirst    + @Delim 
            + EmplLast     + @Delim
            + EmployeeID   + @Delim
            + AssignmentNo + @Delim
            + weDate   + @Delim
            + TransactDate + @Delim
            + Paycode      + @Delim
            + CONVERT (VARCHAR(8), PayAmount)  + @Delim
            + CONVERT (VARCHAR(8), BillAmount) + @Delim
            + ProjectCode  + @Delim
            + ApproverName + @Delim
            + ApproverEmail+ @Delim
            + ApprovalDate + @Delim
            + PayFileGroup + @Delim
            + SourceTime   + @Delim
            + SourceApprove + @Delim
						+ DeptCode + @Delim
						+ DeptName + @Delim
						+ CONVERT(VARCHAR(10),PayRate) + @Delim
						+ CONVERT(VARCHAR(10),BillRate) + @Delim
						+ ShiftNo

UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'

INSERT INTO #tmpExport(SSN,EmpName,AssignmentNo,LineOut)
VALUES
(
	1,'1','MISSING',
	'FirstName|LastName|EmplID|Assignment|WeekEnding|TransDate|PayCode|PayAmt|BillAmt|Project|ApprName|ApprEmail|ApprDate|PayGroup|TimeSource|ApprSource|DeptCode|DeptName|PayRate|BillRate|ShiftNo'
)

SELECT * FROM #tmpExport 
    ORDER BY CASE WHEN AssignmentNo = 'MISSING'
                  THEN '0' 
                  ELSE '1' 
             END
           , EMPNAME
           , TransactDate
           , PayCode
					 , DeptCode
              
DROP TABLE #tmpExport
RETURN
