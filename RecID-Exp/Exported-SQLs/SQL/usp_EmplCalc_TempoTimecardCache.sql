USE [TimeHistory]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_EmplCalc_TempoTimecardCache]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_EmplCalc_TempoTimecardCache] AS' 
END
GO



ALTER Procedure [dbo].[usp_EmplCalc_TempoTimecardCache]
(
  @Client     varchar(4),
  @GroupCode  int,
  @PPED       datetime,
  @EmplBadge  int,
  @SSN        int,
  @LastRecalc datetime
)

AS

-- usp_EmplCalc_TempoTimecardCache

-- WHO:   Run as part of EmplCalc, with immediate exit for non-timeclock and non-Tempo groups
-- WHAT:  Cache Tempo-specific TimeCard data by employee badge
-- WHEN:  Runs after EmplCalc has processed all rules regarding employee timecard
-- WHERE: Currently stored in TimeHistory DB but could be moved to another spindle to avoid disk contention
-- WHY:   Eliminate group timesheet query every 15 min, offload to another table with checksums



/*
-- Run manually outside sproc declarations and hard coding

DECLARE @Client     varchar(4);
DECLARE @GroupCode  int;
DECLARE @PPED       datetime;
DECLARE @EmplBadge  int;
DECLARE @SSN        int;
DECLARE @LastRecalc datetime;


SET @Client     = 'PNET';
SET @GroupCode  = 222101;
SET @PPED       = '2015-12-19';
SET @EmplBadge  = 123456789;
SET @SSN        = 9317;
SET @LastRecalc = GETDATE();
*/


---------------------------------------------------------
-- STEP 1, Is this a timeclock group?  Else exit.

-- NOTE: good enough for now, can be improved at later date
IF @GroupCode < 20000
BEGIN
	PRINT 'This not a timeclock group, aborting';
	RETURN;
END
  
---------------------------------------------------------
-- STEP 2, Are there any Tempo clocks?  Else exit.

IF NOT EXISTS (SELECT ClockType FROM TimeCurrent..tblSiteNames WITH (NOLOCK) WHERE Client = @Client AND GroupCode = @GroupCode AND ClockType = 'W' AND RecordStatus = '1')
BEGIN
	PRINT 'This are no active Tempo clocks in this group, aborting';
	RETURN;
END


---------------------------------------------------------
/*
Table Legend

ID  === RecordID
SN  === SiteNo
DN ===  DeptNo
SH  === ShiftNo
TD  === TransDate
TI   === PaidTimeIn
TO  === PaidTimeOut
AI  === ActualInTime
AO ===  ActualOutTime
IS  === InTimestamp
OS ===  OutTimestamp
RH  === RegHours
PP  === IsPunchPair
CP  === IsCompletePunch
MI  === IsMissingIn
MO ===  IsMissingOut

*/

DECLARE @Timecard_Cache TABLE
(
  ID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
, SN INT
, DN INT
, SH INT NULL
, TD DATETIME
, [TI] DATETIME NULL
, [TO] DATETIME NULL
, [AI] DATETIME NULL
, [AO] DATETIME NULL
, [IS] BIGINT NULL
, [OS] BIGINT NULL
, RH NUMERIC(5,2) NULL
, PP BIT
, CP BIT
, MI BIT
, MO BIT
);


IF (ISNULL(@PPED,'') = '')
BEGIN
	SELECT TOP(1) @PPED = PayrollPeriodEndDate
	FROM TimeHistory..tblPeriodEndDates with(nolock) 
	WHERE 
		  Client = @Client 
	  AND GroupCode = @GroupCode
	ORDER BY PayrollPeriodEndDate DESC;
END
----------------------------------------------------------
-- STEP 3, Get Empl Timecard Summary

INSERT INTO @Timecard_Cache
SELECT 
  ID = thd.RecordID
, SN = thd.SiteNo
, DN = thd.DeptNo
, SH = thd.ShiftNo
, TD = CONVERT(VARCHAR(12),thd.TransDate,101)
, [TI] = TimeHistory.dbo.punchDateTime2(thd.TransDate, thd.InDay, thd.InTime)
, [TO] = TimeHistory.dbo.punchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime)
, [AI] = thd.ActualInTime
, [AO] = thd.ActualOutTime
, [IS] = thd.[InTimestamp]
, [OS] = thd.[outTimestamp]
, RH = thd.Hours
, PP = CASE WHEN thd.ClockAdjustmentNo = '' THEN 1 ELSE 0 END
, CP = CASE WHEN thd.InDay < 8 AND thd.OutDay < 8 THEN 1 ELSE 0 END
, MI = CASE WHEN (thd.InDay > 7 OR thd.ClockAdjustmentNo <> '') THEN 1 ELSE 0 END
, MO = CASE WHEN (thd.OutDay > 7 OR thd.ClockAdjustmentNo <> '') THEN 1 ELSE 0 END 
FROM TimeHistory.dbo.tblTimeHistDetail thd WITH(NOLOCK) 
WHERE 
		thd.Client = @Client
	AND thd.GroupCode = @GroupCode
	AND thd.SSN = @SSN
	AND thd.PayrollPeriodEndDate = @PPED
;


IF NOT EXISTS (SELECT ID FROM @Timecard_Cache)
BEGIN
	PRINT '>>> No records found. <<<'
	RETURN;
END


----------------------------------------------------------
-- Step 4, upsert summary record for sync

IF EXISTS 
	(
	SELECT EmplBadge 
	FROM TimeHistory.dbo.tblTempo_Timecard_Cache 
	WHERE 
		    Client = @Client 
		AND GroupCode = @GroupCode 
		AND SSN = @SSN 
		AND PayrollPeriodEndDate = @PPED
		)
BEGIN
	UPDATE TimeHistory.dbo.tblTempo_Timecard_Cache 
	SET
	ChecksumValue = NULL  /* (SELECT CONVERT(INT,STDEV(BINARY_CHECKSUM(*))) FROM @Timecard_Cache) */
	, LastRecalcTime  = @LastRecalc
	, TimeCardDataXML = (SELECT * FROM @Timecard_Cache FOR XML AUTO)
	WHERE 
		    Client = @Client 
		AND GroupCode = @GroupCode 
		AND SSN = @SSN 
		AND PayrollPeriodEndDate = @PPED
	;
END
ELSE
BEGIN
	INSERT INTO TimeHistory.dbo.tblTempo_Timecard_Cache
	(
	  Client 
	, GroupCode 
	, SSN 
	, EmplBadge 
	, PayrollPeriodEndDate 
	, ChecksumValue 
	, LastRecalcTime  
	, TimeCardDataXML 
	)
	VALUES
	( 
	  @Client 
	, @GroupCode 
	, @SSN
	, @EmplBadge 
	, @PPED 
	, NULL  /* (SELECT CONVERT(INT,STDEV(CHECKSUM(*))) FROM @Timecard_Cache) */
	, @LastRecalc
	, (SELECT * FROM @Timecard_Cache FOR XML AUTO)
	)
	;
END



-- display human readable results during development
-- SELECT * FROM TimeHistory.dbo.tblTempo_Timecard_Cache


