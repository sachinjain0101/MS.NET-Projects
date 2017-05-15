Create PROCEDURE [dbo].[usp_Web1_GetTimeHistDetail_Aprv3]
 @Client varchar(4), 
 @GroupCode int,
 @ViewMasterPayroll int,
 @PeriodDate datetime,
 @SSN int,
 @ClusterId integer = NULL,
 @PayBill char(1)   
 
AS


DECLARE @MPD datetime
DECLARE @FixPunchAcrossSites char(1)
DECLARE @HomeSite INT  --< @HomeSite data type is changed from  SMALLINT to INT by Srinsoft on 09Sept2016 >--
DECLARE @val varchar(20)
DECLARE @ReturnVal tinyInt
DECLARE @DivisionID int
DECLARE @PayType int


SET @ReturnVal = 0
SET @FixPunchAcrossSites = (SELECT isNull(FixPunchAcrossSites, '0')
		 	    FROM TimeCurrent..tblClientGroups
			    WHERE Client = @Client
			    AND groupCode = @GroupCode)

SELECT @DivisionID = isNULL(DivisionID, -1), @PayType = PayType
FROM timeCurrent..tblEmplNames
WHERE ssn = @SSN
AND groupcode = @GroupCode
AND client = @Client

IF @FixPunchAcrossSites	= '1'		    
--Allow anyone with primary site access to fix punches for the ee even if the worked site is different
BEGIN
	SET @HomeSite = (SELECT PrimarySite
			 FROM TimeCurrent..tblEmplNames
			 WHERE Client = @Client
			 AND GroupCode = @GroupCode
			 AND SSN = @SSN)
	--Check if cluster contains the HomeSite
	SET @val = replace(str(@GroupCode,6) + str(@HomeSite, 4), ' ','0')
	SELECT @ReturnVal = (SELECT	Count(*)
			     FROM 	TimeCurrent..tblClusterDef
			     WHERE 	ClusterID = @ClusterID
			     AND	Type = 'C'
     	     AND	Value = @val
           AND RecordStatus = '1')
END


--First create a list of record id's that correspond to records that are part of the current cluster definition
-----------------------------------------------------------------------------------------------------------------------------

DECLARE @ShowActual      AS tinyint
SET @ShowActual = 1
	
IF @ViewMasterPayroll = 1
BEGIN

	SELECT @MPD = (	   select top 1 MasterPayrollDate
	                   from tbltimehistdetail 
	                           where client = @Client
	                   and groupcode = @GroupCode
	                   and ssn = @SSN
	                   and PayrollPeriodEndDate = @PeriodDate)
 

	--only difference between the clients are the ORDER BY clause
	If @Client in('DAVI','DVPC', 'DVPG','DAVT')
	Begin
		SELECT 	tblTimeHistDetail.*,
			tblAdjCodes.SpecialHandling,
			convert(varchar(08),TransDate,1) as TransDate_mdy,
			tblEmplNames.MissingPunch,
			tblPeriodEndDates.Status,
			--next case stmt is to handle virtual sites -- change it to open status if current date is less than @pped + 1
			--w/o this change, fix punch link won't show in some cases
			(case when (IsNull(tblSiteNames.WeekClosed, 'O') = 'M' and getDate() < timecurrent.dbo.getSiteppedDatetime( tblTimeHistDetail.payrollPeriodEndDate, @Client, @GroupCode,tblTimeHistDetail.SiteNo)) then 'O' else IsNull(tblSiteNames.WeekClosed, '0') end) as WeekClosed,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualInTime IS NOT NULL THEN ActualInTime ELSE InTime END,8) as InTime_hm,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualOutTime IS NOT NULL THEN ActualOutTime ELSE OutTime END,8) as OutTime_hm, 
			tblDayDef.DayAbrev as InDayAbrev, 
		 	tblDayDef_1.DayAbrev as OutDayAbrev, 
			TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
			tblInOutSrc_1.SrcAbrev as OutSrcAbrev, 
		 	(case when dbo.usp_GetTimeHistoryClusterDefAsFn (
							tblTimeHistDetail.groupcode,
							tblTimeHistDetail.siteno,
							tblTimeHistDetail.deptno,
							tblTimeHistDetail.agencyno,
							tblTimeHistDetail.ssn,
							@DivisionID,
							tblTimeHistDetail.shiftno,
							@ClusterID) = 1  OR @ReturnVal > 0 then '1' else '0' end) as RecInClusterDef,
			(case when (tblTimeHistDetail.ClockAdjustmentNo = '$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigClkAdjNo else tblTimeHistDetail.ClockAdjustmentNo END) as ClkAdjSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigRecID else tblTimeHistDetail.RecordID END) as RecordIDSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
			CT = '0', IsNull(TCSite.virtualSite, '0') VirtualSite, IsNull(TCSite.ClockType, 'T') ClockType,
			ActualInPunch = dbo.PunchDateTime(tblTimeHistDetail.transDate, InDay, InTime),
							tblTimeHistDetail.CostID
		FROM 	tblTimeHistDetail
		INNER JOIN tblEmplNames ON tblTimeHistDetail.Client = tblEmplNames.Client
		and 	tblTimeHistDetail.GroupCode = tblEmplNames.GroupCode
		and 	tblTimeHistDetail.PayrollPeriodEndDate = tblEmplNames.PayrollPeriodEndDate
		and 	tblTimeHistDetail.SSN = tblEmplNames.SSN
		INNER JOIN tblPeriodEndDates ON tblPeriodEndDates.Client = tblTimeHistDetail.Client
		and 	tblPeriodEndDates.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblPeriodEndDates.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		LEFT  JOIN tblSiteNames ON tblSiteNames.Client = tblTimeHistDetail.Client
		and 	tblSiteNames.GroupCode = tblTimeHistDetail.GroupCode
		and	tblSiteNames.SiteNo = tblTimeHistDetail.SiteNo
		and 	tblSiteNames.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		LEFT  JOIN timecurrent..tblSiteNames as TCSite ON TCSite.Client = tblTimeHistDetail.Client
		and 	TCSite.GroupCode = tblTimeHistDetail.GroupCode
		and	TCSite.SiteNo = tblTimeHistDetail.SiteNo
		LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
		LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo 
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src

		LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
		LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = tblTimeHistDetail.Client
		and 	tblAdjCodes.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblAdjCodes.ClockAdjustmentNo = tblTimeHistDetail.ClockAdjustmentNo
		WHERE 	tblTimeHistDetail.Client = @Client
		and 	tblTimeHistDetail.GroupCode = @GroupCode
		and tblTimeHistDetail.MasterPayrollDate = @MPD
		and tblPeriodEndDates.MasterPayrollDate = @MPD
		and tblTimeHistDetail.SSN = @SSN
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	  	ORDER BY TransDate, ClkAdjSeq, tblTimeHistDetail.InTime, tblTimeHistDetail.ClkTransNo, RecordIDSeq, tblTimeHistDetail.RecordID

	End
	ELSE IF @Client = 'SALI' 
	--for SALI, MPD is based on primarysite's UploadAsSiteNo col
	BEGIN
	--Assumption : Sali is alway bi-weekly.  Can't use MPD because MPD is based on group and is wrong for 'SALI'
	-- Need to get 1st and 2nd week based on UploadAsSiteNo col.
	
		DECLARE @Week1 Datetime
		DECLARE @Week2 Datetime
		DECLARE @CycleDate datetime
		DECLARE @PayrollGroupID int
		DECLARE @UploadSiteNo INT  --< @UploadSiteNo data type is changed from  SMALLINT to INT by Srinsoft on 09Sept2016 >--
		
		Set @CycleDate = (Select PeriodEndCycleStartDate from timecurrent..tblClientGroups where client = @Client and Groupcode = @GroupCode )
		
		Set @PayrollGroupID = (datediff(week, @CycleDate, @PeriodDate) % 2 ) + 1
		
		Set @UploadSiteNo = (Select ISNULL(UploadAsSiteNo, 1) FROM TimeCurrent..TblSiteNames st
					INNER JOIN TimeCurrent..TblEmplNames ee
					ON st.SiteNo = ee.PrimarySite
					AND st.Client = ee.Client
					AND st.GroupCode = ee.GroupCode
					AND ee.SSN = @SSN
					WHERE st.Client = @Client
					AND st.GroupCode = @GroupCode
					AND st.RecordStatus = '1')
		
		IF @UploadSiteNo = @PayrollGroupID
		BEGIN
		--current week is the MPD
			Set @Week2 = @PeriodDate
			Set @Week1 = DateAdd(d, -7, @Week2)
		END
		ELSE
		BEGIN
		--Next week is the MPD
			Set @Week1 = @PeriodDate
			Set @Week2 = DateAdd(d, 7, @Week1)
		END
		
		SELECT 	tblTimeHistDetail.*,
			tblAdjCodes.SpecialHandling,
			convert(varchar(08),TransDate,1) as TransDate_mdy,
			tblEmplNames.MissingPunch,
			tblPeriodEndDates.Status,
			--next case stmt is to handle virtual sites -- change it to open status if current date is less than @pped + 1
			(case when (tblSiteNames.WeekClosed = 'M' and getDate() < timecurrent.dbo.getSiteppedDatetime( tblTimeHistDetail.payrollPeriodEndDate, @Client, @GroupCode,tblTimeHistDetail.SiteNo)) then 'O' else tblSiteNames.WeekClosed end) as WeekClosed,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualInTime IS NOT NULL THEN ActualInTime ELSE InTime END,8) as InTime_hm,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualOutTime IS NOT NULL THEN ActualOutTime ELSE OutTime END,8) as OutTime_hm, 
			tblDayDef.DayAbrev as InDayAbrev, 
		 	tblDayDef_1.DayAbrev as OutDayAbrev, 
			TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
			tblInOutSrc_1.SrcAbrev as OutSrcAbrev, 
		 	(case when dbo.usp_GetTimeHistoryClusterDefAsFn (
							tblTimeHistDetail.groupcode,
							tblTimeHistDetail.siteno,
							tblTimeHistDetail.deptno,
							tblTimeHistDetail.agencyno,
							tblTimeHistDetail.ssn,
							@DivisionID,
							tblTimeHistDetail.shiftno,
							@ClusterID) = 1 OR @ReturnVal > 0 then '1' else '0' end) as RecInClusterDef,
			(case when (tblTimeHistDetail.ClockAdjustmentNo = '$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigClkAdjNo else tblTimeHistDetail.ClockAdjustmentNo END) as ClkAdjSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigRecID else tblTimeHistDetail.RecordID END) as RecordIDSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
			CT = '0', TCSite.virtualSite, TCSite.ClockType, 
 			ActualInPunch = dbo.PunchDateTime(tblTimeHistDetail.transDate, InDay, InTime),
							tblTimeHistDetail.CostID
		FROM 	tblTimeHistDetail
		INNER JOIN tblEmplNames ON tblTimeHistDetail.Client = tblEmplNames.Client
		and 	tblTimeHistDetail.GroupCode = tblEmplNames.GroupCode
		and 	tblTimeHistDetail.PayrollPeriodEndDate = tblEmplNames.PayrollPeriodEndDate
		and 	tblTimeHistDetail.SSN = tblEmplNames.SSN
		INNER JOIN tblPeriodEndDates ON tblPeriodEndDates.Client = tblTimeHistDetail.Client
		and 	tblPeriodEndDates.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblPeriodEndDates.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		INNER  JOIN tblSiteNames ON tblSiteNames.Client = tblTimeHistDetail.Client
		and 	tblSiteNames.GroupCode = tblTimeHistDetail.GroupCode
		and	tblSiteNames.SiteNo = tblTimeHistDetail.SiteNo
		and 	tblSiteNames.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate		
		INNER  JOIN timecurrent..tblSiteNames as TCSite ON TCSite.Client = tblTimeHistDetail.Client
		and 	TCSite.GroupCode = tblTimeHistDetail.GroupCode
		and	TCSite.SiteNo = tblTimeHistDetail.SiteNo
		LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
		LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo 
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
		LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = tblTimeHistDetail.Client
		and 	tblAdjCodes.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblAdjCodes.ClockAdjustmentNo = tblTimeHistDetail.ClockAdjustmentNo
		WHERE 	tblTimeHistDetail.Client = @Client
		and 	tblTimeHistDetail.GroupCode = @GroupCode
		and tblTimeHistDetail.PayrollPeriodEndDate IN (@Week1, @Week2)
		and tblTimeHistDetail.SSN = @SSN
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	  
		ORDER BY TransDate, ClkAdjSeq, tblTimeHistDetail.ClkTransNo, tblTimeHistDetail.InTime, RecordIDSeq, tblTimeHistDetail.RecordID
	
	
	
	
	END
	
	ELSE IF @Client IN('GAMB','GTS', 'DVPC','DVPG')
	BEGIN
		SELECT 	tblTimeHistDetail.*,
			tblAdjCodes.SpecialHandling,
			convert(varchar(08),TransDate,1) as TransDate_mdy,

			tblEmplNames.MissingPunch,
			tblPeriodEndDates.Status,
			--next case stmt is to handle virtual sites -- change it to open status if current date is less than @pped + 1
			(case when (tblSiteNames.WeekClosed = 'M' and getDate() < timecurrent.dbo.getSiteppedDatetime( tblTimeHistDetail.payrollPeriodEndDate, @Client, @GroupCode,tblTimeHistDetail.SiteNo)) then 'O' else tblSiteNames.WeekClosed end) as WeekClosed,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualInTime IS NOT NULL THEN ActualInTime ELSE InTime END,8) as InTime_hm,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualOutTime IS NOT NULL THEN ActualOutTime ELSE OutTime END,8) as OutTime_hm, 
			tblDayDef.DayAbrev as InDayAbrev, 
		 	tblDayDef_1.DayAbrev as OutDayAbrev, 
			TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
			tblInOutSrc_1.SrcAbrev as OutSrcAbrev, 
		 	(case when dbo.usp_GetTimeHistoryClusterDefAsFn (
							tblTimeHistDetail.groupcode,
							tblTimeHistDetail.siteno,
							tblTimeHistDetail.deptno,
							tblTimeHistDetail.agencyno,
							tblTimeHistDetail.ssn,
							@DivisionID,
							tblTimeHistDetail.shiftno,
							@ClusterID) = 1 OR @ReturnVal > 0 then '1' else '0' end) as RecInClusterDef,
			(case when (tblTimeHistDetail.ClockAdjustmentNo = '$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigClkAdjNo else tblTimeHistDetail.ClockAdjustmentNo END) as ClkAdjSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigRecID else tblTimeHistDetail.RecordID END) as RecordIDSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
			CT = '0', TCSite.virtualSite, TCSite.ClockType, 
			ActualInPunch = dbo.PunchDateTime(tblTimeHistDetail.transDate, InDay, InTime),
							tblTimeHistDetail.CostID
		FROM 	tblTimeHistDetail
		INNER JOIN tblEmplNames ON tblTimeHistDetail.Client = tblEmplNames.Client
		and 	tblTimeHistDetail.GroupCode = tblEmplNames.GroupCode
		and 	tblTimeHistDetail.PayrollPeriodEndDate = tblEmplNames.PayrollPeriodEndDate
		and 	tblTimeHistDetail.SSN = tblEmplNames.SSN
		INNER JOIN tblPeriodEndDates ON tblPeriodEndDates.Client = tblTimeHistDetail.Client
		and 	tblPeriodEndDates.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblPeriodEndDates.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		LEFT  JOIN tblSiteNames ON tblSiteNames.Client = tblTimeHistDetail.Client
		and 	tblSiteNames.GroupCode = tblTimeHistDetail.GroupCode
		and	tblSiteNames.SiteNo = tblTimeHistDetail.SiteNo
		and 	tblSiteNames.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate		
		LEFT  JOIN timecurrent..tblSiteNames as TCSite ON TCSite.Client = tblTimeHistDetail.Client
		and 	TCSite.GroupCode = tblTimeHistDetail.GroupCode
		and	TCSite.SiteNo = tblTimeHistDetail.SiteNo
		LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
		LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo 
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
		LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = tblTimeHistDetail.Client
		and 	tblAdjCodes.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblAdjCodes.ClockAdjustmentNo = tblTimeHistDetail.ClockAdjustmentNo

		WHERE 	tblTimeHistDetail.Client = @Client
		and 	tblTimeHistDetail.GroupCode = @GroupCode
		and tblTimeHistDetail.MasterPayrollDate = @MPD
		and tblTimeHistDetail.SSN = @SSN
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
		ORDER BY TransDate, ClkAdjSeq, --tblTimeHistDetail.ClkTransNo, 
--->
      CASE WHEN dbo.PunchDateTime2(tblTimeHistDetail.TransDate, tblTimeHistDetail.InDay, tblTimeHistDetail.InTime) IS NULL THEN
      dbo.PunchDateTime2(tblTimeHistDetail.TransDate, tblTimeHistDetail.OutDay, tblTimeHistDetail.OutTime) ELSE
      dbo.PunchDateTime2(tblTimeHistDetail.TransDate, tblTimeHistDetail.InDay, tblTimeHistDetail.InTime) END,
--->
      tblTimeHistDetail.InTime, 
      RecordIDSeq, tblTimeHistDetail.RecordID

	END

	ELSE

	Begin
		SELECT 	tblTimeHistDetail.*,
			tblAdjCodes.SpecialHandling,
			convert(varchar(08),TransDate,1) as TransDate_mdy,
			tblEmplNames.MissingPunch,
			tblPeriodEndDates.Status,
			--next case stmt is to handle virtual sites -- change it to open status if current date is less than @pped + 1
			(case when (tblSiteNames.WeekClosed = 'M' and getDate() < timecurrent.dbo.getSiteppedDatetime( tblTimeHistDetail.payrollPeriodEndDate, @Client, @GroupCode,tblTimeHistDetail.SiteNo)) then 'O' else tblSiteNames.WeekClosed end) as WeekClosed,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualInTime IS NOT NULL THEN ActualInTime ELSE InTime END,8) as InTime_hm,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualOutTime IS NOT NULL THEN ActualOutTime ELSE OutTime END,8) as OutTime_hm, 
			tblDayDef.DayAbrev as InDayAbrev, 
		 	tblDayDef_1.DayAbrev as OutDayAbrev, 
			TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
			tblInOutSrc_1.SrcAbrev as OutSrcAbrev, 
		 	(case when dbo.usp_GetTimeHistoryClusterDefAsFn (
							tblTimeHistDetail.groupcode,
							tblTimeHistDetail.siteno,
							tblTimeHistDetail.deptno,
							tblTimeHistDetail.agencyno,
							tblTimeHistDetail.ssn,
							@DivisionID,
							tblTimeHistDetail.shiftno,
							@ClusterID) = 1 OR @ReturnVal > 0 then '1' else '0' end) as RecInClusterDef,
			(case when (tblTimeHistDetail.ClockAdjustmentNo = '$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigClkAdjNo else tblTimeHistDetail.ClockAdjustmentNo END) as ClkAdjSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigRecID else tblTimeHistDetail.RecordID END) as RecordIDSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
			CT = '0', TCSite.virtualSite, TCSite.ClockType, 
			ActualInPunch = dbo.PunchDateTime(tblTimeHistDetail.transDate, InDay, InTime),
							tblTimeHistDetail.CostID
		FROM 	tblTimeHistDetail
		INNER JOIN tblEmplNames ON tblTimeHistDetail.Client = tblEmplNames.Client
		and 	tblTimeHistDetail.GroupCode = tblEmplNames.GroupCode
		and 	tblTimeHistDetail.PayrollPeriodEndDate = tblEmplNames.PayrollPeriodEndDate
		and 	tblTimeHistDetail.SSN = tblEmplNames.SSN
		INNER JOIN tblPeriodEndDates ON tblPeriodEndDates.Client = tblTimeHistDetail.Client
		and 	tblPeriodEndDates.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblPeriodEndDates.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		INNER  JOIN tblSiteNames ON tblSiteNames.Client = tblTimeHistDetail.Client
		and 	tblSiteNames.GroupCode = tblTimeHistDetail.GroupCode
		and	tblSiteNames.SiteNo = tblTimeHistDetail.SiteNo
		and 	tblSiteNames.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate		
		INNER  JOIN timecurrent..tblSiteNames as TCSite ON TCSite.Client = tblTimeHistDetail.Client
		and 	TCSite.GroupCode = tblTimeHistDetail.GroupCode
		and	TCSite.SiteNo = tblTimeHistDetail.SiteNo
		LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
		LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo 
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
		LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = tblTimeHistDetail.Client
		and 	tblAdjCodes.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblAdjCodes.ClockAdjustmentNo = tblTimeHistDetail.ClockAdjustmentNo
		WHERE 	tblTimeHistDetail.Client = @Client
		and 	tblTimeHistDetail.GroupCode = @GroupCode
		and tblTimeHistDetail.MasterPayrollDate = @MPD
		and tblTimeHistDetail.SSN = @SSN
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	  
		ORDER BY TransDate, ClkAdjSeq, ActualInPunch, tblTimeHistDetail.ClkTransNo, RecordIDSeq, tblTimeHistDetail.RecordID
	End

	
END


else
BEGIN

	--only difference between the clients are the ORDER BY clause
	If @Client in('DAVI','DVPC', 'DVPG','DAVT')

	Begin
		SELECT 	tblTimeHistDetail.*,
			tblAdjCodes.SpecialHandling,
			convert(varchar(08),TransDate,1) as TransDate_mdy,
			tblEmplNames.MissingPunch,
			tblPeriodEndDates.Status,
			--next case stmt is to handle virtual sites -- change it to open status if current date is less than @pped + 1
			(case when (tblSiteNames.WeekClosed = 'M' and getDate() < timecurrent.dbo.getSiteppedDatetime( @PeriodDate, @Client, @GroupCode,tblTimeHistDetail.SiteNo)) then 'O' else tblSiteNames.WeekClosed end) as WeekClosed,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualInTime IS NOT NULL THEN ActualInTime ELSE InTime END,8) as InTime_hm,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualOutTime IS NOT NULL THEN ActualOutTime ELSE OutTime END,8) as OutTime_hm, 
			tblDayDef.DayAbrev as InDayAbrev, 
		 	tblDayDef_1.DayAbrev as OutDayAbrev, 
			TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
			tblInOutSrc_1.SrcAbrev as OutSrcAbrev, 
		 	(case when dbo.usp_GetTimeHistoryClusterDefAsFn (
							tblTimeHistDetail.groupcode,
							tblTimeHistDetail.siteno,
							tblTimeHistDetail.deptno,
							tblTimeHistDetail.agencyno,
							tblTimeHistDetail.ssn,
							@DivisionID,
							tblTimeHistDetail.shiftno,
							@ClusterID) = 1 OR @ReturnVal > 0 then '1' else '0' end) as RecInClusterDef,
			(case when (tblTimeHistDetail.ClockAdjustmentNo = '$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigClkAdjNo else tblTimeHistDetail.ClockAdjustmentNo END) as ClkAdjSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigRecID else tblTimeHistDetail.RecordID END) as RecordIDSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
			CT = '0', TCSite.virtualSite, TCSite.ClockType, 
			ActualInPunch = dbo.PunchDateTime(tblTimeHistDetail.transDate, InDay, InTime),
							tblTimeHistDetail.CostID
		FROM 	tblTimeHistDetail
		INNER JOIN tblEmplNames ON tblTimeHistDetail.Client = tblEmplNames.Client
		and 	tblTimeHistDetail.GroupCode = tblEmplNames.GroupCode
		and 	tblTimeHistDetail.PayrollPeriodEndDate = tblEmplNames.PayrollPeriodEndDate
		and 	tblTimeHistDetail.SSN = tblEmplNames.SSN
		INNER JOIN tblPeriodEndDates ON tblPeriodEndDates.Client = tblTimeHistDetail.Client
		and 	tblPeriodEndDates.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblPeriodEndDates.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		INNER  JOIN tblSiteNames ON tblSiteNames.Client = tblTimeHistDetail.Client
		and 	tblSiteNames.GroupCode = tblTimeHistDetail.GroupCode
		and	tblSiteNames.SiteNo = tblTimeHistDetail.SiteNo
		and 	tblSiteNames.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate		
		INNER  JOIN timecurrent..tblSiteNames as TCSite ON TCSite.Client = tblTimeHistDetail.Client
		and 	TCSite.GroupCode = tblTimeHistDetail.GroupCode
		and	TCSite.SiteNo = tblTimeHistDetail.SiteNo
		LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
		LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo 
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
		LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = tblTimeHistDetail.Client
		and 	tblAdjCodes.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblAdjCodes.ClockAdjustmentNo = tblTimeHistDetail.ClockAdjustmentNo
		WHERE 	tblTimeHistDetail.Client = @Client
		and 	tblTimeHistDetail.GroupCode = @GroupCode
		and tblTimeHistDetail.PayrollPeriodEndDate = @PeriodDate
		and tblTimeHistDetail.SSN = @SSN
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	  	ORDER BY TransDate, ClkAdjSeq, tblTimeHistDetail.InTime, tblTimeHistDetail.ClkTransNo, RecordIDSeq, tblTimeHistDetail.RecordID

	End
	
	ELSE IF @Client in('GAMB','GTS', 'DVPC', 'DVPG')
	BEGIN
		SELECT 	tblTimeHistDetail.*,
			tblAdjCodes.SpecialHandling,
			convert(varchar(08),TransDate,1) as TransDate_mdy,
			tblEmplNames.MissingPunch,
			tblPeriodEndDates.Status,
			--next case stmt is to handle virtual sites -- change it to open status if current date is less than @pped + 1
			(case when (tblSiteNames.WeekClosed = 'M' and getDate() < timecurrent.dbo.getSiteppedDatetime( @PeriodDate, @Client, @GroupCode,tblTimeHistDetail.SiteNo)) then 'O' else tblSiteNames.WeekClosed end) as WeekClosed,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualInTime IS NOT NULL THEN ActualInTime ELSE InTime END,8) as InTime_hm,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualOutTime IS NOT NULL THEN ActualOutTime ELSE OutTime END,8) as OutTime_hm, 
			tblDayDef.DayAbrev as InDayAbrev, 
		 	tblDayDef_1.DayAbrev as OutDayAbrev, 
			TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
			tblInOutSrc_1.SrcAbrev as OutSrcAbrev, 
		 	(case when dbo.usp_GetTimeHistoryClusterDefAsFn (
							tblTimeHistDetail.groupcode,
							tblTimeHistDetail.siteno,
							tblTimeHistDetail.deptno,
							tblTimeHistDetail.agencyno,
							tblTimeHistDetail.ssn,
							@DivisionID,
							tblTimeHistDetail.shiftno,
							@ClusterID) = 1 OR @ReturnVal > 0 then '1' else '0' end) as RecInClusterDef,
			(case when (tblTimeHistDetail.ClockAdjustmentNo = '$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigClkAdjNo else tblTimeHistDetail.ClockAdjustmentNo END) as ClkAdjSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigRecID else tblTimeHistDetail.RecordID END) as RecordIDSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
			CT = '0', TCSite.virtualSite, TCSite.ClockType, 
			ActualInPunch = dbo.PunchDateTime(tblTimeHistDetail.transDate, InDay, InTime),
							tblTimeHistDetail.CostID
		FROM 	tblTimeHistDetail
		INNER JOIN tblEmplNames ON tblTimeHistDetail.Client = tblEmplNames.Client
		and 	tblTimeHistDetail.GroupCode = tblEmplNames.GroupCode
		and 	tblTimeHistDetail.PayrollPeriodEndDate = tblEmplNames.PayrollPeriodEndDate
		and 	tblTimeHistDetail.SSN = tblEmplNames.SSN
		INNER JOIN tblPeriodEndDates ON tblPeriodEndDates.Client = tblTimeHistDetail.Client
		and 	tblPeriodEndDates.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblPeriodEndDates.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		LEFT  JOIN tblSiteNames ON tblSiteNames.Client = tblTimeHistDetail.Client
		and 	tblSiteNames.GroupCode = tblTimeHistDetail.GroupCode
		and	tblSiteNames.SiteNo = tblTimeHistDetail.SiteNo
		and 	tblSiteNames.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate		
		LEFT  JOIN timecurrent..tblSiteNames as TCSite ON TCSite.Client = tblTimeHistDetail.Client
		and 	TCSite.GroupCode = tblTimeHistDetail.GroupCode
		and	TCSite.SiteNo = tblTimeHistDetail.SiteNo
		LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
		LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo 
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
		LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = tblTimeHistDetail.Client
		and 	tblAdjCodes.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblAdjCodes.ClockAdjustmentNo = tblTimeHistDetail.ClockAdjustmentNo
		WHERE 	tblTimeHistDetail.Client = @Client
		and 	tblTimeHistDetail.GroupCode = @GroupCode
		and tblTimeHistDetail.PayrollPeriodEndDate = @PeriodDate
		and tblTimeHistDetail.SSN = @SSN
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	  
		ORDER BY TransDate, ClkAdjSeq, tblTimeHistDetail.ClkTransNo, tblTimeHistDetail.InTime, RecordIDSeq, tblTimeHistDetail.RecordID

	END

	ELSE 

	Begin
		SELECT 	tblTimeHistDetail.*,
			tblAdjCodes.SpecialHandling,
			convert(varchar(08),TransDate,1) as TransDate_mdy,
			tblEmplNames.MissingPunch,
			tblPeriodEndDates.Status,
			--next case stmt is to handle virtual sites -- change it to open status if current date is less than @pped + 1
			(case when (tblSiteNames.WeekClosed = 'M' and getDate() < timecurrent.dbo.getSiteppedDatetime( @PeriodDate, @Client, @GroupCode,tblTimeHistDetail.SiteNo)) then 'O' else tblSiteNames.WeekClosed end) as WeekClosed,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualInTime IS NOT NULL THEN ActualInTime ELSE InTime END,8) as InTime_hm,
			convert(varchar(5),CASE WHEN @ShowActual = 1 AND ActualOutTime IS NOT NULL THEN ActualOutTime ELSE OutTime END,8) as OutTime_hm, 
			tblDayDef.DayAbrev as InDayAbrev, 
		 	tblDayDef_1.DayAbrev as OutDayAbrev, 
			TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
			tblInOutSrc_1.SrcAbrev as OutSrcAbrev, 
		 	(case when dbo.usp_GetTimeHistoryClusterDefAsFn (
							tblTimeHistDetail.groupcode,
							tblTimeHistDetail.siteno,
							tblTimeHistDetail.deptno,
							tblTimeHistDetail.agencyno,
							tblTimeHistDetail.ssn,
							@DivisionID,
							tblTimeHistDetail.shiftno,
							@ClusterID) = 1 OR @ReturnVal > 0 then '1' else '0' end) as RecInClusterDef,
			(case when (tblTimeHistDetail.ClockAdjustmentNo = '$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigClkAdjNo else tblTimeHistDetail.ClockAdjustmentNo END) as ClkAdjSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='$' or tblTimeHistDetail.ClockAdjustmentNo = '@') then tblTimeHistDetail.AprvlAdjOrigRecID else tblTimeHistDetail.RecordID END) as RecordIDSeq, 
			(case when (tblTimeHistDetail.ClockAdjustmentNo ='x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
			CT = '0', TCSite.virtualSite, TCSite.ClockType, 
			ActualInPunch = dbo.PunchDateTime(tblTimeHistDetail.transDate, InDay, InTime),
							tblTimeHistDetail.CostID
		FROM 	tblTimeHistDetail
		INNER JOIN tblEmplNames ON tblTimeHistDetail.Client = tblEmplNames.Client
		and 	tblTimeHistDetail.GroupCode = tblEmplNames.GroupCode
		and 	tblTimeHistDetail.PayrollPeriodEndDate = tblEmplNames.PayrollPeriodEndDate
		and 	tblTimeHistDetail.SSN = tblEmplNames.SSN
		INNER JOIN tblPeriodEndDates ON tblPeriodEndDates.Client = tblTimeHistDetail.Client
		and 	tblPeriodEndDates.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblPeriodEndDates.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate
		INNER  JOIN tblSiteNames ON tblSiteNames.Client = tblTimeHistDetail.Client
		and 	tblSiteNames.GroupCode = tblTimeHistDetail.GroupCode
		and	tblSiteNames.SiteNo = tblTimeHistDetail.SiteNo
		and 	tblSiteNames.PayrollPeriodEndDate = tblTimeHistDetail.PayrollPeriodEndDate		
		INNER  JOIN timecurrent..tblSiteNames as TCSite ON TCSite.Client = tblTimeHistDetail.Client
		and 	TCSite.GroupCode = tblTimeHistDetail.GroupCode
		and	TCSite.SiteNo = tblTimeHistDetail.SiteNo
		LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
		LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo 
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src
		LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
		LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = tblTimeHistDetail.Client
		and 	tblAdjCodes.GroupCode = tblTimeHistDetail.GroupCode
		and 	tblAdjCodes.ClockAdjustmentNo = tblTimeHistDetail.ClockAdjustmentNo
		WHERE 	tblTimeHistDetail.Client = @Client
		and 	tblTimeHistDetail.GroupCode = @GroupCode
		and tblTimeHistDetail.PayrollPeriodEndDate = @PeriodDate
		and tblTimeHistDetail.SSN = @SSN
		and ((@PayBill = 'B' and (tblAdjCodes.Billable <> 'N' or tblAdjCodes.Billable IS NULL))
			OR
		     (@PayBill = 'P' and (tblAdjCodes.Payable <> 'N' or tblAdjCodes.Payable IS NULL))
		    )
	
	  

		ORDER BY TransDate, ClkAdjSeq, ActualInPunch, tblTimeHistDetail.ClkTransNo, RecordIDSeq, tblTimeHistDetail.RecordID
	End


END












