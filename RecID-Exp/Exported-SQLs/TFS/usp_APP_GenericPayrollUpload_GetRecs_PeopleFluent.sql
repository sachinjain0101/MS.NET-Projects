Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_PeopleFluent]
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

Set @Delim = ','

Set @PPED2 = @PPED

-- First check to see if this is bi-weekly.
--
SELECT @PayrollFreq = PayrollFreq
  FROM TimeCurrent..tblClientGroups 
WHERE client = @Client 
AND GroupCode = @GroupCode

if @PayrollFreq = 'B' 
BEGIN
    Set @PPED2 = dateadd(day, -7, @PPED)
END

if @TestingFlag = 'N'
BEGIN
  if @PayrollFreq = 'B'
  BEGIN
  	Exec usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'Y'
  	if @@error <> 0 
  	   return
  END
  else
  BEGIN
  	Exec usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'N'
  	if @@error <> 0 
  	   return
  END
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

CREATE TABLE #tmpExport
(
    SSN           INT          --Required in VB6: GenericPayrollUpload program
  , EmployeeID    VARCHAR(20)  --Required in VB6: GenericPayrollUpload program
  , EmpName       VARCHAR(120) --Required in VB6: GenericPayrollUpload program
  , FileBreakID   VARCHAR(20)  --The VB6: GenericPayrollUpload program will split apart payfiles on PayGroup from TimeCurrent.dbo.tbl_EmplNames
  , weDate        VARCHAR(12)   --Required in VB6: GenericPayrollUpload program
  , AssignmentNo  VARCHAR(32)
  , PayCode       VARCHAR(32)
  , PayAmount     NUMERIC(7,2)
  , BillAmount    NUMERIC(7,2)
  , SourceTime    VARCHAR(30)
  , SourceApprove VARCHAR(30)
  , EmplFirst     VARCHAR(20)
  , EmplLast      VARCHAR(20)
  , TransactDate  VARCHAR(12)
  , ProjectCode   VARCHAR(32)
  , ApproverName  VARCHAR(40)
  , ApproverEmail VARCHAR(132)
  , ApprovalDate  VARCHAR(14)  --format is: YYYYMMDD HH:MM
  , PayFileGroup  VARCHAR(10)
  , PayBillCode   VARCHAR(10)
  , RecordID      BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
  , AmountType    CHAR(1)       -- Hours, Dollars, etc. ( Units )
  , Line1         VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
)


--regular hours worked
Insert into #tmpExport
SELECT 	
      [SSN] = [hd].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(12), [hd].Payrollperiodenddate, 101)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
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
    , [TransactDate] = '' --CONVERT(VARCHAR(12), [hd].[TransDate], 101)
    , [ProjectCode] = en.assignmentNo
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = Max([hd].[RecordID])
    , ac.AdjustmentType 
    , [Line1]=''
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
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    --, [hd].[TransDate]
    , ac.AdjustmentType 
    , en.AssignmentNo 

 
        
--regular hours not worked (vacation, pto, sick, holiday, etc.)
Insert into #tmpExport
SELECT 	
      [SSN] = [hd].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(12), [hd].Payrollperiodenddate, 101)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
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
    , [TransactDate] = '' --CONVERT(VARCHAR(12), [hd].[TransDate], 101)
    , [ProjectCode] = en.assignmentNo
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = MAX([hd].[RecordID])
    , ac.AdjustmentType 
    , [Line1]=''
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
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    --, [hd].[TransDate]
    , ac.AdjustmentType
    , en.assignmentNo 

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
    , [weDate] = CONVERT(VARCHAR(12), [hd].Payrollperiodenddate, 101)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
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
    , [TransactDate] = '' --CONVERT(VARCHAR(12), [hd].[TransDate], 101)
    , [ProjectCode] = en.assignmentNo
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
    , [Line1]=''
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
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    --, [hd].[TransDate]
    , ac.AdjustmentType 
    , en.assignmentNo
    
--Get DoubleTime hours
Insert into #tmpExport
SELECT 	
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(12), [hd].Payrollperiodenddate, 101)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
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
    , [TransactDate] = '' --CONVERT(VARCHAR(12), [hd].[TransDate], 101)
    , [ProjectCode] = en.assignmentNo
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
    , [Line1]=''
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
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
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
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode2,'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode2]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    --, [hd].[TransDate]
    , ac.AdjustmentType 
    , en.assignmentNo
        
--Get Dollars if applicable        
Insert into #tmpExport
SELECT 	
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(12), [hd].Payrollperiodenddate, 101)
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
    , [TransactDate] = '' --CONVERT(VARCHAR(12), [hd].[TransDate], 101)
    , [ProjectCode] = en.assignmentNo
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
    , [Line1]=''
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
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
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
    --, [hd].[TransDate]
    , ac.AdjustmentType 
    , en.assignmentNo
        
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 


Update #tmpExport
  Set Line1 = EmployeeID   + @Delim
            + Paycode      + @Delim
            + CONVERT (VARCHAR(8), BillAmount) + @Delim
            + wedate + @Delim
            + ProjectCode

--UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'

/*
Insert into #tmpExport(SSN,EmpName,AssignmentNo, Line1 )
Values(1,'1','MISSING',
'EmployeeID,PayCode,Hours,Date Worked,Project')
*/

SELECT * FROM #tmpExport 
    ORDER BY EMPNAME
           , TransactDate
           , PayCode
           
DROP TABLE #tmpExport
RETURN

