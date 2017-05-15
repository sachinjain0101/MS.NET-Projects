CREATE PROCEDURE [dbo].[usp_Web1_UpdateEmployeeBreakCode_DAVT]
(
	@BreakRecordId int,
	@BreakCode int,
	@ChangeDescription varchar(200),
	@MaintUserId int,
  @Suffix varchar(8) = ''
) AS


SET NOCOUNT ON

DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @SiteNo int
DECLARE @PPED datetime
DECLARE @SSN int
DECLARE @Transdate datetime
DECLARE @OldBreakCode int
DECLARE @thdRecordID BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
Declare @BreakCodeIndex int
Declare @UserCode varchar(5)
Declare @UserName varchar(80)
Declare @AdjName varchar(10)
Declare @BreakErrorFieldID varchar(30)
Declare @SiteState varchar(2)
Declare @Comment varchar(1000)
Declare @BreakType varchar(20)

SELECT 
  @OldBreakCode = BreakCode,
  @Client = Client,
  @Groupcode = Groupcode,
  @SiteNo = SiteNo,
  @PPED = PayrollPeriodEndDate,
  @BreakType = BreakType,
  @TransDate = TransDate,
  @SSN = SSN,
  @thdRecordID = InOutId
FROM TimeHistory..tblWTE_Spreadsheet_Breaks with (nolock) 
WHERE RecordId = @BreakRecordId

UPDATE TimeHistory..tblWTE_Spreadsheet_Breaks
  SET BreakCode = @BreakCode
WHERE RecordId = @BreakRecordId

INSERT INTO TimeHistory..tblWTE_Spreadsheet_Breaks_Audit
        ( BreakRecord ,
          FromCode ,
          ToCode ,
          ChangeDescription ,
          MaintDateTime ,
          MaintUserId
        )
VALUES  ( @BreakRecordId, 
          @OldBreakCode,
          @BreakCode,
          @ChangeDescription,
          GetDate(),
          @MaintUserId
        )

Set @SiteState = (select top 1 SiteState from Timecurrent..tblSiteNames where client = @Client and groupcode = @Groupcode and siteno = @SiteNo )

IF @SiteState = 'CA'
BEGIN

  -- May Need to Reverse the Penalty on the time card if the reason was changed to Voluntary.
  --
  IF @OldBreakCode <> @BreakCode
  BEGIN
    --Print 'Here 1'
    -- If the Index = 0 then it's Involuntary - else voluntary. If it's voluntary then reverse the penalty.
    --
    select 
      @BreakCodeIndex = BreakCodeIndex,
      @BreakErrorFieldID =  BreakErrorFieldName
    from TimeHistory..tblWTE_BreakCodes where RecordID = @BreakCode 

    Select @UserCode = UserCode,
      @UserName = left(LastName + ',' + FirstName,50)   
    from TimeCurrent..tblUser where UserID = @MaintUserId

    --Print 'BreakCodeIndex = ' + ltrim(str(@BreakCodeIndex))

    if isnull(@BreakCodeIndex,0) > 0
    BEGIN
      -- Reverse any Penalty on the transdate 
      --
      Set @AdjName = 'NMR_RVRL'
      if @PPED > '1/5/13'
      BEGIN
        Set @AdjName = 'NO_MLBRK-V'
        IF @BreakErrorFieldID = 'SLI'
          Set @AdjName = 'SH_MLBRK-V'
        IF @BreakErrorFieldID = 'LLI'
          Set @AdjName = 'LT_MLBRK-V'
      END
      Update TimeHistory..tblTImeHistDetail
        Set ClockAdjustmentNo = '/', AdjustmentName = @AdjName, UserCode = @UserCode
      where client = @Client
        and groupcode = @Groupcode
        and PayrollPeriodEndDate = @PPED
        and TransDate = @Transdate 
        and SSN = @SSN
        and ClockAdjustmentNo = 'N'
    
      if @@ROWCOUNT > 0 
      BEGIN
        -- Add comment to time card.
        INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
        ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
         VALUES(@Client, @Groupcode, @PPED, @SSN, getdate(), 'Break Penalty Reversal Adjustment Added', @MaintUserID, @UserName, 0)
      END
    END
    ELSE
    BEGIN
      -- Add the Penalty back if there is a Reversal on the transdate 
      --
      Set @AdjName = 'NMR_NB'
      if @PPED > '1/5/13'
      BEGIN
        Set @AdjName = 'NO_MLBRK-W'
        IF @BreakErrorFieldID = 'SLV'
          Set @AdjName = 'SH_MLBRK-W'
        IF @BreakErrorFieldID = 'LLV'
          Set @AdjName = 'LT_MLBRK-W'
      END
      ELSE
      BEGIN
        Set @AdjName = 'MNR_NB'
        IF @BreakErrorFieldID = 'SLV'
          Set @AdjName = 'NMR_NB'
        IF @BreakErrorFieldID = 'LLV'
          Set @AdjName = 'NMR_SL'
      END
      Update TimeHistory..tblTImeHistDetail
        Set ClockAdjustmentNo = 'N', AdjustmentName = @AdjName, UserCode = @UserCode
      where client = @Client
        and groupcode = @Groupcode
        and PayrollPeriodEndDate = @PPED
        and TransDate = @Transdate 
        and SSN = @SSN
        and ClockAdjustmentNo = '/'
    
      if @@ROWCOUNT > 0 
      BEGIN
        -- Add comment to time card.
        INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
        ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
         VALUES(@Client, @Groupcode, @PPED, @SSN, getdate(), 'Break Exception changed from Voluntary to Involuntary. Penalty Adjustment Added', @MaintUserID, @UserName, 0)
      END
    END

  END

/*
  -- May Need to Reverse the Penalty on the time card if the reason was changed to Voluntary.
  --
  IF @OldBreakCode <> @BreakCode
  BEGIN
    --Print 'Here 1'
    -- If the Index = 0 then it's Involuntary - else voluntary. If it's voluntary then reverse the penalty.
    --
    select 
      @BreakCodeIndex = BreakCodeIndex,
      @BreakErrorFieldID =  BreakErrorFieldName
    from TimeHistory..tblWTE_BreakCodes 
    where RecordID = @BreakCode 

    Select @UserCode = UserCode,
      @UserName = left(LastName + ',' + FirstName,50)   
    from TimeCurrent..tblUser 
    where UserID = @MaintUserId

    --Print 'BreakCodeIndex = ' + ltrim(str(@BreakCodeIndex))

    if isnull(@BreakCodeIndex,0) > 0
    BEGIN
      IF @BreakType = 'Lunch'
      Begin
        -- Reverse any Penalty on the transdate 
        --
        Set @AdjName = 'NO_MLBRK-V'
        IF @BreakErrorFieldID = 'SLI'
          Set @AdjName = 'SH_MLBRK-V'
        IF @BreakErrorFieldID = 'LLI'
          Set @AdjName = 'LT_MLBRK-V'

        Update TimeHistory..tblTImeHistDetail
          Set ClockAdjustmentNo = 'N', AdjustmentName = @AdjName, UserCode = @UserCode, TransType = 7
        where client = @Client
          and groupcode = @Groupcode
          and PayrollPeriodEndDate = @PPED
          and TransDate = @Transdate 
          and SSN = @SSN
          and ClockAdjustmentNo = 'N'
    
        if @@ROWCOUNT > 0 
        BEGIN
          -- Add comment to time card.
          Set @Comment = convert(varchar(12),@TransDate,101) + ' Meal Period Penalty Reversed'
          INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
          ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
           VALUES(@Client, @Groupcode, @PPED, @SSN, getdate(), @Comment, @MaintUserID, @UserName, 0)
        END
      END
      IF @BreakType = 'CARest'
      Begin
        -- Reverse any Penalty on the transdate 
        --
        Set @AdjName = 'NO_RESTBRK'
        Update TimeHistory..tblTImeHistDetail
          Set ClockAdjustmentNo = 'H', AdjustmentName = @AdjName, UserCode = @UserCode, TransType = 7
        where client = @Client
          and groupcode = @Groupcode
          and PayrollPeriodEndDate = @PPED
          and TransDate = @Transdate 
          and SSN = @SSN
          and ClockAdjustmentNo = 'H'
    
        if @@ROWCOUNT > 0 
        BEGIN
          -- Add comment to time card.
          Set @Comment = convert(varchar(12),@TransDate,101) + ' Rest Break Penalty Reversed'
          INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
          ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
           VALUES(@Client, @Groupcode, @PPED, @SSN, getdate(), @Comment, @MaintUserID, @UserName, 0)
        END
      END
    END
    ELSE
    BEGIN
      -- Add the Penalty back if there is a Reversal on the transdate 
      --
      IF @BreakType = 'Lunch'
      Begin

        Set @AdjName = 'NO_MLBRK-W'
        IF @BreakErrorFieldID = 'SLV'
          Set @AdjName = 'SH_MLBRK-W'
        IF @BreakErrorFieldID = 'LLV'
          Set @AdjName = 'LT_MLBRK-W'

        Update TimeHistory..tblTImeHistDetail
          Set ClockAdjustmentNo = 'N', AdjustmentName = @AdjName, UserCode = @UserCode, TransType = 0
        where client = @Client
          and groupcode = @Groupcode
          and PayrollPeriodEndDate = @PPED
          and TransDate = @Transdate 
          and SSN = @SSN
          and ClockAdjustmentNo = 'N'
    
        if @@ROWCOUNT > 0 
        BEGIN
          -- Add comment to time card.
          Set @Comment = convert(varchar(12),@TransDate,101) + ' Meal Period Exception changed from Voluntary to Involuntary. Penalty Adjustment Added'
          INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
          ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
           VALUES(@Client, @Groupcode, @PPED, @SSN, getdate(), @Comment, @MaintUserID, @UserName, 0)
        END
      END

      IF @BreakType = 'CARest'
      Begin

        Set @AdjName = 'NO_RESTBRK'

        Update TimeHistory..tblTImeHistDetail
          Set ClockAdjustmentNo = 'H', AdjustmentName = @AdjName, UserCode = @UserCode, TransType = 0
        where client = @Client
          and groupcode = @Groupcode
          and PayrollPeriodEndDate = @PPED
          and TransDate = @Transdate 
          and SSN = @SSN
          and ClockAdjustmentNo = 'H'
    
        if @@ROWCOUNT > 0 
        BEGIN
          -- Add comment to time card.
          Set @Comment = convert(varchar(12),@TransDate,101) + ' Rest Break Exception changed from "All Taken" to "At least 1 missed". Penalty Adjustment Added'
          INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
          ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
           VALUES(@Client, @Groupcode, @PPED, @SSN, getdate(), @Comment, @MaintUserID, @UserName, 0)
        END
      END

    END

  END
*/
  return
END

IF @SiteState = 'WA'
BEGIN
  IF @Suffix <> '' 
  BEGIN
      Update TimeHistory..tblTImeHistDetail
        Set AdjustmentName = left(AdjustmentName,8) + left(@Suffix,2)
      where RecordID = @thdRecordID 
        and right(AdjustmentName,2) <> @Suffix 
  END

  -- May Need to Void the Penalty on the time card if the reason was changed to Voluntary.
  --
  IF @OldBreakCode <> @BreakCode
  BEGIN
    --Print 'Here 2'
    -- If the Index = 0 then it's Involuntary - else voluntary. If it's voluntary then void the penalty.
    --
    select 
      @BreakCodeIndex = BreakCodeIndex,
      @BreakErrorFieldID =  BreakErrorFieldName
    from TimeHistory..tblWTE_BreakCodes 
    where RecordID = @BreakCode 

    Select @UserCode = UserCode,
      @UserName = left(LastName + ',' + FirstName,50)   
    from TimeCurrent..tblUser 
    where UserID = @MaintUserId

    --Print 'BreakCodeIndex = ' + ltrim(str(@BreakCodeIndex))

    if isnull(@BreakCodeIndex,0) > 0
    BEGIN
      -- Void Penalty on the transdate 
      --
      --PRINT 'voiding thd:'+CAST(@thdRecordID AS varchar)
      
      IF @MaintUserId <> 1 
      BEGIN
        -- Indicate that it was a manager Reversal.
        --
        Update TimeHistory..tblTImeHistDetail
          Set TransType = 7, 
							UserCode = @UserCode, 
							AdjustmentName = left(adjustmentName,5) + 'MR' + right(adjustmentName,3)
        where RecordID = @thdRecordID 
          and Transtype <> 7
      END
      ELSE
      BEGIN
        Update TimeHistory..tblTImeHistDetail
          Set TransType = 7, UserCode = @UserCode
        --  ,Hours=0 -- added by Sajjan Sarkar(awaiting Dale confirmation)
        where RecordID = @thdRecordID 
          and Transtype <> 7

      END    
      if @@ROWCOUNT > 0 
      BEGIN
        -- Add comment to time card.
        Set @Comment = convert(varchar(12),@TransDate,101) + ' WA Meal Exception Penalty voided.'
        INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
        ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
        select Client, GroupCode, PayrollPeriodenddate, SSN, getdate(), 
               convert(varchar(12),TransDate,101) + ' WA Meal Exception Penalty(' + ADjustmentName + ') voided.',
               @MaintUserID, @UserName, 0
        from TimeHistory..tblTImeHistDetail with(nolock) where recordid = @thdRecordID

      END
    END
    ELSE
    BEGIN
			--Print 'Unvoid me -- ' + ltrim(str(@thdRecordID)) 

      IF @MaintUserId <> 1 
      BEGIN
        -- Indicate that it was a manager changed to Penalty
        --
        Update TimeHistory..tblTImeHistDetail
          Set TransType = 0, 
							UserCode = @UserCode, 
							AdjustmentName = left(adjustmentName,5) + 'MP' + right(adjustmentName,3)
        --  ,Hours=0 -- added by Sajjan Sarkar(awaiting Dale confirmation)
        where RecordID = @thdRecordID 
          and Transtype = 7
      END
      ELSE
      BEGIN
        -- Add the Penalty back if the break exception was set back to Invol.
        --
        Update TimeHistory..tblTImeHistDetail
          Set transtype = 0, UserCode = @UserCode
        where RecordID = @thdRecordID 
          and Transtype = 7
      END    
      if @@ROWCOUNT > 0 
      BEGIN
        -- Add comment to time card.
        INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
        ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
        select Client, GroupCode, PayrollPeriodenddate, SSN, getdate(), 
               convert(varchar(12),TransDate,101) + ' WA Meal Exception changed from Voluntary to Involuntary. Void Penalty Adjustment reversed for ' + ADjustmentName,
               @MaintUserID, @UserName, 0
        from TimeHistory..tblTImeHistDetail with(nolock) where recordid = @thdRecordID
      END
    END

  END
END


