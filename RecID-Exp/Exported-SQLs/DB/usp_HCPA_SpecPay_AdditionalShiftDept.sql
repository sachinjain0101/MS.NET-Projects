CREATE Procedure [dbo].[usp_HCPA_SpecPay_AdditionalShiftDept]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)

AS

SET NOCOUNT ON


-- Departments >= 9900 represent additional shift amounts or special shift diff percentage amounts. 
-- Based on the values in the GroupDepts.MasterDept, GroupDepts.ClientDeptCode and EmplNames_depts.PayRate fields the
-- logic below will add additional THD records or change the punch record to reflect different amounts / adjustments. 
-- 
-- 
--

/*
select ClockAdjustmentNo, AdjustmentName, AdjustmentDescription, ADP_HoursCode,ADP_HoursCode2,ADP_EarningsCode,ADP_EarningsCode2, RecordStatus  
from TimeCurrent..tblAdjCodes where client = 'HCPA' 
and groupcode = 550010
order by 1, ADP_HoursCode, ADP_EarningsCode

select deptNo, MasterDept,DeptName,ClientDeptCode,CLientDeptCode2 from TimeCurrent..tblGroupDepts where client = 'HCPA' and groupcode = 550082
and recordstatus = '1' 
and deptno >= 9900 order by MasterDept, DeptName

Update Timecurrent..tblGroupDepts Set ClientDeptCode = Replace(ClientDeptCode,'SDHourly','Adjustment') where client = 'HCPA' and clientdeptcode like 'SDHourly%'
*/

DECLARE @thdRecordID int
DECLARE @newDollars numeric(7,2)
DECLARE @newCostID varchar(100)
DECLARE @InClass char(1)
DECLARE @RateCode varchar(132)
DECLARE @ClientCode2 varchar(132)
DECLARE @curDollars numeric(7,2)
DECLARE @curCostID varchar(50)
DECLARE @PayRate numeric(8,2) 
DECLARE @DeptNo int 
DECLARE @ShiftNo smallint
DECLARE @Hours numeric(5,2)
DECLARE @ClockAdjustmentNo CHAR(1)
DECLARE @AdjustmentName VARCHAR(10)
DECLARE @ShiftClass CHAR(1) = 'C'

DECLARE @tmpRec as Table
(
RecordID int,
InClass char(1),
ClientDeptCode varchar(100),
ClientDeptCode2 varchar(100),
MasterDept varchar(100),
Dollars numeric(9,2),
CostID varchar(100),
DeptNo int,
PayRate numeric(7,2)
)

Insert into @tmpRec
select t.RecordID, t.InClass, gd.Clientdeptcode, gd.Clientdeptcode2, gd.MasterDept, t.Dollars , t.CostID, t.DeptNo, d.Payrate
from TimeHistory..tblTimeHistdetail as t with(nolock)
Inner Join TimeCurrent..tblGroupDepts as gd with(nolock)
on gd.Client = t.Client
and gd.GroupCode = t.GroupCode 
and gd.DeptNo = t.DeptNo  
and gd.MasterDept Like 'HCP %'
--and ISNUMERIC(gd.Clientdeptcode) = 1
Inner Join TimeCurrent..tblEmplNames_Depts as d with(nolock)
on d.client = t.client
and d.groupcode = t.groupcode 
and d.ssn = t.ssn
and d.department = t.DeptNo 
where t.client = @Client 
  and t.groupcode = @groupCode 
  and t.SSN = @SSN
  and t.Payrollperiodenddate = @PPED 
  and t.deptno >= 9900 
	and t.Transtype not in(10,7)		-- skip voided transactions

IF @@ROWCOUNT > 0 
BEGIN

	DECLARE cTHDSum CURSOR
	READ_ONLY
	FOR 
	select RecordID, InClass, Clientdeptcode, Clientdeptcode2, MasterDept, Dollars, CostID, DeptNo, Payrate   
	from @tmpRec 

	OPEN cTHDSum

	FETCH NEXT FROM cTHDSum INTO @thdRecordID, @InClass, @RateCode, @ClientCode2, @newCostID, @curDollars, @curCostID, @DeptNo, @PayRate
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
	
			IF @newCostID like '%flat%'
			BEGIN
				-- Possible flat amount
				if @Payrate <> 0 and @PayRate <> @curDollars
				BEGIN
					-- Zero out the hours amounts and make them dollars.
					-- Set the cost ID = pay code so we can upload the hours correctly in the time file.
					-- 
					IF @InClass = 'S'
					BEGIN
						Update TimeHistory..tblTimeHistDetail 
							Set Hours = 0,
									RegHours = 0,
									OT_Hours = 0,
									DT_Hours = 0,
									Dollars = @PayRate,
									--CostID = left(@newCostID,30),
									ClockAdjustmentNo = 'K',
									AdjustmentName = 'AddtShift'
						where RecordID = @thdRecordID 
					end
					else
					BEGIN
						Update TimeHistory..tblTimeHistDetail 
							Set Hours = 0,
									RegHours = 0,
									OT_Hours = 0,
									DT_Hours = 0,
									Dollars = 0,
									--CostID = @newCostID,
									ClockAdjustmentNo = '',
									AdjustmentName = ''
						where RecordID = @thdRecordID 
					END  
				END 
			END
			ELSE
			BEGIN	
				IF @RateCode like '%Call Back%'
				BEGIN
					-- This is handled with a before SP.  So just return
					return
				END
				Set @ShiftNo = 2 
				Set @Hours = 0

				IF left(@RateCode,2) = 'OT'
					Set @ShiftNo = 3 

				IF @RateCode like '%PERCENT=%'
				BEGIN
					-- This is a percentage based department code.
					-- Set the shiftno = percentage (pay file needs this )
					-- set the diff = actual percentage
					Set @ShiftNo = substring(@RateCode,charindex('PERCENT=',@RateCode,1)+8,2)
					Set @PayRate = @Shiftno/100.00 
				END

				IF @RateCode like '%HOURS=%'
				BEGIN
					-- This department forces the hours to a certain value ( pay file needs this ).
					-- 
					Set @Hours = substring(@RateCode,charindex('HOURS=',@RateCode,1)+6,2)
				END
				SET @ClockAdjustmentNo = ''
				SET @AdjustmentName = ''

				IF @RateCode LIKE 'Adjustment=%'
				BEGIN
					SET @ClockAdjustmentNo = 'I'
					SET @AdjustmentName = LEFT(REPLACE(@RateCode,'Adjustment=',''),10)
				END

				
				IF @Deptno = 9944 OR @ClientCode2 LIKE '%ShiftClass=%'
				BEGIN
					IF @Deptno = 9944
					BEGIN
						Update TimeHistory..tblTimeHistDetail 
							Set --CostID = @newCostID,
									ShiftDiffAmt = @PayRate,
									ShiftDiffClass = 'C',
									ClockAdjustmentNo = @ClockAdjustmentNo,
									AdjustmentName = @AdjustmentName
						where RecordID = @thdRecordID 
	 						--and ( isnull(CostID,'') <> Left(@newCostID,30) 
	 							AND (	isnull(ShiftDiffAmt,0) <> @PayRate 
	 										or ShiftDiffClass <> 'C') 
					END
					ELSE
					BEGIN
						IF @ClientCode2 LIKE '%ShiftClass=%'
							SET @ShiftClass = SUBSTRING(@ClientCode2,CHARINDEX('ShiftClass=',@ClientCode2,1)+11,1)

						Update TimeHistory..tblTimeHistDetail 
							Set --CostID = @newCostID,
									ShiftDiffAmt = CASE WHEN shiftNo <= 4 AND shiftdiffamt <> 0 THEN shiftdiffamt ELSE @PayRate end,	-- Don't override any dollar diffs for stackable pay rules
									PayRate = @PayRate,
									ShiftDiffClass = @ShiftClass,
									ClockAdjustmentNo = @ClockAdjustmentNo,
									AdjustmentName = @AdjustmentName
						where RecordID = @thdRecordID 
	 						--and ( isnull(CostID,'') <> Left(@newCostID,30) 
	 							AND ( Payrate <> @PayRate 
											OR (ShiftDiffAmt <> CASE WHEN shiftNo <= 4 AND shiftdiffamt <> 0 THEN shiftdiffamt ELSE @PayRate END)
	 										or ShiftDiffClass <> @ShiftClass) 
					END
				END
				ELSE
				BEGIN
					Update TimeHistory..tblTimeHistDetail 
						Set --CostID = @newCostID,
								ShiftDiffAmt = @PayRate,
								ShiftNo = @ShiftNo,
								ClockAdjustmentNo = @ClockAdjustmentNo,
								AdjustmentName = @AdjustmentName
					where RecordID = @thdRecordID 
	 					--and ( isnull(CostID,'') <> Left(@newCostID,30) 
	 						AND ( isnull(ShiftDiffAmt,0) <> @PayRate 
	 									or ShiftNo <> @ShiftNo ) 
				END 
				IF @Hours <> 0
				BEGIN
					Update TimeHistory..tblTimeHistDetail 
						Set Hours = @Hours,
								RegHours = @Hours,
								OT_Hours = 0,
								DT_Hours = 0
					where RecordID = @thdRecordID 
	 					and [Hours] <> @Hours 
				END
			END 

		END
		FETCH NEXT FROM cTHDSum INTO @thdRecordID, @InClass, @RateCode, @ClientCode2, @newCostID, @curDollars, @curCostID, @DeptNo, @PayRate

	END

	CLOSE cTHDSum
	DEALLOCATE cTHDSum

END
