USE TimeHistory;
GO
/*
US2693   UBrown   05/13/2015

EXEC TimeHistory.dbo.usp_APP_GenericPayrollUpload_GetRecs_EVOL 'EVOL',121401,'05/08/2015','YES','FILENO','REG','OT','DT','Peoplenet','N','Y';

EXEC TimeHistory.dbo.usp_APP_GenericPayrollUpload_GetRecs_EVOL 'PENM', 777501, '02/21/16', 'NO','FileNo','REG','OT','DT','Custom','N','Y'

SET @Client='EVOL'
SET @GroupCode=121401 --121403 --121402 -- 
SET @PPED ='4/16/2016'
SET @PAYRATEFLAG ='NO'
SET @EMPIDType ='FileNo'
SET @REGPAYCODE ='RG'
SET @OTPAYCODE ='OT'
SET @DTPAYCODE ='DT'
SET @PayrollType ='Custom'
SET @IncludeSalary ='N'
SET @TestingFlag= 'Y'

*/
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.usp_APP_GenericPayrollUpload_GetRecs_EVOL') AND [type] =  'P')
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE dbo.usp_APP_GenericPayrollUpload_GetRecs_EVOL AS' 
END
GO

ALTER PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_EVOL]
(
   @Client CHAR(4)
  ,@GroupCode INT
  ,@PPED DATETIME
  ,@PAYRATEFLAG VARCHAR(4)
  ,@EMPIDType VARCHAR(6)
  ,@REGPAYCODE VARCHAR(10)
  ,@OTPAYCODE VARCHAR(10)
  ,@DTPAYCODE VARCHAR(10)
  ,@PayrollType VARCHAR(32)
  ,@IncludeSalary CHAR(1)
  ,@TestingFlag CHAR(1) = 'N'
) AS
SET NOCOUNT ON;

DECLARE
@PayrollFreq CHAR(1)
,@PPED2 DATETIME = @PPED
,@Delim CHAR(1) = '|'
,@Today DATETIME = GETDATE();

SELECT @PayrollFreq = PayrollFreq
  FROM TimeCurrent.dbo.tblClientGroups 
WHERE client = @Client 
AND GroupCode = @GroupCode

IF @PayrollFreq = 'B' 
BEGIN
    SET @PPED2 = DATEADD(DAY, -7, @PPED)
END

IF @TestingFlag = 'N'
BEGIN
  IF @PayrollFreq = 'B'
  BEGIN
  	EXEC usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'Y'
  	IF @@ERROR <> 0 
  	   RETURN
  END
  ELSE
  BEGIN
  	EXEC usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'N'
  	IF @@ERROR <> 0 
  	   RETURN
  END
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
  , RecordID      BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 05Aug2016 >--
  , AmountType    CHAR(1)       -- Hours, Dollars, etc. ( Units )
  , AgencyName    VARCHAR(50)
  , Line1         VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
)

--REG
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].PayrollPeriodEndDate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
	, AgencyName=ISNULL(ag.AgencyName,'')
    , [Line1]=''
    FROM TimeHistory.dbo.tblTimeHistDetail AS hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames AS en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        LEFT JOIN TimeHistory.[dbo].[tblEmplNames_Depts] AS edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
		LEFT JOIN TimeCurrent..tblAgencies ag
            ON	[edh].Client = [ag].Client
            AND	[edh].GroupCode = [ag].GroupCode
			AND en.AgencyNo=ag.Agency
        INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
						--AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
        INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN ISNULL([hd].ClockAdjustmentNo, '') IN ('', '8') THEN '1' ELSE [hd].ClockAdjustmentNo END
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
        AND [hd].RegHours <> 0.00
        AND [ac].[Worked]='Y'
     GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].PayrollPeriodEndDate
    , CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
    , ISNULL(ag.AgencyName,'') 
	        
-- REG Non-Worked (vacation, pto, sick, holiday, etc.)
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].PayrollPeriodEndDate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
	, AgencyName=ISNULL(ag.AgencyName,'')
    , [Line1]=''
    FROM TimeHistory.dbo.tblTimeHistDetail AS hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames AS en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        LEFT JOIN TimeHistory.[dbo].[tblEmplNames_Depts] AS edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
		LEFT JOIN TimeCurrent..tblAgencies ag
            ON	[edh].Client = [ag].Client
            AND	[edh].GroupCode = [ag].GroupCode
			AND en.AgencyNo=ag.Agency
        INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
						--AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
        INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN ISNULL([hd].ClockAdjustmentNo, '') IN ('', '8') THEN '1' ELSE [hd].ClockAdjustmentNo END
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
        AND [hd].RegHours <> 0.00
        AND [ac].[Worked]<>'Y'
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].PayrollPeriodEndDate
    , CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
	,ISNULL(ag.AgencyName,'')

-- OT
INSERT INTO #tmpExport
SELECT
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].PayrollPeriodEndDate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
    , [RecordID] = MAX([hd].[RecordID])
    , ac.AdjustmentType 
	, AgencyName=ISNULL(ag.AgencyName,'')
    , [Line1]=''
    FROM TimeHistory.dbo.tblTimeHistDetail AS hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames AS en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        LEFT JOIN TimeHistory.[dbo].[tblEmplNames_Depts] AS edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
		LEFT JOIN TimeCurrent..tblAgencies ag
            ON	[edh].Client = [ag].Client
            AND	[edh].GroupCode = [ag].GroupCode
			AND en.AgencyNo=ag.Agency
        INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
						--AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
        INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN ISNULL([hd].ClockAdjustmentNo, '') IN ('', '8') THEN '1' ELSE [hd].ClockAdjustmentNo END
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
        AND [hd].[OT_Hours] <> 0.00
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].PayrollPeriodEndDate
    , CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
    , ISNULL(ag.AgencyName,'')     

-- DT
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].PayrollPeriodEndDate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
    , [RecordID] = MAX([hd].[RecordID])
    , ac.AdjustmentType 
	, AgencyName=ISNULL(ag.AgencyName,'')
    , [Line1]=''
    FROM TimeHistory.dbo.tblTimeHistDetail AS hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames AS en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        LEFT JOIN TimeHistory.[dbo].[tblEmplNames_Depts] AS edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
		LEFT JOIN TimeCurrent..tblAgencies ag
            ON	[edh].Client = [ag].Client
            AND	[edh].GroupCode = [ag].GroupCode
			AND en.AgencyNo=ag.Agency
        INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
						--AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
        INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN ISNULL([hd].ClockAdjustmentNo, '') IN ('', '8') THEN '1' ELSE [hd].ClockAdjustmentNo END
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
        AND [hd].[DT_Hours] <> 0.00
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].PayrollPeriodEndDate
    , CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
    , ISNULL(ag.AgencyName,'') 
	        
-- DOLLARS      
INSERT INTO #tmpExport
SELECT 	
      [SSN] = [hd].ssn 	
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [hd].PayrollPeriodEndDate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
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
    , [RecordID] = MAX([hd].[RecordID])
    , ac.AdjustmentType 
	, AgencyName=ISNULL(ag.AgencyName,'')
    , [Line1]=''
    FROM TimeHistory.dbo.tblTimeHistDetail AS hd
        INNER JOIN TimeCurrent.dbo.tblEmplNames AS en
            ON	[en].Client = [hd].Client
            AND	[en].GroupCode = [hd].GroupCode
            AND	[en].SSN = [hd].SSN
        LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed
            ON	ed.Client = [hd].Client
            AND	ed.GroupCode = [hd].GroupCode
            AND	ed.SSN = [hd].SSN
            AND ed.Department = [hd].DeptNo
        LEFT JOIN TimeHistory.[dbo].[tblEmplNames_Depts] AS edh
            ON	[edh].Client = [hd].Client
            AND	[edh].GroupCode = [hd].GroupCode
            AND	[edh].SSN = [hd].SSN
            AND [edh].Department = [hd].DeptNo
            AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
		LEFT JOIN TimeCurrent..tblAgencies ag
            ON	[edh].Client = [ag].Client
            AND	[edh].GroupCode = [ag].GroupCode
			AND en.AgencyNo=ag.Agency
        INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
            ON  [enh].Client = [hd].Client
            AND [enh].GroupCode = [hd].GroupCode
            AND [enh].SSN = [hd].SSN
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
						--AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
        INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
            ON	[ac].Client = [hd].Client
            AND	[ac].GroupCode = [hd].GroupCode
            AND	[ac].ClockAdjustmentNo = CASE WHEN ISNULL([hd].ClockAdjustmentNo, '') IN ('', '8') THEN '1' ELSE [hd].ClockAdjustmentNo END
    WHERE	[hd].Client = @Client 
        AND [hd].GroupCode = @GroupCode 
        AND	[hd].PayrollPeriodEndDate in(@PPED, @PPED2)
        AND [hd].[Dollars] <> 0.00
    GROUP BY 
      [hd].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([hd].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [hd].PayrollPeriodEndDate
    , CASE WHEN LTRIM(ISNULL(hd.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE hd.CostID
                       END
    , ac.ADP_EarningsCode
    , [en].[FirstName]
    , [en].[LastName]
    , [hd].[TransDate]
    , ac.AdjustmentType 
    , ISNULL(ag.AgencyName,'') 
	        
DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 
--select * from #tmpExport

-- UDF
DECLARE @UDFCount INT,@UDFMappingId INT
SELECT @UDFMappingId = TimeCurrent.dbo.fn_UDF_TemplateMappingId (@Client,@GroupCode,0,0,0,'WEBTC','','')

SELECT
@UDFCount = COUNT(*) 
FROM TimeCurrent.dbo.tblUDF_Templates AS t
INNER JOIN TImeCUrrent.dbo.tblUDF_FieldDefs AS f
ON f.TemplateID = t.TemplateID
INNER JOIN TimeCurrent.dbo.tblUDF_TemplateMapping tm
ON t.TemplateID = tm.TemplateID
AND tm.TemplateMappingID = @UDFMappingId
WHERE t.Client = @Client AND t.RecordStatus = '1' ;

IF @UDFCount > 0
BEGIN
  -- UPDATE the UDFs that do not have a THD record id with a valid record ID if possible.
  -- The Record ID will be used later in the Script to match for approval.
  UPDATE UDF SET
  THDRecordID = t.RecordID
  FROM TimeHistory.dbo.tblTimeHistDetail_UDF AS udf
  INNER JOIN TimeHistory.dbo.tblTimeHistDetail AS t
  ON t.Client = udf.Client
  AND t.GroupCode = udf.GroupCode
  AND t.SSN = udf.SSN
  AND t.PayrollPeriodEndDate = udf.PayrollPeriodEndDate 
  AND t.outTimestamp = udf.PunchTimeStamp 
  WHERE
  udf.Client = @Client
  AND udf.GroupCode = @GroupCode 
  AND udf.PayrollPeriodEndDate IN (@PPED, @PPED2) 
  AND udf.THDRecordID = 0
  AND udf.PunchTimeStamp <> 0;  
  
  INSERT INTO #tmpExport
  SELECT 	
      [SSN] = [udf].ssn
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([udf].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , [EmpName] = ([en].FirstName+' '+[en].LastName)
    , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
    , [weDate] = CONVERT(VARCHAR(8), [udf].PayrollPeriodEndDate, 112)
    , [AssignmentNo] = CASE WHEN LTRIM(ISNULL(t.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE t.CostID
                       END
    , [PayCode] = CASE WHEN ISNULL(fd.PayCodeID,'') = '' THEN fd.FieldName ELSE fd.PayCodeID END
    , [PayAmount] = SUM(CAST(udf.FieldValue AS NUMERIC(7,2)))
    , [BillAmount] = SUM(CAST(udf.FieldValue AS NUMERIC(7,2)))
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
    , [RecordID] = MAX(t.RecordID) 
    , 'U'
	, AgencyName=ISNULL(ag.AgencyName,'')
    , [Line1]=''
    FROM TimeHistory.dbo.tblTimeHistDetail_UDF AS udf WITH (NOLOCK)
    Left Join TimeHistory.dbo.tblTimeHistDetail AS t WITH (NOLOCK)
    on t.RecordID = udf.THDRecordID
        INNER JOIN TimeCurrent.dbo.tblEmplNames AS en WITH (NOLOCK)
            ON	[en].Client = [udf].Client
            AND	[en].GroupCode = [udf].GroupCode
            AND	[en].SSN = [udf].SSN
        INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
            ON  [enh].Client = [udf].Client
            AND [enh].GroupCode = [udf].GroupCode
            AND [enh].SSN = [udf].SSN
            AND [enh].[PayrollPeriodEndDate] = [udf].[PayrollPeriodEndDate]
						--AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
		LEFT JOIN TimeCurrent..tblAgencies ag
            ON	[enh].Client = [ag].Client
            AND	[enh].GroupCode = [ag].GroupCode
			AND en.AgencyNo=ag.Agency
        LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed WITH (NOLOCK)
            ON	ed.Client = [udf].Client
            AND	ed.GroupCode = [udf].GroupCode
            AND	ed.SSN = [udf].SSN
            AND ed.Department = ISNULL(t.DeptNo, udf.deptno)
        LEFT JOIN TimeHistory.[dbo].[tblEmplNames_Depts] AS edh WITH (NOLOCK)
            ON	[edh].Client = [udf].Client
            AND	[edh].GroupCode = [udf].GroupCode
            AND	[edh].SSN = [udf].SSN
            AND [edh].Department = ISNULL(t.DeptNo, udf.deptno)
            AND [edh].PayrollPeriodEndDate = [udf].PayrollPeriodEndDate
        Inner Join TimeCurrent.dbo.tblUDF_FieldDefs AS fd WITH (NOLOCK)
        on fd.FieldID = udf.FieldID     
    WHERE	[udf].Client = @Client 
        AND [udf].GroupCode = @GroupCode 
        AND	[udf].PayrollPeriodEndDate in(@PPED, @PPED2)
        AND isnumeric([udf].FieldValue) = 1
     GROUP BY 
      [udf].ssn
    , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN LTRIM(STR([udf].[SSN]))
                         ELSE [en].[FileNo]
                    END 
    , ISNULL([en].PayGroup,'')
    , [udf].PayrollPeriodEndDate
    , CASE WHEN ISNULL(fd.PayCodeID,'') = '' THEN fd.FieldName ELSE fd.PayCodeID END
    , CASE WHEN LTRIM(ISNULL(t.CostID,'')) = '' 
                            THEN CASE WHEN LTRIM(ISNULL(edh.AssignmentNo,'')) = '' 
                                      THEN CASE WHEN ISNULL(ed.AssignmentNo,'') = '' 
                                                THEN 'MISSING' 
                                                ELSE ed.AssignmentNo
                                           END 
                                      ELSE edh.AssignmentNo
                                 END 
                            ELSE t.CostID
                       END
    , [en].[FirstName]
    , [en].[LastName]
    , [udf].[TransDate]
	, ISNULL(ag.AgencyName,'')
END

-- APPROVER
UPDATE X SET
ApproverName = ISNULL(CASE WHEN [bkp].[RecordId] IS NOT NULL
                                       THEN [bkp].[FirstName] + ' ' + [bkp].[LastName]
                                       ELSE (CASE   WHEN LEN(X.ApproverName) < 2
                                                    THEN [usr].[FirstName] + ' ' + [usr].[LastName]
                                                    ELSE X.ApproverName
                                             END)
                                  END,'')
,ApproverEmail =  ISNULL(CASE WHEN [bkp].[RecordId] IS NOT NULL
               THEN [bkp].[Email]
               ELSE(CASE   WHEN LEN(X.[ApproverEmail]) < 2
                           THEN [usr].[Email]
                           ELSE X.[ApproverEmail]
                    END) 
         END,'')
,ApprovalDate = CASE WHEN THD.AprvlStatus_Date IS NULL THEN '' ELSE REPLACE(CONVERT(VARCHAR(16), THD.AprvlStatus_Date, 112), '-','') END 
FROM #tmpExport AS X
INNER JOIN [TimeHistory].[dbo].[tblTimeHistDetail] AS THD
    ON [THD].[RecordID] = X.RecordID
LEFT JOIN [TimeHistory].[dbo].[tblTimeHistDetail_BackupApproval] AS bkp
    ON [bkp].[THDRecordId] = X.RecordID
LEFT JOIN [TimeCurrent].[dbo].[tblUser] AS usr
    ON [usr].[UserID]= ISNULL([THD].[AprvlStatus_UserID],0)


UPDATE #tmpExport
  SET Line1 = EmplFirst    + @Delim 
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
			+ AgencyName 

UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'

INSERT INTO #tmpExport (SSN,EmpName,AssignmentNo,ApprovalDate,Line1)
VALUES (1,'1','MISSING',getdate(),
'FirstName|LastName|EmplID|Assignment|WeekEnding|TransDate|PayCode|PayAmt|BillAmt|Project|ApprName|ApprEmail|ApprDate|PayGroup|TimeSource|ApprSource|AgencyName')

SELECT * FROM #tmpExport 
--where ApprovalDate <> ''
ORDER BY 
 CASE WHEN AssignmentNo = 'MISSING' THEN '0' ELSE '1' END
,EmpName
,TransactDate
,PayCode
           
           
IF @TestingFlag IN ('N', '0')
BEGIN
 UPDATE en SET
 PayRecordsSent = @Today
 FROM TimeHistory.dbo.tblEmplNames AS en
 INNER JOIN #tmpExport AS Y ON [en].[SSN] = Y.[SSN]
 --and Y.ApprovalDate <> ''
 WHERE
 [en].[Client]= @Client
 AND [en].GroupCode = @GroupCode
 AND [en].[PayrollPeriodEndDate] = Y.[weDate]
 AND [en].[SSN] = Y.[SSN]
 AND ISNULL([en].[PayRecordsSent], '1/1/1970') = '1/1/1970'
END
           
DROP TABLE #tmpExport
RETURN

