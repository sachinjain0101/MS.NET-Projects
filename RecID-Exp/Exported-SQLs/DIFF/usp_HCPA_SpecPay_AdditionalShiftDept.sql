Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
    1:  CREATE Procedure [dbo].[usp_HCPA_SpecPay_AdditionalShiftDept]
    2:  (
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
    1:  USE [TimeHistory]
    2:  GO
    3:  /****** Object:  StoredProcedure [dbo].[usp_HCPA_SpecPay_AdditionalShiftDept]    Script Date: 11/3/2015 9:13:50 AM ******/
    4:  SET ANSI_NULLS ON
    5:  GO
    6:  SET QUOTED_IDENTIFIER ON
    7:  GO
   10:  Create Procedure [dbo].[usp_HCPA_SpecPay_AdditionalShiftDept]
   11:  (
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   28:  select deptNo, MasterDept,DeptName,ClientDeptCode,CLientDeptCode2 from TimeCurrent..tblGroupDepts where client = 'HCPA' and gro
   29:  upcode = 550082
   30:  and recordstatus = '1' 
   31:  and deptno >= 9900 order by MasterDept, DeptName
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   36:  select deptNo, MasterDept,DeptName,ClientDeptCode,CLientDeptCode2 from TimeCurrent..tblGroupDepts where client = 'HCPA' and gro
   37:  upcode = 550010
   38:  and deptno >= 9900 order by MasterDept, DeptName
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   35:  */
   37:  DECLARE @thdRecordID int
   38:  DECLARE @newDollars numeric(7,2)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   42:  */
   44:  DECLARE @thdRecordID BIGINT  --< @thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
   45:  DECLARE @newDollars numeric(7,2)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   41:  DECLARE @RateCode varchar(132)
   42:  DECLARE @ClientCode2 varchar(132)
   43:  DECLARE @curDollars numeric(7,2)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   48:  DECLARE @RateCode varchar(132)
   49:  DECLARE @curDollars numeric(7,2)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   50:  DECLARE @AdjustmentName VARCHAR(10)
   51:  DECLARE @ShiftClass CHAR(1) = 'C'
   53:  DECLARE @tmpRec as Table
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   56:  DECLARE @AdjustmentName VARCHAR(10)
   58:  DECLARE @tmpRec as Table
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   54:  (
   55:  RecordID int,
   56:  InClass char(1),
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   59:  (
   60:  RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
   61:  InClass char(1),
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   57:  ClientDeptCode varchar(100),
   58:  ClientDeptCode2 varchar(100),
   59:  MasterDept varchar(100),
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   62:  ClientDeptCode varchar(100),
   63:  MasterDept varchar(100),
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   66:  Insert into @tmpRec
   67:  select t.RecordID, t.InClass, gd.Clientdeptcode, gd.Clientdeptcode2, gd.MasterDept, t.Dollars , t.CostID, t.DeptNo, d.Payrate
   68:  from TimeHistory..tblTimeHistdetail as t with(nolock)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   70:  Insert into @tmpRec
   71:  select t.RecordID, t.InClass, gd.Clientdeptcode, gd.MasterDept, t.Dollars , t.CostID, t.DeptNo, d.Payrate   
   72:  from TimeHistory..tblTimeHistdetail as t with(nolock)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   92:          FOR 
   93:          select RecordID, InClass, Clientdeptcode, Clientdeptcode2, MasterDept, Dollars, CostID, DeptNo, Payrate   
   94:          from @tmpRec 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
   96:          FOR 
   97:          select RecordID, InClass, Clientdeptcode, MasterDept, Dollars, CostID, DeptNo, Payrate   
   98:          from @tmpRec 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
   96:          OPEN cTHDSum
   98:          FETCH NEXT FROM cTHDSum INTO @thdRecordID, @InClass, @RateCode, @ClientCode2, @newCostID, @curDollars, @curCostID, @Dep
   99:  tNo, @PayRate
  100:          WHILE (@@fetch_status <> -1)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
  100:          OPEN cTHDSum
  102:          FETCH NEXT FROM cTHDSum INTO @thdRecordID, @InClass, @RateCode, @newCostID, @curDollars, @curCostID, @DeptNo, @PayRate
  103:          WHILE (@@fetch_status <> -1)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
  120:                                                                          Dollars = @PayRate,
  121:                                                                          --CostID = left(@newCostID,30),
  122:                                                                          ClockAdjustmentNo = 'K',
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
  123:                                                                          Dollars = @PayRate,
  124:                                                                          CostID = left(@newCostID,30),
  125:                                                                          ClockAdjustmentNo = 'K',
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
  133:                                                                          Dollars = 0,
  134:                                                                          --CostID = @newCostID,
  135:                                                                          ClockAdjustmentNo = '',
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
  136:                                                                          Dollars = 0,
  137:                                                                          CostID = @newCostID,
  138:                                                                          ClockAdjustmentNo = '',
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
  176:                                  END
  179:                                  IF @Deptno = 9944 OR @ClientCode2 LIKE '%ShiftClass=%'
  180:                                  BEGIN
  181:                                          IF @Deptno = 9944
  182:                                          BEGIN
  183:                                                  Update TimeHistory..tblTimeHistDetail 
  184:                                                          Set --CostID = @newCostID,
  185:                                                                          ShiftDiffAmt = @PayRate,
  186:                                                                          ShiftDiffClass = 'C',
  187:                                                                          ClockAdjustmentNo = @ClockAdjustmentNo,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
  180:                                  END
  182:                                  Update TimeHistory..tblTimeHistDetail 
  183:                                          Set CostID = @newCostID,
  184:                                                          ShiftDiffAmt = @PayRate,
  185:                                                          ShiftNo = @ShiftNo,
  186:                                                          ClockAdjustmentNo = @ClockAdjustmentNo,
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
  189:                                                  where RecordID = @thdRecordID 
  190:                                                          --and ( isnull(CostID,'') <> Left(@newCostID,30) 
  191:                                                                  AND (   isnull(ShiftDiffAmt,0) <> @PayRate 
  192:                                                                                          or ShiftDiffClass <> 'C') 
  193:                                          END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
  188:                                  where RecordID = @thdRecordID 
  189:                                          and ( isnull(CostID,'') <> Left(@newCostID,30) or isnull(ShiftDiffAmt,0) <> @PayRate )
  191:                                  IF @Hours <> 0
  192:                                  BEGIN
  193:                                          Update TimeHistory..tblTimeHistDetail 
  194:                                                  Set Hours = @Hours,
  195:                                                                  RegHours = @Hours,
  196:                                                                  OT_Hours = 0,
  197:                                                                  DT_Hours = 0
  198:                                          where RecordID = @thdRecordID 
  199:                                                  and [Hours] <> @Hours 
  200:                                  END
  201:                          END 
  203:                  END
  204:                  FETCH NEXT FROM cTHDSum INTO @thdRecordID, @InClass, @RateCode, @newCostID, @curDollars, @curCostID, @DeptNo, @
  205:  PayRate
  207:          END
  209:          CLOSE cTHDSum
  210:          DEALLOCATE cTHDSum
  212:  END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_HCPA_SpecPay_AdditionalShiftDept.sql
  194:                                          ELSE
  195:                                          BEGIN
  196:                                                  IF @ClientCode2 LIKE '%ShiftClass=%'
  197:                                                          SET @ShiftClass = SUBSTRING(@ClientCode2,CHARINDEX('ShiftClass=',@Clien
  198:  tCode2,1)+11,1)
  200:                                                  Update TimeHistory..tblTimeHistDetail 
  201:                                                          Set --CostID = @newCostID,
  202:                                                                          ShiftDiffAmt = CASE WHEN shiftNo <= 4 AND shiftdiffamt 
  203:  <> 0 THEN shiftdiffamt ELSE @PayRate end,       -- Don't override any dollar diffs for stackable pay rules
  204:                                                                          PayRate = @PayRate,
  205:                                                                          ShiftDiffClass = @ShiftClass,
  206:                                                                          ClockAdjustmentNo = @ClockAdjustmentNo,
  207:                                                                          AdjustmentName = @AdjustmentName
  208:                                                  where RecordID = @thdRecordID 
  209:                                                          --and ( isnull(CostID,'') <> Left(@newCostID,30) 
  210:                                                                  AND ( Payrate <> @PayRate 
  211:                                                                                          OR (ShiftDiffAmt <> CASE WHEN shiftNo <
  212:  = 4 AND shiftdiffamt <> 0 THEN shiftdiffamt ELSE @PayRate END)
  213:                                                                                          or ShiftDiffClass <> @ShiftClass) 
  214:                                          END
  215:                                  END
  216:                                  ELSE
  217:                                  BEGIN
  218:                                          Update TimeHistory..tblTimeHistDetail 
  219:                                                  Set --CostID = @newCostID,
  220:                                                                  ShiftDiffAmt = @PayRate,
  221:                                                                  ShiftNo = @ShiftNo,
  222:                                                                  ClockAdjustmentNo = @ClockAdjustmentNo,
  223:                                                                  AdjustmentName = @AdjustmentName
  224:                                          where RecordID = @thdRecordID 
  225:                                                  --and ( isnull(CostID,'') <> Left(@newCostID,30) 
  226:                                                          AND ( isnull(ShiftDiffAmt,0) <> @PayRate 
  227:                                                                                  or ShiftNo <> @ShiftNo ) 
  228:                                  END 
  229:                                  IF @Hours <> 0
  230:                                  BEGIN
  231:                                          Update TimeHistory..tblTimeHistDetail 
  232:                                                  Set Hours = @Hours,
  233:                                                                  RegHours = @Hours,
  234:                                                                  OT_Hours = 0,
  235:                                                                  DT_Hours = 0
  236:                                          where RecordID = @thdRecordID 
  237:                                                  and [Hours] <> @Hours 
  238:                                  END
  239:                          END 
  241:                  END
  242:                  FETCH NEXT FROM cTHDSum INTO @thdRecordID, @InClass, @RateCode, @ClientCode2, @newCostID, @curDollars, @curCost
  243:  ID, @DeptNo, @PayRate
  245:          END
  247:          CLOSE cTHDSum
  248:          DEALLOCATE cTHDSum
  250:  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_HCPA_SPECPAY_ADDITIONALSHIFTDEPT.SQL
*****

