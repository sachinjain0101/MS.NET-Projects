Create PROCEDURE [dbo].[usp_APP_OLST_871700_SpecPay_Empl]
(
  @Client  varchar(4),
  @GroupCode  Int,
  @PPED datetime,
  @SSN int 
)
As

SET NOCOUNT ON

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @DeptNo int
DECLARE @NewDeptNo int
DECLARE @NewDept varchar(50)

DECLARE cTHD CURSOR
READ_ONLY
FOR 
select RecordID, DeptNo
from TimeHistory..tblTimeHistDetail
Where 
    client = @Client
and groupcode = @GroupCode
and payrollperiodenddate = @PPED
and OT_Hours <> 0.00
and JobID = 0
and (CLockAdjustmentno = '' OR (CLockAdjustmentno = '8' and InSrc = '3' and isnull(UserCode,'') in('','PNE')) )
and SSN = @SSN

OPEN cTHD

FETCH NEXT FROM cTHD INTO @RecordID, @DeptNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- Get the new department based on the ClientDeptCode2 in the tblGroupDepts
    Set @NewDept = ''
    Set @NewDept = (select ClientDeptCode2 from TimeCurrent..tblGroupDepts where client = @Client and groupcode = @GroupCode and DeptNo = @DeptNo )

    IF isnull(@NewDept,'') = ''
      Set @NewDept = @DeptNo

    if isnumeric(@NewDept) <> 1
      Set @NewDept = @DeptNo

    Set @NewDeptNo = cast(@NewDept as Int)

    IF @NewDeptNo <> @DeptNo
    BEGIN
      Update TimeHistory..tblTimeHistDetail
        Set JobID = DeptNo,
            DeptNo = @NewDeptNo,
            Changed_DeptNo = '1'
      Where RecordID = @RecordID  
    END
	END
	FETCH NEXT FROM cTHD INTO @RecordID, @DeptNo
END

CLOSE cTHD
DEALLOCATE cTHD


