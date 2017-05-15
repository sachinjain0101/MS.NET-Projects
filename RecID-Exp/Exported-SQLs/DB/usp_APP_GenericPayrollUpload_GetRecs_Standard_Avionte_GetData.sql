CREATE PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_Standard_Avionte_GetData]
(
    @Client         VARCHAR(4),
    @GroupCode      INT,
    @PPED           DATETIME,
    @PPED2          DATETIME,
    @PAYRATEFLAG    VARCHAR(4),
    @EMPIDType      VARCHAR(6),
    @REGPAYCODE     VARCHAR(10),
    @OTPAYCODE      VARCHAR(10),
    @DTPAYCODE      VARCHAR(10),
    @PayrollType    VARCHAR(32),
    @IncludeSalary  CHAR(1),
    @TestingFlag    CHAR(1) = 'N'
)
AS

SET NOCOUNT ON


/*
  This is only setup to give daily values, if weekly values are needed, then extra logic is needed.  Because the "end date"
  will need to be updated to the maximum value on all assignments after the temp table is finished being populated.
  The "ALL" keywork in @PayrollType is to send all records for the pay period regardless of approval status and the "1z2z"
  procedure will set the "PayrecordsSent" datetime on those as well as the approved records.
*/
DECLARE @Delim CHAR(1)
SET @Delim = '|'
--
-- used for determining time source and approver source
DECLARE @FaxApprover INT
SET @FaxApprover = (SELECT UserID FROM[TimeCurrent].[dbo].tblUser WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER' AND Client = @Client)
--

/* 
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
      SSN                    INT          --Required in VB6: GenericPayrollUpload program
    , EmployeeID             VARCHAR(20)  --Required in VB6: GenericPayrollUpload program
    , EmpName                VARCHAR(120) --Required in VB6: GenericPayrollUpload program
    , FileBreakID            VARCHAR(20)  --The VB6: GenericPayrollUpload program will split apart payfiles on PayGroup from[TimeCurrent].[dbo].tbl_EmplNames
    , weDate                 VARCHAR(8)   --Required in VB6: GenericPayrollUpload program
    , GroupCode              INT  
    , AssignmentNo           VARCHAR(32)
    , PayCode                VARCHAR(32)
    , PayAmount              NUMERIC(7,2)
    , BillAmount             NUMERIC(7,2)
    , SourceTime             VARCHAR(30)
    , SourceApprove          VARCHAR(30)
    , EmplFirst              VARCHAR(20)
    , EmplLast               VARCHAR(20)
    , TransactDate           DATETIME  --VARCHAR(8)
    , ProjectCode            VARCHAR(100)
    , ApproverName           VARCHAR(40)
    , ApproverEmail          VARCHAR(132)
    , ApprovalDate           VARCHAR(14)  --format is: YYYYMMDD HH:MM
    , PayFileGroup           VARCHAR(10)
    , PayBillCode            VARCHAR(10)
    , TransCount             INT
    , ApprovedCount          INT
    , PayRecordsSent         DATETIME 
    , AprvlStatus_Date       DATETIME
    , IVR_Count              INT 
    , WTE_Count              INT
    , Fax_Count              INT
    , FaxApprover_Count      INT
    , Client_Count           INT
    , Branch_Count           INT
    , SubVendorAgency_Count  INT
    , Interface_Count        INT
    , Mobile_Count           INT
    , Mobile_Approver        INT 
    , Clock_Count            INT
    , Web_Approver_ID        INT
    , Web_Approver_Count     INT
    , SnapshotDateTime       DATETIME
	, MinTHDRecord           BIGINT  --< MinTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 10Aug2016 >--
    , Line1                  VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
    , RecordID               INT IDENTITY
)

--Get worked, regular hours
INSERT INTO #tmpExport
   SELECT     
          [SSN] = [hd].[ssn]
        , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                             THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                             ELSE [en].[FileNo]
                        END 
        , [EmpName] = ([en].[FirstName]+' '+[en].[LastName])
        , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].[PayGroup],'')))
        , [weDate] = CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [GroupCode] = [hd].[GroupCode]
        , [AssignmentNo] = CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , [PayCode] = CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                           THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                     THEN @REGPAYCODE 
                                     ELSE [edh].[BillToCode]
                                END
                           ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].[ADP_HoursCode],'')))='' 
                                     THEN 'MISSING'
                                     ELSE [ac].[ADP_HoursCode]
                                END
                      END
        , [PayAmount] = SUM( CASE WHEN [ac].[Payable] ='Y'
                                  THEN [hd].[RegHours]
                                  ELSE 0.0
                             END )
        , [BillAmount] =SUM( CASE WHEN [ac].[Billable] ='Y'
                                  THEN [hd].[RegHours]
                                  ELSE 0.0
                             END )                             
        , [SourceTime]=' '
        , [SourceApprove]=' '
        , [EmplFirst] = [en].[FirstName]
        , [EmplLast] = [en].[LastName]
        , [TransactDate] = [hd].[TransDate]
        , [ProjectCode] = ' '
		,''
		,''
		, [ApprovalDate] = Min(CASE when HD.AprvlStatus_Date IS NULL then '' else REPLACE(convert(varchar(16), hd.AprvlStatus_Date, 112), '-','') END) 
        , [PayFileGroup] = ISNULL([en].[PayGroup],' ')
        , [PayBillCode] = ISNULL([edh].[BilltoCode],' ')
        , [TransCount] = SUM(1)
        , [ApprovedCount]= SUM(CASE WHEN [hd].[AprvlStatus] IN ('A', 'L') THEN 1 ELSE 0 END)
        , [PayRecordsSent] =  [enh].[PayRecordsSent]
        , [AprvlStatus_Date] = MAX(ISNULL([hd].[AprvlStatus_Date],'1/2/1970'))
        , [IVR_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('IVR') THEN 1 ELSE 0 END)
        , [WTE_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('WTE', 'IVS') THEN 1 ELSE 0 END)
        , [Fax_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('FAX') THEN 1 ELSE 0 END )
        , [FaxApprover_Count]= SUM(CASE WHEN ISNULL( [hd].[AprvlStatus_UserID], 0) = @FaxApprover THEN 1 ELSE 0 END)
        , [Client_Count] = SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] = 'CLI') THEN 1 ELSE 0 END)
        , [Branch_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('BRA')) THEN 1 ELSE 0 END)
        , [SubVendorAgency_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('AGE')) THEN 1 ELSE 0 END)
        , [Interface_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('INT')) THEN 1 ELSE 0 END)
        , [Mobile_Count] = SUM( CASE WHEN ISNULL([enh].[Mobile],0) =0 THEN 0 ELSE 1 END )
        , [Mobile_Approver] = SUM( CASE WHEN ISNULL([hd].[AprvlStatus_Mobile],0)=0 THEN 0 ELSE 1 END )
        , [Clock_Count] = SUM (CASE WHEN [sn].[ClockType] <> 'V' THEN 1 ELSE 0 END )
        ,0
        , [Web_Approver_Count]=0
        , [SnapshotDateTime] = GetDate()
		, MIN(hd.RecordID)
        , [Line1]=''
    FROM 
        [TimeHistory].[dbo].[tblTimeHistDetail] AS hd
        INNER JOIN [TimeCurrent].[dbo].[tblEmplNames] AS en
            ON  [en].[Client] = [hd].[Client]
            AND [en].[GroupCode] = [hd].[GroupCode]
            AND [en].[SSN] = [hd].[SSN]
        Left JOIN [TimeCurrent].[dbo].[tblEmplNames_Depts] AS ed
            ON  [ed].[Client] = [hd].[Client]
            AND [ed].[GroupCode] = [hd].[GroupCode]
            AND [ed].[SSN] = [hd].[SSN]
            AND [ed].[Department] = [hd].[DeptNo]
        Left JOIN [TimeCurrent].[dbo].[tblEmplAssignments] AS edh
            ON  [edh].[Client] = [hd].[Client]
            AND [edh].[GroupCode] = [hd].[GroupCode]
            AND [edh].[SiteNo]=[hd].[SiteNo]
            AND [edh].[SSN] = [hd].[SSN]
            AND [edh].[DeptNo] = [hd].[DeptNo]
        INNER JOIN [TimeHistory].[dbo].[tblEmplNames] AS enh
            ON  [enh].[Client] = [hd].[Client]
            AND [enh].[GroupCode] = [hd].[GroupCode]
            AND [enh].[SSN] = [hd].[SSN]
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN [TimeCurrent].[dbo].[tblAdjCodes] AS ac
            ON  [ac].[Client] = [hd].[Client]
            AND [ac].[GroupCode] = [hd].[GroupCode]
            AND [ac].[ClockAdjustmentNo] = CASE WHEN IsNull([hd].[ClockAdjustmentNo], '') IN ('', '8','@',' ') then '1' else [hd].[ClockAdjustmentNo] END
        LEFT JOIN [TimeCurrent].[dbo].[tblAgencies] AS ag
            ON  [ag].[Client] = [en].[Client]
            AND [ag].[GroupCode] = [en].[GroupCode]
            AND [ag].[Agency] = [en].[AgencyNo]
        JOIN [TimeCurrent].[dbo].[tblSiteNames] AS sn
            ON  [hd].[Client] = [sn].[Client]
            AND [hd].[GroupCode] = [sn].[GroupCode]
            AND [hd].SiteNo = [sn].SiteNo
    WHERE   [hd].[Client] = @Client 
        AND [hd].[GroupCode] = @GroupCode 
        AND [hd].[PayrollPeriodEndDate] IN(@PPED, @PPED2)
        AND [hd].[RegHours] <> 0.00
        AND [ac].[Worked]='Y'
        AND ISNULL([ag].[ExcludeFromPayFile],'0') = '0'
        --Get employees that are partially closed or not approved.        
        AND 
          ( @PayrollType LIKE '%ALL%' OR @PayrollType LIKE '%Unapproved%'
            OR
            [hd].[SSN] NOT IN ( SELECT DISTINCT SSN
                        FROM [TimeHistory].[dbo].[tblTimeHistDetail] AS thd
                        WHERE [thd].[Client] = @Client
                        AND [thd].[GroupCode] = @GroupCode
                        AND [thd].[PayrollPeriodEndDate] IN (@PPED, @PPED2)
                        AND [thd].[Hours] <> 0
                        AND ([thd].[InDay] = 10 OR [thd].[OutDay] = 10 OR [thd].[AprvlStatus] NOT IN ('A','L')) )
           )
        AND (@PayrollType LIKE '%IGNOREPAYRECORDSSENT%' OR ISNULL([enh].PayRecordsSent, '1/1/1970') = '1/1/1970')
    GROUP BY 
          [hd].[ssn]
        , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                         ELSE [en].[FileNo]
          END 
        , ([en].[FirstName]+' '+[en].[LastName])
        , LTRIM(RTRIM(ISNULL([en].[PayGroup],'')))
        , CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [hd].[GroupCode]
        , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                       THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].[ADP_HoursCode],'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
         END
        , [en].[FirstName]
        , [en].[LastName]
        , [hd].[TransDate]
        , ISNULL([en].[PayGroup],' ')
        , ISNULL([edh].[BilltoCode],' ')
        , [enh].[PayRecordsSent]

   
--Get non-worked regular  hours
INSERT INTO #tmpExport
 SELECT     
      [SSN] = [hd].SSN
    , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                         ELSE [en].[FileNo]
                    END 
        , [EmpName] = ([en].[FirstName]+' '+[en].[LastName])
        , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].[PayGroup],' ')))        
        , [weDate] = CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [GroupCode] = [hd].[GroupCode]
        , [AssignmentNo] = CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , [PayCode] = CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                           THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                     THEN @REGPAYCODE 
                                     ELSE [edh].[BillToCode]
                                END
                           ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                     THEN 'MISSING'
                                     ELSE [ac].[ADP_HoursCode]
                                END
                      END
        , [PayAmount] = SUM( CASE WHEN [ac].[Payable] ='Y'
                                  THEN [hd].[RegHours]
                                  ELSE 0.0
                             END )
        , [BillAmount] =SUM( CASE WHEN [ac].[Billable] ='Y'
                                  THEN [hd].[RegHours]
                                  ELSE 0.0
                             END )                             
        , [SourceTime]=' '
        , [SourceApprove]=' '
        , [EmplFirst] = [en].[FirstName]
        , [EmplLast] = [en].[LastName]
        , [TransactDate] = [hd].[TransDate]
        , [ProjectCode] = ' '
        , ''
		, ''
		, [ApprovalDate] = Min(CASE when HD.AprvlStatus_Date IS NULL then '' else REPLACE(convert(varchar(16), hd.AprvlStatus_Date, 112), '-','') END) 
        , [PayFileGroup] = ISNULL([en].[PayGroup],' ')
        , [PayBillCode] = ISNULL([edh].[BilltoCode],' ')
        , [TransCount] = SUM(1)
        , [ApprovedCount]= SUM(CASE WHEN [hd].[AprvlStatus] IN ('A', 'L') THEN 1 ELSE 0 END)
        , [PayRecordsSent] =  [enh].[PayRecordsSent]
        , [AprvlStatus_Date] = MAX(ISNULL([hd].[AprvlStatus_Date],'1/2/1970'))
        , [IVR_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('IVR') THEN 1 ELSE 0 END)
        , [WTE_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('WTE', 'IVS') THEN 1 ELSE 0 END)
        , [Fax_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('FAX') THEN 1 ELSE 0 END )
        , [FaxApprover_Count]= SUM(CASE WHEN ISNULL( [hd].[AprvlStatus_UserID], 0) = @FaxApprover THEN 1 ELSE 0 END)
        , [Client_Count] = SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] = 'CLI') THEN 1 ELSE 0 END)
        , [Branch_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('BRA')) THEN 1 ELSE 0 END)
        , [SubVendorAgency_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('AGE')) THEN 1 ELSE 0 END)
        , [Interface_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('INT')) THEN 1 ELSE 0 END)
        , [Mobile_Count] = SUM( CASE WHEN ISNULL([enh].[Mobile],0) =0 THEN 0 ELSE 1 END )
        , [Mobile_Approver] = SUM( CASE WHEN ISNULL([hd].[AprvlStatus_Mobile],0)=0 THEN 0 ELSE 1 END )
        , [Clock_Count] = SUM (CASE WHEN [sn].[ClockType] <> 'V' THEN 1 ELSE 0 END )
        , 0
        , [Web_Approver_Count]=0
        , [SnapshotDateTime] = GetDate()
		, MIN(hd.RecordID)
        , [Line1]=''
    FROM 
        [TimeHistory].[dbo].[tblTimeHistDetail] as hd
        INNER JOIN[TimeCurrent].[dbo].[tblEmplNames] as en
            ON  [en].[Client] = [hd].[Client]
            AND [en].[GroupCode] = [hd].[GroupCode]
            AND [en].[SSN] = [hd].[SSN]
        Left JOIN[TimeCurrent].[dbo].[tblEmplNames_Depts] as ed
            ON  [ed].[Client] = [hd].[Client]
            AND [ed].[GroupCode] = [hd].[GroupCode]
            AND [ed].[SSN] = [hd].[SSN]
            AND [ed].[Department] = [hd].[DeptNo]
        Left JOIN[TimeCurrent].[dbo].[tblEmplAssignments] as edh
            ON  [edh].[Client] = [hd].[Client]
            AND [edh].[GroupCode] = [hd].[GroupCode]
            AND [edh].[SiteNo]=[hd].[SiteNo]
            AND [edh].[SSN] = [hd].[SSN]
            AND [edh].[DeptNo] = [hd].[DeptNo]
        INNER JOIN [TimeHistory]..[tblEmplNames] as enh
            ON  [enh].[Client] = [hd].[Client]
            AND [enh].[GroupCode] = [hd].[GroupCode]
            AND [enh].[SSN] = [hd].[SSN]
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN[TimeCurrent].[dbo].[tblAdjCodes] as ac
            ON  [ac].[Client] = [hd].[Client]
            AND [ac].[GroupCode] = [hd].[GroupCode]
            AND [ac].[ClockAdjustmentNo] = CASE WHEN IsNull([hd].[ClockAdjustmentNo], '') IN ('', '8','@',' ') then '1' else [hd].[ClockAdjustmentNo] END
        LEFT JOIN[TimeCurrent].[dbo].[tblAgencies] AS ag
            ON  [ag].[Client] = [en].[Client]
            AND [ag].[GroupCode] = [en].[GroupCode]
            AND [ag].[Agency] = [en].[AgencyNo]
        JOIN [TimeCurrent].[dbo].[tblSiteNames] AS sn
            ON  [hd].[Client] = [sn].[Client]
            AND [hd].[GroupCode] = [sn].[GroupCode]
            AND [hd].SiteNo = [sn].SiteNo
    WHERE   [hd].[Client] = @Client 
        AND [hd].[GroupCode] = @GroupCode 
        AND [hd].[PayrollPeriodEndDate] IN(@PPED, @PPED2)
        AND [hd].[RegHours] <> 0.00
        AND [ac].[Worked]<>'Y'
        AND ISNULL([ag].[ExcludeFromPayFile],'0') = '0'
        --Get employees that are partially closed or not approved.        
        AND 
          ( @PayrollType LIKE '%ALL%' OR @PayrollType LIKE '%Unapproved%'
            OR
            [hd].[SSN] NOT IN ( SELECT DISTINCT SSN
                        FROM [TimeHistory].[dbo].[tblTimeHistDetail] AS thd
                        WHERE [thd].[Client] = @Client
                        AND [thd].[GroupCode] = @GroupCode
                        AND [thd].[PayrollPeriodEndDate] IN (@PPED, @PPED2)
                        AND [thd].[Hours] <> 0
                        AND ([thd].[InDay] = 10 OR [thd].[OutDay] = 10 OR [thd].[AprvlStatus] NOT IN ('A','L')) )
           )
        AND (@PayrollType LIKE '%IGNOREPAYRECORDSSENT%' OR ISNULL([enh].PayRecordsSent, '1/1/1970') = '1/1/1970')
    GROUP BY 
          [hd].[ssn]
        , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                         ELSE [en].[FileNo]
          END 
        , ([en].[FirstName]+' '+[en].[LastName])
        , LTRIM(RTRIM(ISNULL([en].[PayGroup],'')))
        , CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [hd].[GroupCode]
        , CASE WHEN LTRIM(ISNULL([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                       THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                 THEN @REGPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].[ADP_HoursCode],'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
         END
        , [en].[FirstName]
        , [en].[LastName]
        , [hd].[TransDate]
        , ISNULL([en].[PayGroup],' ')
        , ISNULL([edh].[BilltoCode],' ')
        , [enh].[PayRecordsSent]
--Get Over time hours
INSERT INTO #tmpExport
 SELECT     
          [SSN] = [hd].SSN
        , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                         ELSE [en].[FileNo]
                    END 
        , [EmpName] = ([en].[FirstName]+' '+[en].[LastName])
        , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].[PayGroup],' ')))
        , [weDate] = CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [GroupCode] = [hd].[GroupCode]
        , [AssignmentNo] = CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , [PayCode] = CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                           THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                     THEN @OTPAYCODE 
                                     ELSE [edh].[BillToCode]
                                END
                           ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                     THEN 'MISSING'
                                     ELSE [ac].[ADP_HoursCode]
                                END
                      END
        , [PayAmount] = SUM( CASE WHEN [ac].[Payable] ='Y'
                                  THEN [hd].[OT_Hours]
                                  ELSE 0.0
                             END )
        , [BillAmount] =SUM( CASE WHEN [ac].[Billable] ='Y'
                                  THEN [hd].[OT_Hours]
                                  ELSE 0.0
                             END )                             
        , [SourceTime]=' '
        , [SourceApprove]=' '
        , [EmplFirst] = [en].[FirstName]
        , [EmplLast] = [en].[LastName]
        , [TransactDate] = [hd].[TransDate]
        , [ProjectCode] = ' '
        ,''
		,''
		, [ApprovalDate] = MIN(CASE when HD.AprvlStatus_Date IS NULL then '' else REPLACE(convert(varchar(16), hd.AprvlStatus_Date, 112), '-','') END) 
        , [PayFileGroup] = ISNULL([en].[PayGroup],' ')
        , [PayBillCode] = ISNULL([edh].[BilltoCode],' ')
        , [TransCount] = SUM(1)
        , [ApprovedCount]= SUM(CASE WHEN [hd].[AprvlStatus] IN ('A', 'L') THEN 1 ELSE 0 END)
        , [PayRecordsSent] =  [enh].[PayRecordsSent]
        , [AprvlStatus_Date] = MIN(ISNULL([hd].[AprvlStatus_Date],'1/2/1970'))
        , [IVR_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('IVR') THEN 1 ELSE 0 END)
        , [WTE_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('WTE', 'IVS') THEN 1 ELSE 0 END)
        , [Fax_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('FAX') THEN 1 ELSE 0 END )
        , [FaxApprover_Count]= SUM(CASE WHEN ISNULL( [hd].[AprvlStatus_UserID], 0) = @FaxApprover THEN 1 ELSE 0 END)
        , [Client_Count] = SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] = 'CLI') THEN 1 ELSE 0 END)
        , [Branch_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('BRA')) THEN 1 ELSE 0 END)
        , [SubVendorAgency_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('AGE')) THEN 1 ELSE 0 END)
        , [Interface_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('INT')) THEN 1 ELSE 0 END)
        , [Mobile_Count] = SUM( CASE WHEN ISNULL([enh].[Mobile],0) =0 THEN 0 ELSE 1 END )
        , [Mobile_Approver] = SUM( CASE WHEN ISNULL([hd].[AprvlStatus_Mobile],0)=0 THEN 0 ELSE 1 END )
        , [Clock_Count] = SUM (CASE WHEN [sn].[ClockType] <> 'V' THEN 1 ELSE 0 END )
        , 0
        , [Web_Approver_Count]=0
        , [SnapshotDateTime] = GetDate()
		, MIN(hd.RecordID)
        , [Line1]=''
    FROM 
        [TimeHistory].[dbo].[tblTimeHistDetail] as hd
        INNER JOIN[TimeCurrent].[dbo].[tblEmplNames] as en
            ON  [en].[Client] = [hd].[Client]
            AND [en].[GroupCode] = [hd].[GroupCode]
            AND [en].[SSN] = [hd].[SSN]
        Left JOIN[TimeCurrent].[dbo].[tblEmplNames_Depts] as ed
            ON  [ed].[Client] = [hd].[Client]
            AND [ed].[GroupCode] = [hd].[GroupCode]
            AND [ed].[SSN] = [hd].[SSN]
            AND [ed].[Department] = [hd].[DeptNo]
        Left JOIN[TimeCurrent].[dbo].[tblEmplAssignments] as edh
            ON  [edh].[Client] = [hd].[Client]
            AND [edh].[GroupCode] = [hd].[GroupCode]
            AND [edh].[SiteNo]=[hd].[SiteNo]
            AND [edh].[SSN] = [hd].[SSN]
            AND [edh].[DeptNo] = [hd].[DeptNo]
        INNER JOIN [TimeHistory]..[tblEmplNames] as enh
            ON  [enh].[Client] = [hd].[Client]
            AND [enh].[GroupCode] = [hd].[GroupCode]
            AND [enh].[SSN] = [hd].[SSN]
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN[TimeCurrent].[dbo].[tblAdjCodes] as ac
            ON  [ac].[Client] = [hd].[Client]
            AND [ac].[GroupCode] = [hd].[GroupCode]
            AND [ac].[ClockAdjustmentNo] = CASE WHEN IsNull([hd].[ClockAdjustmentNo], '') IN ('', '8','@',' ') then '1' else [hd].[ClockAdjustmentNo] END
        LEFT JOIN[TimeCurrent].[dbo].[tblAgencies] as ag
            ON  [ag].[Client] = [en].[Client]
            AND [ag].[GroupCode] = [en].[GroupCode]
            AND [ag].[Agency] = [en].[AgencyNo]
         JOIN [TimeCurrent].[dbo].[tblSiteNames] AS sn
            ON  [hd].[Client] = [sn].[Client]
            AND [hd].[GroupCode] = [sn].[GroupCode]
            AND [hd].SiteNo = [sn].SiteNo
   WHERE   [hd].[Client] = @Client 
        AND [hd].[GroupCode] = @GroupCode 
        AND [hd].[PayrollPeriodEndDate] in(@PPED, @PPED2)
        AND [hd].[OT_Hours] <> 0.00
        AND isnull([ag].[ExcludeFromPayFile],'0') = '0'
        --Get employees that are partially closed or not approved.        
        AND 
          ( @PayrollType LIKE '%ALL%' OR @PayrollType LIKE '%Unapproved%'
            OR
            [hd].[SSN] NOT IN ( SELECT DISTINCT SSN
                        FROM [TimeHistory].[dbo].[tblTimeHistDetail] AS thd
                        WHERE [thd].[Client] = @Client
                        AND [thd].[GroupCode] = @GroupCode
                        AND [thd].[PayrollPeriodEndDate] in (@PPED, @PPED2)
                        AND [thd].[Hours] <> 0
                        AND ([thd].[InDay] = 10 OR [thd].[OutDay] = 10 OR [thd].[AprvlStatus] NOT IN ('A','L')) )
           )
        AND (@PayrollType LIKE '%IGNOREPAYRECORDSSENT%' OR ISNULL([enh].PayRecordsSent, '1/1/1970') = '1/1/1970')
    GROUP BY 
          [hd].[ssn]
        , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                         ELSE [en].[FileNo]
          END 
        , ([en].[FirstName]+' '+[en].[LastName])
        , LTRIM(RTRIM(ISNULL([en].[PayGroup],'')))
        , CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [hd].[GroupCode]
        , CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                       THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                 THEN @OTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].[ADP_HoursCode],'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
         END
        , [en].[FirstName]
        , [en].[LastName]
        , [hd].[TransDate]
        , ISNULL([en].[PayGroup],' ')
        , ISNULL([edh].[BilltoCode],' ')
        , [enh].[PayRecordsSent]
--Get Doubletime hours
INSERT INTO #tmpExport
 SELECT     
        [SSN] = [hd].SSN
        , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                             THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                             ELSE [en].[FileNo]
                        END 
        , [EmpName] = ([en].[FirstName]+' '+[en].[LastName])
        , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].[PayGroup],' ')))
        , [weDate] = CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [GroupCode] = [hd].[GroupCode]       
        , [AssignmentNo] = CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , [PayCode] = CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                           THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                     THEN @DTPAYCODE 
                                     ELSE [edh].[BillToCode]
                                END
                           ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].ADP_HoursCode,'')))='' 
                                     THEN 'MISSING'
                                     ELSE [ac].[ADP_HoursCode]
                                END
                      END
        , [PayAmount] = SUM( CASE WHEN [ac].[Payable] ='Y'
                                  THEN [hd].[DT_Hours]
                                  ELSE 0.0
                             END )
        , [BillAmount] =SUM( CASE WHEN [ac].[Billable] ='Y'
                                  THEN [hd].[DT_Hours]
                                  ELSE 0.0
                             END )                             
        , [SourceTime]=' '
        , [SourceApprove]=' '
        , [EmplFirst] = [en].[FirstName]
        , [EmplLast] = [en].[LastName]
        , [TransactDate] = [hd].[TransDate]
        , [ProjectCode] = ' '
        ,''
		,''
		, [ApprovalDate] = MIN(CASE when HD.AprvlStatus_Date IS NULL then '' else REPLACE(convert(varchar(16), hd.AprvlStatus_Date, 112), '-','') END) 
        , [PayFileGroup] = ISNULL([en].[PayGroup],' ')
        , [PayBillCode] = ISNULL([edh].[BilltoCode],' ')
        , [TransCount] = SUM(1)
        , [ApprovedCount]= SUM(CASE WHEN [hd].[AprvlStatus] IN ('A', 'L') THEN 1 ELSE 0 END)
        , [PayRecordsSent] =  [enh].[PayRecordsSent]
        , [AprvlStatus_Date] = MIN(ISNULL([hd].[AprvlStatus_Date],'1/2/1970'))
        , [IVR_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('IVR') THEN 1 ELSE 0 END)
        , [WTE_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('WTE', 'IVS') THEN 1 ELSE 0 END)
        , [Fax_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('FAX') THEN 1 ELSE 0 END )
        , [FaxApprover_Count]= SUM(CASE WHEN ISNULL( [hd].[AprvlStatus_UserID], 0) = @FaxApprover THEN 1 ELSE 0 END)
        , [Client_Count] = SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] = 'CLI') THEN 1 ELSE 0 END)
        , [Branch_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('BRA')) THEN 1 ELSE 0 END)
        , [SubVendorAgency_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('AGE')) THEN 1 ELSE 0 END)
        , [Interface_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('INT')) THEN 1 ELSE 0 END)
        , [Mobile_Count] = SUM( CASE WHEN ISNULL([enh].[Mobile],0) =0 THEN 0 ELSE 1 END )
        , [Mobile_Approver] = SUM( CASE WHEN ISNULL([hd].[AprvlStatus_Mobile],0)=0 THEN 0 ELSE 1 END )
        , [Clock_Count] = SUM (CASE WHEN [sn].[ClockType] <> 'V' THEN 1 ELSE 0 END )
        , 0
        , [Web_Approver_Count]=0
        , [SnapshotDateTime] = GetDate()
		, MIN(hd.RecordID)
        , [Line1]=''
    FROM 
        [TimeHistory].[dbo].[tblTimeHistDetail] as hd
        INNER JOIN[TimeCurrent].[dbo].[tblEmplNames] as en
            ON  [en].[Client] = [hd].[Client]
            AND [en].[GroupCode] = [hd].[GroupCode]
            AND [en].[SSN] = [hd].[SSN]
        Left JOIN[TimeCurrent].[dbo].[tblEmplNames_Depts] as ed
            ON  [ed].[Client] = [hd].[Client]
            AND [ed].[GroupCode] = [hd].[GroupCode]
            AND [ed].[SSN] = [hd].[SSN]
            AND [ed].[Department] = [hd].[DeptNo]
        Left JOIN[TimeCurrent].[dbo].[tblEmplAssignments] as edh
            ON  [edh].[Client] = [hd].[Client]
            AND [edh].[GroupCode] = [hd].[GroupCode]
            AND [edh].[SiteNo]=[hd].[SiteNo]
            AND [edh].[SSN] = [hd].[SSN]
            AND [edh].[DeptNo] = [hd].[DeptNo]
        INNER JOIN [TimeHistory]..[tblEmplNames] as enh
            ON  [enh].[Client] = [hd].[Client]
            AND [enh].[GroupCode] = [hd].[GroupCode]
            AND [enh].[SSN] = [hd].[SSN]
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN[TimeCurrent].[dbo].[tblAdjCodes] as ac
            ON  [ac].[Client] = [hd].[Client]
            AND [ac].[GroupCode] = [hd].[GroupCode]
            AND [ac].[ClockAdjustmentNo] = CASE WHEN IsNull([hd].[ClockAdjustmentNo], '') IN ('', '8','@',' ') then '1' else [hd].[ClockAdjustmentNo] END
        LEFT JOIN[TimeCurrent].[dbo].[tblAgencies] as ag
            ON  [ag].[Client] = [en].[Client]
            AND [ag].[GroupCode] = [en].[GroupCode]
            AND [ag].[Agency] = [en].[AgencyNo]
        JOIN [TimeCurrent].[dbo].[tblSiteNames] AS sn
            ON  [hd].[Client] = [sn].[Client]
            AND [hd].[GroupCode] = [sn].[GroupCode]
            AND [hd].SiteNo = [sn].SiteNo
    WHERE   [hd].[Client] = @Client 
        AND [hd].[GroupCode] = @GroupCode 
        AND [hd].[PayrollPeriodEndDate] in(@PPED, @PPED2)
        AND [hd].[DT_Hours] <> 0.00
        AND isnull([ag].[ExcludeFromPayFile],'0') = '0'
        --Get employees that are partially closed or not approved.        
        AND 
          ( @PayrollType LIKE '%ALL%' OR @PayrollType LIKE '%Unapproved%'
            OR
            [hd].[SSN] NOT IN ( SELECT DISTINCT SSN
                        FROM [TimeHistory].[dbo].[tblTimeHistDetail] AS thd
                        WHERE [thd].[Client] = @Client
                        AND [thd].[GroupCode] = @GroupCode
                        AND [thd].[PayrollPeriodEndDate] in (@PPED, @PPED2)
                        AND [thd].[Hours] <> 0
                        AND ([thd].[InDay] = 10 OR [thd].[OutDay] = 10 OR [thd].[AprvlStatus] NOT IN ('A','L')) )
           )
        AND (@PayrollType LIKE '%IGNOREPAYRECORDSSENT%' OR ISNULL([enh].PayRecordsSent, '1/1/1970') = '1/1/1970')
    GROUP BY 
          [hd].[ssn]
        , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                         ELSE [en].[FileNo]
          END 
        , ([en].[FirstName]+' '+[en].[LastName])
        , LTRIM(RTRIM(ISNULL([en].[PayGroup],'')))
        , CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [hd].[GroupCode]
        , CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , CASE WHEN [ac].[ClockAdjustmentNo] = '1' 
                       THEN CASE WHEN ISNULL([edh].[BilltoCode],' ') = ''
                                 THEN @DTPAYCODE 
                                 ELSE [edh].[BillToCode]
                            END
                       ELSE CASE WHEN LTRIM(RTRIM(ISNULL([ac].[ADP_HoursCode],'')))='' 
                                 THEN 'MISSING'
                                 ELSE [ac].[ADP_HoursCode]
                            END
         END
        , [en].[FirstName]
        , [en].[LastName]
        , [hd].[TransDate]
        , ISNULL([en].[PayGroup],' ')
        , ISNULL([edh].[BilltoCode],' ')
        , [enh].[PayRecordsSent]
--Get Dollars if found
INSERT INTO #tmpExport
 SELECT     
        [SSN] = [hd].SSN
        , [EmployeeID]= CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                             THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                             ELSE [en].[FileNo]
                        END 
        , [EmpName] = ([en].[FirstName]+' '+[en].[LastName])
        , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].[PayGroup],' ')))
        , [weDate] = CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [GroupCode] = [hd].[GroupCode]
        , [AssignmentNo] = CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , [PayCode] = ac.ADP_EarningsCode
        , [PayAmount] = SUM( CASE WHEN [ac].[Payable] ='Y'
                                  THEN [hd].[Dollars]
                                  ELSE 0.0
                             END )
        , [BillAmount] =SUM( CASE WHEN [ac].[Billable] ='Y'
                                  THEN [hd].[Dollars]
                                  ELSE 0.0
                             END )                             
        , [SourceTime]=' '
        , [SourceApprove]=' '
        , [EmplFirst] = [en].[FirstName]
        , [EmplLast] = [en].[LastName]
        , [TransactDate] = [hd].[TransDate]
        , [ProjectCode] = ' '
        ,''
		,''
		, [ApprovalDate] = MIN(CASE when HD.AprvlStatus_Date IS NULL then '' else REPLACE(convert(varchar(16), hd.AprvlStatus_Date, 112), '-','') END) 
        , [PayFileGroup] = ISNULL([en].[PayGroup],' ')
        , [PayBillCode] = ISNULL([edh].[BilltoCode],' ')
        , [TransCount] = SUM(1)
        , [ApprovedCount]= SUM(CASE WHEN [hd].[AprvlStatus] IN ('A', 'L') THEN 1 ELSE 0 END)
        , [PayRecordsSent] =  [enh].[PayRecordsSent]
        , [AprvlStatus_Date] = MIN(ISNULL([hd].[AprvlStatus_Date],'1/2/1970'))
        , [IVR_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('IVR') THEN 1 ELSE 0 END)
        , [WTE_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('WTE', 'IVS') THEN 1 ELSE 0 END)
        , [Fax_Count] = SUM(CASE WHEN [hd].[UserCode] IN ('FAX') THEN 1 ELSE 0 END )
        , [FaxApprover_Count]= SUM(CASE WHEN ISNULL( [hd].[AprvlStatus_UserID], 0) = @FaxApprover THEN 1 ELSE 0 END)
        , [Client_Count] = SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] = 'CLI') THEN 1 ELSE 0 END)
        , [Branch_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('BRA')) THEN 1 ELSE 0 END)
        , [SubVendorAgency_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('AGE')) THEN 1 ELSE 0 END)
        , [Interface_Count] =  SUM(CASE WHEN ([hd].[UserCode] <> [hd].[OutUserCode] AND [hd].[OutUserCode] IN ('INT')) THEN 1 ELSE 0 END)
        , [Mobile_Count] = SUM( CASE WHEN ISNULL([enh].[Mobile],0) =0 THEN 0 ELSE 1 END )
        , [Mobile_Approver] = SUM( CASE WHEN ISNULL([hd].[AprvlStatus_Mobile],0)=0 THEN 0 ELSE 1 END )
        , [Clock_Count] = SUM (CASE WHEN [sn].[ClockType] <> 'V' THEN 1 ELSE 0 END )
        , 0
        , [Web_Approver_Count]=0
        , [SnapshotDateTime] = GetDate()
		, MIN(hd.RecordID)
        , [Line1]=''
    FROM 
        [TimeHistory].[dbo].[tblTimeHistDetail] as hd
        INNER JOIN[TimeCurrent].[dbo].[tblEmplNames] as en
            ON  [en].[Client] = [hd].[Client]
            AND [en].[GroupCode] = [hd].[GroupCode]
            AND [en].[SSN] = [hd].[SSN]
        Left JOIN[TimeCurrent].[dbo].[tblEmplNames_Depts] as ed
            ON  [ed].[Client] = [hd].[Client]
            AND [ed].[GroupCode] = [hd].[GroupCode]
            AND [ed].[SSN] = [hd].[SSN]
            AND [ed].[Department] = [hd].[DeptNo]
        Left JOIN[TimeCurrent].[dbo].[tblEmplAssignments] as edh
            ON  [edh].[Client] = [hd].[Client]
            AND [edh].[GroupCode] = [hd].[GroupCode]
            AND [edh].[SiteNo]=[hd].[SiteNo]
            AND [edh].[SSN] = [hd].[SSN]
            AND [edh].[DeptNo] = [hd].[DeptNo]
        INNER JOIN [TimeHistory]..[tblEmplNames] as enh
            ON  [enh].[Client] = [hd].[Client]
            AND [enh].[GroupCode] = [hd].[GroupCode]
            AND [enh].[SSN] = [hd].[SSN]
            AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
        INNER JOIN[TimeCurrent].[dbo].[tblAdjCodes] as ac
            ON  [ac].[Client] = [hd].[Client]
            AND [ac].[GroupCode] = [hd].[GroupCode]
            AND [ac].[ClockAdjustmentNo] = CASE WHEN IsNull([hd].[ClockAdjustmentNo], '') IN ('', '8','@',' ') then '1' else [hd].[ClockAdjustmentNo] END
        LEFT JOIN[TimeCurrent].[dbo].[tblAgencies] as ag
            ON  [ag].[Client] = [en].[Client]
            AND [ag].[GroupCode] = [en].[GroupCode]
            AND [ag].[Agency] = [en].[AgencyNo]
        JOIN [TimeCurrent].[dbo].[tblSiteNames] AS sn
            ON  [hd].[Client] = [sn].[Client]
            AND [hd].[GroupCode] = [sn].[GroupCode]
            AND [hd].SiteNo = [sn].SiteNo
    WHERE   [hd].[Client] = @Client 
        AND [hd].[GroupCode] = @GroupCode 
        AND [hd].[PayrollPeriodEndDate] in(@PPED, @PPED2)
        AND [hd].[Dollars] <> 0.00
        AND isnull([ag].[ExcludeFromPayFile],'0') = '0'
        --Get employees that are partially closed or not approved.        
        AND 
          ( @PayrollType LIKE '%ALL%' OR @PayrollType LIKE '%Unapproved%'
            OR
            [hd].[SSN] NOT IN ( SELECT DISTINCT SSN
                        FROM [TimeHistory].[dbo].[tblTimeHistDetail] AS thd
                        WHERE [thd].[Client] = @Client
                        AND [thd].[GroupCode] = @GroupCode
                        AND [thd].[PayrollPeriodEndDate] in (@PPED, @PPED2)
                        AND [thd].[Hours] <> 0
                        AND ([thd].[InDay] = 10 OR [thd].[OutDay] = 10 OR [thd].[AprvlStatus] NOT IN ('A','L')) )
           )
        AND (@PayrollType LIKE '%IGNOREPAYRECORDSSENT%' OR ISNULL([enh].PayRecordsSent, '1/1/1970') = '1/1/1970')
    GROUP BY 
          [hd].[ssn]
        , CASE WHEN UPPER(@EMPIDType) LIKE '%SSN%'
                         THEN RIGHT( '000000000' + CONVERT (VARCHAR(10),[hd].[SSN]),9)
                         ELSE [en].[FileNo]
          END 
        , ([en].[FirstName]+' '+[en].[LastName])
        , LTRIM(RTRIM(ISNULL([en].[PayGroup],'')))
        , CONVERT(VARCHAR(8), [hd].[Payrollperiodenddate], 112)
        , [hd].[GroupCode]
        , CASE WHEN ltrim(isnull([edh].[AssignmentNo],'')) = '' THEN 'MISSING' ELSE [edh].[AssignmentNo] END
        , [en].[FirstName]
        , [en].[LastName]
        , [hd].[TransDate]
        , ISNULL([en].[PayGroup],' ')
        , ISNULL([edh].[BilltoCode],' ')
        , [enh].[PayRecordsSent]
        , [ac].[ADP_EarningsCode]

DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0

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
    ON [THD].RecordId = #tmpExport.MinTHDRecord
LEFT JOIN [TimeHistory].[dbo].[tblTimeHistDetail_BackupApproval] AS bkp
    ON [bkp].[THDRecordId] = [THD].[RecordID]
LEFT JOIN [TimeCurrent].[dbo].[tblUser] AS usr
    ON ISNULL([THD].[AprvlStatus_UserID],0)= [usr].[USERID]



--    
-- Summarize the project information incase it has duplicates   
CREATE TABLE #tmpProjectSummary
(
    [RecordID]     INT IDENTITY,
    [SSN]          INT, 
    [AssignmentNo] VARCHAR(100), 
    [TransactDate]    DATETIME, 
    [ProjectNum]   VARCHAR(100), 
    [Hours]        NUMERIC(7,2),
    [RemHours]     NUMERIC(7,2),
    [OrderID]      INT
)      
INSERT INTO #tmpProjectSummary (
      SSN
    , AssignmentNo
    , TransactDate
    , ProjectNum
    , [Hours] 
    , [RemHours]
    , [OrderID])
SELECT 
      pr.[SSN]
    , ea.[AssignmentNo]
    , pr.TransDate
    , pr.ProjectNum
    , [Hours] = pr.[Hours]
    , [RemHours]= [pr].[Hours]
    , [pr].[RecordId]
FROM [TimeHistory].[dbo].[tblWTE_Spreadsheet_Project] pr
INNER JOIN [TimeCurrent].[dbo].[tblEmplAssignments] ea
    ON  ea.[Client] = pr.[Client]
    AND ea.[GroupCode] = pr.[GroupCode]
    AND ea.[SSN] = pr.[SSN]
    AND ea.SiteNo = pr.SiteNo
    AND ea.DeptNo = pr.DeptNo
INNER JOIN #tmpExport AS S
    ON  S.[SSN] = pr.[SSN]
    AND S.[AssignmentNo] = ea.[AssignmentNo]
WHERE 
        pr.[Client] = @Client
    AND pr.[GroupCode] = @GroupCode
    AND pr.[PayrollPeriodEndDate] = @PPED
  
GROUP BY 
      pr.[SSN]
    , ea.[AssignmentNo]
    , pr.TransDate
    , pr.ProjectNum
    , [pr].[Hours]
    , [pr].[RecordId]
ORDER BY [pr].[RecordId]      

IF EXISTS(SELECT 1 FROM #tmpProjectSummary)
BEGIN
-- Process the projects and merge it in with the time data
    DECLARE @SSN                 INT
    DECLARE @AssignmentNo        VARCHAR(32)
    DECLARE @TransDate           DATETIME
    DECLARE @ProjectNum          VARCHAR(200)
    DECLARE @Hours               NUMERIC(7,2)
    DECLARE @PaidHours           NUMERIC(7,2)
    DECLARE @BilledHours         NUMERIC(7,2)
    DECLARE @RecordID            INT
    DECLARE @PayCode             VARCHAR(8)

    DECLARE @TotalProjectLines   INT 
    DECLARE @LoopCounter         INT 
    DECLARE @MinProjectId        INT 
    DECLARE @ProjectHours        NUMERIC(7,2)
    DECLARE @RemainingHours      NUMERIC(7,2)
    
    DECLARE @RegBalance          NUMERIC(7,2) = 0.0
    DECLARE @OTBalance           NUMERIC(7,2) = 0.0
    DECLARE @DTBalance           NUMERIC(7,2) = 0.0
    DECLARE @ADJBalance          NUMERIC(7,2) = 0.0
    DECLARE @RegAvailable        NUMERIC(7,2) = 0.0
    DECLARE @OTAvailable         NUMERIC(7,2) = 0.0
    DECLARE @DTAvailable         NUMERIC(7,2) = 0.0
    DECLARE @ADJAvailable        NUMERIC(7,2) = 0.0
    DECLARE @ProjectRemaining    NUMERIC(7,2) = 0.0
    DECLARE @PayAmount           NUMERIC(7,2) = 0.0
    
    DECLARE @RegBalance_Billed    NUMERIC(7,2) = 0.0
    DECLARE @OTBalance_Billed     NUMERIC(7,2) = 0.0
    DECLARE @DTBalance_Billed     NUMERIC(7,2) = 0.0
    DECLARE @ADJBalance_Billed    NUMERIC(7,2) = 0.0
    DECLARE @RegAvailable_Billed  NUMERIC(7,2) = 0.0
    DECLARE @OTAvailable_Billed   NUMERIC(7,2) = 0.0
    DECLARE @DTAvailable_Billed   NUMERIC(7,2) = 0.0
    DECLARE @ADJAvailable_Billed  NUMERIC(7,2) = 0.0
    DECLARE @ProjRemaining_Billed NUMERIC(7,2) = 0.0
    DECLARE @BillAmount           NUMERIC(7,2) = 0.0
    
    DECLARE @PayCodeSequencer     INT=0
    DECLARE @HoldProjectCode      VARCHAR(100)=''
    DECLARE @HoldProjectHours     NUMERIC(7,2) = 0.0
    DECLARE @HoldRecordID         INT = 0
    DECLARE @HoldAssignmentNo     VARCHAR(200)
    DECLARE @HoldSSN              INT=0.0
    DECLARE @HoldTransDate        DATETIME
 
    DECLARE workedCursor CURSOR READ_ONLY
    FOR SELECT  
          RecordID
        , PayCode
        , PayAmount
        , BillAmount
        , SSN
        , AssignmentNo
        , TransactDate
        , Sequencer = CASE WHEN PayCode = @RegPaycode THEN 1
                           WHEN PayCode = @OTPaycode  THEN 2
                           WHEN PayCode = @DTPaycode  THEN 3
                           ELSE 4
                      END
    FROM [#tmpExport]
    ORDER BY 
          SSN
        , AssignmentNo
        , TransactDate
        , Sequencer ASC
    OPEN workedCursor
        FETCH NEXT FROM workedCursor 
        INTO 
              @RecordID
            , @PayCode
            , @PaidHours
            , @BilledHours
            , @SSN
            , @AssignmentNo
            , @TransDate
            , @PayCodeSequencer
    WHILE (@@fetch_status <> -1)
    BEGIN
        IF (@@fetch_status <> -2)
        BEGIN
            SELECT @LoopCounter = 1
            SELECT @MinProjectId = 0
            
            SELECT @RegBalance = CASE WHEN @PayCode = @REGPAYCODE THEN @PaidHours ELSE 0.0 END
            SELECT @OTBalance =  CASE WHEN @PayCode = @OTPAYCODE THEN @PaidHours ELSE 0.0 END
            SELECT @DTBalance =  CASE WHEN @PayCode = @DTPAYCODE THEN @PaidHours ELSE 0.0 END
            SELECT @ADJBalance = CASE WHEN (@PayCode<>@REGPAYCODE AND @PayCode<>@OTPAYCODE AND @PayCode<>@DTPAYCODE) 
                                      THEN @PaidHours ELSE 0.0 END
            SELECT @RegBalance_Billed = CASE WHEN @PayCode = @REGPAYCODE THEN @BilledHours ELSE 0.0 END
            SELECT @OTBalance_Billed =  CASE WHEN @PayCode = @OTPAYCODE THEN @BilledHours ELSE 0.0 END
            SELECT @DTBalance_Billed =  CASE WHEN @PayCode = @DTPAYCODE THEN @BilledHours ELSE 0.0 END
            SELECT @ADJBalance_Billed = CASE WHEN (@PayCode<>@REGPAYCODE AND @PayCode<>@OTPAYCODE AND @PayCode<>@DTPAYCODE) 
                                             THEN @BilledHours ELSE 0.0 END
                                                                                 
            SELECT @TotalProjectLines = COUNT(*)
            FROM #tmpProjectSummary
            WHERE   SSN = @SSN
                AND TransactDate = @TransDate
                AND AssignmentNo = @AssignmentNo
                AND [Hours] <> 0
                AND [RemHours] <> 0
                    
            IF (@TotalProjectLines > 0)
            BEGIN                           
                SELECT @MinProjectId = MIN(OrderID)
                FROM #tmpProjectSummary
                WHERE   SSN = @SSN
                    AND TransactDate = @TransDate
                    AND AssignmentNo = @AssignmentNo
                    AND [Hours] <> 0.0
                    AND [RemHours] <> 0.0
    
                SELECT @ProjectNum = ProjectNum,
                       @ProjectHours = [Hours],
                       @RemainingHours = [RemHours]
                FROM #tmpProjectSummary
                WHERE    OrderID = @MinProjectId
                    AND [Hours] <> 0.0
                    AND [RemHours] <> 0.0

                IF (@HoldProjectHours > 0.0)
                BEGIN                
	                 INSERT INTO #tmpExport (SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,   PayAmount,  BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, 
                                                            ProjectCode, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, 
                                                            Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, 
                                                            Web_Approver_Count, SnapshotDateTime, Line1 )
                                                    SELECT  @HoldSSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, @HoldAssignmentNo, @PayCode, @HoldProjectHours, @HoldProjectHours, SourceTime, SourceApprove, EmplFirst, EmplLast, @HoldTransDate, 
                                                            @HoldProjectCode, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, 
                                                            Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, 
                                                            Web_Approver_Count, SnapshotDateTime, Line1
                                    FROM #tmpExport WHERE [RecordID] = @RecordID
 
 --SELECT 'DEBUG1', recordid, projectcode, transactdate, * FROM #tmpExport
 
                    SELECT @RegBalance = CASE WHEN @PayCode = @REGPAYCODE THEN (@RegBalance-@HoldProjectHours) ELSE 0.0 END
                    SELECT @OTBalance =  CASE WHEN @PayCode = @OTPAYCODE THEN (@OTBalance-@HoldProjectHours) ELSE 0.0 END
                    SELECT @DTBalance =  CASE WHEN @PayCode = @DTPAYCODE THEN (@DTBalance-@HoldProjectHours) ELSE 0.0 END
                    SELECT @ADJBalance = CASE WHEN (@PayCode<>@REGPAYCODE AND @PayCode<>@OTPAYCODE AND @PayCode<>@DTPAYCODE) 
                                              THEN (@ADJBalance-@HoldProjectHours) ELSE 0.0 END
                    SELECT @RegBalance_Billed = CASE WHEN @PayCode = @REGPAYCODE THEN (@RegBalance_Billed-@HoldProjectHours) ELSE 0.0 END
                    SELECT @OTBalance_Billed  = CASE WHEN @PayCode = @OTPAYCODE THEN (@OTBalance_Billed-@HoldProjectHours) ELSE 0.0 END
                    SELECT @DTBalance_Billed  = CASE WHEN @PayCode = @DTPAYCODE THEN (@DTBalance_Billed-@HoldProjectHours) ELSE 0.0 END
                    SELECT @ADJBalance_Billed = CASE WHEN (@PayCode<>@REGPAYCODE AND @PayCode<>@OTPAYCODE AND @PayCode<>@DTPAYCODE) 
                                              THEN (@ADJBalance_Billed-@HoldProjectHours) ELSE 0.0 END                                              
                    SELECT @ProjectHours = CASE WHEN @PayCode = @REGPAYCODE THEN @RegBalance
                                                WHEN @PayCode = @OTPAYCODE  THEN @OTBalance
                                                WHEN @PayCode = @DTPAYCODE  THEN @OTBalance
                                                ELSE @ADJBalance
                                           END

                    UPDATE #TmpProjectSummary SET [RemHours]= CASE WHEN (RemHours-@HoldProjectHours)>0 THEN (RemHours-@HoldProjectHours) ELSE 0.0 END
                        WHERE  RecordID = @HoldRecordID
                            AND ProjectNum = @HoldProjectCode
                            AND [AssignmentNo] = @HoldAssignmentNo
                            AND [TransactDate] = @HoldTransDate
                            AND SSN = @HoldSSN
 --DEBUG
 --PRINT 'DEBUG1 - @HoldProjectHours ='+ CONVERT(VARCHAR,@HoldProjectHours)
 --SELECT 'DEBUG1', * FROM [#tmpProjectSummary]   
                             
                END
            
                -- BEGIN Balance Calculator                     
                SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END
                SELECT @ProjectRemaining = @ProjectHours - @RegAvailable
                SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END
                SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable
                SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END
                SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable - @DTAvailable            
                SELECT @ADJAvailable = CASE WHEN @ProjectRemaining > @ADJBalance THEN @ADJBalance ELSE @ProjectRemaining END
                SET @RegBalance =@RegBalance - @RegAvailable
                SET @OTBalance  =@OTBalance  - @OTAvailable
                SET @DTBalance  =@DTBalance  - @DTAvailable 
                SET @ADJBalance =@ADJBalance - @ADJAvailable
                
                SELECT @RegAvailable_Billed = CASE WHEN @ProjectHours > @RegBalance_Billed THEN @RegBalance_Billed ELSE @ProjectHours END
                SELECT @ProjRemaining_Billed = @ProjectHours - @RegAvailable_Billed
                SELECT @OTAvailable_Billed = CASE WHEN @ProjRemaining_Billed > @OTBalance_Billed THEN @OTBalance_Billed ELSE @ProjRemaining_Billed END
                SELECT @ProjRemaining_Billed = @ProjectHours - @RegAvailable_Billed - @OTAvailable_Billed         
                SELECT @DTAvailable_Billed = CASE WHEN @ProjRemaining_Billed > @DTBalance_Billed THEN @DTBalance_Billed ELSE @ProjRemaining_Billed END
                SELECT @ProjRemaining_Billed = @ProjectHours - @RegAvailable_Billed - @OTAvailable_Billed - @DTAvailable_Billed
                SELECT @ADJAvailable_Billed = CASE WHEN @ProjRemaining_Billed > @ADJBalance_Billed THEN @ADJBalance_Billed ELSE @ProjRemaining_Billed END
                SET @RegBalance_Billed =@RegBalance_Billed - @RegAvailable_Billed
                SET @OTBalance_Billed  =@OTBalance_Billed  - @OTAvailable_Billed
                SET @DTBalance_Billed  =@DTBalance_Billed  - @DTAvailable_Billed 
                SET @ADJBalance_Billed =@ADJBalance_Billed - @ADJAvailable_Billed                
                
                IF (@RemainingHours <=0.0 ) OR (@ProjectNum = @HoldProjectCode)
                BEGIN
                	SET @ProjectNum=''
                END
                                
                UPDATE #tmpExport
                SET PayAmount = @RegAvailable,
                    BillAmount= @RegAvailable_Billed,
                    ProjectCode = @ProjectNum
                WHERE RecordID = @RecordID AND PayCode = @REGPAYCODE
                   
                UPDATE #tmpExport
                SET PayAmount = @OTAvailable,
                    BillAmount= @OTAvailable_Billed,
                    ProjectCode = @ProjectNum
                WHERE RecordID = @RecordID AND PayCode = @OTPAYCODE

                UPDATE #tmpExport
                SET PayAmount = @DTAvailable,
                    BillAmount= @DTAvailable_Billed,
                    ProjectCode = @ProjectNum
                WHERE RecordID = @RecordID AND PayCode = @DTPAYCODE

                UPDATE #tmpExport
                SET PayAmount = @ADJAvailable,
                    BillAmount= @ADJAvailable_Billed,
                    ProjectCode = @ProjectNum
                WHERE RecordID = @RecordID AND (PayCode <> @REGPAYCODE AND PayCode <> @OTPAYCODE AND PayCode <> @DTPAYCODE)

--SELECT 'DEBUG2', recordid, projectcode, transactdate, * FROM #tmpExport

                UPDATE #tmpProjectSummary SET [RemHours]= CASE WHEN @ProjectRemaining>0 THEN @ProjectRemaining ELSE 0.0 END
                        WHERE  OrderID        = @MinProjectId
                            AND ProjectNum     = @ProjectNum
                            AND [AssignmentNo] = @AssignmentNo
                            AND [TransactDate] = @transDate
                            AND SSN            = @SSN

 --DEBUG
 --PRINT 'DEBUG2 - @ProjectHours = ' + CONVERT (VARCHAR,@ProjectHours)+ '   @RemainingHours='+CONVERT(VARCHAR,@RemainingHours)  

                    
                WHILE ((@LoopCounter <= @TotalProjectLines-1) )
                BEGIN
                    SELECT @MinProjectId = MIN(OrderID)
                    FROM #tmpProjectSummary
                    WHERE SSN = @SSN
                        AND TransactDate = @TransDate
                        AND AssignmentNo = @AssignmentNo
                        AND [Hours] <> 0
                        AND [RemHours] <> 0
                
                    SELECT @ProjectNum = ProjectNum,
                           @ProjectHours = [Hours],
                           @RemainingHours = [RemHours]
                    FROM #tmpProjectSummary
                    WHERE  OrderID = @MinProjectId   
                       AND [Hours] <> 0.0
                       AND [RemHours] <> 0.0
                   
                    -- BEGIN Balance Calculator                     
                    SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END                    
                    SELECT @ProjectRemaining = @ProjectHours - @RegAvailable
                    SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END
                    SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable
                    SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END
                    SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable - @DTAvailable                
                    SELECT @ADJAvailable = CASE WHEN @ProjectRemaining > @ADJBalance THEN @ADJBalance ELSE @ProjectRemaining END
                    SET @RegBalance = @RegBalance - @RegAvailable
                    SET @OTBalance  = @OTBalance - @OTAvailable
                    SET @DTBalance  = @DTBalance - @DTAvailable
                    SET @ADJBalance = @ADJBalance - @ADJAvailable

                    SELECT @RegAvailable_Billed = CASE WHEN @ProjectHours > @RegBalance_Billed THEN @RegBalance_Billed ELSE @ProjectHours END
                    SELECT @ProjRemaining_Billed = @ProjectHours - @RegAvailable_Billed
                    SELECT @OTAvailable_Billed = CASE WHEN @ProjRemaining_Billed > @OTBalance_Billed THEN @OTBalance_Billed ELSE @ProjRemaining_Billed END
                    SELECT @ProjRemaining_Billed = @ProjectHours - @RegAvailable_Billed - @OTAvailable_Billed         
                    SELECT @DTAvailable_Billed = CASE WHEN @ProjRemaining_Billed > @DTBalance THEN @DTBalance_Billed ELSE @ProjRemaining_Billed END
                    SELECT @ProjRemaining_Billed = @ProjectHours - @RegAvailable_Billed - @OTAvailable_Billed - @DTAvailable_Billed
                    SELECT @ADJAvailable_Billed = CASE WHEN @ProjRemaining_Billed > @ADJBalance_Billed THEN @ADJBalance_Billed ELSE @ProjRemaining_Billed END
                    SET @RegBalance_Billed = @RegBalance_Billed - @RegAvailable_Billed
                    SET @OTBalance_Billed  = @OTBalance_Billed - @OTAvailable_Billed
                    SET @DTBalance_Billed  = @DTBalance_Billed - @DTAvailable_Billed
                    SET @ADJBalance_Billed = @ADJBalance_Billed - @ADJAvailable_Billed

                    IF (@RemainingHours <=0.0)
                    BEGIN
                	    SET @ProjectNum=''
                    END
                    -- END Balance Calculator               

                    SET @PayAmount = (CASE WHEN @PayCode = @REGPAYCODE THEN @RegAvailable
                                           WHEN @PayCode = @OTPAYCODE  THEN @OTAvailable
                                           WHEN @PayCode = @DTPAYCODE  THEN @DTAvailable
                                           ELSE @ADJAvailable
                                      END)
                                      
                     SET @BillAmount = (CASE WHEN @PayCode = @REGPAYCODE THEN @RegAvailable_Billed
                                            WHEN @PayCode = @OTPAYCODE  THEN @OTAvailable_Billed
                                            WHEN @PayCode = @DTPAYCODE  THEN @DTAvailable_Billed
                                            ELSE @ADJAvailable_Billed
                                     END)
                    INSERT INTO #tmpExport (SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,   PayAmount,  BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, 
                                            ProjectCode, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, 
                                            Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, 
                                            Web_Approver_Count, SnapshotDateTime, Line1 )
                                    SELECT  SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @PayAmount, @BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, 
                                            @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, 
                                            Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, 
                                            Web_Approver_Count, SnapshotDateTime, Line1
                                   FROM #tmpExport WHERE [RecordID] = @RecordID

--SELECT 'DEBUG3', recordid, projectcode, transactdate, * FROM #tmpExport
                    
                    UPDATE #TmpProjectSummary SET [RemHours]= CASE WHEN (@ProjectRemaining)>=0.0 THEN (@ProjectRemaining) ELSE 0.0 END
                        WHERE   OrderID =@MinProjectId
                            AND ProjectNum = @ProjectNum
                            AND [AssignmentNo] = @AssignmentNo
                            AND [TransactDate]=@transDate
                            AND [SSN] = SSN
 --DEBUG
 --PRINT 'DEBUG3 - @ProjectRemaining ='+ Convert(VARCHAR,@ProjectRemaining)+ '   @RemainingHours='+CONVERT(VARCHAR,@RemainingHours)  + '   @MinProjectId='+CONVERT(VARCHAR,@MinProjectId)+'  @ProjectNum='+@ProjectNum
  
                                
                    SELECT @LoopCounter = @LoopCounter + 1

                END --While loop:(@LoopCounter <= @TotalProjectLines - 1)
                    
                IF (@ProjectRemaining <=0.0)
                BEGIN
                   SET @ProjectNum=''
                END
                    
                IF (@RegBalance > 0.0 AND @RegBalance_Billed > 0.0 )
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,   BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1 )
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @RegBalance, @RegBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId  
                    
--SELECT 'DEBUG REG1', recordid, projectcode, transactdate, * FROM #tmpExport                 
                    
                END  -- IF (@RegBalance > 0.0 AND @RegBalance_Billed > 0.0 )
                
                IF (@RegBalance <= 0.0 AND  @RegBalance_Billed > 0.0 )
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount, BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1 )
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, PayAmount, @RegBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId 
                    
--SELECT 'DEBUG REG2', recordid, projectcode, transactdate, * FROM #tmpExport                 
                    
                      
                END  --  IF (@RegBalance <= 0.0 AND  @RegBalance_Billed > 0.0 )
                
                IF (@RegBalance > 0.0 AND  @RegBalance_Billed <= 0.0 )
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,  BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1 )
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @RegBalance,BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                    
--SELECT 'DEBUG REG3', recordid, projectcode, transactdate, * FROM #tmpExport                 
                    
                END  --  IF (@RegBalance > 0.0 AND  @RegBalance_Billed <= 0.0 )
                
                IF (@OTBalance > 0.0 AND @OTBalance_Billed > 0.0)
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,  BillAmount, SourceTime,        SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @OTBalance, @OTBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                    
--SELECT 'DEBUG OT1', recordid, projectcode, transactdate, * FROM #tmpExport  
               
                END  -- IF (@OTBalance > 0.0 AND @OTBalance_Billed > 0.0)
                
                IF (@OTBalance <= 0.0 AND @OTBalance_Billed > 0.0)
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount, BillAmount,        SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, PayAmount, @OTBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                    
--SELECT 'DEBUG OT2', recordid, projectcode, transactdate, * FROM #tmpExport 
                                    
                END  -- IF (@OTBalance <= 0.0 AND @OTBalance_Billed > 0.0)
                
                IF (@OTBalance > 0.0 AND @OTBalance_Billed <= 0.0)
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,  BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @OTBalance, BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                    
--SELECT 'DEBUG OT3', recordid, projectcode, transactdate, * FROM #tmpExport  
                                   
                END  -- IF (@OTBalance > 0.0 AND @OTBalance_Billed <= 0.0)
                
                IF (@DTBalance > 0.0 AND @DTBalance_Billed > 0.0 )
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,  BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @DTBalance, @DTBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                    
--SELECT 'DEBUG OT4', recordid, projectcode, transactdate, * FROM #tmpExport 
                                    
                END  -- IF (@DTBalance > 0.0 AND @DTBalance_Billed > 0.0 )
                
                IF (@DTBalance <= 0.0 AND @DTBalance_Billed > 0.0 )
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount, BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, PayAmount, @DTBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                END  -- IF (@DTBalance <= 0.0 AND @DTBalance_Billed > 0.0 )
                
                IF (@DTBalance > 0.0 AND @DTBalance_Billed <= 0.0 )
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,  BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @DTBalance, BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                END  -- IF (@DTBalance > 0.0 AND @DTBalance_Billed <= 0.0 )
                
                IF (@ADJBalance > 0.0 AND @ADJBalance_Billed > 0.0)
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,   BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @ADJBalance, @ADJBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                END  -- IF (@ADJBalance > 0.0 AND @ADJBalance_Billed > 0.0 )
                
                IF (@ADJBalance <= 0.0 AND @ADJBalance_Billed > 0.0)
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount, BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, PayAmount, @ADJBalance_Billed, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                END  -- IF (@ADJBalance <= 0.0 AND @ADJBalance_Billed > 0.0 )
                
                IF (@ADJBalance > 0.0 AND @ADJBalance_Billed <= 0.0)
                BEGIN
                    INSERT INTO #tmpExport(SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, PayCode,  PayAmount,   BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, ProjectCode,  ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1)
                                    SELECT SSN, EmployeeID, EmpName, FileBreakID, weDate, GroupCode, AssignmentNo, @PayCode, @ADJBalance, BillAmount, SourceTime, SourceApprove, EmplFirst, EmplLast, TransactDate, @ProjectNum, ApproverName, ApproverEmail, ApprovalDate, PayFileGroup, PayBillCode, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date, IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, Client_Count, Branch_Count, SubVendorAgency_Count, Interface_Count, Mobile_Count, Mobile_Approver, Clock_Count, Web_Approver_ID, Web_Approver_Count, SnapshotDateTime, Line1
                    FROM #tmpExport WHERE [RecordID] = @RecordId
                END  -- IF (@ADJBalance > 0.0 AND @ADJBalance_Billed <= 0.0 )
                
            END  -- IF (@TotalProjectLines > 0)
 
            SET @RegAvailable       = 0.0
            SET @OTAvailable        = 0.0
            SET @DTAvailable        = 0.0
            SET @ADJAvailable       = 0.0

            IF @ProjectRemaining > 0.0
            BEGIN
                SET @HoldProjectCode  = @projectNum
                SET @HoldRecordID     = @MinProjectID
                SET @HoldProjectHours = @ProjectRemaining
                SET @HoldAssignmentNo = @AssignmentNo
                SET @HoldTransDate    = @TransDate
                SET @HoldSSN          = @SSN
                
                UPDATE #TmpProjectSummary SET [RemHours]= CASE WHEN (RemHours >= @ProjectRemaining) THEN @ProjectRemaining ELSE 0.0 END
                WHERE   OrderID =@MinProjectId
                    AND ProjectNum = @ProjectNum
                    AND [AssignmentNo] = @AssignmentNo
                    AND [TransactDate]=@transDate
 --DEBUG
 --PRINT 'DEBUG4 - @ProjectRemaining ='+ Convert(VARCHAR,@ProjectRemaining)
 --SELECT 'DEBUG4', * FROM [#tmpProjectSummary]   
                        
            END
            ELSE
            BEGIN
                SET @HoldProjectCode  = ''
                SET @HoldRecordID     = 0
                SET @HoldProjectHours = 0
                SET @HoldAssignmentNo = ''
                SET @HoldTransDate    = '01/01/1900'
                SET @HoldSSN          = 0
            END
            
            SET @ProjectRemaining   = 0.0
            SET @RegBalance         = 0.0
            SET @OTBalance          = 0.0
            SET @DTBalance          = 0.0
            SET @ADJBalance         = 0.0
            
            SET @RegAvailable_Billed= 0.0
            SET @OTAvailable_Billed = 0.0
            SET @DTAvailable_Billed = 0.0
            SET @ADJAvailable_Billed= 0.0
            SET @RegBalance_Billed  = 0.0
            SET @OTBalance_Billed   = 0.0
            SET @DTBalance_Billed   = 0.0
            SET @ADJBalance_Billed  = 0.0

            SET @PayAmount          = 0.0
            SET @BillAmount         = 0.0
    
        END  -- IF (@@fetch_status <> -2)
 
        FETCH NEXT FROM workedCursor 
        INTO 
              @RecordID
            , @PayCode
            , @PaidHours
            , @BilledHours
            , @SSN
            , @AssignmentNo
            , @TransDate
            , @PayCodeSequencer
    END  -- WHILE (@@fetch_status <> -1)
    CLOSE workedCursor
    DEALLOCATE workedCursor
END  -- IF EXISTS(SELECT 1 FROM #tmpProjectSummary)



DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0

UPDATE [#tmpExport]
  SET [#tmpExport].[Web_Approver_Count] = 1
FROM  [#tmpExport] tmp
 JOIN [TimeCurrent].[dbo].[tblUser]
         ON [tmp].[Web_Approver_ID] = [TimeCurrent].[dbo].[tblUser].[UserID]
         AND [TimeCurrent].[dbo].[tblUser].[RecordStatus]='1'
             
UPDATE #tmpExport SET [SourceTime]= CASE WHEN IVR_Count>0 THEN 'I'
                                         WHEN Fax_Count>0 THEN 'F'
                                         WHEN WTE_Count>0 THEN 'W'
                                         WHEN Client_Count>0 THEN 'D'
                                         WHEN Branch_Count>0 THEN 'B'                                                                                                                           
                                         WHEN SubVendorAgency_Count>0 THEN 'S'
                                         WHEN Interface_Count>0 THEN 'X'
                                         WHEN Clock_Count>0 THEN 'C'
                                         WHEN Mobile_Count>0 THEN 'M'
                                         ELSE 'P'  --PeopleNet Dashboard
                                    END
                    , [SourceApprove]= CASE WHEN FAXApprover_Count>0 THEN 'F'
                                            WHEN Mobile_Approver>0 THEN 'M'
                                            WHEN Web_Approver_Count>0 THEN 'W'
                                            ELSE 'P'   --PeopleNet Dashboard
                                       END
UPDATE #tmpExport
  SET Line1 = ISNULL(EmplFirst, ' ')    + @Delim 
            + ISNULL(EmplLast, ' ')     + @Delim
            + ISNULL(EmployeeID, ' ')   + @Delim
            + ISNULL(AssignmentNo, ' ') + @Delim
            + ISNULL(weDate, ' ')       + @Delim
            + CONVERT( VARCHAR(8),ISNULL(TransactDate, ' '), 112) + @Delim
            + ISNULL(Paycode, ' ')      + @Delim
            + ISNULL(CONVERT (VARCHAR(8), PayAmount), ' ')  + @Delim
            + ISNULL(CONVERT (VARCHAR(8), BillAmount), ' ') + @Delim
            + ISNULL(ProjectCode, ' ')  + @Delim
            + ISNULL(ApproverName, ' ') + @Delim
            + ISNULL(ApproverEmail, ' ')+ @Delim
            + ISNULL(ApprovalDate, ' ') + @Delim
            + ISNULL(PayFileGroup, ' ') + @Delim
            + ISNULL(SourceTime, ' ')   + @Delim
            + ISNULL(SourceApprove, ' ') + @Delim
			+ 'H'


UPDATE #tmpExport  SET EmployeeID = ' ' WHERE AssignmentNo = 'MISSING'
SELECT
    SSN           
  , EmployeeID    
  , EmpName       
  , FileBreakID   
  , weDate        
  , GroupCode     
  , AssignmentNo  
  , PayCode       
  , PayAmount     
  , BillAmount    
  , SourceTime    
  , SourceApprove 
  , EmplFirst     
  , EmplLast      
  , CONVERT(VARCHAR(8), TransactDate , 112) 
  , ProjectCode   
  , ApproverName  
  , ApproverEmail 
  , ApprovalDate  
  , PayFileGroup  
  , PayBillCode   
  , Line1
 FROM #tmpExport 
    ORDER BY CASE WHEN AssignmentNo = 'MISSING'
                  THEN '0' 
                  ELSE '1' 
             END
           , EMPNAME
           , PayCode
           , TransactDate ASC
           
DROP TABLE #tmpExport
DROP TABLE #tmpProjectSummary
RETURN
