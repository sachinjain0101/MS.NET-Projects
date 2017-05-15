Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_Standard_PEOPLENET_ClockV2]
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

--execute semimonthly payfile

if @PayrollFreq = 'S' 
BEGIN
    exec usp_APP_GenericPayrollUpload_GetRecs_Standard_PEOPLENET_ClockV2_Semi 
																			@Client       
																			,@GroupCode    
																			,@PPED         
																			,@PAYRATEFLAG  
																			,@EMPIDType    
																			,@REGPAYCODE   
																			,@OTPAYCODE    
																			,@DTPAYCODE    
																			,@PayrollType  
																			,@IncludeSalary
																			,@TestingFlag  
	RETURN
END

--semimonthly payfile 

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
  , weDate        VARCHAR(50)   --Required in VB6: GenericPayrollUpload program

  , AssignmentNo  VARCHAR(32)
  , PayCode       VARCHAR(32)
  , PayAmount     NUMERIC(7,2)
  , BillAmount    NUMERIC(7,2)
	, WorkedHours   NUMERIC(7,2) 
  , SourceTime    VARCHAR(30)
  , SourceApprove VARCHAR(30)
  , EmplFirst     VARCHAR(20)
  , EmplLast      VARCHAR(20)
  , TransactDate  VARCHAR(50)
  , ProjectCode   VARCHAR(32)
  , ApproverName  VARCHAR(40)
  , ApproverEmail VARCHAR(132)
  , ApprovalDate  VARCHAR(50)  --format is: YYYYMMDD HH:MM
  , PayFileGroup  VARCHAR(10)
  , PayBillCode   VARCHAR(10)
  , RecordID      BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 11Aug2016 >--
  , AmountType    CHAR(1)       -- Hours, Dollars, etc. ( Units )
  , BranchID      VARCHAR(50)	-- 02/19/2016 NK - added per new reqs  
  , TimeSheetID   INT			-- 02/19/2016 NK - added per new reqs 
  , ImageFileName INT			-- 02/19/2016 NK - added per new reqs 
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
    , [weDate] = CONVERT(VARCHAR(50), [hd].Payrollperiodenddate, 120)
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
		, sum(hd.Reghours)
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(50), [hd].[TransDate], 120)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = Max([hd].[RecordID])
    , ac.AdjustmentType 
	, BranchID=''
	, TimeSheetID=th_esds.RecordID
	, ImageFileName=th_esds.RecordID
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
		LEFT JOIN TimeHistory..tblEmplSites_Depts th_esds --to get TimeSheetID and ImageFileName
			ON  th_esds.Client = hd.Client
			AND th_esds.GroupCode = hd.GroupCode
			AND th_esds.SSN = hd.SSN
			AND th_esds.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
			AND th_esds.SiteNo = hd.SiteNo
			AND th_esds.DeptNo = hd.DeptNo
			--AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'    
		LEFT JOIN TimeCurrent..tblEmplAssignments as ea -- to get BranchID
			ON  ea.Client = hd.Client
			AND ea.Groupcode = hd.Groupcode
			AND ea.SSN = hd.SSN
			AND ea.DeptNo =  hd.DeptNo
			AND ea.SiteNo = hd.SiteNo
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
	, en.FileNo
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
	, th_esds.RecordID
 
        
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
    , [weDate] = CONVERT(VARCHAR(50), [hd].Payrollperiodenddate, 120)
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
		, sum(hd.Reghours)
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(50), [hd].[TransDate], 120)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = MAX([hd].[RecordID])
    , ac.AdjustmentType 
	, BranchID=''
	, TimeSheetID=th_esds.RecordID
	, ImageFileName=th_esds.RecordID
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
		LEFT JOIN TimeHistory..tblEmplSites_Depts th_esds --to get TimeSheetID and ImageFileName
			ON  th_esds.Client = hd.Client
			AND th_esds.GroupCode = hd.GroupCode
			AND th_esds.SSN = hd.SSN
			AND th_esds.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
			AND th_esds.SiteNo = hd.SiteNo
			AND th_esds.DeptNo = hd.DeptNo
			--AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'    
		LEFT JOIN TimeCurrent..tblEmplAssignments as ea -- to get BranchID
			ON  ea.Client = hd.Client
			AND ea.Groupcode = hd.Groupcode
			AND ea.SSN = hd.SSN
			AND ea.DeptNo =  hd.DeptNo
			AND ea.SiteNo = hd.SiteNo
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
    , [en].[FileNo]
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
	, th_esds.RecordID

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
    , [weDate] = CONVERT(VARCHAR(50), [hd].Payrollperiodenddate, 120)
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
		, sum(hd.OT_hours)
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(50), [hd].[TransDate], 120)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
	, BranchID=''
	, TimeSheetID=th_esds.RecordID
	, ImageFileName=th_esds.RecordID
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
		LEFT JOIN TimeHistory..tblEmplSites_Depts th_esds --to get TimeSheetID and ImageFileName
			ON  th_esds.Client = hd.Client
			AND th_esds.GroupCode = hd.GroupCode
			AND th_esds.SSN = hd.SSN
			AND th_esds.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
			AND th_esds.SiteNo = hd.SiteNo
			AND th_esds.DeptNo = hd.DeptNo
			--AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'    
		LEFT JOIN TimeCurrent..tblEmplAssignments as ea -- to get BranchID
			ON  ea.Client = hd.Client
			AND ea.Groupcode = hd.Groupcode
			AND ea.SSN = hd.SSN
			AND ea.DeptNo =  hd.DeptNo
			AND ea.SiteNo = hd.SiteNo
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
	, [en].[FileNo]
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
	, th_esds.RecordID
	    
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
    , [weDate] = CONVERT(VARCHAR(50), [hd].Payrollperiodenddate, 120)
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
		, sum(hd.DT_hours)
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(50), [hd].[TransDate], 120)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
	, BranchID=''
	, TimeSheetID=th_esds.RecordID
	, ImageFileName=th_esds.RecordID
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
		LEFT JOIN TimeHistory..tblEmplSites_Depts th_esds --to get TimeSheetID and ImageFileName
			ON  th_esds.Client = hd.Client
			AND th_esds.GroupCode = hd.GroupCode
			AND th_esds.SSN = hd.SSN
			AND th_esds.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
			AND th_esds.SiteNo = hd.SiteNo
			AND th_esds.DeptNo = hd.DeptNo
			--AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'    
		LEFT JOIN TimeCurrent..tblEmplAssignments as ea -- to get BranchID
			ON  ea.Client = hd.Client
			AND ea.Groupcode = hd.Groupcode
			AND ea.SSN = hd.SSN
			AND ea.DeptNo =  hd.DeptNo
			AND ea.SiteNo = hd.SiteNo
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
	, [en].[FileNo]		
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
	, th_esds.RecordID
	       
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
    , [weDate] = CONVERT(VARCHAR(50), [hd].Payrollperiodenddate, 120)
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
		, 0.00
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(50), [hd].[TransDate], 120)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max([hd].[RecordID])
    , ac.AdjustmentType 
	, BranchID=''
	, TimeSheetID=th_esds.RecordID
	, ImageFileName=th_esds.RecordID
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
		LEFT JOIN TimeHistory..tblEmplSites_Depts th_esds --to get TimeSheetID and ImageFileName
			ON  th_esds.Client = hd.Client
			AND th_esds.GroupCode = hd.GroupCode
			AND th_esds.SSN = hd.SSN
			AND th_esds.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
			AND th_esds.SiteNo = hd.SiteNo
			AND th_esds.DeptNo = hd.DeptNo
			--AND ISNULL(th_esds.PayRecordsSent, '1/1/1970') = '1/1/1970'    
		LEFT JOIN TimeCurrent..tblEmplAssignments as ea -- to get BranchID
			ON  ea.Client = hd.Client
			AND ea.Groupcode = hd.Groupcode
			AND ea.SSN = hd.SSN
			AND ea.DeptNo =  hd.DeptNo
			AND ea.SiteNo = hd.SiteNo
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
	, [en].[FileNo]				 
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
	, th_esds.RecordID
	
	        
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 

/*
-- Handle UDF information:
--
DECLARE @UDFCount int
DECLARE @UDFMappingId INT

SELECT @UDFMappingId = TimeCurrent.dbo.fn_UDF_TemplateMappingId(@Client,@GroupCode,0,0,0,'WEBTC')

Set @UDFCount = (
          select COUNT(*) from TimeCurrent..tblUDF_Templates as t
          inner join TImeCUrrent..tblUDF_FieldDefs as f
          on f.TemplateID = t.TemplateID
          INNER JOIN TimeCurrent..tblUDF_TemplateMapping tm
          ON t.TemplateID = tm.TemplateID
          AND tm.TemplateMappingID = @UDFMappingId
          where t.Client = @Client and t.RecordStatus = '1' )
--          and isnull(f.PayCodeID,'') <> ''  )

IF @UDFCount > 0
BEGIN
  -- UDF Fields are present that need to be included in the pay file.
  --

  -- Update the UDFs that do not have a THD record id with a valid record ID if possible.
  -- The Record ID will be used later in the Script to match for approval.
  --
  Update TimeHistory..tblTimeHistDetail_UDF
    Set TimeHistory..tblTimeHistDetail_UDF.THDRecordID = t.RecordID  
  from TimeHistory..tblTimeHistDetail_UDF as udf
  inner join TimeHistory..tblTimeHistDetail as t
  on t.Client = udf.Client and t.GroupCode = udf.GroupCode and t.SSN = udf.SSN and t.PayrollPeriodEndDate = udf.Payrollperiodenddate 
  and t.outTimestamp = udf.PunchTimeStamp 
  where
  udf.Client = @Client
  and udf.GroupCode = @GroupCode 
  and udf.Payrollperiodenddate in(@PPED, @PPED2) 
  and udf.THDRecordID = 0
  and udf.PunchTimeStamp <> 0
  
  
  Insert into #tmpExport
  SELECT 	
      [SSN] = [udf].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([udf].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [udf].Payrollperiodenddate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN 'MISSING' 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [PayCode] = case when isnull(fd.PayCodeID,'') = '' then fd.FieldName else fd.PayCodeID end
    , [PayAmount] = SUM(cast(udf.FieldValue as numeric(7,2)))
    , [BillAmount] = SUM(cast(udf.FieldValue as numeric(7,2)))
    , [SourceTime]='C'
    , [SourceApprove]=''
    , [EmplFirst] = [en].[FirstName]
    , [EmplLast] = [en].[LastName]
    , [TransactDate] = CONVERT(VARCHAR(8), [udf].[TransDate], 112)
    , [ProjectCode] = ''
    , [ApproverName] = ''
    , [ApproverEmail] = ''
    , [ApprovalDate] = ''
    , [PayFileGroup] = ISNULL([en].[PayGroup],'')
    , [PayBillCode] = ''
    , [RecordID] = max(udf.thdRecordID) 
    , 'U'
    , [Line1]=''
    FROM TimeHistory.dbo.tblTimeHistDetail_UDF as udf with(nolock)
    Left Join TimeHistory.dbo.tblTimeHistDetail as t with(nolock)
    on t.RecordID = udf.THDRecordID
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en with(nolock)
            ON	[en].Client = [udf].Client
            AND	[en].GroupCode = [udf].GroupCode
            AND	[en].SSN = [udf].SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed with(nolock)
            ON	ed.Client = [udf].Client
            AND	ed.GroupCode = [udf].GroupCode
            AND	ed.SSN = [udf].SSN
            AND ed.Department = isnull(t.DeptNo, udf.deptno)
        Left JOIN TimeHistory.[dbo].[tblEmplNames_Depts] as edh with(nolock)
            ON	[edh].Client = [udf].Client
            AND	[edh].GroupCode = [udf].GroupCode
            AND	[edh].SSN = [udf].SSN
            AND [edh].Department = isnull(t.DeptNo, udf.deptno)
            AND [edh].PayrollPeriodEndDate = [udf].Payrollperiodenddate
        Inner Join TimeCurrent..tblUDF_FieldDefs as fd with(nolock)
        on fd.FieldID = udf.FieldID     
    WHERE	[udf].Client = @Client 
        AND [udf].GroupCode = @GroupCode 
        AND	[udf].PayrollPeriodEndDate in(@PPED, @PPED2)
        AND isnumeric([udf].FieldValue) = 1
     GROUP BY 
      [udf].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str([udf].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [udf].Payrollperiodenddate
    , case when isnull(fd.PayCodeID,'') = '' then fd.FieldName else fd.PayCodeID end
    , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL([ed].[AssignmentNo],'')) = '' 
                                      THEN 'MISSING' 
                                      ELSE [ed].[AssignmentNo]
                                 END 
                            ELSE [edh].[AssignmentNo]
                       END
    , [en].[FirstName]
    , [en].[LastName]
    , [udf].[TransDate]

END
*/

-- Set Approver information.
--

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
      ,#tmpExport.ApprovalDate = case when THD.AprvlStatus_Date IS NULL then '' else convert(varchar(50), thd.AprvlStatus_Date, 120) end 
FROM #tmpExport
INNER JOIN [TimeHistory].[dbo].[tblTimeHistDetail] AS THD
    ON [THD].[RecordID] = #tmpExport.RecordID
LEFT JOIN [TimeHistory].[dbo].[tblTimeHistDetail_BackupApproval] AS bkp
    ON [bkp].[THDRecordId] = #tmpExport.RecordID
LEFT JOIN [TimeCurrent].[dbo].[tblUser] AS usr
    ON [usr].[UserID]= ISNULL([THD].[AprvlStatus_UserID],0)
	--ApprovalDate

----exec usp_APP_GenericPayrollUpload_GetRecs_Standard_PEOPLENET_ClockV2 'PERO', 290001, '01/03/16', 'NO','FileNo','REG','OT','DT','PeoplenetV2','N','Y'
-- exec usp_APP_GenericPayrollUpload_GetRecs_Standard_PEOPLENET_ClockV2 'PENM', 777501, '02/21/16', 'NO','FileNo','REG','OT','DT','PeoplenetV2','N','Y'

Update #tmpExport
  Set Line1 = ISNULL(BranchID,' ')     + @Delim
			+ ISNULL(EmplFirst,' ')    + @Delim 
            + ISNULL(EmplLast,' ')     + @Delim
            + ISNULL(EmployeeID,' ')   + @Delim
            + ISNULL(AssignmentNo,' ') + @Delim
            + CONVERT(VARCHAR(50), ISNULL(weDate, ' '), 120)  + @Delim
			+ CONVERT( VARCHAR(50),ISNULL(TransactDate, ' '), 120) + @Delim            
			+ CONVERT (VARCHAR(8), ISNULL(WorkedHours,0))  + @Delim
            + ISNULL(Paycode,' ')      + @Delim
			+ ''					   + @Delim  --TimeCode
            + ISNULL(CONVERT (VARCHAR(8), PayAmount),0)  + @Delim
            + ISNULL(CONVERT (VARCHAR(8), BillAmount),0) + @Delim
            + ISNULL(ProjectCode,' ')  + @Delim
            + ISNULL(ApproverName,' ') + @Delim
            + ISNULL(ApproverEmail,' ')+ @Delim
            + CONVERT( VARCHAR(50),ISNULL(ApprovalDate, ' '), 120) + @Delim 
            + ISNULL(PayFileGroup,' ') + @Delim
            + ISNULL(SourceTime,' ')   + @Delim
            + ISNULL(SourceApprove,' ')+ @Delim
			+ ISNULL(CONVERT(VARCHAR(15),TimeSheetID),'0') + @Delim			-- TimeSheetID
			+ Case when ISNULL(approverName,'') <> '' then '1' else '0' end + @Delim
			+ ISNULL(CONVERT(VARCHAR(15),ImageFileName),' ') + @Delim		-- IMageFileName


UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'

Insert into #tmpExport(SSN,EmpName,AssignmentNo, Line1 )
Values(1,'1','MISSING',
'BranchID|EmployeeFirstName|EmployeeLastName|EmployeeID|AssignmentNumber|WeekEndingDate|TransDate|WorkedHours|PayCode|TimeCode|PayAmt|BillAmt|ProjectCode|ApproverName|ApproverEmail|ApprovalDateTime|PayFileGroup|TimeSource|ApprovalSource|TimeSheetID|ApprovalStatus|ImageFileName')

SELECT * FROM #tmpExport 
    ORDER BY CASE WHEN AssignmentNo = 'MISSING'
                  THEN '0' 
                  ELSE '1' 
             END
           , EMPNAME
           , TransactDate
           , PayCode
           
           
IF (@TestingFlag IN ('N', '0') )
BEGIN
     UPDATE TimeHistory.dbo.tblEmplNames
         SET TimeHistory.dbo.tblEmplNames.PayRecordsSent = @Today
     FROM TimeHistory.dbo.tblEmplNames en
         JOIN #tmpExport ON [en].[SSN] = #tmpExport.[SSN]
     WHERE   [en].[Client]= @Client
         AND [en].GroupCode = @GroupCode
         AND [en].[PayrollPeriodEndDate] = #tmpExport.[weDate]
         AND [en].[SSN] = #tmpExport.[SSN]
         AND ISNULL([en].[PayRecordsSent], '1/1/1970') = '1/1/1970'
END
           
DROP TABLE #tmpExport
RETURN
