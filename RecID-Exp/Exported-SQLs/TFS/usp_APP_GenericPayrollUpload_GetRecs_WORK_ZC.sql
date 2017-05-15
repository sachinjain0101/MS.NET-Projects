Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_WORK_ZC]
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
  , ProjectCode   VARCHAR(100)
  , ApproverName  VARCHAR(40)
  , ApproverEmail VARCHAR(132)
  , ApprovalDate  VARCHAR(14)  --format is: YYYYMMDD HH:MM
  , PayFileGroup  VARCHAR(10)
  , PayBillCode   VARCHAR(10)
  , RecordID      BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 11Aug2016 >--
  , AmountType    CHAR(1)       -- Hours, Dollars, etc. ( Units )
  , AltEmployeeID VARCHAR(20)
  , AltAssignment VARCHAR(32)
  , BillRate      numeric(7,2)
  , Line1         VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
)


--regular hours worked
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn
    , EmployeeID = en.FileNo
    , EmpName = (en.LastName+','+en.FirstName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
    , weDate = CONVERT(VARCHAR(12), hd.Payrollperiodenddate, 101)
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
    , PayCode = CASE WHEN ac.ClockADjustmentNo = '1' THEN @REGPAYCODE
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , PayAmount = SUM( CASE WHEN ac.Payable ='Y'
                              THEN hd.RegHours
                              ELSE 0.0
                         END )
    , BillAmount =SUM( CASE WHEN ac.Billable ='Y'
                              THEN hd.RegHours
                              ELSE 0.0
                         END )                             
    , SourceTime='C'
    , SourceApprove=''
    , EmplFirst = en.FirstName
    , EmplLast = en.LastName
    , TransactDate = CONVERT(VARCHAR(12), hd.TransDate, 101)
    , ProjectCode = gd.ClientDeptCode 
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = Max(hd.RecordID)
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , ed.BillRate 
    , Line1=''
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	en.Client = hd.Client
            AND	en.GroupCode = hd.GroupCode
            AND	en.SSN = hd.SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = hd.Client
            AND	ed.GroupCode = hd.GroupCode
            AND	ed.SSN = hd.SSN
            AND ed.Department = hd.DeptNo
        Left JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SSN = hd.SSN
            AND edh.Department = hd.DeptNo
            AND edh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeHistory..tblEmplNames as enh
            ON  enh.Client = hd.Client
            AND enh.GroupCode = hd.GroupCode
            AND enh.SSN = hd.SSN
            AND enh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
        INNER JOIN TImeCurrent..tblGroupDepts as gd
        on gd.Client = hd.Client
        and gd.GroupCode = hd.GroupCode
        and gd.DeptNo = hd.DeptNo 
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.RegHours <> 0.00
        AND ac.Worked='Y'
     GROUP BY 
      hd.ssn
    , en.FileNo
    , ISNULL(en.PayGroup,'')
    , hd.Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE ed.AssignmentNo
                                 END 
                            ELSE edh.AssignmentNo
                       END
    , CASE WHEN ac.ClockADjustmentNo = '1' THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , en.FirstName
    , en.LastName
    , hd.TransDate
    , ac.AdjustmentType
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , gd.ClientDeptCode 
    , ed.BillRate 

 
        
--regular hours not worked (vacation, pto, sick, holiday, etc.)
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn
    , EmployeeID= en.FileNo
    , EmpName = (en.LastName+','+en.FirstName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
    , weDate = CONVERT(VARCHAR(12), hd.Payrollperiodenddate, 101)
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
    , PayCode = CASE WHEN ac.ClockADjustmentNo = '1' THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , PayAmount = SUM( CASE WHEN ac.Payable ='Y'
                              THEN hd.RegHours
                              ELSE 0.0
                         END )
    , BillAmount =SUM( CASE WHEN ac.Billable ='Y'
                              THEN hd.RegHours
                              ELSE 0.0
                         END )                             
    , SourceTime='C'
    , SourceApprove=''
    , EmplFirst = en.FirstName
    , EmplLast = en.LastName
    , TransactDate = CONVERT(VARCHAR(12), hd.TransDate, 101)
    , ProjectCode = gd.ClientDeptCode
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = MAX(hd.RecordID)
    , ac.AdjustmentType
    , en.AssignmentNo,ISNULL(ed.Custom1,'') 
    , ed.BillRate 
    , Line1=''
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	en.Client = hd.Client
            AND	en.GroupCode = hd.GroupCode
            AND	en.SSN = hd.SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = hd.Client
            AND	ed.GroupCode = hd.GroupCode
            AND	ed.SSN = hd.SSN
            AND ed.Department = hd.DeptNo
        Left JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SSN = hd.SSN
            AND edh.Department = hd.DeptNo
            AND edh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeHistory..tblEmplNames as enh
            ON  enh.Client = hd.Client
            AND enh.GroupCode = hd.GroupCode
            AND enh.SSN = hd.SSN
            AND enh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
        INNER JOIN TImeCurrent..tblGroupDepts as gd
        on gd.Client = hd.Client
        and gd.GroupCode = hd.GroupCode
        and gd.DeptNo = hd.DeptNo 
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.RegHours <> 0.00
        AND ac.Worked<>'Y'
    GROUP BY 
      hd.ssn
    , en.FileNo
    , ISNULL(en.PayGroup,'')
    , hd.Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE ed.AssignmentNo
                                 END 
                            ELSE edh.AssignmentNo
                       END
    , CASE WHEN ac.ClockADjustmentNo = '1' THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , en.FirstName
    , en.LastName
    , hd.TransDate
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , gd.ClientDeptCode
    , ed.BillRate 

-- Get the Overtime hours
INSERT INTO #tmpExport
SELECT
      SSN = hd.ssn 	
    , EmployeeID = en.FileNo
    , EmpName = (en.LastName+','+en.FirstName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
    , weDate = CONVERT(VARCHAR(12), hd.Payrollperiodenddate, 101)
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
    , PayCode = CASE WHEN ac.ClockADjustmentNo = '1' THEN @OTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , PayAmount = SUM( CASE WHEN ac.Payable ='Y'
                              THEN hd.OT_Hours
                              ELSE 0.0
                         END )
    , BillAmount =SUM( CASE WHEN ac.Billable ='Y'
                              THEN hd.OT_Hours
                              ELSE 0.0
                         END )                             
    , SourceTime='C'
    , SourceApprove=''
    , EmplFirst = en.FirstName
    , EmplLast = en.LastName
    , TransactDate = CONVERT(VARCHAR(12), hd.TransDate, 101)
    , ProjectCode = gd.ClientDeptCode
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = max(hd.RecordID)
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , ed.BillRate 
    , Line1=''
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	en.Client = hd.Client
            AND	en.GroupCode = hd.GroupCode
            AND	en.SSN = hd.SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = hd.Client
            AND	ed.GroupCode = hd.GroupCode
            AND	ed.SSN = hd.SSN
            AND ed.Department = hd.DeptNo
        Left JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SSN = hd.SSN
            AND edh.Department = hd.DeptNo
            AND edh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeHistory..tblEmplNames as enh
            ON  enh.Client = hd.Client
            AND enh.GroupCode = hd.GroupCode
            AND enh.SSN = hd.SSN
            AND enh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
        INNER JOIN TImeCurrent..tblGroupDepts as gd
        on gd.Client = hd.Client
        and gd.GroupCode = hd.GroupCode
        and gd.DeptNo = hd.DeptNo 
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.OT_Hours <> 0.00
    GROUP BY 
      hd.ssn
    , en.FileNo
    , ISNULL(en.PayGroup,'')
    , hd.Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE ed.AssignmentNo
                                 END 
                            ELSE edh.AssignmentNo
                       END
    , CASE WHEN ac.ClockADjustmentNo = '1' THEN @OTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , en.FirstName
    , en.LastName
    , hd.TransDate
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , gd.ClientDeptCode
    , ed.BillRate 
    
--Get DoubleTime hours
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn 	
    , EmployeeID = en.FileNo
    , EmpName = (en.LastName+','+en.FirstName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
    , weDate = CONVERT(VARCHAR(12), hd.Payrollperiodenddate, 101)
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
    , PayCode = CASE WHEN ac.ClockADjustmentNo = '1' THEN @DTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , PayAmount = SUM( CASE WHEN ac.Payable ='Y'
                              THEN hd.DT_Hours
                              ELSE 0.0
                         END )
    , BillAmount =SUM( CASE WHEN ac.Billable ='Y'
                              THEN hd.DT_Hours
                              ELSE 0.0
                         END )                             
    , SourceTime='C'
    , SourceApprove=''
    , EmplFirst = en.FirstName
    , EmplLast = en.LastName
    , TransactDate = CONVERT(VARCHAR(12), hd.TransDate, 101)
    , ProjectCode = gd.ClientDeptCode
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = max(hd.RecordID)
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , ed.BillRate 
    , Line1=''
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	en.Client = hd.Client
            AND	en.GroupCode = hd.GroupCode
            AND	en.SSN = hd.SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = hd.Client
            AND	ed.GroupCode = hd.GroupCode
            AND	ed.SSN = hd.SSN
            AND ed.Department = hd.DeptNo
        Left JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SSN = hd.SSN
            AND edh.Department = hd.DeptNo
            AND edh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeHistory..tblEmplNames as enh
            ON  enh.Client = hd.Client
            AND enh.GroupCode = hd.GroupCode
            AND enh.SSN = hd.SSN
            AND enh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
        INNER JOIN TImeCurrent..tblGroupDepts as gd
        on gd.Client = hd.Client
        and gd.GroupCode = hd.GroupCode
        and gd.DeptNo = hd.DeptNo 
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.DT_Hours <> 0.00
    GROUP BY 
      hd.ssn
    , en.FileNo
    , ISNULL(en.PayGroup,'')
    , hd.Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE ed.AssignmentNo
                                 END 
                            ELSE edh.AssignmentNo
                       END
    , CASE WHEN ac.ClockADjustmentNo = '1' 
                       THEN @DTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , en.FirstName
    , en.LastName
    , hd.TransDate
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , gd.ClientDeptCode
    , ed.BillRate 
        
--Get Dollars if applicable        
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn 	
    , EmployeeID = en.FileNo
    , EmpName = (en.LastName+','+en.FirstName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
    , weDate = CONVERT(VARCHAR(12), hd.Payrollperiodenddate, 101)
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
    , PayCode = ac.ADP_EarningsCode
    , PayAmount = SUM( CASE WHEN ac.Payable ='Y'
                              THEN hd.Dollars
                              ELSE 0.0
                         END )
    , BillAmount =SUM( CASE WHEN ac.Billable ='Y'
                              THEN hd.Dollars
                              ELSE 0.0
                         END )                             
    , SourceTime='C'
    , SourceApprove=''
    , EmplFirst = en.FirstName
    , EmplLast = en.LastName
    , TransactDate = CONVERT(VARCHAR(12), hd.TransDate, 101)
    , ProjectCode = gd.ClientDeptCode
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = max(hd.RecordID)
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , ed.BillRate 
    , Line1=''
    FROM TimeHistory.dbo.tblTimeHistDetail as hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames as en
            ON	en.Client = hd.Client
            AND	en.GroupCode = hd.GroupCode
            AND	en.SSN = hd.SSN
        Left JOIN TimeCurrent.dbo.tblEmplNames_Depts as ed
            ON	ed.Client = hd.Client
            AND	ed.GroupCode = hd.GroupCode
            AND	ed.SSN = hd.SSN
            AND ed.Department = hd.DeptNo
        Left JOIN TimeHistory.dbo.tblEmplNames_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SSN = hd.SSN
            AND edh.Department = hd.DeptNo
            AND edh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeHistory..tblEmplNames as enh
            ON  enh.Client = hd.Client
            AND enh.GroupCode = hd.GroupCode
            AND enh.SSN = hd.SSN
            AND enh.PayrollPeriodEndDate = hd.PayrollPeriodEndDate
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
        INNER JOIN TImeCurrent..tblGroupDepts as gd
        on gd.Client = hd.Client
        and gd.GroupCode = hd.GroupCode
        and gd.DeptNo = hd.DeptNo 
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.Dollars <> 0.00
    GROUP BY 
      hd.ssn
    , en.FileNo
    , ISNULL(en.PayGroup,'')
    , hd.Payrollperiodenddate
    , CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(ed.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(hd.CostID,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE hd.costID 
                                           END 
                                      ELSE ed.AssignmentNo
                                 END 
                            ELSE edh.AssignmentNo
                       END
    , ac.ADP_EarningsCode
    , en.FirstName
    , en.LastName
    , hd.TransDate
    , ac.AdjustmentType 
    , en.AssignmentNo,ISNULL(ed.Custom1,'')
    , gd.ClientDeptCode
    , ed.BillRate 
        
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 

-- Set Approver information.
--

UPDATE #tmpExport
    SET #tmpExport.ApproverName = isnull(CASE WHEN bkp.RecordId IS NOT NULL
                                       THEN bkp.FirstName + ' ' + bkp.LastName
                                       ELSE (CASE   WHEN LEN(#tmpExport.ApproverName) < 2
                                                    THEN usr.FirstName + ' ' + usr.LastName
                                                    ELSE #tmpExport.ApproverName
                                             END)
                                  END,'')
      ,#tmpExport.ApproverEmail =  isnull(CASE WHEN bkp.RecordId IS NOT NULL
                                        THEN bkp.Email
                                        ELSE(CASE   WHEN LEN(#tmpExport.ApproverEmail) < 2
                                                    THEN usr.Email
                                                    ELSE #tmpExport.ApproverEmail
                                             END) 
                                  END,'')
      ,#tmpExport.ApprovalDate = case when THD.AprvlStatus_Date IS NULL then '' else convert(varchar(12), thd.AprvlStatus_Date, 101) end 
FROM #tmpExport
INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS THD
    ON THD.RecordID = #tmpExport.RecordID
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval AS bkp
    ON bkp.THDRecordId = #tmpExport.RecordID
LEFT JOIN TimeCurrent.dbo.tblUser AS usr
    ON usr.UserID= ISNULL(THD.AprvlStatus_UserID,0)

DECLARE @ApproverName varchar(80)
DECLARE @ApproverEmail varchar(200)
DECLARE @ApprovalDate datetime

select @ApproverName = (u.FirstName + ' ' + u.LastName ),
       @ApproverEmail = u.email,
       @ApprovalDate = p.WeekClosedDateTime
from TImeHistory..tblPeriodenddates as p
Left Join TImeCurrent..tblUser as u
on u.client = p.client
and u.logonname = p.MaintUserName
where p.client = @Client 
and p.Groupcode = @Groupcode 
and p.PayrollPeriodEndDate = @PPED

Update #tmpExport
  Set  ApproverName = @ApproverName 
      ,ApproverEmail =  @ApproverEmail 
      ,ApprovalDate = convert(varchar(12),@ApprovalDate,101)
where ApprovalDate = ''

Update #tmpExport
  Set Line1 = '"' + EmpName + '"' + @Delim
            + Paycode + @Delim
            + '"' + EmplFirst + '"' + @Delim 
            + '"' + EmplLast + '"' + @Delim
            + CONVERT (VARCHAR(8), BillAmount) + @Delim
            + TransactDate + @Delim
            + case when datepart(weekday,Transactdate) = 1 then 'Sunday'  
                   when datepart(weekday,Transactdate) = 2 then 'Monday'  
                   when datepart(weekday,Transactdate) = 3 then 'Tuesday'  
                   when datepart(weekday,Transactdate) = 4 then 'Wednesday'  
                   when datepart(weekday,Transactdate) = 5 then 'Thursday'  
                   when datepart(weekday,Transactdate) = 6 then 'Friday'  
                   when datepart(weekday,Transactdate) = 7 then 'Saturday'  else 'unknown' end + @Delim
            + convert(varchar(12),DATEADD(day,-6,@PPED),101) + @Delim
            + weDate   + @Delim
            + ApprovalDate + @Delim
            + ProjectCode  + @Delim
            + AltEmployeeID   + @Delim
            + AltAssignment + @Delim
            + LTRIM(str(BillRate,8,2))

-- Comment this line out since the client doesn't want anything excluded.          
--UPDATE #tmpExport  SET EmployeeID = '' WHERE AltAssignment in('MISSING','')

Insert into #tmpExport(SSN,EmpName,AssignmentNo, Line1 )
Values(1,'1','MISSING',
'"Last Name, First Name Middle Name",CodeType,First Name,Last Name,Units,Day Date,Day Name,Timecard Start Date,Weekend Date,Approved Date and Time,TrackCode,ZCWorkerID,ZC Project#,Bill Rate')

SELECT * FROM #tmpExport 
    ORDER BY CASE WHEN AssignmentNo = 'MISSING'
                  THEN '0' 
                  ELSE '1' 
             END
           , EMPNAME
           , TransactDate
           , PayCode
           
           
DROP TABLE #tmpExport

