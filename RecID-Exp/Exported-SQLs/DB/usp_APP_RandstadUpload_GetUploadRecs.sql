CREATE   PROCEDURE [dbo].[usp_APP_RandstadUpload_GetUploadRecs]
(
	@Client         char(4),
	@GroupCode      int,
	@PPED           datetime
)

AS


SET NOCOUNT ON
--*/

/*
DECLARE @Client         as char(4)
DECLARE @GroupCode      as int
DECLARE @PPED           as datetime

SET @Client = 'RAND'
SET @GroupCode = 317800
SET @PPED = '10/28/07'
*/
/*
  EXEC usp_APP_PRECHECK_Upload @Client, @GroupCode, @PPED, 'N'
  if @@error <> 0 
    return
*/

EXEC TimeHistory..usp_APP_OrderedFillRatio_Trigger @Client, @GroupCode, @PPED

DECLARE @UseCostID char(1)
DECLARE @AssignmentNoInCostId CHAR(1)
DECLARE @SSN int
DECLARE @FileNo varchar(32)
DECLARE @FirstName varchar(50)
DECLARE @LastName varchar(50)
DECLARE @TransDate datetime
DECLARE @Hours numeric(7,2)
DECLARE @Dollars numeric(7,2)
DECLARE @DeptNo int
DECLARE @OutputString varchar(8000)
DECLARE @crlf CHAR(2)
DECLARE @UDFMappingId INT

-- The majority of Randstad's templates have a web app code of WTE_Timesheet.  A few have a code of WTE_ClockOut because employees are prompted
-- for udf values when they clock out.  Check WTE_TimeSheet first.  If 0 is returned, try WTE_ClockOut 
SET @UDFMappingId = 0
SELECT @UDFMappingId = TimeCurrent.dbo.fn_UDF_TemplateMappingId(@Client,@GroupCode,0,0,0,'WTE_TimeSheet','','')
IF @UDFMappingId = 0
BEGIN
	SELECT @UDFMappingId = TimeCurrent.dbo.fn_UDF_TemplateMappingId(@Client,@GroupCode,0,0,0,'WTE_ClockOut','','')
END


Set @UseCostID = (select TOP 1 fd.SaveInCostID from TimeCurrent.dbo.tblUDF_Templates as t 
										Inner Join TimeCurrent..tblUDF_FieldDefs as fd
											on FD.templateid = t.TemplateID
										INNER JOIN TimeCurrent..tblUDF_TemplateMapping tm
										ON t.TemplateID = tm.TemplateID
										AND tm.TemplateMappingID = @UDFMappingId
									where t.Client = @Client and t.Recordstatus = '1' 
										and fd.Recordstatus = '1' and fd.SaveInCostID = '1')


IF isnull(@UseCostID,'') not in('1','0')
	Set @UseCostID = '0'

SET @AssignmentNoInCostId = '0'

IF (@GroupCode = 348900)
BEGIN
	SET @AssignmentNoInCostId = '1'
END

Create Table #tmpRecs
(
  SSN int,
  FileNo varchar(32),
  AssignmentNo varchar(32),
  TransDate datetime,
  Hours numeric(9,2),
  Dollars numeric(9,2),
  CostID varchar(80),
  DeptNo int,
  AdjustmentCode varchar(8),
  ClockAdjustmentNo varchar(3), --< Srinsoft 08/24/2015 Changed ClockAdjustmentNo char(1) to varchar(3) >--
  ApproverName varchar(40),
  BillingMarkupRate VARCHAR(10),
  ApprovedDateTime Datetime,
  RecordID BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
)

/*
	Vesta have special logic for training departments.  When an employee punches at the clock for his regular job
	then he punches in to dept 90 and that gets changed to 96,97 or 98 by PNE depending on the shift and day of week.
	If an employee punches into a dept less than 90 then it is not changed as this is a training dept.  These training
	departments then have to be mapped to the correct 96/97/98 department in the pay file 
*/
IF (@Client = 'RAND' AND @GroupCode = 607300)
BEGIN

	SELECT @OutputString = ''
	SELECT @crlf = char(13) + char(10)
	
	DECLARE notPaidCursor CURSOR READ_ONLY 
	FOR SELECT 	thd.SSN, 
							en.FileNo,
							en.FirstName,
							en.LastName,
							CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
							SUM(thd.Hours) AS Hours, 
						  SUM(CASE WHEN LEFT(adjs.SpecialHandling, 1) = 'D' THEN thd.Dollars * -1 ELSE thd.Dollars END) AS Dollars,
							dbo.fn_getVestaDeptNo_PayFile(@Client, @GroupCode, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo) as DeptNo
				FROM timehistory..tblTimeHistDetail thd
				LEFT JOIN TimeHistory..tblEmplNames_Depts ends
				  ON (thd.SSN = ends.SSN) 
				  AND (thd.GroupCode = ends.GroupCode) 
				  AND (thd.PayrollPeriodEndDate = ends.PayrollPeriodEndDate) 
				  AND (dbo.fn_getVestaDeptNo_PayFile(@Client, @GroupCode, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo) = ends.Department) 
				  AND (thd.Client = ends.Client) 
				INNER JOIN TimeCurrent..tblSiteNames sn
				  ON (thd.GroupCode = sn.GroupCode) 
				  AND (thd.SiteNo = sn.SiteNo) 
				  AND (thd.Client = sn.Client) 	
				INNER JOIN TimeCurrent..tblClientGroups cg
				  ON (thd.GroupCode = cg.GroupCode) 
				  AND (thd.Client = cg.Client)	
				INNER JOIN TimeCurrent..tblEmplNames as en
				  ON en.Client = thd.Client 
				  AND en.GroupCode = thd.GroupCode
			    and en.SSN = thd.SSN	
				INNER JOIN TimeCurrent..tblAdjCodes as adjs
				  ON adjs.Client = thd.Client
				  AND adjs.GroupCode = thd.GroupCode
				  AND adjs.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('8', ' ', '', '$', '@', null) THEN '1' ELSE thd.ClockAdjustmentNo END
				LEFT JOIN TimeCurrent..tblAgencies as ag
				  ON ag.Client = en.Client
				  AND	ag.GroupCode = en.GroupCode
				  AND	ag.Agency = en.AgencyNo
				WHERE (thd.Client = @Client) 
				  AND IsNull(ends.ExcludeFromUpload, '0') = 0
				  AND (cg.IncludeInUpload = 1)
				  AND (sn.IncludeInUpload = 1)
				  AND isnull(ag.ExcludeFromPayFile,'0') = '0'
				  AND (thd.PayrollPeriodEndDate = @PPED)
				  AND (thd.GroupCode = @GroupCode)
					AND (thd.ClockAdjustmentNo NOT IN ('$','Z'))  -- Adjust Bill, therefore should not be included in Pay File - GG
					AND IsNull(en.AgencyNo, 0) <= 1
					AND ends.recordid IS NULL
			GROUP BY 	thd.SSN, en.FileNo, en.FirstName, en.LastName,
							  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
							  dbo.fn_getVestaDeptNo_PayFile(@Client, @GroupCode, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo)
			ORDER BY 	thd.SSN, 
							  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END,
							  DeptNo
	OPEN notPaidCursor
	
	FETCH NEXT FROM notPaidCursor INTO @SSN, @FileNo, @FirstName, @LastName, @TransDate, @Hours, @Dollars, @DeptNo
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			SELECT @OutputString = @OutputString + IsNull(@LastName, '') + ', ' + IsNull(@FirstName, '') + '(' + IsNull(@FileNo, '') + ') dept ' + IsNull(cast(@DeptNo as varchar), '') + ' on ' + IsNull(convert(varchar, @TransDate, 101), '') + ' for ' + case when @Hours <> 0 then cast(@hours as varchar) + ' hours' else '$' + cast(@Dollars as varchar) end + @crlf
		END
		FETCH NEXT FROM notPaidCursor INTO @SSN, @FileNo, @FirstName, @LastName, @TransDate, @Hours, @Dollars, @DeptNo
	END
	CLOSE notPaidCursor
	DEALLOCATE notPaidCursor
	
	IF (@OutputString <> '')
	BEGIN
		SELECT @OutputString = 'The following transactions were not included in the payfile...' + @crlf + @OutputString 
		--PRINT @OutputString
		EXEC Scheduler..usp_APP_AddNotification 2, @GroupCode, 'RandstadUpload', 0, 0, @OutputString, ''
	END

  INSERT INTO #tmpRecs(	SSN, FileNo, AssignmentNo, TransDate, CostID, DeptNo, AdjustmentCode, ClockAdjustmentNo, 
  											ApproverName, BillingMarkupRate, Hours, Dollars, ApprovedDateTime, RecordID)
	SELECT 	thd.SSN, 
					en.FileNo,
					CASE WHEN @AssignmentNoInCostId = '0' THEN ends.AssignmentNo ELSE thd.CostId END,
					TransDate = CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
				  Costid = case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid end,
					dbo.fn_getVestaDeptNo_PayFile(@Client, @GroupCode, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo) as DeptNo,
				  LEFT(ISNULL(adjs.ADP_EarningsCode, '') + '     ', 5),
				  ClockAdjustmentNo = CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
			    ApproverName = cast('' as varchar(40)),
--			    BillingMarkupRate = RIGHT('00' + CAST(ISNULL(adjs.BillingMarkup, 0) * 100 AS VARCHAR), 5),
					BillingMarkupRate = RIGHT(LEFT('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) - 1), 3) + SUBSTRING('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) + 1, 2),
					Hours = SUM(thd.Hours), 
				  Dollars = SUM(CASE WHEN LEFT(adjs.SpecialHandling, 1) = 'D' THEN thd.Dollars * -1 ELSE thd.Dollars END),				  
			    ApprovedDateTime = max( isnull(thd.AprvlStatus_Date, getdate())),
			    MaxRecordID = Max(thd.recordID)
	FROM timehistory..tblTimeHistDetail thd
	INNER JOIN TimeHistory..tblEmplNames_Depts ends
  ON (thd.SSN = ends.SSN) 
  AND (thd.GroupCode = ends.GroupCode) 
  AND (thd.PayrollPeriodEndDate = ends.PayrollPeriodEndDate) 
  AND (dbo.fn_getVestaDeptNo_PayFile(@Client, @GroupCode, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo) = ends.Department) 
  AND (thd.Client = ends.Client) 
	INNER JOIN TimeCurrent..tblSiteNames sn
  ON (thd.GroupCode = sn.GroupCode) 
  AND (thd.SiteNo = sn.SiteNo) 
  AND (thd.Client = sn.Client) 
	INNER JOIN TimeCurrent..tblClientGroups cg
  ON (thd.GroupCode = cg.GroupCode) 
  AND (thd.Client = cg.Client)
	INNER JOIN TimeCurrent..tblEmplNames as en
  ON en.Client = thd.Client 
  AND en.GroupCode = thd.GroupCode
  and en.SSN = thd.SSN
	INNER JOIN TimeCurrent..tblAdjCodes as adjs
  ON adjs.Client = thd.Client
  AND adjs.GroupCode = thd.GroupCode
  AND ISNULL(adjs.ClockAdjustmentNo, '') = CASE WHEN thd.ClockAdjustmentNo IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END
  LEFT JOIN TimeCurrent..tblAgencies as ag
  ON ag.Client = en.Client
  AND	ag.GroupCode = en.GroupCode
  AND	ag.Agency = en.AgencyNo
  WHERE (thd.Client = @Client) 
  AND (ends.ExcludeFromUpload = 0)
  AND (cg.IncludeInUpload = 1)
  AND (sn.IncludeInUpload = 1)
  AND isnull(ag.ExcludeFromPayFile,'0') = '0'
  AND (thd.PayrollPeriodEndDate = @PPED)
  AND (thd.GroupCode = @GroupCode)
	AND (thd.ClockAdjustmentNo NOT IN ('$','Z'))  -- Adjust Bill, therefore should not be included in Pay File - GG	
  AND (thd.Hours <> 0 OR thd.Dollars <> 0)
	GROUP BY 	thd.SSN, en.FileNo,
					  CASE WHEN @AssignmentNoInCostId = '0' THEN ends.AssignmentNo ELSE thd.CostId END,
					  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
					  dbo.fn_getVestaDeptNo_PayFile(@Client, @GroupCode, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo),
					  LEFT(ISNULL(adjs.ADP_EarningsCode, '') + '     ', 5),
					  CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
					  case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid END,
				    RIGHT(LEFT('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) - 1), 3) + SUBSTRING('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) + 1, 2)
	ORDER BY 	CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
					  case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid end,
					  DeptNo,
					  thd.SSN, 
					  CASE WHEN @AssignmentNoInCostId = '0' THEN ends.AssignmentNo ELSE thd.CostId END, 
					  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END

END
ELSE IF (@Client = 'RAND' AND @GroupCode = 362100)
BEGIN
	
	SELECT @OutputString = ''
	SELECT @crlf = char(13) + char(10)
	
	DECLARE notPaidCursor CURSOR READ_ONLY 
	FOR SELECT 	thd.SSN, 
							en.FileNo,
							en.FirstName,
							en.LastName,
							CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
							SUM(thd.Hours) AS Hours, 
						  SUM(CASE WHEN LEFT(adjs.SpecialHandling, 1) = 'D' THEN thd.Dollars * -1 ELSE thd.Dollars END) AS Dollars,
							dbo.fn_getVestaDeptNo_PayFile_Alph(@Client, @GroupCode, thd.SSN, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo, 0) as DeptNo
				FROM timehistory..tblTimeHistDetail thd
				LEFT JOIN TimeHistory..tblEmplNames_Depts ends
				  ON (thd.SSN = ends.SSN) 
				  AND (thd.GroupCode = ends.GroupCode) 
				  AND (thd.PayrollPeriodEndDate = ends.PayrollPeriodEndDate) 
				  AND (dbo.fn_getVestaDeptNo_PayFile_Alph(@Client, @GroupCode, thd.SSN, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo, 0) = ends.Department) 
				  AND (thd.Client = ends.Client) 
				INNER JOIN TimeCurrent..tblSiteNames sn
				  ON (thd.GroupCode = sn.GroupCode) 
				  AND (thd.SiteNo = sn.SiteNo) 
				  AND (thd.Client = sn.Client) 	
				INNER JOIN TimeCurrent..tblClientGroups cg
				  ON (thd.GroupCode = cg.GroupCode) 
				  AND (thd.Client = cg.Client)	
				INNER JOIN TimeCurrent..tblEmplNames as en
				  ON en.Client = thd.Client 
				  AND en.GroupCode = thd.GroupCode
			    and en.SSN = thd.SSN	
				INNER JOIN TimeCurrent..tblAdjCodes as adjs
				  ON adjs.Client = thd.Client
				  AND adjs.GroupCode = thd.GroupCode
				  AND adjs.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('8', ' ', '', '$', '@', null) THEN '1' ELSE thd.ClockAdjustmentNo END
				LEFT JOIN TimeCurrent..tblAgencies as ag
				  ON ag.Client = en.Client
				  AND	ag.GroupCode = en.GroupCode
				  AND	ag.Agency = en.AgencyNo
				WHERE (thd.Client = @Client) 
				  AND IsNull(ends.ExcludeFromUpload, '0') = 0
				  AND (cg.IncludeInUpload = 1)
				  AND (sn.IncludeInUpload = 1)
                  AND isnull(ag.ExcludeFromPayFile,'0') = '0'
				  AND (thd.PayrollPeriodEndDate = @PPED)
				  AND (thd.GroupCode = @GroupCode)
					AND (thd.ClockAdjustmentNo NOT IN ('$','Z'))  -- Adjust Bill, therefore should not be included in Pay File - GG
					AND IsNull(en.AgencyNo, 0) <= 1
					AND ends.recordid IS NULL
			GROUP BY 	thd.SSN, en.FileNo, en.FirstName, en.LastName,
							  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
							  dbo.fn_getVestaDeptNo_PayFile_Alph(@Client, @GroupCode, thd.SSN, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo, 0)
			ORDER BY 	thd.SSN, 
							  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END,
							  DeptNo
	OPEN notPaidCursor
	
	FETCH NEXT FROM notPaidCursor INTO @SSN, @FileNo, @FirstName, @LastName, @TransDate, @Hours, @Dollars, @DeptNo
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			SELECT @OutputString = @OutputString + IsNull(@LastName, '') + ', ' + IsNull(@FirstName, '') + '(' + IsNull(@FileNo, '') + ') dept ' + IsNull(cast(@DeptNo as varchar), '') + ' on ' + IsNull(convert(varchar, @TransDate, 101), '') + ' for ' + case when @Hours <> 0 then cast(@hours as varchar) + ' hours' else '$' + cast(@Dollars as varchar) end + @crlf
		END
		FETCH NEXT FROM notPaidCursor INTO @SSN, @FileNo, @FirstName, @LastName, @TransDate, @Hours, @Dollars, @DeptNo
	END
	CLOSE notPaidCursor
	DEALLOCATE notPaidCursor
	
	IF (@OutputString <> '')
	BEGIN
		SELECT @OutputString = 'The following transactions were not included in the payfile...' + @crlf + @OutputString 
		--PRINT @OutputString
		EXEC Scheduler..usp_APP_AddNotification 2, @GroupCode, 'RandstadUpload', 0, 0, @OutputString, ''
	END

  INSERT INTO #tmpRecs(	SSN, FileNo, AssignmentNo, TransDate, CostID, DeptNo, AdjustmentCode, ClockAdjustmentNo, 
  											ApproverName, BillingMarkupRate, Hours, Dollars, ApprovedDateTime, RecordID)
	SELECT 	thd.SSN, 
					en.FileNo,
					CASE WHEN @AssignmentNoInCostId = '0' THEN ends.AssignmentNo ELSE thd.CostId END,
					TransDate = CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
				  Costid = case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid end,
					dbo.fn_getVestaDeptNo_PayFile_Alph(@Client, @GroupCode, thd.SSN, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo, 0) as DeptNo,
				  LEFT(ISNULL(adjs.ADP_EarningsCode, '') + '     ', 5),
				  ClockAdjustmentNo = CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
			    ApproverName = cast('' as varchar(40)),
--			    BillingMarkupRate = RIGHT('00' + CAST(ISNULL(adjs.BillingMarkup, 0) * 100 AS VARCHAR), 5),
					BillingMarkupRate = RIGHT(LEFT('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) - 1), 3) + SUBSTRING('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) + 1, 2),
					Hours = SUM(thd.Hours), 
				  Dollars = SUM(CASE WHEN LEFT(adjs.SpecialHandling, 1) = 'D' THEN thd.Dollars * -1 ELSE thd.Dollars END),				  
			    ApprovedDateTime = max( isnull(thd.AprvlStatus_Date, getdate())),
			    MaxRecordID = Max(thd.recordID)
	FROM timehistory..tblTimeHistDetail thd
	INNER JOIN TimeHistory..tblEmplNames_Depts ends
  ON (thd.SSN = ends.SSN) 
  AND (thd.GroupCode = ends.GroupCode) 
  AND (thd.PayrollPeriodEndDate = ends.PayrollPeriodEndDate) 
  AND (dbo.fn_getVestaDeptNo_PayFile_Alph(@Client, @GroupCode, thd.SSN, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo, 0) = ends.Department) 
  AND (thd.Client = ends.Client) 
	INNER JOIN TimeCurrent..tblSiteNames sn
  ON (thd.GroupCode = sn.GroupCode) 
  AND (thd.SiteNo = sn.SiteNo) 
  AND (thd.Client = sn.Client) 
	INNER JOIN TimeCurrent..tblClientGroups cg
  ON (thd.GroupCode = cg.GroupCode) 
  AND (thd.Client = cg.Client)
	INNER JOIN TimeCurrent..tblEmplNames as en
  ON en.Client = thd.Client 
  AND en.GroupCode = thd.GroupCode
  and en.SSN = thd.SSN
  INNER JOIN TimeCurrent..tblAdjCodes as adjs
  ON adjs.Client = thd.Client
  AND adjs.GroupCode = thd.GroupCode
  AND ISNULL(adjs.ClockAdjustmentNo, '') = CASE WHEN thd.ClockAdjustmentNo IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END
  LEFT JOIN TimeCurrent..tblAgencies as ag
  ON ag.Client = en.Client
  AND	ag.GroupCode = en.GroupCode
  AND	ag.Agency = en.AgencyNo
  WHERE (thd.Client = @Client) 
  AND (ends.ExcludeFromUpload = 0)
  AND (cg.IncludeInUpload = 1)
  AND (sn.IncludeInUpload = 1)
  AND isnull(ag.ExcludeFromPayFile,'0') = '0'
  AND (thd.PayrollPeriodEndDate = @PPED)
  AND (thd.GroupCode = @GroupCode)
	AND (thd.ClockAdjustmentNo NOT IN ('$','Z'))  -- Adjust Bill, therefore should not be included in Pay File - GG	
  AND (thd.Hours <> 0 OR thd.Dollars <> 0)
	GROUP BY 	thd.SSN, en.FileNo,
					  CASE WHEN @AssignmentNoInCostId = '0' THEN ends.AssignmentNo ELSE thd.CostId END,
					  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
					  dbo.fn_getVestaDeptNo_PayFile_Alph(@Client, @GroupCode, thd.SSN, thd.SiteNo, thd.DeptNo, thd.InDay, thd.ShiftNo, 0),
					  LEFT(ISNULL(adjs.ADP_EarningsCode, '') + '     ', 5),
					  CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
					  case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid END,
				    RIGHT(LEFT('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) - 1), 3) + SUBSTRING('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) + 1, 2)
	ORDER BY 	CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
					  case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid end,
					  DeptNo,
					  thd.SSN, 
					  CASE WHEN @AssignmentNoInCostId = '0' THEN ends.AssignmentNo ELSE thd.CostId END, 
					  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END

END
ELSE
BEGIN
  INSERT INTO #tmpRecs(	SSN, FileNo, AssignmentNo, TransDate, CostID, DeptNo, AdjustmentCode, ClockAdjustmentNo, 
  											ApproverName, BillingMarkupRate, Hours, Dollars, ApprovedDateTime, RecordID)
	SELECT 	thd.SSN, 
					en.FileNo,
--					CASE WHEN @AssignmentNoInCostId = '0' THEN ISNULL(esd.AssignmentNo, ends.AssignmentNo) ELSE thd.CostId END AS AssignmentNo,
					CASE WHEN @AssignmentNoInCostId = '0' THEN CASE WHEN ISNULL(esd.AssignmentNo,'') = '' THEN ends.AssignmentNo ELSE esd.AssignmentNo END ELSE thd.CostId END AS AssignmentNo,
					TransDate = CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
				  Costid = case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid end,
				  thd.DeptNo,
				  LEFT(ISNULL(adjs.ADP_EarningsCode, '') + '     ', 5),
				  ClockAdjustmentNo = CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
			    ApproverName = cast('' as varchar(40)),
			    BillingMarkupRate = RIGHT(LEFT('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) - 1), 3) + SUBSTRING('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) + 1, 2),
					Hours = SUM(thd.Hours),
				  Dollars = SUM(CASE WHEN LEFT(adjs.SpecialHandling, 1) = 'D' THEN thd.Dollars * -1 ELSE thd.Dollars END),
			    ApprovedDateTime = MAX(isnull(thd.AprvlStatus_Date, getdate())),
			    MaxRecordID = MAX(thd.recordID)
	
	FROM timehistory..tblTimeHistDetail thd
	
	INNER JOIN TimeCurrent..tblEmplSites_Depts esd
	  ON (thd.SSN = esd.SSN) 
	  AND (thd.GroupCode = esd.GroupCode) 
	  AND (thd.SiteNo = esd.SiteNo) 
	  AND (thd.DeptNo = esd.DeptNo) 
	  AND (thd.Client = esd.Client) 
	
	INNER JOIN TimeHistory..tblEmplNames_Depts ends
	  ON (thd.SSN = ends.SSN) 
	  AND (thd.GroupCode = ends.GroupCode) 
	  AND (thd.PayrollPeriodEndDate = ends.PayrollPeriodEndDate) 
	  AND (thd.DeptNo = ends.Department) 
	  AND (thd.Client = ends.Client) 
	
	INNER JOIN TimeCurrent..tblSiteNames sn
	  ON (thd.GroupCode = sn.GroupCode) 
	  AND (thd.SiteNo = sn.SiteNo) 
	  AND (thd.Client = sn.Client) 
	
	INNER JOIN TimeCurrent..tblClientGroups cg
	  ON (thd.GroupCode = cg.GroupCode) 
	  AND (thd.Client = cg.Client)
	
	INNER JOIN TimeCurrent..tblEmplNames as en
	  ON en.Client = thd.Client 
	  AND en.GroupCode = thd.GroupCode
    and en.SSN = thd.SSN
	
	INNER JOIN TimeCurrent..tblAdjCodes as adjs
	  ON adjs.Client = thd.Client
	  AND adjs.GroupCode = thd.GroupCode
	  AND ISNULL(adjs.ClockAdjustmentNo, '') = CASE WHEN thd.ClockAdjustmentNo IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END

	LEFT JOIN TimeCurrent..tblAgencies as ag
	  ON ag.Client = en.Client
	  AND	ag.GroupCode = en.GroupCode
	  AND	ag.Agency = en.AgencyNo	
	WHERE (thd.Client = @Client) 
	  AND (ends.ExcludeFromUpload = 0)
	  AND (cg.IncludeInUpload = 1)
	  AND (sn.IncludeInUpload = 1)
      AND isnull(ag.ExcludeFromPayFile,'0') = '0'
	  AND (thd.PayrollPeriodEndDate = @PPED)
	  AND (thd.GroupCode = @GroupCode)
		AND (thd.ClockAdjustmentNo NOT IN ('$','Z'))  -- Adjust Bill, therefore should not be included in Pay File - GG
	  AND (thd.Hours <> 0 OR thd.Dollars <> 0)
	GROUP BY 
	  thd.SSN, en.FileNo, 
	--  CASE WHEN @AssignmentNoInCostId = '0' THEN ISNULL(esd.AssignmentNo, ends.AssignmentNo) ELSE thd.CostId END,
	  CASE WHEN @AssignmentNoInCostId = '0' THEN CASE WHEN ISNULL(esd.AssignmentNo,'') = '' THEN ends.AssignmentNo ELSE esd.AssignmentNo END ELSE thd.CostId END,
	  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END, 
	  thd.DeptNo,
	  LEFT(ISNULL(adjs.ADP_EarningsCode, '') + '     ', 5),
	  CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
	  case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid END,
	  RIGHT(LEFT('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) - 1), 3) + SUBSTRING('00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', CHARINDEX('.', '00' + CAST(ISNULL(adjs.BillingMarkup, 0.00) AS VARCHAR) + '00', 0) + 1, 2)
	
	ORDER BY 
	  CASE WHEN ISNULL(thd.ClockAdjustmentNo, '') IN ('8', ' ', '', '$', '@') THEN '1' ELSE thd.ClockAdjustmentNo END,
	  case when @UseCostID = '0' OR isnull(thd.CostID,'') in('0','') then '' else thd.Costid end,
	  thd.DeptNo,
	  thd.SSN, 
	  --CASE WHEN @AssignmentNoInCostId = '0' THEN ISNULL(esd.AssignmentNo,ends.AssignmentNo) ELSE thd.CostId END, 
	  CASE WHEN @AssignmentNoInCostId = '0' THEN CASE WHEN ISNULL(esd.AssignmentNo,'') = '' THEN ends.AssignmentNo ELSE esd.AssignmentNo END ELSE thd.CostId END,
	  CASE WHEN ISNULL(adjs.ADP_EarningsCode, '') <> '' AND ISNULL(adjs.SpecialHandling, '') <> '' THEN thd.PayrollPeriodEndDate ELSE thd.TransDate END
END

UPDATE #tmpRecs
SET #tmpRecs.ApproverName = case when isnull(usr.Lastname,'') = '' then isnull(usr.LogonName,'') else usr.LastName + ',' + isnull(usr.FirstName,'') end
FROM #tmpRecs
INNER JOIN TimeHistory..tblTimeHistDetail as thd
ON thd.RecordID = #tmpRecs.RecordID
LEFT JOIN TimeCurrent..tblUser as Usr
ON usr.Client = thd.Client
AND usr.UserID = isnull(thd.AprvlStatus_UserID,0)
	  
-- =============================================
-- Send email with Records that are negative. These will not get paid correctly.
-- =============================================
DECLARE @MailSubject varchar(500)
DECLARE @MailMessage varchar(8000)
DECLARE @Source varchar(80)

Set @MailMessage = ''

DECLARE cNegs CURSOR
READ_ONLY
FOR 
Select sLine = e.LastName + ',' + e.FirstName + ': ' + convert(varchar(12),t.TransDate,101) + ' ' + ltrim(str(Hours,8,2))
from #tmpRecs as t
Inner Join TimeCurrent..tblEmplnames as e
on e.client = @Client 
and e.groupcode = @Groupcode
and e.SSN = t.SSN
where t.Hours < 0

OPEN cNegs

FETCH NEXT FROM cNegs INTO @Source
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Set @MailMessage = @MailMessage + @Source + char(13) + char(10)
		IF len(@MailMessage) > 7600
		BEGIN
			Set @MailMessage = 'WARNING: The following empls have negatives in the payfile' + char(13) + char(10) + @MailMessage
			Set @MailSubject = 'WARNING: Negs in Payfile for RAND - ' + ltrim(str(@GroupCode))
			--EXEC [Scheduler].[dbo].[usp_Email_SendDirect] @Client, @GroupCode, 0, 'dale@peoplenet-us.com,gary.gordon@peoplenet-us.com', 'support@peoplenet-us.com', 'PeopleNet', '', '', @MailSubject, @MailMessage, '', 0, ''
			Set @MailMessage = ''
		END
	END
	FETCH NEXT FROM cNegs INTO @Source
END

CLOSE cNegs
DEALLOCATE cNegs

IF len(@MailMessage) > 10
BEGIN
	Set @MailMessage = 'WARNING: The following empls have negatives in the payfile' + char(13) + char(10) + @MailMessage
	Set @MailSubject = 'WARNING: Negs in Payfile for RAND - ' + ltrim(str(@GroupCode))
	--EXEC [Scheduler].[dbo].[usp_Email_SendDirect] @Client, @GroupCode, 0, 'dale@peoplenet-us.com,gary.gordon@peoplenet-us.com', 'support@peoplenet-us.com', 'PeopleNet', '', '', @MailSubject, @MailMessage, '', 0, ''
END

DELETE FROM #tmpRecs
WHERE Hours = 0 AND Dollars = 0

select * from #tmpRecs
order by 
	  case when @UseCostID = '0' OR isnull(CostID,'') in('0','') then '' else Costid end,
	  DeptNo,
	  SSN, 
	  AssignmentNo, 
		CASE WHEN ClockAdjustmentNo IN ('8', ' ', '', '$', '@', null) THEN '1' ELSE ClockAdjustmentNo END,	  
	  TransDate

drop table #tmpRecs



