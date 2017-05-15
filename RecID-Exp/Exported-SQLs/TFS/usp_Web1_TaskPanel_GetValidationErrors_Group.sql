Create PROCEDURE [dbo].[usp_Web1_TaskPanel_GetValidationErrors_Group]
    (
      @Client VARCHAR(4) ,
      @GroupCode INT ,
      @PPED DATETIME ,
      @UserID INT
    )
AS 
SET NOCOUNT ON 

IF @Client = 'HCPA'
BEGIN
  Exec Timehistory.dbo.usp_Web1_TaskPanel_GetValidationErrors_Group_HCPA @Client, @GroupCode, @PPED, @UserID
  RETURN
END

DECLARE @PPED2 datetime
Set @PPED2 = dateadd(day,-7,@PPED)

Declare @JobID BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 12Oct2016 >--
Set @JobID = (select max(jobID) from refreshwork.[dbo].[tblWork_DAVT_DeptRefresh_Audit] with(nolock))

    SELECT  t.Client, 
            t.RecordID ,
            t.Payrollperiodenddate ,
            t.TransDate ,
            t.Groupcode ,
            g.GroupName ,
            t.SSN ,
            t.SiteNo ,
            sn.SiteName ,
            t.DeptNo ,
            gd.DeptName_Long ,
            AdjCode = t.ClockAdjustmentNo ,
            t.AdjustmentName ,
            en.fileno ,
            en.LastName ,
            en.FirstName ,
            [Hours] = t.Hours + t.Dollars ,
            t.TransType ,
            CASE WHEN ISNULL(t.ClockAdjustmentNo, '') IN ( '', '8' ) THEN TimeCurrent.dbo.fn_GetDateTime(t.ActualInTime, 33)
                 ELSE ''
            END AS InTime,
            CASE WHEN ISNULL(t.ClockAdjustmentNo, '') IN ( '', '8' ) THEN TimeCurrent.dbo.fn_GetDateTime(t.ActualOutTime, 33)
                 ELSE ''
            END AS OutTime,
            en.paytype,
            SalaryError = case when paytype = '1' then 
                            Case when en.PrimarySite <> t.SiteNo then 'Invalid salary allocation setup for site/dept = ' + ltrim(str(t.siteno)) + '/' + ltrim(str(t.deptno))
                            else 'Invalid primary site or primary dept' end 
                          else '' end
    FROM    Timehistory..tblTimeHistdetail AS t WITH ( NOLOCK )
    INNER JOIN TimeCurrent..tblClientGroups AS g
    ON      g.client = t.client
            AND g.groupcode = t.groupcode
    INNER JOIN TimeCurrent..tblEmplNames AS en WITH ( NOLOCK )
    ON      en.client = t.client
            AND en.groupcode = t.groupcode
            AND en.ssn = t.ssn
    INNER JOIN TImeCurrent..tblSIteNames AS sn WITH ( NOLOCK )
    ON      sn.client = t.Client
            AND sn.siteno = t.siteno
    LEFT JOIN TimeCurrent..tblDeptNames AS dn WITH ( NOLOCK )
    ON      dn.Client = sn.Client
            AND dn.Groupcode = sn.groupcode
            AND dn.SiteNo = sn.SiteNo
            AND dn.DeptNo = t.DeptNo
    INNER JOIN TimeCurrent..tblGroupDepts AS gd WITH ( NOLOCK )
    ON      gd.Client = t.Client
            AND gd.groupcode = t.groupcode
            AND gd.deptno = t.deptno
    WHERE   t.Client = @Client
            AND t.groupcode = @GroupCode
            AND t.Payrollperiodenddate = @PPED
            AND ISNULL(t.crossoverstatus, '') <> '2'
            AND ISNULL(dn.recordstatus, '0') = '0'
            AND t.DeptNo <> 88 -- skip travel departments
--            AND en.PayType = 0

UNION ALL

    SELECT  en.Client, 
            RecordID = isnull( (select top 1 th.RecordID
                         from  TimeHistory..tblTimeHistDetail as th with(nolock)
                            where th.client = @Client
                            and th.groupcode = @GroupCode 
                            and th.ssn = t.ssn
                            and th.payrollperiodenddate IN(@PPED, @PPED2) ),0),
            Payrollperiodenddate = @PPED,
            TransDate = @PPED,
            t.Groupcode ,
            g.GroupName ,
            t.SSN ,
            t.SiteNo ,
            sn.SiteName ,
            t.DeptNo ,
            gd.DeptName_Long ,
            AdjCode = '',
            AdjustmentName = '',
            en.fileno ,
            en.LastName ,
            en.FirstName ,
            [Hours] = t.CurrentPeriodHours,
            TransType = 0,
            InTime = '',
            OutTime = '',
            paytype = '1',
            SalaryError = t.ActionDesc
    FROM    refreshwork.[dbo].[tblWork_DAVT_DeptRefresh_Audit] as t with(nolock)
    INNER JOIN TimeCurrent..tblClientGroups AS g
    ON      g.client = @Client
            AND g.groupcode = t.groupcode
    INNER JOIN TimeCurrent..tblEmplNames AS en WITH ( NOLOCK )
    ON      en.client = @CLient
            AND en.groupcode = t.groupcode
            AND en.ssn = t.ssn
    INNER JOIN TImeCurrent..tblSIteNames AS sn WITH ( NOLOCK )
    ON      sn.client = @Client
            AND sn.siteno = t.siteno
    Left JOIN TimeCurrent..tblGroupDepts AS gd WITH ( NOLOCK )
    ON      gd.Client = @Client
            AND gd.groupcode = t.groupcode
            AND gd.deptno = t.deptno
    WHERE   t.groupcode = @GroupCode
        And t.jobid = @JobID
        and t.ActionDesc like 'Validation%'
UNION ALL
    SELECT  t.Client, 
            t.RecordID ,
            t.Payrollperiodenddate ,
            t.TransDate ,
            t.Groupcode ,
            g.GroupName ,
            t.SSN ,
            t.SiteNo ,
            sn.SiteName ,
            t.DeptNo ,
            gd.DeptName_Long ,
            AdjCode = t.ClockAdjustmentNo ,
            t.AdjustmentName ,
            en.fileno ,
            en.LastName ,
            en.FirstName ,
            [Hours] = t.Hours + t.Dollars ,
            t.TransType ,
            CASE WHEN ISNULL(t.ClockAdjustmentNo, '') IN ( '', '8' ) THEN TimeCurrent.dbo.fn_GetDateTime(t.ActualInTime, 33)
                 ELSE ''
            END AS InTime,
            CASE WHEN ISNULL(t.ClockAdjustmentNo, '') IN ( '', '8' ) THEN TimeCurrent.dbo.fn_GetDateTime(t.ActualOutTime, 33)
                 ELSE ''
            END AS OutTime,
            paytype = '1',
            SalaryError = case when left(en.fileno,1) = '9' then 'Guest teammate incorrectly setup' else 'Missing Employee ID' end
    FROM    Timehistory..tblTimeHistdetail AS t WITH ( NOLOCK )
    INNER JOIN TimeCurrent..tblClientGroups AS g
    ON      g.client = t.client
            AND g.groupcode = t.groupcode
    INNER JOIN TimeCurrent..tblEmplNames AS en WITH ( NOLOCK )
    ON      en.client = t.client
            AND en.groupcode = t.groupcode
            AND en.ssn = t.ssn
    INNER JOIN TImeCurrent..tblSIteNames AS sn WITH ( NOLOCK )
    ON      sn.client = t.Client
            AND sn.siteno = t.siteno
    INNER JOIN TimeCurrent..tblGroupDepts AS gd WITH ( NOLOCK )
    ON      gd.Client = t.Client
            AND gd.groupcode = t.groupcode
            AND gd.deptno = t.deptno
    WHERE   t.Client = @Client
            AND t.groupcode = @GroupCode
            AND t.Payrollperiodenddate = @PPED
            AND ISNULL(t.crossoverstatus, '') <> '2'
            AND (LEN(isnull(en.FileNo,'')) <> 6 or (left(en.fileNo,1) = '9' and len(en.fileno) = 6) )
            AND en.AgencyNo <= 3
    ORDER BY GroupCode ,
            LastName ,
            FirstName
