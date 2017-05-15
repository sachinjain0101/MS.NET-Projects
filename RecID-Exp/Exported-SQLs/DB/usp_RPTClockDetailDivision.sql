CREATE procedure [dbo].[usp_RPTClockDetailDivision]
(
  @Date date,
  @Client char(4),
  @Group integer,
  @Report varchar(4),
  @Sites varchar(1024),
  @Dept varchar(1024),
  @Ref1 char(1), -- 'A' = All Hours, 'W' = Worked Hours
  @ClusterId integer,
  @TimePrecision char(1) -- 'R' = Rounded Hours, 'A' = Actual Hours
)


AS




SET NOCOUNT ON

DECLARE @SelectString VARCHAR(2000)
DECLARE @FromString VARCHAR(2000)
DECLARE @WhereString VARCHAR(3000)
DECLARE @GroupString VARCHAR(2000)
DECLARE @EndDOW integer
DECLARE @crlf CHAR(2)
DECLARE @DeptOrder VARCHAR(48)
DECLARE @PayrollFreq char(1)
DECLARE @EmplIdColumn varchar(50)

SELECT @crlf = char(13) + char(10);

IF @Sites IS NULL
BEGIN
	SET @Sites = 'ALL'
END

-- First pass at building a CTE from tblTimeHistoryDetail
IF @Report = 'PDDV'
BEGIN

-- use CTE to populate report
 
with ClientShiftsCTE (Client, ClientName, GroupCode, GroupName, SiteNo, SiteName, DeptNo, DeptName, Division, DivisionName, 
                      Agency, AgencyName, ShiftNo, ShiftName, Level)
AS
(
SELECT c.Client, c.ClientName, GroupCode, GroupName, CAST (NULL as INT) as SiteNo,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 01Sept2016 >--
 CAST (NULL as varchar (60)) as SiteName, 
CAST (NULL as INT) DeptNo,   --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 01Sept2016 >--
CAST (NULL as varchar (30)) as DeptName,   CAST (NULL as INT) as Division, CAST (NULL as varchar (60)) as DivisionName,
 NULL, NULL, NULL, NULL, 1 as Level 
FROM TimeCurrent.dbo.tblClients AS c INNER JOIN
TimeCurrent.dbo.tblClientGroups AS cg ON cg.Client = c.Client
Where c.recordstatus = '1' 
AND c.BillingType <> 'X'
AND cg.recordstatus = '1'
AND cg.GroupCode < '999899'
AND c.Client = @Client 
AND cg.GroupCode = @Group
UNION ALL

SELECT ce.Client, ce.ClientName, ce.GroupCode, ce.GroupName, sn.SiteNo, sn.SiteName, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1 + Level
FROM TimeCurrent.dbo.tblSiteNames AS sn INNER JOIN
ClientShiftsCTE AS ce ON sn.Client = ce.Client 
AND sn.GroupCode = ce.GroupCode 
WHERE sn.RecordStatus = '1' 
AND sn.SiteNo <> 9999  -- template siteno
AND ce.Level = 1
AND (
	 EXISTS (Select * 
			from TimeCurrent.dbo.tblSiteNames AS sn1 
			WHERE sn1.Client = sn.Client 
			AND sn1.GroupCode = sn.GroupCode
			AND  sn1.SiteNo = sn.SiteNo
			AND @Sites <> 'ALL'
			AND TimeCurrent.dbo.fn_InCSV(@Sites,sn1.SiteNo,'1') = 1
			)
	OR
	EXISTS (Select NULL Where @Sites = 'ALL')
	) 
UNION ALL

SELECT ce.Client, ce.ClientName, ce.GroupCode, ce.GroupName, CAST (NULL as INT) as SiteNo,   --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 01Sept2016 >--
CAST (NULL as varchar (60)) as SiteName,   dn.DeptNo,  dn.DeptName,
CAST (NULL as INT) as Division, CAST (NULL as varchar (60)) as DivisionName, NULL, NULL, NULL, NULL, 2 + Level
FROM  TimeCurrent.dbo.tblGroupDepts AS dn INNER JOIN
ClientShiftsCTE AS ce ON dn.Client = ce.Client 
AND dn.GroupCode = ce.GroupCode 
WHERE dn.RecordStatus = '1' 
AND ce.Level = 1
AND (
	 EXISTS (Select * 
			from TimeCurrent.dbo.tblGroupDepts AS dn1 
			WHERE dn1.Client = dn.Client 
			AND dn1.GroupCode = dn.GroupCode
			AND  dn1.DeptNo = dn.DeptNo
			AND @Dept <> 'ALL'
			AND TimeCurrent.dbo.fn_InCSV(@Dept,dn1.DeptNo,'1') = '1'
			)
	OR
	EXISTS (Select NULL Where @Dept = 'ALL')
	) 
UNION ALL

SELECT ce.Client, ce.ClientName, ce.GroupCode, ce.GroupName, CAST (NULL as INT) as SiteNo,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 01Sept2016 >--
CAST (NULL as varchar (60)) as SiteName,   
CAST (NULL as INT) DeptNo,  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 01Sept2016 >--
CAST (NULL as varchar (30)) as DeptName,
dv.Division, dv.DivisionName, NULL, NULL, NULL, NULL, 3 + Level
FROM TimeCurrent.dbo.tblDivisions  AS dv INNER JOIN
ClientShiftsCTE AS ce ON dv.Client = ce.Client 
AND dv.GroupCode = ce.GroupCode 
WHERE dv.RecordStatus = '1' 
AND ce.Level = 1

), THDcte (Client, GroupCode, PayrollPeriodEndDate, DeptNo, DeptName , DivisionID,  SupervisorName, 
SSN, LastName , FirstName , TransDate,InDayName,OutDayName, InSrc, UserCode, ActualInPunch,  InDay,  InTime, ActualInTime, 
		ClockAdjustmentNo, AdjustmentCode,OutSrc, OutUserCode, OutDay ,  ActualOutTime, OutTime,  AdjustmentName,
		 Hours, RegHours, OT_Hours,  DT_Hours)
AS
(		 
SELECT THD.Client, THD.GroupCode, THD.PayrollPeriodEndDate, THD.DeptNo, GD.DeptName , THD.DivisionID,  DV.DivisionName as SupervisorName, 
THD.SSN, LastName , FirstName , THD.TransDate,InDayDef.DayAbrev as InDayName, OutDaydef.DayAbrev AS OutDayName,
		THD.InSrc, THD.UserCode, dbo.PunchDateTime(thd.transDate, thd.InDay, thd.InTime) as ActualInPunch, 
		CASE WHEN THD.InDay > 7 OR THD.InDay = 7 THEN '0' ELSE THD.InDay END as InDay,  
CASE WHEN (THD.InDay = 10 OR THD.InDay = 0 OR THD.ClockAdjustmentNo <> ' ') THEN NULL
	 WHEN  @TimePrecision = 'A'												THEN convert(varchar(8),IsNull(THD.ActualInTime,THD.InTime),108) 
	 WHEN  @TimePrecision = 'R'												THEN THD.InTime 
	 ELSE THD.InTime END as InTime, 
THD.ActualInTime, THD.ClockAdjustmentNo, THD.AdjustmentCode, THD.OutSrc, THD.OutUserCode, CASE WHEN THD.OutDay = 10 THEN '0' ELSE THD.OutDay END as OutDay ,  THD.ActualOutTime, 
CASE WHEN (THD.OutDay = 10 OR THD.OutDay = 0 OR THD.ClockAdjustmentNo <> ' ') THEN NULL
	 WHEN  @TimePrecision = 'A'												THEN convert(varchar(8),IsNull(THD.ActualOutTime,THD.OutTime),108) 
	 WHEN  @TimePrecision = 'R'												THEN THD.OutTime 
	 ELSE THD.OutTime END as OutTime, 
(CASE WHEN THD.AdjustmentName is NULL or THD.AdjustmentName = '' THEN THD.ClockAdjustmentNo Else THD.AdjustmentName END) as AdjustmentName,
THD.Hours, THD.RegHours, THD.OT_Hours,  THD.DT_Hours
  FROM TimeHistory.dbo.tblTimeHistDetail AS THD INNER JOIN
  TimeCurrent.dbo.tblEmplNames as EN ON THD.Client = EN.Client AND THD.GroupCode = EN.GroupCode and THD.SSN = EN.SSN INNER JOIN 
  ClientShiftsCTE as DV ON THD.Client = DV.Client AND THD.GroupCode = DV.GroupCode and THD.DivisionID =  DV.Division  INNER JOIN
  ClientShiftsCTE as GD ON THD.Client = GD.Client AND THD.GroupCode = GD.GroupCode and THD.DeptNo = GD.DeptNo INNER JOIN
  ClientShiftsCTE as SN ON THD.Client = SN.Client AND THD.GroupCode = SN.GroupCode and THD.SiteNo = SN.SiteNo INNER JOIN
  TimeCurrent.dbo.tblDayDef InDaydef ON InDaydef.DayNo = CASE WHEN THD.InDay > 7 OR THD.InDay = 7 THEN '0' ELSE THD.InDay END INNER JOIN
  TimeCurrent.dbo.tblDayDef OutDaydef ON OutDaydef.DayNo = CASE WHEN THD.OutDay > 7 OR THD.OutDay = 7 THEN '0' ELSE THD.OutDay END
	
  WHERE DV.Level = 4 AND GD.Level = 3 AND sn.Level = 2
  AND THD.PayrollPeriodEndDate = @Date
  AND 
	 (
	  EXISTS (Select NULL Where @ClusterId = 4 OR @ClusterId IS NULL)
	  OR    --if group level cluster exists, don't restrict
	  EXISTS (Select 1 from timecurrent.dbo.tblClusterDef where ClusterID = @ClusterID and Type = 'G' and GroupCode = @Group and RecordStatus = '1')
	  OR
			(
			 Exists(Select 1 from timecurrent.dbo.tblClusterDef where ClusterID = @ClusterID and Type != 'C' and GroupCode = @Group and RecordStatus = '1')
			 AND
			 dbo.usp_GetTimeHistoryClusterDefAsFn (THD.groupcode,THD.siteno,THD.deptno,THD.agencyno,THD.ssn,THD.DivisionID,THD.shiftno, @ClusterID ) = '1'
			)
	  OR  -- if site level is the only type, then do inner join rather than going thru fn
	  EXISTS (Select * From TimeCurrent.dbo.tblClusterDef Cluster 
			   Where Cluster.Client = THD.Client 
			   AND Cluster.GroupCode = THD.GroupCode
			   AND Cluster.SiteNo = THD.SiteNo 
			   AND Cluster.ClusterID = @clusterID 
			   AND Cluster.Type = 'C' 
			   AND Cluster.RecordStatus = '1' 
			  )
     )
    

  AND  (
			(@ref1 = 'W') or 
				((@ref1 = 'A') and (LEN(THD.AdjustmentCode) = 0 )) OR
					(
						(@ref1 = 'A') and (LEN(THD.AdjustmentCode) > 0 )
						AND EXISTS (Select * FROM TimeCurrent.dbo.tblAdjCodes ac
									Where THD.AdjustmentCode = AC.AdjustmentCode
									AND THD.Client = AC.Client
									AND THD.GroupCode = AC.GroupCode
									AND (AC.Worked is NULL or AC.Worked = 'Y')
									)
					)
	  )  
)

SELECT SuperVisorName, SSN, LastName , FirstName, DeptName , TransDate,  InDayName, InTime,
OutDayName, OutTime, AdjustmentName, Hours, RegHours, OT_Hours,  DT_Hours 
FROM THDcte
Order by SuperVisorName,LastName,FirstName,SSN, TransDate,  InTime


END



