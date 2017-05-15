CREATE Procedure [dbo].[usp_APP_STFM_CelenaseSpecPay]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS

SET NOCOUNT ON

/*
For the Florence location the employees need to be able to punch 
out up to 10-minutes early and have there time round to the end of the shift.

The shift end times are 5:10AM and 5:10PM. Any employee punching out between 5:00-5:09 should be recorded as 5:10. 
This change only applies to the Florence Clock (Clock 2). 

This is contingent upon Kim removing the 08:00-17:00 shift


*/

DECLARE cTHD CURSOR
READ_ONLY
FOR 
Select RecordID, InTime, OutTime, NewOutTime = '12/30/1899 05:10'
from TimeHistory..tblTimeHistDetail 
where client = @Client
and Groupcode = @Groupcode
and SSN = @SSN
and PayrollPeriodenddate = @PPED
and OutTime between '12/30/1899 05:00' and '12/30/1899 05:09'
and Hours > 0.00
UNION ALL
Select RecordID, InTime, OutTime, NewOutTime = '12/30/1899 17:10'
from TimeHistory..tblTimeHistDetail 
where client = @Client
and Groupcode = @Groupcode
and SSN = @SSN
and PayrollPeriodenddate = @PPED
and OutTime between '12/30/1899 17:00' and '12/30/1899 17:09'
and Hours > 0.00

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
DECLARE @inTime Datetime
DECLARE @OutTime Datetime
DECLARE @NewOutTime datetime
DECLARE @NewHours numeric(7,2)

OPEN cTHD

FETCH NEXT FROM cTHD into @RecordID, @InTime, @OutTime, @NewOutTime
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		if @NewOutTime < @InTime
			Set @NewOuttime = dateadd(day,1,@NewOutTime)

		Set @NewHours = datediff(minute, @InTime, @NewOutTime) / 60.00

		If @NewHours > 0.00
		BEGIN
			Update TimeHistory..tblTimeHistDetail
				Set OutTime = @NewOutTime,
						Hours = @NewHours
			where RecordID = @RecordID
		END
	END
	FETCH NEXT FROM cTHD into @RecordID, @InTime, @OutTime, @NewOutTime
END

CLOSE cTHD
DEALLOCATE cTHD



