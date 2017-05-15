Create PROCEDURE [dbo].[usp_APP_CRCC_Upload_GetUploadRecs_Diffs]
(
  @Client       varchar(4),
  @GroupCode    int,
  @PPED         datetime,
  @SSN          int,
  @FinalizeUserID varchar(20) = ''
)
AS

SET NOCOUNT ON

DECLARE  @EMPIDType    varchar(6)
DECLARE  @REGPAYCODE   varchar(10)
DECLARE  @OTPAYCODE    varchar(10)
DECLARE  @DTPAYCODE    varchar(10)

SET @EMPIDType = 'FileNo'
SET @REGPAYCODE = 'REG'
SET @OTPAYCODE = 'OT'
SET @DTPAYCODE = 'DT'

DECLARE @PayrollFreq    CHAR(1)
DECLARE @PPED2          DATETIME
DECLARE @Delim          CHAR(1)
DECLARE @Today          DATETIME
SELECT @Today = GETDATE()

Set @Delim = '|'

Set @PPED2 = @PPED

-- First check to see if this is bi-weekly.
--
SELECT @PayrollFreq = PayrollFreq
  FROM TimeCurrent..tblClientGroups 
WHERE client = @Client 
AND GroupCode = @GroupCode

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
  , weDate        VARCHAR(8)   --Required in VB6: GenericPayrollUpload program
  , DeptNo        int
  , SiteNo        int
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
  , RecordID      BIGINT  --< RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
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
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , hd.DeptNo, hd.SiteNo
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL(edh.[BillToCode],'') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
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
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
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
        Left JOIN TimeCurrent.[dbo].[tblEmplAssignments] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].[SiteNo]=[hd].[SiteNo]
            AND	[edh].SSN = [hd].SSN
            AND [edh].DeptNo = [hd].DeptNo
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
        AND hd.SSN = @SSN 
     GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , hd.DeptNo, hd.SiteNo
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ISNULL([edh].[BilltoCode],'')
    , ac.AdjustmentType 

 
        
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
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , hd.DeptNo, hd.SiteNo
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
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
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
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
        Left JOIN TimeCurrent.[dbo].[tblEmplAssignments] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].[SiteNo]=[hd].[SiteNo]
            AND	[edh].SSN = [hd].SSN
            AND [edh].DeptNo = [hd].DeptNo
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
        AND hd.SSN = @SSN 
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , hd.DeptNo, hd.SiteNo
    , [hd].Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ISNULL([edh].[BilltoCode],'')
    , ac.AdjustmentType 

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
    , hd.DeptNo, hd.SiteNo
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo] 
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @OTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
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
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
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
        Left JOIN TimeCurrent.[dbo].[tblEmplAssignments] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].[SiteNo]=[hd].[SiteNo]
            AND	[edh].SSN = [hd].SSN
            AND [edh].DeptNo = [hd].DeptNo
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
        AND hd.SSN = @SSN 
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , hd.DeptNo, hd.SiteNo
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @OTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ISNULL([edh].[BilltoCode],'')
    , ac.AdjustmentType 
    
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
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , hd.DeptNo, hd.SiteNo
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo] 
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @OTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
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
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
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
        Left JOIN TimeCurrent.[dbo].[tblEmplAssignments] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].[SiteNo]=[hd].[SiteNo]
            AND	[edh].SSN = [hd].SSN
            AND [edh].DeptNo = [hd].DeptNo
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
        AND hd.SSN = @SSN 
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , hd.DeptNo, hd.SiteNo
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @OTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                 THEN ''
                                 ELSE [ac].[ADP_HoursCode]
                            END
                  END
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ISNULL([edh].[BilltoCode],'')
    , ac.AdjustmentType 
        
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
    , [weDate] = CONVERT(VARCHAR(8), [hd].Payrollperiodenddate, 112)
    , hd.DeptNo, hd.SiteNo
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
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
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
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
        Left JOIN TimeCurrent.[dbo].[tblEmplAssignments] as edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].[SiteNo]=[hd].[SiteNo]
            AND	[edh].SSN = [hd].SSN
            AND [edh].DeptNo = [hd].DeptNo
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
        AND hd.SSN = @SSN 
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].Payrollperiodenddate
    , hd.DeptNo, hd.SiteNo
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN '' 
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
    , ISNULL([edh].[BilltoCode],'')
    , ac.AdjustmentType 
        
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 

Update #tmpExport
  Set Line1 = EmplFirst    + @Delim 
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
            + SourceApprove + @Delim + AmountType 

/*
Insert into #tmpExport(SSN,EmpName,AssignmentNo, Line1 )
Values(1,'1','',
'FirstName|LastName|EmplID|Assignment|WeekEnding|TransDate|PayCode|PayAmt|BillAmt|Project|ApprName|ApprEmail|ApprDate|PayGroup|TimeSource|ApprSource|AmtType')

SELECT * FROM #tmpExport 
    ORDER BY CASE WHEN AssignmentNo = ''
                  THEN '0' 
                  ELSE '1' 
             END
           , EMPNAME
           , TransactDate
           , PayCode
           
*/

--select * from TimeHistory..tblUploadHistory where Client = 'HSSS' and GroupCode = 230202 and SSN = 613239130 and MasterPayrollDate = '5/19/12'

Create table #tmpECRRecs
(
  SiteNo int,
  DeptNo int,
  DeptID varchar(32),
  PayCode varchar(20),
  Amount numeric(9,2),
  OldAmount numeric(9,2)
)

Create table #tmpPayRecs
(
  SiteNo int,
  DeptNo int,
  DeptID varchar(32),
  PayCode varchar(20),
  Amount numeric(9,2)
)

Insert into #tmpECRRecs(SiteNo, DeptNo, DeptID, PayCode, Amount, OldAmount  )
select SiteNo, DeptNo, AssignmentNo, PayCode, sum(PayAmount), 0 from #tmpExport 
group by SiteNo, DeptNo, AssignmentNo, PayCode


Create Table #tmpUpload
(
  FirstName  varchar(50),
  LastName  varchar(50),
  EmplID  varchar(20),
  Assignment  varchar(50),
  WeekEnding  varchar(20),
  TransDate  varchar(20),
  PayCode  varchar(32),
  PayAmt  numeric(9,2),
  BillAmt  numeric(9,2),
  Project  varchar(50),
  ApprName  varchar(80),
  ApprEmail  varchar(120),
  ApprDate  varchar(20),
  PayGroup  varchar(50),
  TimeSource  varchar(50),
  ApprSource  varchar(50),
  AmtType    varchar(8)
)

-- =============================================
-- Get Upload History Records and load for comparison.
-- =============================================
DECLARE cPayRecs CURSOR
READ_ONLY
FOR 
Select UploadRecord 
from TimeHistory..tblUploadHistory 
where Client = @Client 
and GroupCode = @GroupCode
and SSN = @SSN
and MasterPayrollDate = @PPED

DECLARE @UploadRec varchar(800)
DECLARE @strSQL varchar(3000)

OPEN cPayRecs

FETCH NEXT FROM cPayRecs into @UploadRec 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Set @strSQL = 'insert into #tmpUpload (FirstName,LastName,EmplID,Assignment,WeekEnding,TransDate,PayCode,PayAmt,BillAmt,Project,ApprName,ApprEmail,ApprDate,PayGroup,TimeSource,ApprSource,AmtType) VALUES('''
		SET @strSQL = @strSQL + REPLACE(@UploadRec,'|', ''',''') + ''')' 
		PRINT @strSQL
		EXEC (@strSQL)
		
	END
	FETCH NEXT FROM cPayRecs into @UploadRec 
END

CLOSE cPayRecs
DEALLOCATE cPayRecs

DECLARE @SiteNo int

--select * from #tmpUpload 

-- Include any Prior ECRs and Summarize again
-- 
insert into #tmpUpload(Assignment, PayCode, PayAmt, AmtType  )  
Select DeptCode, PayCode, Amount, 'H'   
from [TimeHistory].[dbo].[tblUploadHistory_ManualCheck]
where Client = @Client
and GroupCode = @GroupCode 
and SSN = @SSN
and MasterPayrolldate = @PPED

--select * from #tmpUpload 
--select * from [TimeHistory].[dbo].[tblUploadHistory_ManualCheck] where Client = 'HSSS'

-- Get Default SiteNo 
SET @SiteNo = (Select top 1 SiteNo from #tmpECRRecs )

-- Summarize the old pay records and the prior ECR records into a summary table. 
-- This table will be used to compare against the current pay records created above.
-- this will aid in creating the differences.
--
Insert into #tmpPayRecs(SiteNo, DeptNo, DeptID, PayCode, Amount )
Select @SiteNo, isnull(ed.Department,ec.Department), u.Assignment, u.PayCode, SUM(u.PayAmt)
from #tmpUpload as u
Left Join TimeHistory..tblEmplNames_Depts as ed
on ed.Client = @Client and ed.GroupCode = @GroupCode and ed.SSN = @SSN 
and ed.AssignmentNo = u.Assignment 
and ed.PayrollPeriodEndDate = @PPED 
Left Join TimeCurrent..tblEmplNames_Depts as ec
on ec.Client = @Client 
and ec.GroupCode = @GroupCode 
and ec.SSN = @SSN 
and ec.AssignmentNo = u.Assignment 
where AmtType <> 'U'    -- Ignore UDF fields
Group By
isnull(ed.Department,ec.Department), u.Assignment, u.PayCode
 
-- Update the existing ECR records with what the old values were from the pay file
--
Update #tmpECRRecs 
  Set #tmpECRRecs.OldAmount = t2.Amount 
from #tmpECRRecs 
Inner Join #tmpPayRecs as t2
on 
t2.SiteNo = #tmpECRRecs.SiteNo 
and t2.DeptNo = #tmpECRRecs.DeptNo 
and t2.PayCode = #tmpECRRecs.PayCode 

-- Insert any  records that are in the old pay file - that do not exist in the current ECR.
Insert into #tmpECRRecs(SiteNo, DeptNo, DeptID, PayCode, Amount, OldAmount )
select t2.SiteNo, t2.DeptNo, t2.DeptID, t2.PayCode, 0, t2.Amount  
from #tmpPayRecs as t2
Left Join #tmpECRRecs as t1
on t1.SiteNo = t2.SiteNo 
and t1.DeptNo = t2.DeptNo 
and t1.PayCode = t2.PayCode
where
isnull(t1.DeptNo,-1) = -1


IF @FinalizeUserID = '' 
BEGIN
  SELECT 
  EmplName = en.Lastname + ',' + en.FirstName, 
  EmplID = en.FileNo, 
  t.SiteNo, 
  DeptName = gd.DeptName + '(' + t.DeptID + ')',
  t.PayCode,
  [Hours] = t.Amount,
  OldHours = isnull(t.OldAmount,0.00),
  DiffHours = t.Amount - isnull(t.OldAmount,0.00)
  FROM #tmpECRRecs as t
  Left Join TimeCurrent..tblGroupdepts as gd
  on gd.Client = @Client
  and gd.Groupcode = @Groupcode
  and gd.DeptNo = t.DeptNo
  Inner Join TimeCUrrent..tblEmplNames as en
  on en.Client = @Client and en.GroupCode = @GroupCode and en.SSN = @SSN
  ORDER BY t.SiteNo, t.DeptNo, t.PayCode 
END

If @FinalizeUserID <> '' 
Begin

  SELECT 
  EmplName = en.Lastname + ',' + en.FirstName, 
  EmplID = en.FileNo, 
  t.SiteNo, 
  DeptName = gd.DeptName + '(' + t.DeptID + ')',
  t.PayCode,
  [Hours] = t.Amount,
  OldHours = isnull(t.OldAmount,0.00),
  DiffHours = t.Amount - isnull(t.OldAmount,0.00)
  FROM #tmpECRRecs as t
  Left Join TimeCurrent..tblGroupdepts as gd
  on gd.Client = @Client
  and gd.Groupcode = @Groupcode
  and gd.DeptNo = t.DeptNo
  Inner Join TimeCUrrent..tblEmplNames as en
  on en.Client = @Client and en.GroupCode = @GroupCode and en.SSN = @SSN
  where
  t.Amount - isnull(t.OldAmount,0.00) <> 0.00
  ORDER BY t.SiteNo, t.DeptNo, t.PayCode 
  
  INSERT INTO [TimeHistory].[dbo].[tblUploadHistory_ManualCheck]
  ([Client],[GroupCode],[MasterPayrolldate],[SSN],[SiteNo],[DeptNo],[ShiftNo],[DeptCode],[PayCode],[Amount],[isECR],[ECRUserID],[ECRDateTime])
  select @Client, @GroupCode, @PPED, @SSN, SiteNo, DeptNo, 0, DeptID, PayCode, Amount - isnull(OldAmount,0.00), '1', @FinalizeUserID, GETDATE()
  from #tmpECRRecs 
  where Amount - isnull(OldAmount,0.00) <> 0.00

  IF @@RowCount > 0
  BEGIN
    -- Create Audit record.
    INSERT INTO [TimeCurrent].[dbo].[tblMCRequest_Audit]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [PayrollUserID], [DateAdded])
    VALUES(@Client, @GroupCode, @PPED, @SSN, @FinalizeUserID, getdate() )

  END

End


Drop Table #tmpECRRecs 
Drop Table #tmpPayRecs
           
DROP TABLE #tmpExport
RETURN



