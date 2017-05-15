CREATE Procedure [dbo].[usp_APP_1z2z_PaidLunch]
(
  @Client varchar(4),  
  @Group integer, 
  @PPED DATETIME,
  @SSN integer
) 
As


SET NOCOUNT ON

DECLARE @OutTime datetime
DECLARE @iOutTime datetime
DECLARE @InTime DateTime
DECLARE @NewInTime DateTime
DECLARE @NewInDay int
DECLARE @TransDate datetime
DECLARE @Minutes numeric(7,2)
DECLARE @MPD datetime
DECLARE @RecordID int
DECLARE @oRecordID BIGINT  --< @oRecordID data type is converted from INT to BIGINT by Srinsoft on 28July2016 >--
DECLARE @iRecordID BIGINT  --< @iRecordID data type is converted from INT to BIGINT by Srinsoft on 28July2016 >--
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @TotHours numeric(9,2)
DECLARE @MinLunchMinutes INT 
DECLARE @MaxLunchMinutes INT 
DECLARE @MinHoursPerDay NUMERIC(7,2)
DECLARE @PaidMinutes INT 
DECLARE @DailyHours NUMERIC(7,2)
DECLARE @PPSD DATETIME
DECLARE @ClientID varchar(50)
DECLARE @WorkSiteID varchar(50)
DECLARE @PaidLunchStatus INT 

SELECT @PPSD = DATEADD(dd, -6, @PPED)

IF EXISTS(SELECT 1
					FROM TimeCurrent.dbo.tblEmplAssignments ea WITH(NOLOCK)
					INNER JOIN TimeCurrent.dbo.tblRFR_Hierarchy_ClientWorkSite_Rules rules WITH(NOLOCK)
					ON rules.Client = ea.Client
					AND rules.ClientID = ea.ClientID
					AND ISNULL(rules.PdLunch_Status, '0') = '1'
					WHERE ea.Client = @Client
					AND ea.GroupCode = @Group
					AND ea.SSN = @SSN
					AND ((@PPSD between ea.StartDate AND CASE WHEN ISNULL(ea.EndDate, '01/01/1900') = '01/01/1900' THEN @PPSD ELSE ea.EndDate END) OR 
							 (@PPED between ea.StartDate AND CASE WHEN ISNULL(ea.EndDate, '01/01/1900') = '01/01/1900' THEN @PPED ELSE ea.EndDate END) OR
							 ((ea.StartDate BETWEEN @PPSD AND @PPED) AND (ea.EndDate BETWEEN @PPSD AND @PPED))))
BEGIN
	
	DELETE FROM TimeHistory..tblTimeHistDetail
	WHERE Client = @Client
	AND GroupCode = @Group
	AND SSN = @SSN
	AND ClockAdjustmentNo = '8'
	AND AdjustmentName = 'PD_LUNCH'
	AND UserCode = 'SYS'
	AND PayrollPeriodEndDate = @PPED

	DECLARE cPunch CURSOR READ_ONLY FOR 
	SELECT 	o.ActualOutTime, 
					o.RecordID, 
					i.ActualInTime, 
					i.OutTime, 
					i.SiteNo, 
					i.DeptNo, 
					i.RecordID, 
					i.TransDate, 
					i.MasterPayrollDate,
				 	DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)),
				 	(SELECT SUM(thd.Hours)
				 	 FROM TimeHistory.dbo.tblTimeHistDetail thd
				 	 WHERE thd.Client = o.Client
				 	 AND thd.GroupCode = o.GroupCode
				 	 AND thd.SSN = o.SSN
				 	 AND thd.PayrollPeriodEndDate = o.PayrollPeriodEndDate
				 	 AND thd.TransDate = o.TransDate) AS DailyHours,
					ea.ClientID,
					ea.WorkSiteID
					/*(	SELECT 	TOP 1 CASE WHEN IsNull(rules.WorkSiteID, '') = '' THEN 1 ELSE 0 END as SortOrder, 
											rules.PdLunch_MinDailyHours,
											rules.PdLunch_AmtPaidMins
							FROM TimeCurrent.dbo.tblRFR_Hierarchy_ClientWorkSite_Rules rules
							WHERE rules.Client = ea.Client
							AND rules.ClientID = ea.ClientID
							AND ((isnull(rules.WorkSiteID, '') = '') OR (rules.WorkSiteID = ea.WorkSiteID))
							ORDER BY 1
						 ) */
	FROM TimeHistory..tblTimeHistDetail as o
	INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea
	ON ea.Client = o.Client
	AND ea.GroupCode = o.GroupCode
	AND ea.SSN = o.SSN
	AND ea.SiteNo = o.SiteNo
	AND ea.DeptNo = o.DeptNo
	INNER JOIN TimeHistory..tblTimeHistDetail as i
	ON i.Client = o.Client
	AND i.Groupcode = o.GroupCode
	AND i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
	AND i.SSN = o.SSN
--	AND datediff(minute, isnull(o.ActualOutTime,dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime)), 
--											 isnull(i.ActualInTime,dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) ) between isnull(rul.PdLunch_MinSpanMins, 0) and isnull(PdLunch_MaxSpanMins, -1)
	WHERE o.Client = @Client
	AND o.Groupcode = @Group
	AND o.Payrollperiodenddate = @PPED
	AND o.SSN = @SSN
	AND o.OutDay NOT IN (10, 11)
	AND i.INDay NOT IN (10, 11)
	AND i.ClockAdjustmentNo IN ('', ' ')
	AND o.ClockAdjustmentNo IN ('', ' ')
	AND o.Hours > 0
	AND i.Hours > 0
	/*AND NOT EXISTS (SELECT 1
									FROM TimeHistory..tblTimeHistDetail thd1
									WHERE thd1.Client = @Client
									AND thd1.GroupCode = @Group
									AND thd1.PayrollPeriodEndDate = @PPED
									AND thd1.SSN = @SSN
									AND thd1.TransDate = o.TransDate
									AND thd1.ClockAdjustmentNo = '8')*/
	
	OPEN cPunch
	
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes, @DailyHours, @ClientID, @WorkSiteID
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN

			SELECT 	@PaidLunchStatus = CASE WHEN rules_ws.PdLunch_Status = -1 THEN rules_df.PdLunch_Status ELSE rules_ws.PdLunch_Status END,
							@MinHoursPerDay = CASE WHEN rules_ws.PdLunch_MinDailyHours = -1 THEN rules_df.PdLunch_MinDailyHours ELSE rules_ws.PdLunch_MinDailyHours END,
							@PaidMinutes = CASE WHEN rules_ws.PdLunch_AmtPaidMins = -1 THEN rules_df.PdLunch_AmtPaidMins ELSE rules_ws.PdLunch_AmtPaidMins END,
							@MinLunchMinutes = CASE WHEN rules_ws.PdLunch_MinSpanMins = -1 THEN rules_df.PdLunch_MinSpanMins ELSE rules_ws.PdLunch_MinSpanMins END,
							@MaxLunchMinutes = CASE WHEN rules_ws.PdLunch_MaxSpanMins = -1 THEN rules_df.PdLunch_MaxSpanMins ELSE rules_ws.PdLunch_MaxSpanMins END
			FROM TimeCurrent.dbo.tblRFR_Hierarchy_ClientWorkSite_Rules rules_df
			LEFT JOIN TimeCurrent.dbo.tblRFR_Hierarchy_ClientWorkSite_Rules rules_ws
			ON rules_ws.Client = rules_df.Client
			AND rules_ws.ClientID = rules_df.ClientID
			AND rules_ws.WorkSiteID = @WorkSiteID		 
			WHERE rules_df.Client = @Client
			AND rules_df.ClientID = @ClientID
			AND rules_df.WorkSiteID = '-1'
	
			IF (@PaidLunchStatus = '1')
			BEGIN
				IF (@Minutes BETWEEN @MinLunchMinutes AND @MaxLunchMinutes)
				BEGIN
					IF (@Minutes > @PaidMinutes)
					BEGIN
						SET @Minutes = @PaidMinutes
					END
					SELECT @TotHours = @Minutes / 60
					
					--PRINT 'Minutes: ' + CAST(@Minutes AS VARCHAR)
					--PRINT 'PaidMinutes: ' + CAST(@PaidMinutes AS VARCHAR)			
					--PRINT 'TotHours: ' + CAST(@TotHours AS VARCHAR)						
						
					IF (@DailyHours > @MinHoursPerDay)
					BEGIN
			
				    EXEC TimeHistory.dbo.usp_APP_XLSImport_Adjustment_Insert_THD 	@Client, @Group, @PPED, @SSN, @SiteNo, @DeptNo, '8', 'PD_LUNCH', 
																																					@TotHours, 0, @TransDate, @MPD, 'SYS'
					END
				END
			END
		END
		FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes, @DailyHours, @ClientID, @WorkSiteID
	END
	
	CLOSE cPunch
	DEALLOCATE cPunch

END






