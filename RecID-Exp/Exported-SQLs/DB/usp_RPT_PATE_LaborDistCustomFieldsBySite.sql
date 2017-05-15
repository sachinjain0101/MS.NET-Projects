CREATE procedure [dbo].[usp_RPT_PATE_LaborDistCustomFieldsBySite](
                @ClusterId integer,
                @Date datetime,
                @Client varchar(8),
                @Group integer,
                @Report varchar(4),
                @Sites varchar(1024),
                @Dept varchar(1024))

AS


SET NOCOUNT ON
SET ANSI_WARNINGS OFF

IF @Sites is null
BEGIN
  SET @Sites = 'ALL'
END
IF @Dept is null
BEGIN
  SET @Dept = 'ALL'
END

-- Hack, but Harmony is putting bad data in the tables and causing reports to fail
IF (@Client = 'RDRM')
BEGIN
	update timehistory..tblTimeHistDetail_UDF 
	set fieldvalue = '0.00'
	where FieldValue in ('undefined','nan')
	and Client = 'rdrm'
END

CREATE TABLE #tmpSites (SiteNo int)
CREATE TABLE #tmpDepts (DeptNo int)
DECLARE @pos int

IF @Sites <> 'ALL'
BEGIN
	SELECT @pos = CharIndex(',', @Sites, 0)
	WHILE @pos > 0
	BEGIN
		INSERT INTO #tmpSites (SiteNo) VALUES (CAST (Substring(@Sites, 1, @pos - 1) AS int))
		SELECT @Sites = Substring(@Sites, @pos + 1, Len(@Sites) - @pos)
		SELECT @pos = CharIndex(',', @Sites, 0)
	END
	INSERT INTO #tmpSites (SiteNo) VALUES (CAST (@Sites AS int))
END

IF @Dept <> 'ALL'
BEGIN
	SELECT @pos = CharIndex(',', @Dept, 0)
	WHILE @pos > 0
	BEGIN
		INSERT INTO #tmpDepts (DeptNo) VALUES (CAST (Substring(@Dept, 1, @pos - 1) AS int))
		SELECT @Dept = Substring(@Dept, @pos + 1, Len(@Dept) - @pos)
		SELECT @pos = CharIndex(',', @Dept, 0)
	END
	INSERT INTO #tmpDepts (DeptNo) VALUES (CAST (@Dept AS int))
END

CREATE TABLE #tmpDailyHrs  
(  
    RecordID             INT IDENTITY (1, 1) NOT NULL,  
    Client               VARCHAR(4),  
    GroupCode            INT,  
    SiteNo               INT,  
    DeptNo               INT,      
    SSN                  INT,  
    PayrollPeriodEndDate DATETIME,
    TransDate            DATETIME,      
    PayRate              NUMERIC(14, 2),  
    LastName             VARCHAR(50),
    FirstName            VARCHAR(50),
    DateApproved         DATETIME,
    Approver             VARCHAR(50),
    RegHours             NUMERIC(14, 2),  
    OT_Hours             NUMERIC(14, 2),  
    DT_Hours             NUMERIC(14, 2),  
    MaxTHDRecordID       BIGINT,  --< MaxTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 31Aug2016 >--
    OrderPoint           VARCHAR(50),
    OrderPointName       VARCHAR(100)
)  

CREATE TABLE #tmpUDFSummary  
(  
    RecordId              INT IDENTITY,  
    Client                VARCHAR(4),
    GroupCode             INT,  
    SSN                   INT,   
    SiteNo                INT,
    DeptNo                INT,
    PayrollPeriodEndDate  DATETIME,  
    TransDate             DATETIME,   
    THD_GroupingID        INT,
    Brand                 VARCHAR(100),
    BrandHours            NUMERIC(14, 2),   
    Sales                 NUMERIC(14, 2),
    Event                 VARCHAR(100),
    CoOp                  VARCHAR(100),
    Season                VARCHAR(100) 
)   

INSERT INTO #tmpDailyHrs 
SELECT  thd.Client,
        thd.GroupCode,
        thd.SiteNo,
        thd.DeptNo,
        thd.SSN,
        thd.PayrollPeriodEndDate,
        thd.TransDate,
        ISNULL(thd.PayRate,0),
        en.LastName,
        en.FirstName,
        MAX(thd.AprvlStatus_Date) AS DateApproved,
        NULL AS Approver,
        SUM(thd.RegHours),
        SUM(thd.OT_Hours),
        SUM(thd.DT_Hours),
        MAX(thd.RecordID),
        sn.CompanyID AS OrderPoint,
        sn.SiteName AS OrderPointName
FROM TimeHistory..tblTimeHistDetail thd WITH (NOLOCK)
INNER JOIN TimeCurrent..tblSiteNames AS SN WITH (NOLOCK)
ON thd.Client = SN.Client
AND thd.GroupCode = SN.GroupCode
AND thd.SiteNo = SN.SiteNo
INNER JOIN TimeCurrent..tblEmplNames en WITH (NOLOCK)
ON thd.Client = en.Client
AND thd.GroupCode = en.GroupCode
AND thd.SSN = en.SSN
INNER JOIN TimeCurrent..tblGroupDepts gd
ON gd.Client = thd.Client
AND gd.GroupCode = thd.GroupCode
AND gd.DeptNo = thd.DeptNo
LEFT JOIN TimeCurrent..tblUser u WITH (NOLOCK)
ON u.UserID = thd.AprvlStatus_UserID
LEFT JOIN TimeHistory..tblTimeHistDetail_PATE thdp
ON thdp.THDRecordID = thd.RecordID
WHERE thd.Client = @Client
AND thd.GroupCode = @Group
AND thd.PayrollPeriodEndDate = @Date
AND (@Sites = 'ALL' OR thd.SiteNo in (SELECT SiteNo FROM #tmpSites))
AND (@Dept = 'ALL' OR thd.DeptNo in (SELECT DeptNo FROM #tmpDepts))
AND EXISTS(SELECT ClusterID FROM dbo.tvf_GetTimeHistoryClusterDefAsFn(THD.groupcode,THD.siteno,THD.deptno,THD.agencyno,THD.ssn,THD.DivisionID,THD.shiftno, @ClusterID))
GROUP BY  thd.Client,
          thd.GroupCode,
          thd.SiteNo,
          thd.DeptNo,
          thd.SSN,
          thd.TransDate,
          thd.PayrollPeriodEndDate,
          ISNULL(thd.PayRate,0),
          en.LastName,
          en.FirstName,
          sn.CompanyID,
          sn.SiteName
          
UPDATE tmpDailyHrs  
SET Approver = CASE  WHEN bkp.RecordId IS NOT NULL   
                         THEN bkp.Email  
                         ELSE CASE WHEN ISNULL(usr.Email,'') = ''   
                                   THEN (CASE WHEN ISNULL(usr.LastName,'') = ''   
                                              THEN ISNULL(usr.LogonName,'')   
                                              ELSE LEFT(usr.LastName + '; ' + ISNULL(usr.FirstName,''),50)   
                                         END)  
                                   ELSE LEFT(usr.Email,50)   
                              END  
                    END  
FROM #tmpDailyHrs AS tmpDailyHrs  
INNER JOIN TimeHistory..tblTimeHistDetail as thd  
ON thd.RecordID = tmpDailyHrs.MaxTHDRecordID  
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp  WITH(NOLOCK) 
ON bkp.THDRecordId = tmpDailyHrs.MaxTHDRecordID  
LEFT JOIN TimeCurrent..tblUser as Usr  WITH(NOLOCK) 
ON usr.UserID = ISNULL(thd.AprvlStatus_UserID,0)            

INSERT INTO #tmpUDFSummary( Client, GroupCode, SSN, SiteNo, DeptNo, PayrollPeriodEndDate, TransDate, 
                            THD_GroupingID, --FieldID,
                            Brand, 
                            BrandHours,   
                            Sales,
                            Event) 
SELECT DISTINCT thd_udf.Client, thd_udf.GroupCode, thd_udf.SSN, thd_udf.SiteNo, thd_udf.DeptNo, thd_udf.Payrollperiodenddate, thd_udf.TransDate,
                thd_udf.Position, --thd_udf.FieldID, --thd_udf.FieldValue,
                MAX(CASE WHEN fd_brnd.FieldName = 'BRND' THEN thd_udf.FieldValue END) AS Brand,
                SUM(CASE WHEN fd_brnd_hrs.FieldName = 'BRND_HRS' THEN CAST(CASE thd_udf.FieldValue WHEN '' THEN '0' ELSE REPLACE(thd_udf.FieldValue, ',', '') END AS NUMERIC(14, 2)) END) AS BrandHours,
                SUM(CASE WHEN fd_sales.FieldName = 'SALES' THEN CAST(CASE thd_udf.FieldValue WHEN '' THEN '0' ELSE REPLACE(thd_udf.FieldValue, ',', '') END AS NUMERIC(14, 2)) END) AS Sales,                
                MAX(CASE WHEN fd_event.FieldName = 'EVNT' THEN thd_udf.FieldValue END) AS Event
FROM #tmpDailyHrs dlyHrs
INNER JOIN TimeHistory..tblTimeHistDetail_UDF thd_udf
ON thd_udf.Client = dlyHrs.Client
AND thd_udf.GroupCode = dlyHrs.GroupCode
AND thd_udf.SSN = dlyHrs.SSN
AND thd_udf.SiteNo = dlyHrs.SiteNo
AND thd_udf.DeptNo = dlyHrs.DeptNo
AND thd_udf.PayrollPeriodEndDate = dlyHrs.PayrollPeriodEndDate
AND thd_udf.TransDate = dlyHrs.TransDate
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_brnd
ON fd_brnd.FieldID = thd_udf.FieldID
AND fd_brnd.FieldName = 'BRND'
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_brnd_hrs
ON fd_brnd_hrs.FieldID = thd_udf.FieldID
AND fd_brnd_hrs.FieldName = 'BRND_HRS'
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_sales
ON fd_sales.FieldID = thd_udf.FieldID
AND fd_sales.FieldName = 'SALES'
LEFT JOIN TimeCurrent..tblUDF_FieldDefs fd_event
ON fd_event.FieldID = thd_udf.FieldID
AND fd_event.FieldName = 'EVNT'
WHERE thd_udf.Position IS NOT NULL 
GROUP BY thd_udf.Client, thd_udf.GroupCode, thd_udf.SSN, thd_udf.SiteNo, thd_udf.DeptNo, thd_udf.Payrollperiodenddate, thd_udf.TransDate,
                thd_udf.Position
ORDER BY thd_udf.Client, thd_udf.GroupCode, thd_udf.SSN, thd_udf.SiteNo, thd_udf.DeptNo, thd_udf.TransDate

UPDATE summ
SET CoOp = udf.FieldValue
FROM #tmpUDFSummary summ
INNER JOIN TimeHistory.dbo.tblTimeHistDetail_UDF udf
ON udf.Client = summ.Client
AND udf.GroupCode = summ.GroupCode
AND udf.SSN = summ.SSN
AND udf.SiteNo = summ.SiteNo
AND udf.DeptNo = summ.DeptNo
AND udf.PayrollPeriodEndDate = summ.PayrollPeriodEndDate
AND udf.TransDate = summ.TransDate
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.FieldID = udf.FieldID
WHERE fd.FieldName = 'COOP' 

UPDATE summ
SET Season = udf.FieldValue
FROM #tmpUDFSummary summ
INNER JOIN TimeHistory.dbo.tblTimeHistDetail_UDF udf
ON udf.Client = summ.Client
AND udf.GroupCode = summ.GroupCode
AND udf.SSN = summ.SSN
AND udf.SiteNo = summ.SiteNo
AND udf.DeptNo = summ.DeptNo
AND udf.PayrollPeriodEndDate = summ.PayrollPeriodEndDate
AND udf.TransDate = summ.TransDate
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.FieldID = udf.FieldID
WHERE fd.FieldName = 'SESN' 


-- Add Season Description
UPDATE summ
SET Season = Season + '-' + fo.OptionDesc
FROM #tmpUDFSummary summ
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.FieldName = 'SESN' 
INNER JOIN TimeCurrent.dbo.tblUDF_Templates t
ON t.TemplateID = fd.TemplateID
INNER JOIN TimeCurrent.dbo.tblUDF_TemplateMapping tm
ON tm.TemplateID = t.TemplateID
AND tm.GroupCode = summ.GroupCode
INNER JOIN TimeCurrent..tblUDF_FieldOptions fo
ON fo.FieldID = fd.FieldID
AND fo.TemplateMappingID = tm.TemplateMappingID
AND fo.OptionValue = summ.Season

-- Add Event Description
UPDATE summ
SET Event = Event + '-' + fo.OptionDesc
FROM #tmpUDFSummary summ
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.FieldName = 'EVNT' 
INNER JOIN TimeCurrent.dbo.tblUDF_Templates t
ON t.TemplateID = fd.TemplateID
INNER JOIN TimeCurrent.dbo.tblUDF_TemplateMapping tm
ON tm.TemplateID = t.TemplateID
AND tm.GroupCode = summ.GroupCode
INNER JOIN TimeCurrent..tblUDF_FieldOptions fo
ON fo.FieldID = fd.FieldID
AND fo.TemplateMappingID = tm.TemplateMappingID
AND fo.OptionValue = summ.Event

-- Add Brand Description
UPDATE summ
SET Brand = Brand + '-' + fo.OptionDesc
FROM #tmpUDFSummary summ
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.FieldName = 'BRND' 
INNER JOIN TimeCurrent.dbo.tblUDF_Templates t
ON t.TemplateID = fd.TemplateID
INNER JOIN TimeCurrent.dbo.tblUDF_TemplateMapping tm
ON tm.TemplateID = t.TemplateID
AND tm.GroupCode = summ.GroupCode
INNER JOIN TimeCurrent..tblUDF_FieldOptions fo
ON fo.FieldID = fd.FieldID
AND fo.TemplateMappingID = tm.TemplateMappingID
AND fo.OptionValue = summ.Brand

      
SELECT dlyHrs.SSN, 
       dlyHrs.LastName, 
       dlyHrs.FirstName,
       dlyHrs.OrderPoint AS ClientDeptCode, -- IVR #
       dlyHrs.OrderPointName AS DeptName, 
       'Emp' AS UserCode, --  Service Type
       cg.GroupName AS SiteName, -- Customer
       convert(varchar, dlyHrs.DateApproved, 101) AprvlStatus_Date,
       dlyHrs.Approver AS ApproverName,
       ISNULL(summ.Season, '') AS Season,
       ISNULL(summ.EVENT, '') AS Event,
       ISNULL(summ.Brand, '') AS Brand,
			 ISNULL(summ.Coop, '') AS Coop,
       ISNULL(CAST(summ.Sales AS VARCHAR), '') AS Sales,
       dlyHrs.PayRate,
       RegHrs1 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-6,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.RegHours ELSE 0 END),
       RegHrs2 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-5,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.RegHours ELSE 0 END),
       RegHrs3 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-4,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.RegHours ELSE 0 END),
       RegHrs4 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-3,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.RegHours ELSE 0 END),
       RegHrs5 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-2,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.RegHours ELSE 0 END),
       RegHrs6 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-1,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.RegHours ELSE 0 END),
       RegHrs7 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),dlyHrs.PayrollPeriodEndDate,101) THEN dlyHrs.RegHours ELSE 0 END),
       OTHrs1 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-6,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.OT_Hours ELSE 0 END),
       OTHrs2 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-5,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.OT_Hours ELSE 0 END),
       OTHrs3 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-4,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.OT_Hours ELSE 0 END),
       OTHrs4 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-3,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.OT_Hours ELSE 0 END),
       OTHrs5 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-2,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.OT_Hours ELSE 0 END),
       OTHrs6 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-1,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.OT_Hours ELSE 0 END),
       OTHrs7 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),dlyHrs.PayrollPeriodEndDate,101) THEN dlyHrs.OT_Hours ELSE 0 END),
       DTHrs1 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-6,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.DT_Hours ELSE 0 END),
       DTHrs2 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-5,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.DT_Hours ELSE 0 END),
       DTHrs3 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-4,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.DT_Hours ELSE 0 END),
       DTHrs4 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-3,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.DT_Hours ELSE 0 END),
       DTHrs5 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-2,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.DT_Hours ELSE 0 END),
       DTHrs6 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),DATEADD(dd,-1,dlyHrs.PayrollPeriodEndDate),101) THEN dlyHrs.DT_Hours ELSE 0 END),
       DTHrs7 = Sum(CASE WHEN CONVERT(varchar(10),dlyHrs.TransDate,101) = CONVERT(varchar(10),dlyHrs.PayrollPeriodEndDate,101) THEN dlyHrs.DT_Hours ELSE 0 END)
FROM #tmpDailyHrs dlyHrs
INNER JOIN TimeCurrent.dbo.tblClientGroups cg
ON cg.Client = dlyHrs.Client
AND cg.GroupCode = dlyHrs.GroupCode
LEFT JOIN #tmpUDFSummary summ
ON summ.Client = dlyHrs.Client
AND summ.GroupCode = dlyHrs.GroupCode
AND summ.SSN = dlyHrs.SSN
AND summ.SiteNo = dlyHrs.SiteNo
AND summ.DeptNo = dlyHrs.DeptNo
AND summ.TransDate = dlyHrs.TransDate
GROUP BY dlyHrs.SSN, 
       dlyHrs.LastName, 
       dlyHrs.FirstName,
       cg.GroupName,
       convert(varchar, dlyHrs.DateApproved, 101),
       dlyHrs.Approver,
       summ.Season,
       summ.Event,
       summ.Brand,
			 summ.Coop,
       summ.Sales,
       dlyHrs.PayRate,
       dlyHrs.OrderPoint,
       dlyHrs.OrderPointName


