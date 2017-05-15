Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_Standard_PEOPLENET_Clock_OLD]
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
  , RecordID      BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 11Aug2016 >--
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
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [edh].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL(edh.[BillToCode],'') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
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
    , [ApproverName] = (ISNULL([edh].[Approver_FirstName1],ISNULL([edh].[Approver_FirstName2],'')) 
                         + ' ' 
                         +ISNULL([edh].[Approver_LastName1],ISNULL([edh].[Approver_LastName2],'')))
    , [ApproverEmail] = ISNULL([edh].[Approver_Email1],ISNULL([edh].[Approver_Email2],''))
    , [ApprovalDate] = CONVERT(VARCHAR(8),[hd].[AprvlStatus_Date], 112) + ' ' 
                     + CONVERT(VARCHAR(2),DATEPART(HH,[hd].[AprvlStatus_Date]))+ ':'
                     + CONVERT(VARCHAR(2),DATEPART(MI,[hd].[AprvlStatus_Date]))
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
    , [RecordID] = [hd].[RecordID]
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
     GROUP BY 
          [hd].ssn
        , [en].FileNo
        , [en].PayGroup
        , [en].LastName
        , [en].FirstName
        , [hd].PayrollPeriodEndDate
        , [hd].[TransDate]
        , [hd].[AprvlStatus_Date]
        , [hd].[RecordID]
        , [hd].[CostID]
        , [edh].[Approver_FirstName1]
        , [edh].[Approver_FirstName2]
        , [edh].[Approver_LastName1]
        , [edh].[Approver_LastName2]
        , [edh].[Approver_Email1]
        , [edh].[Approver_Email2]
        , [edh].[BilltoCode]
        , [hd].[AprvlStatus]
        , [edh].AssignmentNo
        , [ac].ClockADjustmentNo 
        , [ac].ADP_HoursCode 
        
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
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [edh].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
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
    , [ApproverName] = (ISNULL([edh].[Approver_FirstName1],ISNULL([edh].[Approver_FirstName2],'')) 
                         + ' ' 
                         +ISNULL([edh].[Approver_LastName1],ISNULL([edh].[Approver_LastName2],'')))
    , [ApproverEmail] = ISNULL([edh].[Approver_Email1],ISNULL([edh].[Approver_Email2],''))
    , [ApprovalDate] = CONVERT(VARCHAR(8),[hd].[AprvlStatus_Date], 112) + ' ' 
                     + CONVERT(VARCHAR(2),DATEPART(HH,[hd].[AprvlStatus_Date]))+ ':'
                     + CONVERT(VARCHAR(2),DATEPART(MI,[hd].[AprvlStatus_Date]))
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
    , [RecordID] = [hd].[RecordID]
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
    GROUP BY 
          [hd].ssn
        , [en].FileNo
        , [en].PayGroup
        , [en].LastName
        , [en].FirstName
        , [hd].PayrollPeriodEndDate
        , [hd].[TransDate]
        , [hd].[AprvlStatus_Date]
        , [hd].[RecordID]
        , [hd].[CostID]
        , [edh].[Approver_FirstName1]
        , [edh].[Approver_FirstName2]
        , [edh].[Approver_LastName1]
        , [edh].[Approver_LastName2]
        , [edh].[Approver_Email1]
        , [edh].[Approver_Email2]
        , [edh].[BilltoCode]
        , [hd].[AprvlStatus]
        , [edh].AssignmentNo
        , [ac].ClockADjustmentNo 
        , [ac].ADP_HoursCode 

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
                            THEN CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [edh].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo] 
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @OTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
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
    , [ApproverName] = (ISNULL([edh].[Approver_FirstName1],ISNULL([edh].[Approver_FirstName2],'')) 
                         + ' ' 
                         +ISNULL([edh].[Approver_LastName1],ISNULL([edh].[Approver_LastName2],'')))
    , [ApproverEmail] = ISNULL([edh].[Approver_Email1],ISNULL([edh].[Approver_Email2],''))
    , [ApprovalDate] = CONVERT(VARCHAR(8),[hd].[AprvlStatus_Date], 112) + ' ' 
                     + CONVERT(VARCHAR(2),DATEPART(HH,[hd].[AprvlStatus_Date]))+ ':'
                     + CONVERT(VARCHAR(2),DATEPART(MI,[hd].[AprvlStatus_Date]))
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
    , [RecordID] = [hd].[RecordID]
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
    GROUP BY 
          [hd].ssn
        , [en].FileNo
        , [en].PayGroup
        , [en].LastName
        , [en].FirstName
        , [hd].PayrollPeriodEndDate
        , [hd].[TransDate]
        , [hd].[AprvlStatus_Date]
        , [hd].[RecordID]
        , [hd].[CostID]
        , [edh].[Approver_FirstName1]
        , [edh].[Approver_FirstName2]
        , [edh].[Approver_LastName1]
        , [edh].[Approver_LastName2]
        , [edh].[Approver_Email1]
        , [edh].[Approver_Email2]
        , [edh].[BilltoCode]
        , [hd].[AprvlStatus]
        , [edh].AssignmentNo
        , [ac].ClockADjustmentNo 
        , [ac].ADP_HoursCode 

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
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [edh].[AssignmentNo] 
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = CASE WHEN [ac].ClockADjustmentNo = '1' 
                       THEN CASE WHEN ISNULL([edh].[BillToCode],'') = ''
                                 THEN @OTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
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
    , [ApproverName] = (ISNULL([edh].[Approver_FirstName1],ISNULL([edh].[Approver_FirstName2],'')) 
                         + ' ' 
                         +ISNULL([edh].[Approver_LastName1],ISNULL([edh].[Approver_LastName2],'')))
    , [ApproverEmail] = ISNULL([edh].[Approver_Email1],ISNULL([edh].[Approver_Email2],''))
    , [ApprovalDate] = CONVERT(VARCHAR(8),[hd].[AprvlStatus_Date], 112) + ' ' 
                     + CONVERT(VARCHAR(2),DATEPART(HH,[hd].[AprvlStatus_Date]))+ ':'
                     + CONVERT(VARCHAR(2),DATEPART(MI,[hd].[AprvlStatus_Date]))
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
    , [RecordID] = [hd].[RecordID]
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
    GROUP BY 
          [hd].ssn
        , [en].FileNo
        , [en].PayGroup
        , [en].LastName
        , [en].FirstName
        , [hd].PayrollPeriodEndDate
        , [hd].[TransDate]
        , [hd].[AprvlStatus_Date]
        , [hd].[RecordID]
        , [hd].[CostID]
        , [edh].[Approver_FirstName1]
        , [edh].[Approver_FirstName2]
        , [edh].[Approver_LastName1]
        , [edh].[Approver_LastName2]
        , [edh].[Approver_Email1]
        , [edh].[Approver_Email2]
        , [edh].[BilltoCode]
        , [hd].[AprvlStatus]
        , [edh].AssignmentNo
        , [ac].ClockADjustmentNo 
        , [ac].ADP_HoursCode 
        
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
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE [edh].[AssignmentNo]
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
    , [ApproverName] = (ISNULL([edh].[Approver_FirstName1],ISNULL([edh].[Approver_FirstName2],'')) 
                         + ' ' 
                         +ISNULL([edh].[Approver_LastName1],ISNULL([edh].[Approver_LastName2],'')))
    , [ApproverEmail] = ISNULL([edh].[Approver_Email1],ISNULL([edh].[Approver_Email2],''))
    , [ApprovalDate] = CONVERT(VARCHAR(8),[hd].[AprvlStatus_Date], 112) + ' ' 
                     + CONVERT(VARCHAR(2),DATEPART(HH,[hd].[AprvlStatus_Date]))+ ':'
                     + CONVERT(VARCHAR(2),DATEPART(MI,[hd].[AprvlStatus_Date]))
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ISNULL([edh].[BilltoCode],'')
    , [RecordID] = [hd].[RecordID]
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
    GROUP BY 
          [hd].ssn
        , [en].FileNo
        , [en].PayGroup
        , [en].LastName
        , [en].FirstName
        , [hd].PayrollPeriodEndDate
        , [hd].[TransDate]
        , [hd].[AprvlStatus_Date]
        , [hd].[RecordID]
        , [hd].[CostID]
        , [edh].[Approver_FirstName1]
        , [edh].[Approver_FirstName2]
        , [edh].[Approver_LastName1]
        , [edh].[Approver_LastName2]
        , [edh].[Approver_Email1]
        , [edh].[Approver_Email2]
        , [edh].[BilltoCode]
        , [hd].[AprvlStatus]
        , [edh].AssignmentNo
        , [ac].ClockADjustmentNo 
        , [ac].ADP_EarningsCode
        
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 

IF @Payrolltype not like '%ALLTIME%'
BEGIN
Delete from #tmpExport where SSN IN ( SELECT DISTINCT SSN
                        FROM TimeHistory.dbo.tblTimeHistDetail AS thd
                        WHERE [thd].[Client] = @Client
                        AND [thd].[GroupCode] = @GroupCode
                        AND [thd].[PayrollPeriodEndDate] in (@PPED, @PPED2)
                        AND [thd].[Hours] <> 0
                        AND ([thd].[InDay] = 10 OR [thd].[OutDay] = 10 OR [thd].[AprvlStatus] NOT IN ('A','L')) )
END

UPDATE #tmpExport
    SET #tmpExport.ApproverName = CASE WHEN [bkp].[RecordId] IS NOT NULL
                                       THEN [bkp].[FirstName] + ' ' + [bkp].[LastName]
                                       ELSE (CASE   WHEN LEN(#tmpExport.ApproverName) < 2
                                                    THEN [usr].[FirstName] + ' ' + [usr].[LastName]
                                                    ELSE #tmpExport.ApproverName
                                             END)
                                  END
      ,#tmpExport.ApproverEmail =  CASE WHEN [bkp].[RecordId] IS NOT NULL
                                        THEN [bkp].[Email]
                                        ELSE(CASE   WHEN LEN(#tmpExport.[ApproverEmail]) < 2
                                                    THEN [usr].[Email]
                                                    ELSE #tmpExport.[ApproverEmail]
                                             END) 
                                  END                              
FROM #tmpExport
INNER JOIN [TimeHistory].[dbo].[tblTimeHistDetail] AS THD
    ON [THD].[RecordID] = #tmpExport.RecordID
LEFT JOIN [TimeHistory].[dbo].[tblTimeHistDetail_BackupApproval] AS bkp
    ON [bkp].[THDRecordId] = #tmpExport.RecordID
LEFT JOIN [TimeCurrent].[dbo].[tblUser] AS usr
    ON [usr].[UserID]= ISNULL([THD].[AprvlStatus_UserID],0)
    
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
            + isnull(ApproverName,'') + @Delim
            + isnull(ApproverEmail,'') + @Delim
            + isnull(ApprovalDate,'') + @Delim
            + PayFileGroup + @Delim
            + SourceTime   + @Delim
            + SourceApprove

UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'

SELECT * FROM #tmpExport 
    ORDER BY CASE WHEN AssignmentNo = 'MISSING'
                  THEN '0' 
                  ELSE '1' 
             END
           , EMPNAME
           , PayCode
           
           
IF (@TestingFlag IN ('N', '0') )
BEGIN
     UPDATE TimeHistory.dbo.tblEmplNames
         SET TimeHistory.dbo.tblEmplNames.PayRecordsSent = @Today
     FROM TimeHistory.dbo.tblEmplNames en
         JOIN #tmpExport ON [en].[SSN] = #tmpExport.[SSN]
     WHERE   [en].[Client]= @Client
         AND [en].[PayrollPeriodEndDate] = #tmpExport.[weDate]
         AND [en].[SSN] = #tmpExport.[SSN]
         AND ISNULL([en].[PayRecordsSent], '1/1/1970') = '1/1/1970'
END
           
DROP TABLE #tmpExport
RETURN

