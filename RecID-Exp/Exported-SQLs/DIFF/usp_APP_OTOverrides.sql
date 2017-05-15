Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
    3:  -- Create Procedure usp_APP_OTOverrides
    4:  -- Alter Procedure usp_APP_OTOverrides
    5:  -- Create Procedure usp_APP_OTOverrides
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
    3:  -- Create Procedure usp_APP_OTOverrides
    4:  -- Create Procedure usp_APP_OTOverrides
    5:  -- Create PROCEDURE usp_APP_OTOverrides
    6:  -- Create Procedure usp_APP_OTOverrides
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
    7:  -- Author:              Sajjan Sarkar
    8:  -- Create date: 5/9/2012
    9:  -- Description: apply OTOverrides
   10:  -- Logic:
   11:          /*
   12:          For each day:
   13:                  td = total hrs for the day left to be allocated   ( called @TotalUnallocatedHoursForThisDay in sproc)
   14:                  dt = total DT hrs for the day left to be allocated( called @UnallocatedDTHours in sproc)
   15:                  ot = total OT hrs for the day left to be allocated( called @UnallocatedOTHours in sproc)
   17:                  if(td >0 and (dt>0 or ot>0))
   18:                  {
   19:                          for each txn in the day
   20:                          {
   21:                                  tx = total hrs for the txn left to be allocated( called @TotalUnallocatedHrsForThisTxn in sproc
   22:  )
   23:                                  if(tx>0)
   24:                                  {
   25:                                          if(tx<=dt)
   26:                                          {
   27:                                                  update THD set DT =tx,reg=0 
   28:                                                  dt = dt-tx
   29:                                                  td= td-tx
   30:                                                  tx = 0
   31:                                          }
   32:                                          else
   33:                                          {
   34:                                                  update THD set DT = dt,reg = tx-dt
   35:                                                  tx = tx-dt
   36:                                                  td = td-dt
   37:                                                  dt = 0                          
   38:                                          }
   39:                                  }
   40:                                  if(tx>0)
   41:                                  {
   42:                                          if(tx<=ot)
   43:                                          {
   44:                                                  update THD set OT =tx,reg=0 
   45:                                                  ot = ot-tx
   46:                                                  td= td-tx
   47:                                                  tx = 0
   48:                                          }
   49:                                          else
   50:                                          {
   51:                                                  update THD set OT = dt,reg = tx-ot
   52:                                                  tx = tx-ot
   53:                                                  td = td-ot
   54:                                                  ot = 0
   55:                                          }
   56:                                  }
   58:                          }
   59:                  }
   61:          */
   63:  -- =============================================
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
    8:  -- Author:              Sajjan Sarkar
    9:  -- Create date: 5/9/2012YouTube - Broadcast Yourself.
   10:  -- Description: not sure
   11:  -- =============================================
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
   77:          -- interfering with SELECT statements.
   78:          SET NOCOUNT ON;
   80:          DECLARE @SiteNo INT
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
   24:          -- interfering with SELECT statements.
   25:          SET NOCOUNT ON ;
   27:          DECLARE @SiteNo INT
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
   81:          DECLARE @DeptNo INT
   82:          DECLARE @UnallocatedOTHours NUMERIC(7, 2)
   83:          DECLARE @UnallocatedDTHours NUMERIC(7, 2)      
   85:          DECLARE @TotalUnallocatedHrsForThisTxn NUMERIC(7, 2)
   86:                  DECLARE @TotalUnallocatedHoursForThisDay NUMERIC(7, 2)
   87:          DECLARE @TransDate DATETIME
   88:          DECLARE @THDRecordID INT    
   92:          /** Get all OT Overrides for this C,G and PPED */
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
   28:          DECLARE @DeptNo INT
   29:          DECLARE @newOT NUMERIC(7, 2)
   30:          DECLARE @newDT NUMERIC(7, 2)      
   31:          DECLARE @reg NUMERIC(7, 2)
   32:          DECLARE @Total NUMERIC(7, 2)
   33:          DECLARE @TransDate DATETIME
   34:          DECLARE @THDRecordID BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
   35:          DECLARE @newOT_ORIG NUMERIC(7, 2)
   36:          DECLARE @newDT_ORIG NUMERIC(7, 2)              
   40:          /** Get all OT Overrides for this C,G and PPED */
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  111:                  /** Loop thru all OT overrides  **/
  112:          FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @UnallocatedOTHours, @UnallocatedDTHours, @TransDate 
  113:          WHILE ( @@fetch_status <> -1 )
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
   59:                  /** Loop thru all OT overrides  **/
   60:          FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @newOT, @newDT, @TransDate 
   61:          WHILE ( @@fetch_status <> -1 ) 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  116:                      BEGIN
  117:                          /*
  118:                                                          Move all hours from OT, DT into REG.
  119:                                                  */
  121:                          /**Set reg =total, DT=OT=0 in THD for that assignment and that day */
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
   64:                      BEGIN
   65:                          --PRINT ''
   66:                          --PRINT 'Processing Positives'
   67:                          --PRINT '@TransDate: ' + CAST(@TransDate AS VARCHAR)
   68:                          --PRINT '@SiteNo: ' + cast(@SiteNo as varchar) + ';  ' + '@DeptNo: ' + cast(@DeptNo as varchar)
   69:                          --PRINT '@NewOT: ' + CAST(@newOT AS VARCHAR) + ';  ' + '@NewDT: ' + CAST(@newDT AS VARCHAR)            
   71:                          SET @newOT_ORIG = @newOT
   72:                          SET @newDT_ORIG = @newDT
   73:                          /**Set reg =total, DT=OT=0 in THD for that assignment and that day */
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  124:                                  OT_Hours = 0 ,
  125:                                  DT_Hours = 0 ,
  126:                                  RegDollars = 0 ,
  127:                                  OT_Dollars = 0 ,
  128:                                  DT_Dollars = 0 ,
  129:                                  RegDollars4 = 0 ,
  130:                                  OT_Dollars4 = 0 ,
  131:                                  DT_Dollars4 = 0 ,
  132:                                  RegBillingDollars = 0 ,
  133:                                  OTBillingDollars = 0 ,
  134:                                  DTBillingDollars = 0 ,
  135:                                  RegBillingDollars4 = 0 ,
  136:                                  OTBillingDollars4 = 0 ,
  137:                                  DTBillingDollars4 = 0
  138:                          WHERE   Client = @Client
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
   76:                                  OT_Hours = 0 ,
   77:                                  DT_Hours = 0,
   78:                                  RegDollars = 0,
   79:                                  OT_Dollars = 0,
   80:                                  DT_Dollars = 0,
   81:                                  RegDollars4 = 0,
   82:                                  OT_Dollars4 = 0,
   83:                                  DT_Dollars4 = 0,
   84:                                  RegBillingDollars = 0,
   85:                                  OTBillingDollars = 0,
   86:                                  DTBillingDollars = 0,                                
   87:                                  RegBillingDollars4 = 0,
   88:                                  OTBillingDollars4 = 0,
   89:                                  DTBillingDollars4=0
   90:                          WHERE   Client = @Client
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  144:                                  AND TransDate = @TransDate                                
  146:                                                  -- get sumarized hours for this day
  147:                          SELECT  @TotalUnallocatedHoursForThisDay = SUM([THD].[Hours])
  148:                          FROM    [TimeHistory]..[tblTimeHistDetail] AS THD WITH ( NOLOCK )
  149:                          WHERE   Client = @Client
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
   96:                                  AND TransDate = @TransDate                                
   97:                          /**For each row, get all rows  in THD for that assignment and that day*/ 
   99:  -----------------   POSITIVES                                
  100:                          DECLARE innerCursor CURSOR READ_ONLY
  101:                          FOR
  102:                              SELECT  RecordID , -- used for updates
  103:                                      Hours ,
  104:                                      RegHours
  105:                              FROM    TimeHistory..tblTimeHistDetail AS TTHD
  106:                              WHERE   Client = @Client
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  155:                                  AND TransDate = @TransDate   
  156:                                                  /*
  157:                                                          Only process txns if :
  158:                                                                  - there are +ve hours in the timecard
  159:                                                                  - OT or DT allocation is specified
  160:                                                  */
  161:                          IF @TotalUnallocatedHoursForThisDay > 0
  162:                              AND ( @UnallocatedDTHours <> 0
  163:                                    OR @UnallocatedOTHours <> 0
  164:                                  )
  165:                              BEGIN
  166:                                   /**
  167:                                                                          For each row, get all rows  in THD :
  168:                                                                                  - for that assignment
  169:                                                                                  - that day
  170:                                                                                  - with +ve hours
  171:                                                                  */ 
  173:                                  DECLARE perTxnCursor CURSOR READ_ONLY
  174:                                  FOR
  175:                                      SELECT  RecordID , -- used for updates
  176:                                              Hours
  177:                                      FROM    TimeHistory..tblTimeHistDetail AS TTHD WITH ( NOLOCK )
  178:                                      WHERE   Client = @Client
  179:                                              AND GroupCode = @Groupcode
  180:                                              AND PayrollPeriodEndDate = @PPED
  181:                                              AND SSN = @SSN
  182:                                              AND SiteNo = @SiteNo
  183:                                              AND DeptNo = @DeptNo
  184:                                              AND TransDate = @TransDate
  185:                                              AND Hours >= 0
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
  112:                                      AND TransDate = @TransDate
  113:                                      AND Hours >= 0
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  188:                                      ORDER BY InTime DESC -- ordering this way allows us to attempt to affect minimum no of rows
  190:                                  OPEN perTxnCursor
  192:                                  FETCH NEXT FROM perTxnCursor INTO @THDRecordID, @TotalUnallocatedHrsForThisTxn
  193:                                  WHILE ( @@fetch_status <> -1 )
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
  116:                              ORDER BY InTime DESC -- ordering this way allows us to attempt to affect minimum no of rows
  117:                          OPEN innerCursor
  119:                          FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
  120:                          WHILE ( @@fetch_status <> -1 ) 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  196:                                              BEGIN
  197:                                                  PRINT 'Processing record ID:' + CAST(@THDRecordID AS VARCHAR)
  199:                                                                                  /**********************************************
  200:  ************************************************************
  201:                                                                                                                          PROCESS
  202:  ING DT ALLOCATION
  203:                                                                                  ***********************************************
  204:  ************************************************************/                                                                  
  206:                                                  IF @TotalUnallocatedHrsForThisTxn > 0 -- there are unallocated hours
  207:                                                      BEGIN
  208:                                                                                                                  /*
  209:                                                                                                                          if all 
  210:  available hours for the txn can be allocated to DT, do it.
  211:                                                                                                                  */
  212:                                                          IF ( @TotalUnallocatedHrsForThisTxn <= @UnallocatedDTHours )
  213:                                                              BEGIN
  214:                                                                  UPDATE  [TimeHistory]..[tblTimeHistDetail]
  215:                                                                  SET     [DT_Hours] = @TotalUnallocatedHrsForThisTxn ,
  216:                                                                          [RegHours] = 0 -- nothing left 
  217:                                                                  WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID
  220:                                                                  SET @UnallocatedDTHours = @UnallocatedDTHours - @TotalUnallocat
  221:  edHrsForThisTxn -- new value is old - hrs we just allocated                                                
  222:                                                                  SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursFo
  223:  rThisDay
  224:                                                                      - @TotalUnallocatedHrsForThisTxn  -- reduce no of unallocat
  225:  ed hours
  226:                                                                  SET @TotalUnallocatedHrsForThisTxn = 0 -- since all have been a
  227:  llocated to DT
  228:                                                              END
  229:                                                          ELSE --@TotalUnallocatedHrsForThisTxn > @UnallocatedDTHours
  230:                                                              BEGIN
  231:                                                                                                  /*
  232:                                                                                                          We have more hours than
  233:   what the DT needs, so 
  234:                                                                                                          use up the whole DT ove
  235:  rride.
  236:                                                                                                  */
  237:                                                                  UPDATE  [TimeHistory]..[tblTimeHistDetail]
  238:                                                                  SET     [DT_Hours] = @UnallocatedDTHours ,
  239:                                                                          [RegHours] = @TotalUnallocatedHrsForThisTxn - @Unalloca
  240:  tedDTHours-- everything else goes to reg
  241:                                                                  WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID
  243:                                                                  SET @TotalUnallocatedHrsForThisTxn = @TotalUnallocatedHrsForThi
  244:  sTxn - @UnallocatedDTHours -- deduct the newly allocated DT hrs
  245:                                                                  SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursFo
  246:  rThisDay - @UnallocatedDTHours-- deduct the newly allocated DT hrs from this day total
  247:                                                                  SET @UnallocatedDTHours = 0 -- no other DT allocation needs to 
  248:  happen for this day
  251:                                                              END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
  123:                                      BEGIN
  124:                                                                                  /** If over-ride amount is less than total hour
  125:  s ,
  126:                                                                                          update DT and Reg in THD with new value
  127:  s
  128:                                                                                  */
  129:                                                                                                      --PRINT '@THDRecordID: ' + 
  130:  CAST(@THDRecordID AS varchar)
  131:                                                                                                      --PRINT '@Total: ' + CAST(@
  132:  Total AS varchar)
  133:                                                                                                      --PRINT '@reg: ' + CAST(@re
  134:  g AS varchar)
  135:                                                                                                      --PRINT 'IF ' + CAST(@newDT
  136:   AS VARCHAR) + ' <= ' + CAST(@Total AS VARCHAR)
  137:                                          IF @newDT <= @Total 
  138:                                              BEGIN
  139:                                                  --PRINT 'updating DT 1'
  140:                                                  UPDATE  TimeHistory..tblTimeHistDetail
  141:                                                  SET     DT_Hours = @newDT ,
  142:                                                          RegHours = @Total - @newDT  /*GG - I think you mean't RegHours here*/
  143:                                                  WHERE   RecordID = @THDRecordID
  145:                                                  SET @reg = @Total - @newDT
  146:                                                  SET @newDT = 0 -- this is used after the OT block
  147:                                              END
  148:                                          ELSE 
  149:                                          /** If over-ride amount is less than total hours ,
  150:                                                                                          top up DT and reset newDT with remainde
  151:  r and set Reg=0 as
  152:                                                                                          there aren't any more hours left
  153:                                                                                          in THD with new values
  154:                                                                                  */ 
  155:                                              BEGIN
  156:                                                --PRINT 'updating DT 2'
  157:                                                  UPDATE  TimeHistory..tblTimeHistDetail
  158:                                                  SET     DT_Hours = @Total ,
  159:                                                          RegHours = 0
  160:                                                  WHERE   RecordID = @THDRecordID
  161:                                                          /**Will be used in next loop of inner cursor, in another THD row*/
  162:                                                  SET @newDT = @newDT - @Total
  163:                                                  SET @reg = 0
  164:                                              END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  252:                                                      END
  254:                                                                                  /**********************************************
  255:  ************************************************************
  256:                                                                                                                          PROCESS
  257:  ING OT ALLOCATION
  258:                                                                                  ***********************************************
  259:  ************************************************************/
  261:                                                  IF @TotalUnallocatedHrsForThisTxn > 0-- there are unallocated hours
  262:                                                      BEGIN
  263:                                                                                                  /*
  264:                                                                                                          if all available hours 
  265:  for the txn can be allocated to DT, do it.
  266:                                                                                                  */
  267:                                                          IF ( @TotalUnallocatedHrsForThisTxn <= @UnallocatedOTHours )
  268:                                                              BEGIN
  269:                                                                  UPDATE  [TimeHistory]..[tblTimeHistDetail]
  270:                                                                  SET     [OT_Hours] = @TotalUnallocatedHrsForThisTxn ,
  271:                                                                          [RegHours] = 0
  272:                                                                  WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID
  275:                                                                  SET @UnallocatedOTHours = @UnallocatedOTHours - @TotalUnallocat
  276:  edHrsForThisTxn -- new value is old - hrs we just allocated                                                
  277:                                                                  SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursFo
  278:  rThisDay
  279:                                                                      - @TotalUnallocatedHrsForThisTxn  -- reduce no of unallocat
  280:  ed hours
  281:                                                                  SET @TotalUnallocatedHrsForThisTxn = 0 -- since all have been a
  282:  llocated to OT
  283:                                                              END
  284:                                                          ELSE --@TotalUnallocatedHrsForThisTxn > @UnallocatedOTHours
  285:                                                              BEGIN
  286:                                                                                                  /*
  287:                                                                                                          We have more hours than
  288:   what the DT needs, so 
  289:                                                                                                          use up the whole DT ove
  290:  rride.
  291:                                                                                                  */
  292:                                                                  UPDATE  [TimeHistory]..[tblTimeHistDetail]
  293:                                                                  SET     [OT_Hours] = @UnallocatedOTHours ,
  294:                                                                          [RegHours] = @TotalUnallocatedHrsForThisTxn - @Unalloca
  295:  tedOTHours-- everything else goes to reg
  296:                                                                  WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID
  298:                                                                  SET @TotalUnallocatedHrsForThisTxn = @TotalUnallocatedHrsForThi
  299:  sTxn - @UnallocatedOTHours -- deduct the newly allocated OT hrs
  300:                                                                  SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursFo
  301:  rThisDay - @UnallocatedOTHours-- deduct the newly allocated OT hrs from this day total
  302:                                                                  SET @UnallocatedOTHours = 0 -- no other OT allocation needs to 
  303:  happen for this day
  306:                                                              END
  307:                                                      END
  311:                                              END
  313:                                          FETCH NEXT FROM perTxnCursor INTO @THDRecordID, @TotalUnallocatedHrsForThisTxn
  314:                                      END--WHILE (@@fetch_status <> -1)                   
  316:                                  CLOSE perTxnCursor
  317:                                  DEALLOCATE perTxnCursor
  318:                              END     
  324:                          /**update $s*/
  325:                          UPDATE  TimeHistory..tblTimeHistdetail
  326:                          SET     RegDollars = ROUND(Payrate * regHours, 2) ,
  327:                                  OT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, 
  328:  SiteNo, DeptNo, 'OT') )
  329:                                                     * OT_Hours, 2) ,
  330:                                  DT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, 
  331:  SiteNo, DeptNo, 'DT') )
  332:                                                     * DT_Hours, 2) ,
  333:                                  RegBillingDollars = ROUND(Billrate * regHours, 2) ,
  334:                                  OTBillingDollars = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, Grou
  335:  pCode, SSN, SiteNo, DeptNo, 'OT'),
  336:                                                                 2) * OT_Hours, 2) ,
  337:                                  DTBillingDollars = ROUND(( Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCod
  338:  e, SSN, SiteNo, DeptNo, 'DT') )
  339:                                                           * DT_Hours, 2) ,
  340:                                  RegDollars4 = ROUND(Payrate * regHours, 4) ,
  341:                                  OT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN,
  342:   SiteNo, DeptNo, 'OT') )
  343:                                                      * OT_Hours, 4) ,
  344:                                  DT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN,
  345:   SiteNo, DeptNo, 'DT') )
  346:                                                      * DT_Hours, 4) ,
  347:                                  RegBillingDollars4 = ROUND(Billrate * RegHours, 4) ,
  348:                                  OTBillingDollars4 = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, Gro
  349:  upCode, SSN, SiteNo, DeptNo, 'OT'),
  350:                                                                  2) * OT_Hours, 4) ,
  351:                                  DTBillingDollars4 = ROUND(( Billrate * 2.0 ) * DT_Hours, 4)
  352:                          WHERE   Client = @Client
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
  165:                                      END 
  166:                                   /** If over-ride amount is less than total hours ,
  167:                                                                                          update OT and Reg in THD with new value
  168:  s                                                                                       
  169:                                                                                          @reg is used as it would have the lates
  170:  t value after the DT block.
  171:                                                                                  */                                             
  173:                                  IF @newOT <= @reg 
  174:                                      BEGIN
  175:                                          --PRINT 'updating OT 1'
  176:                                          UPDATE  TimeHistory..tblTimeHistDetail
  177:                                          SET     OT_Hours = @newOT ,
  178:                                                  RegHours = @reg - @newOT
  179:                                          WHERE   RecordID = @THDRecordID
  181:                                          SET @newOT = 0
  182:                                      END
  183:                                  ELSE 
  184:                                      BEGIN
  185:                                      /** If over-ride amount is less than total hours ,
  186:                                                                                          top up OT and reset newOT with remainde
  187:  r and set Reg=0 as
  188:                                                                                          there aren't any more hours left
  189:                                                                                          in THD with new values
  190:                                                                                  */
  191:                                                                                                      --PRINT 'updating OT 2'
  192:                                          UPDATE  TimeHistory..tblTimeHistDetail
  193:                                          SET     OT_Hours = @reg ,
  194:                                                  RegHours = 0   /* GG - RegHours  */
  195:                                          WHERE   RecordID = @THDRecordID
  197:                                          SET @newOT = @newOT - @reg
  198:                                      END
  200:                                  --PRINT '@NewOT: ' + CAST(@NewOT AS VARCHAR)
  201:                                  --PRINT '@NewDT: ' + CAST(@newDT AS VARCHAR)
  202:                                  IF @newOT = 0
  203:                                      AND @newDT = 0  /**Else will be handled in next loop*/ 
  204:                                      BEGIN
  205:                                          BREAK
  206:                                      END
  208:                                  FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
  209:                              END--WHILE (@@fetch_status <> -1)                   
  211:                          CLOSE innerCursor
  212:                          DEALLOCATE innerCursor
  214:  -----------------   NEGATIVES         
  215:                          --PRINT ''
  216:                          --PRINT 'Processing Negatives'
  217:                          SET @newOT = @newOT_ORIG
  218:                          SET @newDT = @newDT_ORIG
  219:                          --PRINT '@TransDate: ' + CAST(@TransDate AS VARCHAR)
  220:                          --PRINT '@SiteNo: ' + cast(@SiteNo as varchar) + ';  ' + '@DeptNo: ' + cast(@DeptNo as varchar)
  221:                          --PRINT '@NewOT: ' + CAST(@newOT AS VARCHAR) + ';  ' + '@NewDT: ' + CAST(@newDT AS VARCHAR)            
  223:                          --PRINT '@NewOT: ' + CAST(@NewOT AS VARCHAR)
  224:                          --PRINT '@NewDT: ' + CAST(@newDT AS VARCHAR)                        
  226:                          DECLARE innerCursor CURSOR READ_ONLY
  227:                          FOR
  228:                              SELECT  RecordID , -- used for updates
  229:                                      Hours ,
  230:                                      RegHours
  231:                              FROM    TimeHistory..tblTimeHistDetail AS TTHD
  232:                              WHERE   Client = @Client
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
  358:                                  AND TransDate = @transdate
  360:                      END 
  361:                  FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @UnallocatedOTHours, @UnallocatedDTHours, @TransDate 
  362:              END--WHILE (@@fetch_status <> -1)                   
  364:          CLOSE outerCursor
  365:          DEALLOCATE outerCursor
  370:      END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
  238:                                      AND TransDate = @TransDate
  239:                                      AND Hours < 0
  240:                              /* GG - Need to order by in punch descending.  You have to sort OT and DT to end of day, regardless
  241:   of number of transactions*/
  242:                              ORDER BY InTime DESC -- ordering this way allows us to attempt to affect minimum no of rows
  243:                          OPEN innerCursor
  245:                          FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
  246:                          WHILE ( @@fetch_status <> -1 ) 
  247:                              BEGIN
  248:                                  IF ( @@fetch_status <> -2 ) 
  249:                                      BEGIN
  250:                                                                                  /** If over-ride amount is less than total hour
  251:  s ,
  252:                                                                                          update DT and Reg in THD with new value
  253:  s
  254:                                                                                  */
  255:                                                                                                      --PRINT '@THDRecordID: ' + 
  256:  CAST(@THDRecordID AS varchar)
  257:                                                                                                      --PRINT 'IF ABS(' + CAST(@n
  258:  ewDT AS VARCHAR) + ') <= ' + CAST(@Total AS VARCHAR)
  259:                                          IF @newDT <= @Total * -1
  260:                                              BEGIN
  261:                                                  --PRINT 'updating DT 1'
  262:                                                  UPDATE  TimeHistory..tblTimeHistDetail
  263:                                                  SET     DT_Hours = @newDT * -1 ,
  264:                                                          RegHours = @Total - (@newDT * -1) /*GG - I think you mean't RegHours he
  265:  re*/
  266:                                                  WHERE   RecordID = @THDRecordID
  268:                                                  SET @reg = @Total - (@newDT * -1)
  269:                                                  SET @newDT = 0 -- this is used after the OT block
  270:                                              END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_OTOverrides.sql
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_OTOVERRIDES.SQL
  271:                                          ELSE 
  272:                                          /** If over-ride amount is less than total hours ,
  273:                                                                                          top up DT and reset newDT with remainde
  274:  r and set Reg=0 as
  275:                                                                                          there aren't any more hours left
  276:                                                                                          in THD with new values
  277:                                                                                  */ 
  278:                                              BEGIN
  279:                                                --PRINT 'updating DT 2'
  280:                                                  UPDATE  TimeHistory..tblTimeHistDetail
  281:                                                  SET     DT_Hours = @Total ,
  282:                                                          RegHours = 0
  283:                                                  WHERE   RecordID = @THDRecordID
  284:                                                          /**Will be used in next loop of inner cursor, in another THD row*/
  285:                                                  SET @newDT = @newDT - (@Total * -1)
  286:                                                  SET @reg = 0
  287:                                              END
  288:                                      END 
  289:                                   /** If over-ride amount is less than total hours ,
  290:                                                                                          update OT and Reg in THD with new value
  291:  s                                                                                       
  292:                                                                                          @reg is used as it would have the lates
  293:  t value after the DT block.
  294:                                                                                  */                                             
  296:                                  IF @newOT <= @reg * -1
  297:                                      BEGIN
  298:                                          --PRINT 'updating OT 1'
  299:                                          UPDATE  TimeHistory..tblTimeHistDetail
  300:                                          SET     OT_Hours = (@newOT * -1) ,
  301:                                                  RegHours = @reg - (@newOT * -1)
  302:                                          WHERE   RecordID = @THDRecordID
  304:                                          SET @newOT = 0
  305:                                      END
  306:                                  ELSE 
  307:                                      BEGIN
  308:                                      /** If over-ride amount is less than total hours ,
  309:                                                                                          top up OT and reset newOT with remainde
  310:  r and set Reg=0 as
  311:                                                                                          there aren't any more hours left
  312:                                                                                          in THD with new values
  313:                                                                                  */
  314:                                                                                                      --PRINT 'updating OT 2'
  315:                                          UPDATE  TimeHistory..tblTimeHistDetail
  316:                                          SET     OT_Hours = @reg ,
  317:                                                  RegHours = 0   /* GG - RegHours  */
  318:                                          WHERE   RecordID = @THDRecordID
  320:                                          SET @newOT = @newOT - (@reg * -1)
  321:                                      END
  323:                                  --PRINT '@NewOT: ' + CAST(@NewOT AS VARCHAR)
  324:                                  --PRINT '@NewDT: ' + CAST(@newDT AS VARCHAR)
  325:                                  IF @newOT = 0
  326:                                      AND @newDT = 0  /**Else will be handled in next loop*/ 
  327:                                      BEGIN
  328:                                          BREAK
  329:                                      END
  331:                                  FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
  332:                              END--WHILE (@@fetch_status <> -1)                   
  334:                          CLOSE innerCursor
  335:                          DEALLOCATE innerCursor
  337:                          /**update $s*/
  338:                          UPDATE  TimeHistory..tblTimeHistdetail
  339:                          SET     RegDollars = ROUND(Payrate * regHours, 2) ,
  340:                                  OT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, 
  341:  SiteNo, DeptNo, 'OT') ) * OT_Hours, 2) ,
  342:                                  DT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, 
  343:  SiteNo, DeptNo, 'DT') ) * DT_Hours, 2) ,
  344:                                  RegBillingDollars = ROUND(Billrate * regHours, 2) ,
  345:                                  OTBillingDollars = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, Grou
  346:  pCode, SSN, SiteNo, DeptNo, 'OT'), 2) * OT_Hours, 2) ,
  347:                                  DTBillingDollars = ROUND(( Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCod
  348:  e, SSN, SiteNo, DeptNo, 'DT') ) * DT_Hours, 2) ,
  349:                                  RegDollars4 = ROUND(Payrate * regHours, 4) ,
  350:                                  OT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN,
  351:   SiteNo, DeptNo, 'OT') ) * OT_Hours, 4) ,
  352:                                  DT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN,
  353:   SiteNo, DeptNo, 'DT') ) * DT_Hours, 4) ,
  354:                                  RegBillingDollars4 = ROUND(Billrate * RegHours, 4) ,
  355:                                  OTBillingDollars4 = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, Gro
  356:  upCode, SSN, SiteNo, DeptNo, 'OT'), 2) * OT_Hours, 4) ,
  357:                                  DTBillingDollars4 = ROUND(( Billrate * 2.0 ) * DT_Hours, 4)
  358:                          WHERE   Client = @Client
  359:                                  AND GroupCode = @groupcode
  360:                                  AND PayrollPeriodEndDate = @pped
  361:                                  AND SSN = @ssn
  362:                                  AND SiteNo = @siteno
  363:                                  AND DeptNo = @deptno
  364:                                  AND TransDate = @transdate
  366:                      END 
  367:                  FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @newOT, @newDT, @TransDate 
  368:              END--WHILE (@@fetch_status <> -1)                   
  370:          CLOSE outerCursor
  371:          DEALLOCATE outerCursor
  376:      END
*****

