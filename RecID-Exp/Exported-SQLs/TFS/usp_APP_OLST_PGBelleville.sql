Create PROCEDURE [dbo].[usp_APP_OLST_PGBelleville]
(
  @OTMult numeric(15,10),
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
SET NOCOUNT ON


DECLARE @BillRate NUMERIC(7,2)
DECLARE @PayRate NUMERIC(7,2)
DECLARE @AssignmentNo VARCHAR(60)
DECLARE @SpecificDept INT
DECLARE @HomeDept INT 
DECLARE @THDRecordID BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--

/*
-- 1. Update the transaction from the employee to the correct department given the punch time and the department that he punched in to
UPDATE TimeHistory.dbo.tblTimeHistDetail
SET DeptNo = (SELECT gd2.DeptNo
							FROM TimeCurrent.dbo.tblGroupDepts gd2
							INNER JOIN TimeCurrent.dbo.tblEmplNames_Depts ends
							ON ends.Client = gd2.Client
							AND ends.GroupCode = gd2.GroupCode
							AND ends.SSN = thd.SSN
							AND ends.Department = gd2.DeptNo
							AND ends.RecordStatus = '1'
							WHERE gd2.Client = @Client
							AND gd2.GroupCode = @GroupCode
							-- e.g. GA = GA
							AND LEFT(gd2.ClientDeptCode2, CASE WHEN CHARINDEX('|', gd2.ClientDeptCode2, 0) - 1 < 0 THEN 0 ELSE CHARINDEX('|', gd2.ClientDeptCode2, 0) - 1 END) = LEFT(gd.ClientDeptCode2, CASE WHEN CHARINDEX('|', gd.ClientDeptCode2, 0) - 1 < 0 THEN 0 ELSE CHARINDEX('|', gd.ClientDeptCode2, 0) - 1 END)
							AND gd2.ClientDeptCode = 'HOME'
							AND RIGHT(gd2.ClientDeptCode2, LEN (gd2.ClientDeptCode2) - CHARINDEX('|', gd2.ClientDeptCode2, 0)) = CASE  WHEN thd.InTime BETWEEN '1899-12-30 04:00' AND '1899-12-30 09:00' AND InDay NOT IN (1,7) THEN 'DAY'
																																																												 WHEN thd.InTime BETWEEN '1899-12-30 16:00' AND '1899-12-30 21:00' AND InDay NOT IN (1,7) THEN 'MID'
																																																												 WHEN  InDay IN (1,7) THEN 'WE'
																																																												 ELSE '' END
							AND gd2.ClientDeptCode2 LIKE '%|%'),
			CostId = NULL
FROM TimeHistory.dbo.tblTimeHistDetail thd
INNER JOIN TimeCurrent.dbo.tblGroupDepts gd
ON gd.Client = thd.Client
AND gd.GroupCode = thd.GroupCode
AND gd.DeptNo = thd.DeptNo
WHERE thd.Client = @Client
AND thd.GroupCode = @GroupCode
AND thd.PayrollPeriodEndDate = @PPED
AND thd.SSN = @SSN
AND thd.ClockAdjustmentNo IN ('', ' ')
AND gd.ClientDeptCode2 LIKE '%|%'
AND gd.ClientDeptCode = 'HOME'
*/
 
DECLARE txnCursor CURSOR READ_ONLY
FOR SELECT RecordId, DeptNo
		FROM TimeHistory..tblTimeHistDetail
		WHERE	Client = @Client
		AND GroupCode = @GroupCode
		AND PayrollPeriodEndDate = @PPED
		AND SSN = @SSN		
OPEN txnCursor

FETCH NEXT FROM txnCursor INTO @THDRecordId, @SpecificDept
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		SELECT @HomeDept = gd2.DeptNo
		FROM TimeCurrent.dbo.tblGroupDepts gd
		INNER JOIN TimeCurrent.dbo.tblGroupDepts gd2
		ON gd2.Client = gd.Client
		AND gd2.GroupCode = gd.GroupCode
		AND gd2.ClientDeptCode2 = gd.ClientDeptCode2
		AND gd2.ClientDeptCode = 'HOME'
		WHERE gd.Client = @Client
		AND gd.GroupCode = @GroupCode
		AND gd.DeptNo = @SpecificDept
		
		SELECT @AssignmentNo = AssignmentNo,
					 @PayRate = PayRate,
					 @BillRate = BillRate
		FROM TimeHistory.dbo.tblEmplNames_Depts
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND PayrollPeriodenddate = @PPED
		AND SSN = @SSN
		AND Department = @HomeDept
		AND ISNULL(AssignmentNo,'') <> '' 
		AND BillRate <> 0.00
		
		IF ISNULL(@AssignmentNo,'') = '' 
		BEGIN		
			SELECT @AssignmentNo = AssignmentNo,
						 @PayRate = PayRate,
						 @BillRate = BillRate
			FROM TimeCurrent.dbo.tblEmplNames_Depts
			WHERE Client = @Client
			AND GroupCode = @GroupCode
			AND SSN = @SSN
			AND Department = @HomeDept
			AND ISNULL(AssignmentNo,'') <> '' 
			AND BillRate <> 0.00		
			AND Recordstatus = '1'
			ORDER BY RecordID ASC			
		END
		
		IF ISNULL(@AssignmentNo,'') = '' 
		BEGIN				
			SELECT @AssignmentNo = AssignmentNo,
						 @PayRate = PayRate,
						 @BillRate = BillRate
			FROM TimeHistory.dbo.tblEmplNames_Depts
			WHERE Client = @Client
			AND GroupCode = @GroupCode
			AND PayrollPeriodenddate = @PPED
			AND SSN = @SSN
			AND Department = @HomeDept
			AND ISNULL(AssignmentNo,'') <> '' 
		END
		
		IF ISNULL(@AssignmentNo,'') = '' 
		BEGIN		
			SELECT @AssignmentNo = AssignmentNo,
						 @PayRate = PayRate,
						 @BillRate = BillRate
			FROM TimeCurrent.dbo.tblEmplNames_Depts
			WHERE Client = @Client
			AND GroupCode = @GroupCode
			AND SSN = @SSN
			AND Department = @HomeDept
			AND ISNULL(AssignmentNo,'') <> '' 
			AND RecordStatus = '1'
			ORDER BY RecordID ASC
		END		

		--set OT adjustments hours to OT_Hours
		UPDATE TimeHistory..tblTimeHistdetail
		SET OT_Hours = Hours, RegHours = 0
		WHERE RecordID = @THDRecordID
		AND ClockAdjustmentNo IN (2,3)
		AND RegHours != 0

		UPDATE TimeHistory..tblTimeHistdetail
		SET BillRate = @BillRate,
	      PayRate = @PayRate,
	      RegDollars = round(@PayRate * regHours,2),
	      OT_Dollars = round((@PayRate * 1.5) * OT_Hours,2),
	      DT_Dollars = round((@PayRate * 2.0) * DT_Hours,2),
	      RegBillingDollars = round(@BillRate * regHours,2),
	      OTBillingDollars = round((@BillRate * @OTMult) * OT_Hours,2),
	      DTBillingDollars = round((@BillRate * 2.0) * DT_Hours,2),
	      RegDollars4 = round(@PayRate * regHours,4),
	      OT_Dollars4 = round((@PayRate * 1.5) * OT_Hours,4),
	      DT_Dollars4 = round((@PayRate * 2.0) * DT_Hours,4),
	      RegBillingDollars4 = round(@BillRate * RegHours,4),
	      OTBillingDollars4 = round((@BillRate * @OTMult) * OT_Hours,4),
	      DTBillingDollars4 = round((@BillRate * 2.0) * DT_Hours,4),
				CostID = @AssignmentNo
		WHERE RecordId = @THDRecordID

	END
	FETCH NEXT FROM txnCursor INTO @THDRecordId, @SpecificDept
END
CLOSE txnCursor
DEALLOCATE txnCursor

