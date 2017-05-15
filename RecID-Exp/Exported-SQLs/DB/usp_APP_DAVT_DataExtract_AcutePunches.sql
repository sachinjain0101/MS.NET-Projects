CREATE PROCEDURE [dbo].[usp_APP_DAVT_DataExtract_AcutePunches]
(
	@Client VARCHAR(4),
	@GroupCode INT,
	@MPD DATE
)
AS


SET NOCOUNT ON

DECLARE @PPED DATE 

--Drop Table #tmpReport
--Drop Table #tmpiPAD
--Drop TABLE #tmpParent
--Drop TABLE #tmpIpadUsers

Create Table #tmpReport
(
RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Nov2016 >--
GroupCode	INT,
SiteNo	INT,
InSiteNo INT,
OutSIteNo INT,
DeptNo INT,	
SSN INT,
PPED	DATE,
TransDate DATE,
Shiftno SMALLINT,
InTime DATETIME,
OutTime DATETIME,
AdjName VARCHAR(20),
TotHours NUMERIC(7,2),
RegHours NUMERIC(7,2),
OTHours NUMERIC(7,2),
DailyOTHours NUMERIC(7,2),
DTHours NUMERIC(7,2),
ClockAdjustmentNo VARCHAR(3),
Dollars NUMERIC(7,2),
ManualIN	INT,	
ManualOut	INT,	
SystemIN		INT,
SystemOut		INT,
iPadINPunches		INT,
iPadOUTPunches		INT,
ClockINPunches		INT,
ClockOUTPunches		INT,
WebINPunches		INT,
WebOUTPunches		INT,
InUserCode VARCHAR(20),
OutUserCode VARCHAR(20)
)

--Drop Table #tmpiPAD

Create Table #tmpiPAD
(
RecordID int,   --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Nov2016 >--
PunchType CHAR(1)
)

--Drop TABLE #tmpParent

CREATE TABLE #tmpParent
(
	Client VARCHAR(4),
	Groupcode INT,
	Siteno INT
)

INSERT INTO #tmpParent
        ( Client, Groupcode, Siteno )
SELECT DISTINCT d.Client, d.Groupcode, d.SIteno 
FROM TimeCurrent..tblDeptNames AS d WITH(NOLOCK)
INNER JOIN TimeCurrent..tblSiteNames AS sn WITH(NOLOCK)
ON sn.client = d.Client
AND sn.groupcode = d.GroupCode
AND sn.siteno = d.siteno 
AND ISNULL(sn.MasterClockMailbox,'') = ''
INNER JOIN TimeCUrrent..tblGroupDepts AS gd WITH(NOLOCK)
ON gd.client = d.Client
AND gd.groupcode = d.GroupCode
AND gd.deptno = d.deptno 
AND SUBSTRING(gd.ClientDeptCode,6,3) IN ('380','381','382','383','384')
WHERE
d.client = 'DAVT'
AND d.RecordStatus = '1'

DECLARE cPPED CURSOR
READ_ONLY
FOR 
SELECT DISTINCT p.Client, p.GroupCode, p.Payrollperiodenddate
FROM #tmpParent AS s
INNER JOIN TimeHistory..tblPeriodEndDates AS p WITH(NOLOCK)
ON p.client = s.Client
AND p.groupcode = s.Groupcode
AND p.MasterPayrollDate = @MPD

OPEN cPPED

FETCH NEXT FROM cPPED INTO @Client, @Groupcode, @PPED
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		INSERT INTO #tmpiPAD
		SELECT DISTINCT 
		 t.RecordID 
		,gl.PunchDirection
		FROM TimeHistory..tblTimeHistDetail as t with(nolock)
		INNER JOIN TimeHistory.dbo.tblTimeHistDetail_GeoLocation AS gl WITH(NOLOCK)
		ON gl.client = t.Client
		AND gl.groupcode  = t.Groupcode
		AND gl.PayrollPeriodEndDate = t.PayrollPeriodEndDate
		AND gl.SiteNo = t.SiteNo 
		AND ( gl.siteno = ISNULL(t.InSiteNo,t.SiteNo) 
					OR gl.siteno = ISNULL(t.OutSiteNo,t.SiteNo) )
		AND (		 gl.PunchLocationTime = ISNULL(t.InTimestamp,0)
					OR gl.PunchLocationTime = ISNULL(t.outTimestamp,0) )
		WHERE
			t.client = @Client
			AND t.GroupCode = @GroupCode
			AND t.PayrollPeriodEndDate = @PPED

		Insert into #tmpReport 
		select 
		t.RecordID
		,t.GroupCode
		,t.SiteNo
		,t.InSiteNo
		,t.OutSiteNo
		,t.DeptNo 
		,t.SSN
		,PPED = t.PayrollPeriodEndDate
		,t.TransDate
		,t.ShiftNo
		,TimeHistory.dbo.PunchDateTime2(t.Transdate,t.InDay,t.InTime)
		,TimeHistory.dbo.PunchDateTime2(t.Transdate,t.OutDay,t.OutTime)
		,t.AdjustmentName
		,t.hours  
		,t.RegHours
		,OT_Hours = t.OT_Hours - t.AllocatedOT_Hours
		,DailyOTHours = t.AllocatedOT_Hours
		,t.DT_Hours
		,t.ClockAdjustmentNo
		,t.Dollars
		,ManualIN = case when t.ClockadjustmentNo = '' and t.InSrc = '3'
																	and isnull(t.UserCode,'') not in('PNE','SYS','','VTS','VTC','VT2') then 1 else 0 end
		,ManualOut = case when t.ClockadjustmentNo = '' and t.OutSrc = '3' 
																	and isnull(t.OutUserCode,'') not in('PNE','','SYS','VTS','VTC','VT2') then 1 else 0 end
		,SystemIN = case when t.ClockadjustmentNo = '' and t.InSrc = '3'
																	and isnull(t.UserCode,'') in('PNE','SYS','') then 1 else 0 end
		,SystemOut = case when t.ClockadjustmentNo = '' and t.OutSrc = '3' 
																	and isnull(t.OutUserCode,'') in('PNE','','SYS') then 1 else 0 end
		,iPadINPunches = CASE WHEN (ISNULL(iPadIN.RecordID,0) <> 0 OR t.insrc = 'D') AND iPadIN.PunchType = 'I' THEN 1 ELSE 0 END
		,iPadOUTPunches = CASE WHEN (ISNULL(iPadOUT.RecordID,0) <> 0 OR t.outsrc = 'D') AND iPadOUT.PunchType = 'O' THEN 1 ELSE 0 END
		,ClockINPunches = case when t.ClockadjustmentNo = '' and ISNULL(iPadIN.RecordID,0) = 0 AND t.Insrc = '0' THEN 1 ELSE 0 END
		,ClockOUTPunches = case when t.ClockadjustmentNo = '' and ISNULL(iPadOUT.RecordID,0) = 0 AND t.Outsrc = '0' THEN 1 ELSE 0 END 
		,WebINPunches = case when t.ClockadjustmentNo = '' AND (t.Usercode in('VTC','VT2','VTS') or t.Insrc in('C','V') ) THEN 1 ELSE 0 END
		,WebOUTPunches = case when t.ClockadjustmentNo = '' AND (t.OutUserCode IN('VTC','VT2','VTS') or t.Outsrc in('C','V') ) THEN 1 ELSE 0 END
		,t.UserCode
		,t.OutUserCode
		from #tmpParent AS s 
		INNER JOIN TimeHistory..tblTimeHistDetail as t with(nolock)
		ON t.client = s.Client
		AND t.groupcode  = s.Groupcode
		AND t.SiteNo = s.SiteNo 
		AND t.PayrollPeriodEndDate = @PPED --IN(@MPD, @PPED)
    AND IsNull(t.CrossoverStatus, '') <> '2'
		LEFT JOIN #tmpiPAD AS iPadIN
		ON iPadIn.RecordID = t.RecordID
		AND iPadIN.PunchType = 'I'
		LEFT JOIN #tmpiPAD AS iPadOut
		ON iPadOut.RecordID = t.RecordID
		AND iPadOut.PunchType = 'O'
		WHERE s.GroupCode = @GroupCode 

	END
	FETCH NEXT FROM cPPED INTO @Client, @Groupcode, @PPED
END

CLOSE cPPED
DEALLOCATE cPPED

--select * from #tmpReport
--RETURN


select Distinct en.FileNo, en.SSN
INTO #tmpIpadUsers
from [Audit].[dbo].[tblWork_DavitaAcuteRegistrations] as r (NOLOCK)
Inner Join TimeCurrent..tblEmplnames as en
on en.client = 'DAVT'
and en.fileno = right('000000' + ltrim(rtrim(right(r.TerminalID,6))),6)
where terminalID like 'DAVT%'
and len(terminalID) = 10 
and TerminalID <> 'DAVT999406'

/*
CREATE TABLE #tmpSummReport
(
GroupName	varchar(100),
DivisionName varchar(100),
RegionID varchar(100),
SiteNo INT,
SiteName varchar(100),		
Modality varchar(10),		
FC varchar(10),		
WeekendingDate DATE,	
Transdate	DATE,
DeptNo INT,	
DeptName_long	varchar(100),	
EmplID varchar(20),		
LastName varchar(100),	
Firstname varchar(100),
RegisteriPad char(1),
RecordID INT,	
PhysicalIn varchar(100), 
INHospitalID varchar(20),		
InTime DATETIME,	
Insrc varchar(30),		
PhysicalOut varchar(100),	
OutHospitalID varchar(20),		
OutTime DATETIME,	
Outsrc varchar(30),	
AdjName varchar(30),	
Paytype TINYINT,	
TotHours NUMERIC(7,2),	
RegHours NUMERIC(7,2),	
OTHours NUMERIC(7,2),	
DailyOTHours NUMERIC(7,2),	
DTHours NUMERIC(7,2),	
NWHours NUMERIC(7,2),	
Dollars NUMERIC(7,2)
)
--truncate table #tmpSummReport
*/

select 
g.GroupName
,dv.DivisionName
,RegionID = sn.DivisionID
,r.SiteNo
,sn.SiteName
,Modality = SUBSTRING(gd.clientdeptcode,6,3)
,FC = RIGHT(gd.clientdeptcode,3)
,WeekendingDate = CONVERT(VARCHAR(10),r.PPED,120)
,TransDate = CONVERT(VARCHAR(10),r.Transdate,120)
,r.DeptNo
,gd.DeptName_long
,EmplID = CASE WHEN en.AgencyNo > 3 THEN LTRIM(STR(en.recordID)) ELSE en.FileNo END
,en.LastName
,en.FIrstname 
,registerediPad = case when isnull(u.ssn,0) <> 0 then 'Y' else '' end
,r.RecordID
--,PrimaryDept = LTRIM(STR(en.PrimaryDept)) + '-' +  pd.DeptName_Long 
,PhysicalIn = CASE WHEN ISNULL(r.InSiteNo,0) <> 0 THEN REPLACE(si.sitename,',',' ') ELSE '' END  
,InHospitalID = isnull(si.PayrollUploadCode,'')
,InDateTIme = CONVERT(VARCHAR(16),r.InTime,120)
,Insrc = CASE WHEN r.ManualIN = 1 THEN 'MANUAL'
							WHEN r.SystemIN = 1 THEN 'SYSTEM'
							WHEN r.iPadINPunches = 1 THEN 'iPad'
							WHEN r.ClockINPunches = 1 THEN 'CLOCK'
							WHEN r.WebINPunches = 1 THEN 'WEB' ELSE CASE WHEN ISNULL(r.InUserCode,'') = '' THEN 'SYSTEM' ELSE r.InUserCOde end END
,PhysicalOut = CASE WHEN ISNULL(r.OutSiteNo,0) <> 0 THEN REPLACE(so.sitename,',',' ') ELSE '' END  
,OutHospitalID = isnull(so.PayrollUploadCode,'')
,OutDateTIme = CONVERT(VARCHAR(16),r.OutTime,120)
,Outsrc = CASE WHEN r.ManualOut = 1 THEN 'MANUAL'
							WHEN r.SystemOut = 1 THEN 'SYSTEM'
							WHEN r.iPadOUTPunches = 1 THEN 'iPad'
							WHEN r.ClockOUTPunches = 1 THEN 'CLOCK'
							WHEN r.WebOUTPunches = 1 THEN 'WEB' ELSE CASE WHEN ISNULL(r.OutUserCode,'') = '' THEN 'SYSTEM' ELSE r.OutUserCode END END
,AdjName = CASE WHEN r.AdjName <> '' then a.ClockAdjustmentNo + '-' + r.AdjName ELSE '' end
,Paytype = CASE WHEN en.AgencyNo > 3 THEN 2 ELSE en.PayType end
,r.TotHours
,RegHours = CASE WHEN a.Worked = 'Y' THEN r.RegHours ELSE 0 end
,r.OTHours
,r.DailyOTHours
,r.DTHours  
,NWHours = CASE WHEN a.Worked = 'Y' THEN 0 ELSE r.RegHours end 
,r.Dollars           
from #tmpReport as r
Inner Join TimeCurrent..tblClientgroups as g with(nolock)
on g.client = 'DAVT' 
AND g.groupcode = r.groupcode
INNER JOIN TImecurrent..tblGroupDepts AS gd
ON gd.client = 'DAVT'
AND gd.groupcode = r.GroupCode
AND gd.deptno = r.deptno 
AND (SUBSTRING(gd.ClientDeptCode,6,3) IN ('380','381','382','383','384')  OR r.DeptNo = 88 )
INNER JOIN TImecurrent..tblEmplNames AS en WITH(NOLOCK)
ON en.client = 'DAVT'
AND en.groupcode = r.GroupCode
AND en.ssn = r.ssn 
INNER JOIN TImecurrent..tblGroupDepts AS pd
ON pd.client = 'DAVT'
AND pd.groupcode = en.GroupCode
AND pd.deptno = en.PrimaryDept
Inner Join TimeCurrent..tblSiteNames as sn with(nolock)
on sn.client = 'DAVT'
and sn.groupcode = r.groupcode
and sn.siteno = r.siteno 
Inner Join TimeCurrent..tblSiteNames as si with(nolock)
on si.client = 'DAVT'
and si.groupcode = r.groupcode
and si.siteno = CASE WHEN ISNULL(r.InSiteNo,0) <> 0 THEN r.InSiteNo ELSE r.siteno END
Inner Join TimeCurrent..tblSiteNames as so with(nolock)
on so.client = 'DAVT'
and so.groupcode = r.groupcode
and so.siteno = CASE WHEN ISNULL(r.OutSiteNo,0) <> 0 THEN r.OutSiteNo ELSE r.siteno END
Left join TImeCurrent..tblDivisions as dv with(nolock)
on dv.Client = 'DAVT'
and dv.groupcode = sn.groupcode
and dv.Division = sn.Division
INNER JOIN TimeCurrent..tblAdjCodes AS a WITH(NOLOCK)
ON a.client = 'DAVT'
AND a.groupcode = r.GroupCode
AND a.ClockAdjustmentNo = CASE WHEN r.ClockAdjustmentNo IN('',' ') THEN '1' ELSE r.ClockAdjustmentNo end
Left Join #tmpIpadUsers as u
on u.SSN = r.SSN 

/*
DECLARE @Delim CHAR(1) = ','

select LineOut = 
GroupName	+ @Delim + 
ISNULL(DivisionName,'')	+ @Delim + 
ISNULL(RegionID,'')	+ @Delim + 
LTRIM(STR(SiteNo))	+ @Delim + 
SiteName 	+ @Delim + 
ISNULL(Modality,'')	+ @Delim + 
ISNULL(FC,'') + @Delim + 
CONVERT(VARCHAR(12),WeekendingDate,101)	+ @Delim + 
CONVERT(VARCHAR(12),Transdate,101)+ @Delim + 
LTRIM(STR(DeptNo)) + @Delim +
ISNULL(DeptName_long,'') + @Delim +
EmplID + @Delim +
LastName + @Delim +
Firstname + @Delim +
RegisteriPad + @Delim +
LTRIM(STR(RecordID)) + @Delim +
ISNULL(PhysicalIn,'') + @Delim +
ISNULL(INHospitalID,'') + @Delim +
CONVERT(VARCHAR(12),InTime,120) + @Delim +
Insrc + @Delim +
ISNULL(PhysicalOut,'') + @Delim +
ISNULL(OutHospitalID,'') + @Delim +
CONVERT(VARCHAR(12),OutTime,120) + @Delim +
Outsrc + @Delim +
AdjName + @Delim +
LTRIM(STR(Paytype)) + @Delim +
LTRIM(STR(TotHours,10,2)) + @Delim +
LTRIM(STR(RegHours,10,2)) + @Delim +
LTRIM(STR(OTHours,10,2)) + @Delim +
LTRIM(STR(DailyOTHours,10,2)) + @Delim +
LTRIM(STR(DTHours,10,2)) + @Delim +
LTRIM(STR(NWHours,10,2)) + @Delim +
LTRIM(STR(Dollars,10,2))
FROM #tmpSummReport

*/
