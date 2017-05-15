CREATE            PROCEDURE [dbo].[usp_APP_UpdateTimeDetailRec_Out](
         @Client char(4),
         @GroupCode int ,
         @SSN int ,
         @PayrollPeriodEndDate datetime ,
         @SiteNo INT ,  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 22Aug2016 >--
         @DeptNo INT ,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 22Aug2016 >--
         @JobID int ,
         @TransDate datetime ,
         @ClkTransNo int,
         @NewPPED datetime,
         @lShiftClass int 
)
AS

--*/

/*
DECLARE @Client char(4)
DECLARE @GroupCode int 
DECLARE @SSN int 
DECLARE @PayrollPeriodEndDate datetime 
DECLARE @SiteNo smallint 
DECLARE @DeptNo tinyint 
DECLARE @JobID int 
DECLARE @TransDate datetime 
DECLARE @ClkTransNo int 
DECLARE @NewPPED datetime 
DECLARE @lShiftClass int

SELECT @Client = 'SUNT'
SELECT @GroupCode = 528900
SELECT @SSN = 253198993
SELECT @PayrollPeriodEndDate =  '4/05/2002'
SELECT @SiteNo = 1
SELECT @DeptNo = 33
SELECT @JobID = 0
SELECT @TransDate = '3/30/2002 02:22:22'
SELECT @ClkTransNo = 3943 
SELECT @NewPPED = '4/05/2002'
Select @lShiftClass = 1


--select * from tblTimeHistdetail where Client = 'SUNT' and Groupcode = 528900 and payrollperiodenddate >= '3/29/02'
--and SSN = 253198993 order by TransDate, InDay, InTime

--delete from tblTimeHistDetail where RecordID IN(88317602)

--delete from timeCurrent..tblTimeTrans where Client = 'SUNT'
--and SSN = 253198993 

--select * from timeCurrent..tblTimeTrans where Client = 'SUNT' and SSN = 253198993 

*/

SET NOCOUNT ON

--Set the default values.
DECLARE @OutDay tinyint 
DECLARE @tmpOutDay tinyint 
DECLARE @OutTime datetime 
DECLARE @tmpOutTime datetime 
DECLARE @tmpInTime datetime 
DECLARE @tmpPPED datetime
DECLARE @Hours numeric(5,2) 
DECLARE @OutSrc char(1) 
DECLARE @tmpOutSrc char(1) 
DECLARE @tmpHours numeric(5,2)
DECLARE @tmpMinutes int
DECLARE @MPCount int
DECLARE @tmpRecordID BIGINT  --< @tmpRecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--


SELECT @OutDay = datepart(weekday, @TransDate) 
SELECT @OutTime = '12/30/1899 ' + cast(datepart(hh,@TransDate) as char(2)) + ':' + cast(datepart(mi, @TransDate) as char(2))
SELECT @OutSrc = 'V'

DECLARE curLastRec CURSOR LOCAL FOR
SELECT Top 1 RecordID, OutDay, OutTime, OutSrc, Hours, 
nTime = dateadd(minute, datediff(minute,'12/30/1899', InTime),TransDate),
PayrollPeriodEndDate
From tblTimeHistdetail
where Client = @Client
      and GroupCode = @GroupCode
      and (PayrollPeriodEndDate = @PayrollPeriodEndDate or PayrollPeriodEndDate = dateadd(day, -7, @PayrollPeriodEndDate) )
      and SiteNo = @SiteNo
      and DeptNo = @DeptNo
      and SSN = @SSN
      and dateadd(minute, datediff(minute,'12/30/1899', InTime),TransDate) >=  dateadd(hour, -20, @TransDate)
Order By TransDate DESC,InTime DESC


OPEN curLastRec
Fetch Next From curLastRec Into @tmpRecordID, @tmpOutDay, @tmpOutTime, @tmpOutSrc, @tmpHours, @tmpInTime, @tmpPPED

if @@Fetch_Status = 0 and (@tmpOutDay = 10 OR @tmpOutDay = 11)
  Begin
    --Print "Update Recordid - " + ltrim(str(@tmpRecordID))

    SELECT @tmpMinutes = datediff(minute, @tmpInTime, @TransDate)
    SELECT @tmpHours = @tmpMinutes / 60.00

    Update tblTimeHistDetail Set OutDay = @OutDay, 
            OutTime = @OutTime, 
            OutSrc = @OutSrc,
      	    Hours = @tmpHours,
            ShiftNo = 0	
    Where RecordID = @tmpRecordID

    IF @NewPPED <> @tmpPPED AND @NewPPED IS NOT NULL
    BEGIN
--      Print 'Update PPED.'
      IF @lShiftClass = 0     -- based on OUT
      BEGIN
        -- Change the PPED of the transaction to be in the new week and not the
        -- old week.
        Update tblTimeHistDetail Set PayrollPeriodEndDate = @NewPPED
          Where CURRENT of curLastRec
      END

        -- Reset the Missing Punch Flag.      
        IF @Client = 'HRZS'
        BEGIN
          Select @MPCount = (Select Sum(1) from tblTimeHistDetail 
                                where Client = @Client 
                                  and Groupcode = @groupcode 
                                  and SSN = @SSN 
                                  and payrollperiodenddate = @PayrollPeriodEndDate
                                  and (Inday = 10 or OutDay = 10 or InDay = 11 or OutDay = 11) )
        END
        ELSE
        BEGIN
          Select @MPCount = (Select Sum(1) from tblTimeHistDetail 
                                where Client = @Client 
                                  and Groupcode = @groupcode 
                                  and SSN = @SSN 
                                  and payrollperiodenddate = @PayrollPeriodEndDate
                                  and (Inday = 10 or OutDay = 10) )
        END
      
        if @MPCount is NULL
          Select @MPCount = 0

        if @MPCount > 0
        BEGIN
          update tblEmplNames Set MissingPunch = '1'
                              where Client = @Client 
                                and Groupcode = @groupcode 
                                and SSN = @SSN 
                                and payrollperiodenddate = @tmpPPED
        END
        ELSE
        BEGIN
          update tblEmplNames Set MissingPunch = '0'
                              where Client = @Client 
                                and Groupcode = @groupcode 
                                and SSN = @SSN 
                                and payrollperiodenddate = @tmpPPED
        
        END
    END
    ELSE
    BEGIN
      -- Reset the Missing Punch Flag.      
      Select @MPCount = (Select Sum(1) from tblTimeHistDetail 
                            where Client = @Client 
                              and Groupcode = @groupcode 
                              and SSN = @SSN 
                              and payrollperiodenddate = @PayrollPeriodEndDate
                              and (Inday = 10 or OutDay = 10) )

      if @MPCount is NULL
        Select @MPCount = 0

      if @MPCount > 0
      BEGIN
        update tblEmplNames Set MissingPunch = '1'
                            where Client = @Client 
                              and Groupcode = @groupcode 
                              and SSN = @SSN 
                              and payrollperiodenddate = @PayrollPeriodEndDate
      
      END
      ELSE
      BEGIN
        update tblEmplNames Set MissingPunch = '0'
                            where Client = @Client 
                              and Groupcode = @groupcode 
                              and SSN = @SSN 
                              and payrollperiodenddate = @PayrollPeriodEndDate
      
      END
    END
  End
Else
  Begin
--    Print "Add a new record with out Punch"
    Exec usp_APP_AddTimeDetailRec_Out @Client,@GroupCode,@SSN,@PayrollPeriodEndDate,@SiteNo,@DeptNo,@JobID,@TransDate,@ClkTransNo
  End
CLOSE CurLastRec
DEALLOCATE CurLastRec






