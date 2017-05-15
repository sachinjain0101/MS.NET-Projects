CREATE      PROC [dbo].[usp_APP_ShiftDiff_CheckDept] (
  @Client char(4),
  @GroupCode int,
  @SSN int,
  @SiteNo int,
  @DeptNo int,
  @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
  @Insrc char(1) = '0',
  @Outsrc char(1) = '0'
) AS


SET NOCOUNT ON
--*/


  DECLARE @AppliesToShiftDiff char(1)
  DECLARE @Applies char(1)
  DECLARE @ClockType char(1)
  DECLARE @ClockVersion varchar(10)

  if @Client = 'GAMB'
  BEGIN
    -- If this is a Gambro Group that is using the new clocks then skip the special
    -- shift diff processing for this group and handle it normally.
    --
    IF @GroupCode <> 720200
    BEGIN
      Select @ClockType = ClockType, @ClockVersion = ClockVersion from TimeCurrent.dbo.tblSiteNames where client = @Client and Groupcode = @GroupCode and SiteNo = @SiteNo
      -- If it's a new GAMB Clock (i.e. Healthcare ) then check all transactions because the clock
      -- doesn't split them any more.
      --
      IF ( @ClockType in('J','V') ) or (isnull(@ClockVersion,'G99') > 'G48A')
      BEGIN
        -- This is really just a place holder so SQL won't complain about not having a 
        -- statement inside the IF conditional
        SET @AppliesToShiftDiff = '0'
      END
      ELSE
      BEGIN
        -- If GAMB-Tranz clock we only want to check for shift diff if the transaction was entered on the web.
        -- Else the clock would have already split the transactions. No need to duplicate the work.
        --
        if (@Insrc in('3','V','S') or @OutSrc in('3','V','S') )
        BEGIN
          -- This is really just a place holder so SQL won't complain about not having a 
          -- statement inside the IF conditional
          SET @AppliesToShiftDiff = '0'
        END
        ELSE
        BEGIN
          SELECT '0' as AppliesToShiftDiff
          RETURN
        END
      END
    END

    IF @GroupCode = 720200
    BEGIN    
      if @SiteNo in(2000,2001)
        SELECT '1' as AppliesToShiftDiff
      ELSE
        Select AppliesToShiftDiff = isnULL(ShiftDiffClass,'1') from TimeCurrent.dbo.tblEmplNames
          where client = @Client and groupcode = @GroupCode and SSN = @SSN
    END
    ELSE
    BEGIN
      -- For GAMBRO the shiftdiffclass at the empl level drives if shift diff should be applied
      -- or not.
      --
      Select AppliesToShiftDiff = case when isnULL(ShiftDiffClass,'1') = '0' Then '0' Else '1' end from TimeCurrent.dbo.tblEmplNames
          where client = @Client and groupcode = @GroupCode and SSN = @SSN
    END

    RETURN

  END

  Select @AppliesToShiftDiff = (Select CASE WHEN DiffType = 'D' then '0' else '1' end 
                                From timecurrent..tbldeptShiftDiffs
                                Where client = @Client
                                and groupcode = @GroupCode
                                and siteno = @SiteNo
                                and deptno = @DeptNo
                                and applydiff = '1'
                                and recordStatus = '1'
                                and DiffType = 'D' )
  if @AppliesToShiftDiff is null
    Set @AppliesToShiftDiff = '1'

	if RTRIM(@Client) = 'LSA'
		if (SELECT Changed_DeptNo FROM tblTimeHistDetail WHERE RecordID = @RecordID) = '2'
			SET @AppliesToShiftDiff = 'X'

  SELECT @AppliesToShiftDiff as AppliesToShiftDiff

/*
  Select @Applies = (Select ShiftDiffClass from TimeCurrent..tblEmplNames 
                      where Client = @Client
                        and GroupCode = @GroupCode
                        and SSN = @SSN)
  If @Applies is NULL
    Set @Applies = '0'

  if @Applies <> '0'
  BEGIN
    -- Make sure the department allows shift diff.
    --
    if @AppliesToShiftDiff = '1'
    BEGIN
      SELECT '1' as AppliesToShiftDiff
    END
    else
    Begin
      SELECT '0' as AppliesToShiftDiff
    End

  END
  else
  Begin
    SELECT '0' as AppliesToShiftDiff
  End
*/














