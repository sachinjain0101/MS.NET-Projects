Create PROCEDURE [dbo].[usp_DAVT_SpecPay_PdBreak_Dept100]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)

AS
SET NOCOUNT ON

DECLARE @savDeptNo BIGINT  --< @SavDeptNo data type is changed from  INT to BIGINT by Srinsoft on 05Oct2016 >--
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
DECLARE @DeptNo int


if exists(Select 1 from TimeHistory..tblTimeHistDetail where Client = @Client and GroupCode = @GroupCode and PayrollPeriodEndDate = @PPED and SSN = @SSN and DeptNo = 100 )
BEGIN
  -- There is a department 100 on the card. So we need to change that to the previous department
  --
  DECLARE cTHD1 CURSOR
  READ_ONLY
  FOR 
  select RecordID, 
  DeptNo
  from Timehistory..tblTimeHistDetail as t
  where client = @Client
  and groupcode = @GroupCode
  and SSN = @SSN
  and Payrollperiodenddate = @PPED
  --and ClockAdjustmentNo in('',' ','8')
  and TransType <> '7'
  and inday < 8 and outday < 8
  order by TransDate, ClockADjustmentNo desc, InDay, InTime 

  SET @savdeptNo = 0


  OPEN cTHD1

  FETCH NEXT FROM cTHD1 INTO @RecordID, @DeptNo
  WHILE (@@fetch_status <> -1)
  BEGIN
	  IF (@@fetch_status <> -2)
	  BEGIN

      IF @savDeptNo = 0
        Set @savDeptNo = @DeptNo
          
      IF @DeptNo = 100
      BEGIN
        IF @savDeptNo = 100
          Set @savDeptNo = 0    -- Don't set the saved department to 100
        Update TimeHistory..tblTimeHistDetail Set JobID = @savDeptNo where RecordID = @RecordID and isnull(jobID,0) <> @savDeptNo
      END
      ELSE
      BEGIN
        IF @savDeptNo <> @DeptNo 
          Set @savDeptNo = @DeptNo 
      END
      
	  END
	  FETCH NEXT FROM cTHD1 INTO @RecordID, @DeptNo
  END

  CLOSE cTHD1
  DEALLOCATE cTHD1

END



