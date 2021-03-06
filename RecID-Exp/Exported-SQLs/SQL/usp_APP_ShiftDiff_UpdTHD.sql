USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_ShiftDiff_UpdTHD]    Script Date: 10/12/2016 10:44:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
***********************************************************************************
 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

  SHIFT DIFF processing. Script to update detail record with shift diff info.

***********************************************************************************
 Copyright (c) Cignify Corporation, as an unpublished work first licensed in
 2002.  This program is a confidential, unpublished work of authorship created
 in 2002.  It is a trade secret which is the property of Cignify Corporation.

 All use, disclosure, and/or reproduction not specifically authorized by
 Cignify Corporation, is prohibited.  This program is protected by
 domestic and international copyright and/or trade secret laws.
 All rights reserved.

***********************************************************************************
REVISION HISTORY

DATE      INIT  Description
--------  ----  --------------------------------------------------------------------------------

***********************************************************************************
*/
/*
EXEC usp_APP_ShiftDiff_UpdTHD 'RENA',220100,'4/1/2006',384421427,268926896,7,191.5,'03/30/2006',-0.3,'12/30/1899 17:00','12/30/1899 05:00'
EXEC usp_APP_ShiftDiff_UpdTHD 'RENA',220100,'4/1/2006',384421427,268926890,1,0,'03/30/2006',-3.55,'12/30/1899 05:00','12/30/1899 17:00'
EXEC usp_APP_ShiftDiff_UpdTHD 'RENA',220100,'4/1/2006',384421427,268378578,1,0,'03/30/2006',-2.87,'12/30/1899 05:00','12/30/1899 17:00'
EXEC usp_APP_ShiftDiff_UpdTHD_DEH 'RENA',220100,'4/1/2006',384421427,268217267,7,191.5,'03/29/2006',0.5,'12/30/1899 17:00','12/30/1899 05:00'
EXEC usp_APP_ShiftDiff_UpdTHD_DEH 'RENA',220100,'4/1/2006',384421427,268926894,7,191.5,'03/29/2006',2.67,'12/30/1899 17:00','12/30/1899 05:00'
EXEC usp_APP_ShiftDiff_UpdTHD 'RENA',220100,'4/1/2006',384421427,268926889,1,0,'03/29/2006',-4.6,'12/30/1899 05:00','12/30/1899 17:00'

EXEC usp_APP_ShiftDiff_UpdTHD_DEH 'CLEA',442800,'12/10/2008',259156419,489957614,2,0.5,'12/09/2008',0.72,'12/30/1899 15:00','12/30/1899 23:00'

select * from tblTimeHistDetail where recordid = 1145870965
*/


--/*
ALTER Procedure [dbo].[usp_APP_ShiftDiff_UpdTHD]
(
  @Client char(4),
  @GroupCode int,
  @PPED datetime,  
  @SSN int,
  @RecordID int,
  @ShiftNo int,
  @DiffAmt numeric(5,2),
  @TransDate datetime,
  @MinHours numeric(5,2),
  @ShiftStart datetime = NULL,
  @ShiftEnd datetime = NULL
)
AS
--*/

/*
DECLARE  @Client char(4)
DECLARE  @GroupCode int
DECLARE  @PPED datetime
DECLARE  @SSN int
DECLARE  @RecordID int
DECLARE  @ShiftNo int
DECLARE  @DiffAmt numeric(5,2)
DECLARE  @TransDate datetime
DECLARE  @MinHours numeric(5,2)

SET  @Client = 'LIFE'
SET  @GroupCode = 19
SET  @PPED = '10/26/02'
SET  @SSN = 999992221
SET  @RecordID = 1958
SET  @ShiftNo = 3
SET  @DiffAmt = 1
SET  @TransDate = '10/16/02'
SET  @MinHours = 0.7
*/

DECLARE @TotHrs numeric(9,2)
DECLARE @CalcShiftDiff  char(1)
DECLARE @TransDate2 datetime
DECLARE @InSrc char(1)
DECLARE @InTime datetime
DECLARE @WebShiftDiffMaint char(1) 

Set @CalcShiftDiff = '1'

IF @Client in('GAMB','CROW')
BEGIN
  SET @CalcShiftDiff  = (SELECT EN.ShiftDiffClass FROM TimeCurrent..tblEmplNames as EN
                                WHERE EN.Client = @Client 
                                  AND EN.GroupCode = @GroupCode  
                                  AND EN.SSN = @SSN)
  
  if @CalcShiftDiff is NULL
    Set @CalcShiftDiff = '0'
END

IF @MinHours > 0.00
BEGIN
  -- This section of code will check all other transactions that may fall in the shift diff boundaries.
  -- due to split transactions at the clock or lunch punches at the clock we need to check for other
  -- transactions 

  -- First get the InSrc and InTime of the current record we'll need that to determine if the 
  -- punch was split at midnight -- if so it'll fail into the previous days totals for shift diffs
  -- 
  Select @InSrc = InSrc, @InTime = InTime from TimeHistory..tblTimeHistDetail where RecordID = @RecordID

  IF @InSrc in('8','3') and (@InTime = '12/30/1899 00:01' OR @InTime = '12/30/1899 00:00')
  BEGIN

    -- This is a EOD split so back transdate up one day to include this as part of the previous days
    -- punches.
    Set @TransDate = dateadd(day, -1, @TransDate)
  END

  IF @ShiftEnd < @ShiftStart
  BEGIN
    Set @TransDate2 = dateadd(day,1,@Transdate)
    Set @ShiftEnd = dbo.PunchDateTime2(@TransDate2, datepart(weekday,@TransDate2), @ShiftEnd)
  END
  ELSE
    Set @ShiftEnd = dbo.PunchDateTime2(@TransDate, datepart(weekday,@TransDate), @ShiftEnd)

  Set @ShiftStart = dbo.PunchDateTime2(@TransDate, datepart(weekday,@TransDate), @ShiftStart)

  Select @TotHrs = sum(Hours) from TimeHistory..tblTimeHistDetail
  where client = @Client
      AND GroupCode = @GroupCode
      AND PayrollPeriodEndDate = @PPED
      AND SSN = @SSN
      AND TransDate = @TransDate
      AND dbo.PunchDateTime2(Transdate,InDay,InTime) >= @ShiftStart
      AND dbo.PunchDateTime2(TransDate,OutDay,OutTime) <= @ShiftEnd
      AND ClockAdjustmentNo in('',' ')
      AND RecordID <> @RecordID

  IF isnull(@TotHrs,0) > 0
    Set @MinHours = @MinHours - @TotHrs


END

if @MinHours > 0.00 
BEGIN
  -- 1. Determine total hours for this transdate and ShiftNo to see if the minimum is meet.
  --    There could be other transactions for this employee.
  BEGIN

		Set @WebShiftDiffMaint = (Select CASE WHEN ISNULL(AllowTaskPanel,'0') = '0' then ISNULL(WebShiftDiffMaint,'0') ELSE '1' END from TimeCurrent..tblClients with(nolock) where client = @Client )

    DECLARE @InDateTime          datetime
    DECLARE @OutDateTime         datetime
    DECLARE @LinkRecordID        int
    DECLARE @LinkShiftDiffClass  char(1)
    DECLARE @LinkShiftDiffAmt    numeric(5,2)
		DECLARE @LinkShiftNo				 int 
    
    SELECT 
				@InDateTime = dbo.PunchDateTime2(TransDate, InDay, InTime), 
				@OutDateTime = dbo.PunchDateTime2(TransDate, OutDay, OutTime) 
    FROM TimeHistory.dbo.tblTimeHistDetail WHERE RecordID = @RecordID

    SELECT 
			@LinkRecordID = RecordID, 
			@LinkShiftDiffClass = ShiftDiffClass, 
			@LinkShiftDiffAmt = ShiftDiffAmt,
			@LinkShiftNo = ShiftNo 
    FROM TimeHistory.dbo.tblTimeHistDetail
    WHERE Client = @Client
      AND GroupCode = @GroupCode
      AND PayrollPeriodEndDate = @PPED
      AND SSN = @SSN
      AND TransDate = @TransDate
      AND dbo.PunchDateTime2(TransDate, OutDay, OutTime) = @InDateTime

    IF (@LinkRecordID > 0)
    BEGIN
			IF @WebShiftDiffMaint <> '2'
			BEGIN
				Set @ShiftNo = @LinkShiftNo 
			END
			ELSE
      BEGIN
				SET @ShiftNo = @LinkShiftDiffClass
			END

      UPDATE TimeHistory.dbo.tblTimeHistDetail 
      SET ShiftNo = @ShiftNo, 
					ShiftDiffClass = @LinkShiftDiffClass, 
					ShiftDiffAmt = @LinkShiftDiffAmt
      WHERE RecordID = @RecordID
      	AND isnull(Changed_DeptNo, 0) <> '2'  --exclude out manually changed shifts
    END
    ELSE
    BEGIN
      SELECT 
				@LinkRecordID = RecordID, 
				@LinkShiftDiffClass = ShiftDiffClass, 
				@LinkShiftDiffAmt = ShiftDiffAmt,
				@LinkShiftNo = ShiftNo 
      FROM TimeHistory.dbo.tblTimeHistDetail
      WHERE Client = @Client
        AND GroupCode = @GroupCode
        AND PayrollPeriodEndDate = @PPED
        AND SSN = @SSN
        AND TransDate = @TransDate
        AND dbo.PunchDateTime(TransDate, InDay, InTime) = @OutDateTime

      IF (@LinkRecordID > 0)
      BEGIN
				IF @WebShiftDiffMaint <> '2'
				BEGIN
					Set @ShiftNo = @LinkShiftNo 
				END
				ELSE
				BEGIN
					SET @ShiftNo = @LinkShiftDiffClass
				END

        UPDATE TimeHistory.dbo.tblTimeHistDetail 
        SET ShiftNo = @ShiftNo, 
						ShiftDiffClass = @LinkShiftDiffClass, 
						ShiftDiffAmt = @LinkShiftDiffAmt
        WHERE RecordID = @RecordID
        	AND isnull(Changed_DeptNo, 0) <> '2'  --exclude out manually changed shifts
      END
    END
/*
    -- reset trans to no shift diff.
    Update tblTimeHistDetail 
        Set ShiftNo = 1,
            ShiftDiffClass = '0',
            ShiftDiffAmt = 0.00
    Where RecordID = @RecordID
*/
  END
END
ELSE
BEGIN

  if @Client = 'GAMB'
  BEGIN
    IF @GroupCode = 720200
    BEGIN
      Set @CalcShiftDiff = '1'
    END
    ELSE
    BEGIN
      IF @MinHours < 0.00 
      BEGIN
        if @ShiftNo = 1
          Set @CalcShiftDiff = '0'
        else
          Set @CalcShiftDiff = '1'
        Set @ShiftNo = 1
      END
      ELSE
      BEGIN
        Set @CalcShiftDiff = '0'
        Set @ShiftNo = 1
      END
    END
  END

  -- No Min Hours requirement so update detail with shift diff info.
    Update TimeHistory.dbo.tblTimeHistDetail 
        Set ShiftNo = @ShiftNo,
            ShiftDiffClass = (CASE @CalcShiftDiff WHEN '0' THEN '0' ELSE substring(str(@ShiftNo,3),3,1) END),
            ShiftDiffAmt = (CASE @CalcShiftDiff WHEN '0' THEN 0.00 ELSE @DiffAmt END)
    Where RecordID = @RecordID
    	AND isnull(Changed_DeptNo, 0) <> '2'  --exclude out manually changed shifts
END






