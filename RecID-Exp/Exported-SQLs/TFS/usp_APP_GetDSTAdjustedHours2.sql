Create PROCEDURE [dbo].[usp_APP_GetDSTAdjustedHours2](
           @Client char(4)
         , @GroupCode int 
         , @SiteNo INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 16Aug2016 >-- 
         , @InPunch datetime
         , @OutPunch datetime
         , @TimeOnDST datetime  -- optional parm, if not passed then sp will figure it out
         , @TimeOffDST datetime -- optional parm, if not passed then sp will figure it out
         , @DaylightSavTime char(1)
         , @DSTAdjustedHours numeric(6,2) OUTPUT
)
AS

  -- DST goes ON first sunday in april so time rolls 1 hour forward from 2:00am to 3:00am.
  -- DST goes OFF last sunday in october so time rolls 1 hour backward from 1:59am back to 1:00am.

  declare @numhours numeric(6,2)
--  declare @dststatus char(1)
  declare @dstapril datetime
  declare @dstoctober datetime
  declare @day int
  declare @month int
  declare @currentyear int
  declare @tempdate datetime

  select @numhours = datediff( minute, @InPunch, @OutPunch )
  select @numhours = @numhours / 60.00

/* commented out since this is only used for Lifecare clocks
  -- timecurrent..DSTstatus valid values: 0=no, null=no, 1=on, 2=off
  -- Clock should send send a "dst on" message when it goes on dst and 
  -- when "dst on" is received by system, tblsitenames!DSTstatus should get set to '1'
  -- Clock should send send a "dst off" message when it goes off dst and 
  -- when "dst off" is received by system, tblsitenames!DSTstatus should get set to '2'
  select @dststatus = ( select isnull( DSTstatus, '0' )
                        from timecurrent..tblsitenames
                        where     client = @Client
                              and groupcode = @GroupCode
                              and siteno = @SiteNo ) --not checking recordstatus since there's an index on client,group,site

  if @dststatus = '0'
  begin
    select @DSTAdjustedHours = @numhours
    return
  end
*/

  select @DSTAdjustedHours = @numhours

  if @TimeOnDST is null
  begin
    select @currentyear = datepart( year, getdate() )
    -- find 2nd sunday in march
		select @tempdate = cast( ( '3/8/' + cast( @currentyear as char(4) ) + ' 02:00' ) as datetime )
		select @TimeOnDST = dateadd(dd, (7-DATEPART(dw, @Tempdate)+1) % 7, @tempdate)
  end

  if @TimeOffDST is null 
  begin
    select @currentyear = datepart( year, getdate() )
    -- find first sunday in november
		select @tempdate = cast( ( '11/1/' + cast( @currentyear as char(4) ) + ' 02:00' ) as datetime )
		select @TimeOffDST = dateadd(dd, (7-DATEPART(dw, @Tempdate)+1) % 7, @tempdate)
  end    

  -- timehistory!DaylightSavTime values
  -- '1'	in-dstoff	out-dstoff
  -- '2'	in-dstoff	out-dston
  -- '3'	in-dston	out-dstoff
  -- '4'	in-dston	out-dston

  declare @clocktype char(1)
	declare @timezone varchar(5)

	select @clockType = clocktype, @timeZone = timezone
  from timecurrent..tblsitenames WITH(NOLOCK)
  where     client = @Client
  and groupcode = @GroupCode
  and siteno = @SiteNo
				--not checking recordstatus since there's an index on client,group,site

	if @TimeZone = 'PNT' and @ClockType not in('T','V') --PNT does not have DST
		return

  if @Clocktype not in('T','V') --java clocks set dststatus properly so use it
  begin
    if @InPunch < @TimeOnDST and @OutPunch >= dateadd( hour, 1, @TimeOnDST ) --and @DaylightSavTime = '2'  
    begin 
        select @numhours = @numhours - 1
    end
    else if @InPunch < @TimeOffDST and @OutPunch >= dateadd(hour, -1, @TimeOffDST) and @DaylightSavTime = '3'
    begin
        select @numhours = @numhours + 1
    end
    else if @InPunch < dateadd(hh, -1, @TimeOffDST) and @OutPunch >= @TimeOffDST  --takes care of Coastal issue
    begin
        select @numhours = @numhours + 1
    end
		--when eod split occurs, we are losing the daylightsavtime flag
  	--there is still a problem if txn splits at sometime between 1am and 2am.
	
    select @DSTAdjustedHours = @numhours
  end
  else
  begin
    if @Clocktype = 'T' 
    begin

      if @InPunch < @TimeOnDST and @OutPunch >= dateadd( hour, 1, @TimeOnDST ) --and @DaylightSavTime = '2'  
      begin 
          select @numhours = @numhours - 1
      end
      else if @InPunch < dateadd(hour, -1, @TimeOffDST) and @OutPunch >= @TimeOffDST and @DaylightSavTime = '2'
      begin
          select @numhours = @numhours + 1
      end
    end  
    else
    begin

      if @InPunch < @TimeOnDST and @OutPunch >= dateadd( hour, 1, @TimeOnDST ) --and @DaylightSavTime = '2'  
      begin 
          select @numhours = @numhours - 1
      end
      else if @InPunch < dateadd(hour, -1, @TimeOffDST) and @OutPunch >= @TimeOffDST --and @DaylightSavTime = '3'
      begin
          select @numhours = @numhours + 1
      end
    end  

    select @DSTAdjustedHours = @numhours
  end







