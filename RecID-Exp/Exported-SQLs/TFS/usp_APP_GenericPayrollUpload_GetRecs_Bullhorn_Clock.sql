Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_Bullhorn_Clock]
(
  @Client       varchar(4),
  @GroupCode    int,
  @PPED         datetime,
  @PAYRATEFLAG  varchar(4),
  @EMPIDType    varchar(6),
  @REGPAYCODE   varchar(10),
  @OTPAYCODE    varchar(10),
  @DTPAYCODE    varchar(10),
  @PayrollType  varchar(500),
  @IncludeSalary char(1),
  @TestingFlag   char(1) = 'N'
)
AS

SET NOCOUNT ON

DECLARE @PayrollFreq    CHAR(1)
DECLARE @PPED2          DATETIME
DECLARE @Today          DATETIME
SELECT @Today = GETDATE()

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
  , weDate        dateTime   --Required in VB6: GenericPayrollUpload program
  , AssignmentNo  VARCHAR(32)
  , PayCode       VARCHAR(32)
  , PayAmount     NUMERIC(7,2)
  , BillAmount    NUMERIC(7,2)
  , SourceTime    VARCHAR(30)
  , SourceApprove VARCHAR(30)
  , EmplFirst     VARCHAR(20)
  , EmplLast      VARCHAR(20)
  , TransactDate  datetime
  , ProjectCode   VARCHAR(32)
  , ApproverName  VARCHAR(40)
  , ApproverEmail VARCHAR(132)
  , ApprovalDate  datetime  --format is: YYYYMMDD HH:MM
  , PayFileGroup  VARCHAR(10)
  , PayBillCode   VARCHAR(10)
  , RecordID      BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 04Aug2016 >--
  , AmountType    VARCHAR(8)    -- Hours, OT, DT, Dollars, etc. ( Units )
  , xmlTimeCard   VARCHAR(1500)
  , xmlTimeEntry  VARCHAR(1500)
  , KickoutToLogFile VARCHAR(400)
)


--regular hours worked
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn
    , EmployeeID= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
    , EmpName = (en.FirstName+' '+en.LastName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
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
    , hd.TransDate
    , ProjectCode = ''
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = Max(hd.RecordID)
    , 'REG'
    , '','',''
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
        Left JOIN TimeCurrent.dbo.tblEmplSites_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SiteNo=hd.SiteNo
            AND	edh.SSN = hd.SSN
            AND edh.DeptNo = hd.DeptNo
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.RegHours <> 0.00
        AND ac.Worked='Y'
     GROUP BY 
      hd.ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
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
                       THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , en.FirstName
    , en.LastName
    , hd.TransDate
 
        
--regular hours not worked (vacation, pto, sick, holiday, etc.)
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn
    , EmployeeID= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
    , EmpName = (en.FirstName+' '+en.LastName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
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
    , PayCode = CASE WHEN ac.ClockADjustmentNo = '1' 
                       THEN @REGPAYCODE 
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
    , hd.TransDate
    , ProjectCode = ''
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = MAX(hd.RecordID)
    , 'NONWORK'
    , '','',''
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
        Left JOIN TimeCurrent.dbo.tblEmplSites_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SiteNo=hd.SiteNo
            AND	edh.SSN = hd.SSN
            AND edh.DeptNo = hd.DeptNo
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.RegHours <> 0.00
        AND ac.Worked<>'Y'
    GROUP BY 
      hd.ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
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
                       THEN @REGPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , en.FirstName
    , en.LastName
    , hd.TransDate


-- Get the Overtime hours
INSERT INTO #tmpExport
SELECT
      SSN = hd.ssn 	
    , EmployeeID= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
    , EmpName = (en.FirstName+' '+en.LastName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
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
    , PayCode = CASE WHEN ac.ClockADjustmentNo = '1' 
                       THEN @OTPAYCODE 
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
    , hd.TransDate
    , ProjectCode = ''
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = max(hd.RecordID)
    , 'OT'
    , '','',''
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
        Left JOIN TimeCurrent.dbo.tblEmplSites_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SiteNo=hd.SiteNo
            AND	edh.SSN = hd.SSN
            AND edh.DeptNo = hd.DeptNo
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.OT_Hours <> 0.00
    GROUP BY 
      hd.ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
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
                       THEN @OTPAYCODE 
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL(ac.ADP_HoursCode,'')))='' 
                                 THEN 'MISSING'
                                 ELSE ac.ADP_HoursCode
                            END
                  END
    , en.FirstName
    , en.LastName
    , hd.TransDate
    
--Get DoubleTime hours
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn 	
    , EmployeeID= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
    , EmpName = (en.FirstName+' '+en.LastName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
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
    , PayCode = CASE WHEN ac.ClockADjustmentNo = '1' 
                       THEN @DTPAYCODE 
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
    , hd.TransDate
    , ProjectCode = ''
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = max(hd.RecordID)
    , 'DT'
    , '','',''
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
        Left JOIN TimeCurrent.dbo.tblEmplSites_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SiteNo=hd.SiteNo
            AND	edh.SSN = hd.SSN
            AND edh.DeptNo = hd.DeptNo
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.DT_Hours <> 0.00
    GROUP BY 
      hd.ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
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
        
--Get Dollars if applicable        
Insert into #tmpExport
SELECT 	
      SSN = hd.ssn 	
    , EmployeeID= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
    , EmpName = (en.FirstName+' '+en.LastName)
    , FileBreakID= LTRIM(RTRIM(ISNULL(en.PayGroup,'')))
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
    , hd.TransDate
    , ProjectCode = ''
    , ApproverName = ''
    , ApproverEmail = ''
    , ApprovalDate = ''
    , PayFileGroup = ISNULL(en.PayGroup,'')
    , PayBillCode = ''
    , RecordID = max(hd.RecordID)
    , 'DOLLARS'
    , '','',''
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
        Left JOIN TimeCurrent.dbo.tblEmplSites_Depts as edh
            ON	edh.Client = hd.Client
            AND	edh.GroupCode = hd.GroupCode
            AND	edh.SiteNo=hd.SiteNo
            AND	edh.SSN = hd.SSN
            AND edh.DeptNo = hd.DeptNo
        INNER JOIN TimeCurrent.dbo.tblAdjCodes as ac
            ON	ac.Client = hd.Client
            AND	ac.GroupCode = hd.GroupCode
            AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8') then '1' else hd.ClockAdjustmentNo END
    WHERE	hd.Client = @Client 
        AND hd.GroupCode = @GroupCode 
        AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
        AND hd.Dollars <> 0.00
    GROUP BY 
      hd.ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN ltrim(str(hd.SSN))
                         ELSE en.FileNo
                    END 
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
      ,#tmpExport.ApprovalDate = case when THD.AprvlStatus_Date IS NULL then NULL else thd.AprvlStatus_Date end 
FROM #tmpExport
INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS THD
    ON THD.RecordID = #tmpExport.RecordID
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval AS bkp
    ON bkp.THDRecordId = #tmpExport.RecordID
LEFT JOIN TimeCurrent.dbo.tblUser AS usr
    ON usr.UserID= ISNULL(THD.AprvlStatus_UserID,0)

Declare @externalID varchar(20)
Declare @BullhornUserID varchar(20)
DECLARE @WeekendingDayNo int

Set @BullhornUserID = '1024711'
Set @externalID = 'PeopleNet'
Set @WeekendingDayNo = datepart(weekday,@PPED)

-- Must force all hours to fit the bullHorn week ending date of Sunday.
if @Client = 'PRID' and @WeekendingDayNo <> 1
BEGIN
  -- Monday
  IF @WeekendingDayNo = 2
  BEGIN
    -- Move week ending date back one day and all Monday hours back 7 days.
    Update #tmpExport Set weDate = dateadd(day,-1,wedate)
    Update #tmpExport Set TransactDate = dateadd(day,-7,TransactDate) where TransactDate > wedate
  END
  -- Tuesday
  IF @WeekendingDayNo = 3
  BEGIN
    -- Move week ending date back three days and all Monday hours back 7 days.
    Update #tmpExport Set weDate = dateadd(day,-2,wedate)
    Update #tmpExport Set TransactDate = dateadd(day,-7,TransactDate) where TransactDate > wedate
  END
  -- Wednesday
  IF @WeekendingDayNo = 4
  BEGIN
    -- Move week ending date forward four days and all Monday hours back 7 days.
    Update #tmpExport Set weDate = dateadd(day,4,wedate)
    Update #tmpExport Set TransactDate = dateadd(day,7,TransactDate) where datepart(weekday, TransactDate) in(1,5,6,7)
  END
  -- Thursday
  IF @WeekendingDayNo = 5
  BEGIN
    -- Move week ending date forward four days and all Monday hours back 7 days.
    Update #tmpExport Set weDate = dateadd(day,3,wedate)
    Update #tmpExport Set TransactDate = dateadd(day,7,TransactDate) where datepart(weekday, TransactDate) in(1,6,7)
  END
  -- Friday
  IF @WeekendingDayNo = 6
  BEGIN
    -- Move week ending date forward four days and all Monday hours back 7 days.
    Update #tmpExport Set weDate = dateadd(day,2,wedate)
    Update #tmpExport Set TransactDate = dateadd(day,7,TransactDate) where datepart(weekday, TransactDate) in(1,7)
  END
  -- Saturday
  IF @WeekendingDayNo = 7
  BEGIN
    -- Move week ending date forward four days and all Monday hours back 7 days.
    Update #tmpExport Set weDate = dateadd(day,1,wedate)
    Update #tmpExport Set TransactDate = dateadd(day,7,TransactDate) where datepart(weekday, TransactDate) = 1
  END
END

Declare @tmpXML TABLE
(
  sortID int IDENTITY(1,1) NOT NULL,
  EmployeeID varchar(20), 
  SSN int, 
  EmpName varchar(100), 
  AssignmentNo varchar(32),
  KickoutToLogFile varchar(1000),
  Line1 varchar(2000)
)  

-- Each record in the #tmpExport represents a time entry Item.

Update #tmpExport
  Set xmlTimeCard = '<timecard placementID="' + AssignmentNo + '" EmplName="' + empName + '">
<dateBegin>' + convert(varchar(12),dateadd(day,-6,wedate),101) + '</dateBegin>
<dateEnd>' + convert(varchar(12),wedate,101) + '</dateEnd>
<externalID>' +	@externalID + '</externalID>
<timeCardStatus>' + case when isnull(ApproverName,'') <> '' then 'Client Approved' else 'Submitted' end + '</timeCardStatus>
<timecardType>Regular</timecardType><timeEntries>'
,xmlTimeEntry = 
'<timeEntry><approvalInfo>' + case when isnull(ApprovalDate,'1/1/1970') = '1/1/1970' then 'un-approved item' else isnull(Approvername,'') + ' ' + isnull(ApproverEmail,'') + ' ' + convert(varchar(12),ApprovalDate,101) + ' ' + convert(varchar(5),ApprovalDate,108) end + '</approvalInfo>
<dateWorked>' + convert(varchar(12),TransactDate,101) + '</dateWorked>
<hours>' + ltrim(str(PayAmount,9,2)) + '</hours>
<payClassID>' + payCode + '</payClassID>
<projectCode>' + projectCode + '</projectCode>
<BullhornUserID>' + @BullhornUserID + '</BullhornUserID>
<PNETHoursType>' + AmountType + '</PNETHoursType>
<projectID></projectID></timeEntry>'
where AssignmentNo <> 'MISSING'

UPDATE #tmpExport  
  SET KickoutToLogFile = empName + ' has ' + AmountType +  ' hours = ' + ltrim(str(PayAmount,9,2)) + ' without a placement ID on ' + convert(varchar(12),TransactDate,101)  
WHERE AssignmentNo = 'MISSING'

--UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'

Insert into @tmpXML(EmployeeID, SSN, EmpName, AssignmentNo, Line1)
values('1',1,'','','<?xml version="1.0" encoding="UTF-8"?><timecards>')

DECLARE cPayRecs CURSOR
READ_ONLY
FOR 
Select AssignmentNo, xmlTimeCard, xmlTimeEntry, SSN, EmpName, EmployeeID from #tmpExport 
where KickoutToLogFile = ''
order by assignmentNo, SSN, TransactDate, AmountType

DECLARE @AssignmentNo varchar(32)
DECLARE @savAssignment varchar(32)
DECLARE @TimeCard varchar(1500)
DECLARE @TimeEntry varchar(1500)
DECLARE @KickoutToLogFile varchar(500)
DECLARE @SSN int
DECLARE @EmpName varchar(100)
DECLARE @EmployeeID varchar(20)

Set @savAssignment = ''

OPEN cPayRecs

FETCH NEXT FROM cPayRecs INTO @AssignmentNo, @TimeCard, @TimeEntry, @SSN, @EmpName, @EmployeeID
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    if @savAssignment <> @AssignmentNo
    BEGIN  
        if @savAssignment = ''
        BEGIN
          -- start the new one
          Insert into @tmpXML(EmployeeID, SSN, EmpName, AssignmentNo, KickoutToLogFile, Line1)
          values(@EmployeeID,@SSN,@EmpName,@AssignmentNo,'', @TimeCard)
        END
        Else
        BEGIN
          -- End the prior time card and start the new one
          Insert into @tmpXML(EmployeeID, SSN, EmpName, AssignmentNo, KickoutToLogFile, Line1)
          values(@EmployeeID,@SSN,@EmpName,@AssignmentNo, '', '</timeEntries></timecard>' + @TimeCard)
        END
        Set @savAssignment = @AssignmentNo
    END
    Insert into @tmpXML(EmployeeID, SSN, EmpName, AssignmentNo, KickoutToLogFile, Line1)
    values(@EmployeeID,@SSN,@EmpName,@AssignmentNo,'', @TimeEntry)

	END
	FETCH NEXT FROM cPayRecs INTO @AssignmentNo, @TimeCard, @TimeEntry, @SSN, @EmpName, @EmployeeID
END

CLOSE cPayRecs
DEALLOCATE cPayRecs


Insert into @tmpXML(EmployeeID, SSN, EmpName, AssignmentNo, KickoutToLogFile, Line1)
values('9',9,'','9','', '</timeEntries></timecard></timecards>')


Insert into @tmpXML(EmployeeID, SSN, EmpName, AssignmentNo, KickoutToLogFile, Line1)
Select EmployeeID, SSN, EmpName, AssignmentNo, KickoutToLogFile, '' from #tmpExport 
where KickoutToLogFile <> ''
order by EmpName, TransactDate, AmountType


select * from @tmpXML order by SortID

/*           
IF (@TestingFlag IN ('N', '0') )
BEGIN
     UPDATE TimeHistory.dbo.tblEmplNames
         SET TimeHistory.dbo.tblEmplNames.PayRecordsSent = @Today
     FROM TimeHistory.dbo.tblEmplNames en
         JOIN #tmpExport ON en.SSN = #tmpExport.SSN
     WHERE   en.Client= @Client
         AND en.PayrollPeriodEndDate = #tmpExport.weDate
         AND en.SSN = #tmpExport.SSN
         AND ISNULL(en.PayRecordsSent, '1/1/1970') = '1/1/1970'
END
*/
           
DROP TABLE #tmpExport
RETURN

