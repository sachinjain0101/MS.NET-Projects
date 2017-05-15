Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
   62:  DECLARE @WeekLocked char(1)
   63:  DECLARE @Bereavement NUMERIC(7,2)
   64:  DECLARE @JuryDuty NUMERIC(7,2),
   65:                                  @AdminPTO NUMERIC(7,2),
   66:                                  @AdminUNPTO NUMERIC(7,2),
   67:                                  @NonWorkPTO NUMERIC(7,2)
   69:  Set @Date1 = '1/1/1970'
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
   61:  DECLARE @WeekLocked char(1)
   63:  Set @Date1 = '1/1/1970'
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
   89:  Set @PPED_1 = dateadd(day, -7, @PPED_2)
   91:  --IF getdate() < @PPED_2
   92:  --  Set @PPED_2 = @PPED_1
   94:  --Print @PPED_1
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
   83:  Set @PPED_1 = dateadd(day, -7, @PPED_2)
   85:  IF getdate() < @PPED_2
   86:    Set @PPED_2 = @PPED_1
   88:  --Print @PPED_1
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  105:  and TransDate <= @PPED_2
  106:  --AND TransDate < '1/1/2017'                    -- exclude any holidays prior to 1/1/2017.
  108:  DECLARE @Holidaydate datetime
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
   99:  and TransDate <= @PPED_2
  101:  DECLARE @Holidaydate datetime
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  154:    (
  155:      RecordID int,
  156:      GroupCOde int,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  147:    (
  148:      RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
  149:      GroupCOde int,
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  200:  END
  202:  /*
  203:  PRINT @PPED_1
  204:  PRINT @PPED_2
  205:  PRINT @Date1
  206:  PRINT @Date2
  207:  PRINT @Date3
  208:  PRINT @Date4
  209:  PRINT @LastRecalc
  211:  Select t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, WeekLocked = isnull(en.WeekLocked,'0'), sum(t.Hours) 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  193:  END
  195:  DECLARE cSSNs CURSOR
  196:  READ_ONLY
  197:  FOR 
  198:  Select t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, WeekLocked = isnull(en.WeekLocked,'0'), sum(t.Hours) 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  220:  and t.payrollperiodenddate in(@PPED_1, @PPED_2)
  221:  and t.clockadjustmentno in('2','5','P','3','4','2AL','2AU','2NW' ) 
  222:  --and t.TransDate not in(@Date1,@Date2,@Date3,@Date4)
  223:  and isnull(en.WeekLocked,'0') <> '1'
  224:  --and ( isnull(en.LastRecalcTime,'1/1/1970') > @LastRecalc OR isnull(t.CrossoverStatus,'') in('2','4') )
  225:  Group By t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, en.weeklocked 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  207:  and t.payrollperiodenddate in(@PPED_1, @PPED_2)
  208:  and t.clockadjustmentno in('2','5','P') 
  209:  and t.TransDate not in(@Date1,@Date2,@Date3,@Date4)
  210:  and isnull(en.WeekLocked,'0') <> '1'
  211:  and ( isnull(en.LastRecalcTime,'1/1/1970') > @LastRecalc OR isnull(t.CrossoverStatus,'') in('2','4') )
  212:  Group By t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, en.weeklocked 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  226:  Having Sum(t.Hours) <> 0.00
  227:  */
  229:  DECLARE cSSNs CURSOR
  230:  READ_ONLY
  231:  FOR 
  232:  Select t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, WeekLocked = isnull(en.WeekLocked,'0'), sum(t.Hours) 
  233:  from TimeHistory..tblTimeHistDetail as t with (nolock)
  234:  Inner Join TimeHistory..tblEmplnames as en with (nolock)
  235:  on en.client = t.client
  236:  and en.groupcode = t.groupcode
  237:  and en.ssn = t.ssn
  238:  and en.payrollperiodenddate = t.payrollperiodenddate
  239:  where t.client = @Client 
  240:  and t.groupcode = @GroupCode 
  241:  and t.payrollperiodenddate in(@PPED_1, @PPED_2)
  242:  and t.clockadjustmentno in('2','5','P','3','4','2AL','2AU','2NW' ) 
  243:  --and t.TransDate not in(@Date1,@Date2,@Date3,@Date4)
  244:  and isnull(en.WeekLocked,'0') <> '1'
  245:  --and ( isnull(en.LastRecalcTime,'1/1/1970') > @LastRecalc OR isnull(t.CrossoverStatus,'') in('2','4') )
  246:  Group By t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, en.weeklocked 
  247:  Having Sum(t.Hours) <> 0.00
  249:  OPEN cSSNS
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  213:  Having Sum(t.Hours) <> 0.00
  215:  OPEN cSSNS
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  255:          BEGIN
  257:      if exists(select recordid from TimeHistory..tblTimeHistDetail with (nolock) 
  258:                                                          WHERE client = @Client and groupcode = @Groupcode
  259:                                                                          AND SSN = @SSN and clockadjustmentno in('2','5','P','3'
  260:  ,'4','2AL','2AU','2NW' ) and Payrollperiodenddate = @PPED
  261:                                                                          AND (isnull(CrossoverOtherGroup,0) = 0 or isnull(Crosso
  262:  verOtherGroup,0) = @GroupCode ) )
  263:      BEGIN
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  221:          BEGIN
  223:      if exists(select recordid from TimeHistory..tblTimeHistDetail with (nolock) where client = @Client and groupcode = @Groupco
  224:  de
  225:      and SSN = @SSN and clockadjustmentno in('2','5','P') and Payrollperiodenddate = @PPED
  226:      and (isnull(CrossoverOtherGroup,0) = 0 or isnull(CrossoverOtherGroup,0) = @GroupCode ) )
  227:      BEGIN
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  267:                          --
  268:                          Select @WeekTot = Sum(case when clockadjustmentno not in('>','<','-','2UP','2CG','2LT','2D0','2SC','SUP
  269:  ') then hours else 0.00 end ),
  270:               @RegHours = sum(case when RegHours <> 0.00 and clockadjustmentno not in('>','<','-','2UP','2CG','2LT','2D0','2SC',
  271:  'SUP') then RegHours else 0.00 end),
  272:               @WeeklyOTHours = sum(case when OT_Hours <> 0.00 then OT_Hours - AllocatedOT_Hours else 0.00 end),
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  231:                          --
  232:                          Select @WeekTot = Sum(case when clockadjustmentno not in('>','<','-') then hours else 0.00 end ),
  233:               @RegHours = sum(case when RegHours <> 0.00 and clockadjustmentno not in('>','<','-') then RegHours else 0.00 end),
  235:               @WeeklyOTHours = sum(case when OT_Hours <> 0.00 then OT_Hours - AllocatedOT_Hours else 0.00 end),
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  274:               @DTHours = sum(DT_Hours),
  275:                                                   --@PTOTaken = Sum(Case when ClockAdjustmentNo = '2' and TransDate not in(@Date
  276:  1,@Date2,@Date3,@Date4) then Hours else 0.00 end ),
  277:                                                   @PTOTaken = Sum(Case when ClockAdjustmentNo = '2' then Hours else 0.00 end ),
  278:                                                   @EILTaken = Sum(Case when ClockAdjustmentNo = '5' then Hours else 0.00 end ),
  279:                                                   --@uPTOTaken = Sum(Case when ClockAdjustmentNo = 'P' and TransDate not in(@Dat
  280:  e1,@Date2,@Date3,@Date4) then Hours else 0.00 end ),
  281:                                                   @uPTOTaken = Sum(Case when ClockAdjustmentNo = 'P' then Hours else 0.00 end ),
  283:               @UnPaid = sum(case when clockadjustmentno in('>','<','-') and UserCode = 'SYW' then Hours else 0.00 end),
  284:                                                   @Bereavement = Sum(Case when ClockAdjustmentNo = '3' then Hours else 0.00 end 
  285:  ),
  286:                                                   @Juryduty =  Sum(Case when ClockAdjustmentNo = '4' then Hours else 0.00 end ),
  288:                                                   @AdminPTO =  Sum(Case when ClockAdjustmentNo = '2AL' then Hours else 0.00 end 
  289:  ),
  290:                                                   @AdminUNPTO =  Sum(Case when ClockAdjustmentNo = '2AU' then Hours else 0.00 en
  291:  d ),
  292:                                                   @NonWorkPTO =  Sum(Case when ClockAdjustmentNo = '2NW' then Hours else 0.00 en
  293:  d )
  294:                                  from    TimeHistory..tblTimeHistDetail with (nolock)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  237:               @DTHours = sum(DT_Hours),
  238:                                                   @PTOTaken = Sum(Case when ClockAdjustmentNo = '2' and TransDate not in(@Date1,
  239:  @Date2,@Date3,@Date4) then Hours else 0.00 end ),
  240:                                                   @EILTaken = Sum(Case when ClockAdjustmentNo = '5' then Hours else 0.00 end ),
  241:                                                   @uPTOTaken = Sum(Case when ClockAdjustmentNo = 'P' and TransDate not in(@Date1
  242:  ,@Date2,@Date3,@Date4) then Hours else 0.00 end ),
  243:               @UnPaid = sum(case when clockadjustmentno in('>','<','-') and UserCode = 'SYW' then Hours else 0.00 end)
  244:                                  from    TimeHistory..tblTimeHistDetail with (nolock)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  299:                              and (isnull(CrossoverOtherGroup,0) = 0 or isnull(CrossoverOtherGroup,0) = @GroupCode )
  300:            --and NOT( TransDate in(@Date1,@Date2,@Date3,@Date4) and ClockAdjustmentNo in('2','P') )  -- Exclude Holiday PTO
  303:                          Select @BaseHours = BaseHours,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  249:                              and (isnull(CrossoverOtherGroup,0) = 0 or isnull(CrossoverOtherGroup,0) = @GroupCode )
  250:            and NOT( TransDate in(@Date1,@Date2,@Date3,@Date4) and ClockAdjustmentNo in('2','P') )  -- Exclude Holiday PTO
  253:                          Select @BaseHours = BaseHours,
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  334:            and PayrollPeriodenddate = @PPED and ssn = @SSN
  335:            and ClockAdjustmentNo in('2','5','P','3','4') and UserCode = 'SYW' and Hours <= 0.00
  336:          IF @SubStatus4 <> 'L'
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  284:            and PayrollPeriodenddate = @PPED and ssn = @SSN
  285:            and ClockAdjustmentNo in('2','5','P') and UserCode = 'SYW' and Hours <= 0.00
  286:          IF @SubStatus4 <> 'L'
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  359:        END
  362:                          IF isnull(@WeekTot,0) <= @BaseHours 
  363:                                          OR (@PTOTaken + @uPTOTaken + @EILTaken + @Bereavement + @JuryDuty + @AdminPTO + @AdminU
  364:  NPTO + @NonWorkPTO) <= 0.00
  365:                          BEGIN
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  309:        END
  311:                          IF isnull(@WeekTot,0) <= @BaseHours OR (@PTOTaken + @uPTOTaken + @EILTaken) <= 0.00
  312:                          BEGIN
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  377:                          Set @AuditRecordID = @@Identity
  379:                          Set @PTOBalance1 = @WeekTot - @BaseHours
  381:                          -- AdminPTO
  382:                    --
  383:                          IF @AdminPTO > 0 AND @PTOBalance1 > 0
  384:                          BEGIN
  385:                                  EXEC TimeHistory.[dbo].[usp_WEB1_DAVT_CheckUnpaidPTO_Weekly_Helper] @Client, @GroupCode, @SSN, 
  386:  @PPED, @MPD, @PTOBalance1, @AdminPTO, '2AL', 'AdmPTO*', @AuditRecordID
  388:                                  IF @AdminPTO> @PTOBalance1
  389:                                  BEGIN
  390:                          Set @PTOBalance1 = 0
  391:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  324:                          Set @AuditRecordID = @@Identity
  326:                          -- Take it from Unscheduled PTO first.
  327:                    --
  328:                          Set @PTOBalance1 = @WeekTot - @BaseHours
  329:                          IF @uPTOTaken > 0
  330:                          BEGIN
  331:                                  IF @uPTOTaken > @PTOBalance1
  332:                                  BEGIN
  333:            -- Remove Unscheduled PTO and Add Unpaid Unscheduled PTO.
  334:                                          --
  335:                          Set @uPTOTaken = @PTOBalance1
  336:                          Set @PTOBalance1 = 0
  337:                                  Set @TempHours = @uPTOTaken * -1
  338:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  339:   0, 'P', 'UNSCPTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  340:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  341:   0, '<', 'nPD UnSch*', @uPTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  342:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  343:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'nPD UnSch*'
  344:                                          where RecordID = @AuditRecordID
  345:                                  END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  393:                                  BEGIN
  394:                          Set @PTOBalance1 = @PTOBalance1 - @AdminPTO
  395:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  347:                                  BEGIN
  348:            -- Remove Unscheduled PTO and Add Unpaid Unscheduled PTO.
  349:                                          --
  350:                          Set @PTOBalance1 = @PTOBalance1 - @uPTOTaken
  351:                                  Set @TempHours = @uPTOTaken * -1
  352:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  353:   0, 'P', 'UNSCPTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  354:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  355:   0, '<', 'nPD UnSch*', @uPTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  356:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  357:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'nPD UnSch*'
  358:                                          where RecordID = @AuditRecordID
  359:                                  END
  360:          -- AutoApprove the UN PAID hours if the original hours were approved.
  361:          --
  362:          if exists (Select 1 from Timehistory..tblTimeHistDetail with (nolock)
  363:              where client = @Client
  364:              and groupcode = @Groupcode
  365:              and SSN = @SSN
  366:              and Payrollperiodenddate = @PPED
  367:              and ClockAdjustmentNo = 'P'
  368:              and isnull(AprvlStatus,'') = 'A')
  369:          BEGIN
  370:            Update Timehistory..tblTimeHistDetail
  371:              Set AprvlStatus = 'A',AprvlStatus_UserID = 7584, AprvlStatus_Date = getdate()
  372:            where client = @Client
  373:              and groupcode = @Groupcode
  374:              and SSN = @SSN
  375:              and Payrollperiodenddate = @PPED
  376:              and isnull(AprvlStatus,'') <> 'A'
  377:              and ( (ClockAdjustmentNo = '<') OR (ClockADjustmentNo = 'P' and Hours < 0.00 and UserCode = 'SYW') )
  378:          END  
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  396:                          END
  397:                          -- AdminUNPTO
  398:                    --
  399:                          IF @AdminUNPTO > 0 AND @PTOBalance1 > 0
  400:                          BEGIN
  401:                                  EXEC TimeHistory.[dbo].[usp_WEB1_DAVT_CheckUnpaidPTO_Weekly_Helper] @Client, @GroupCode, @SSN, 
  402:  @PPED, @MPD, @PTOBalance1, @AdminUNPTO, '2AU', 'AdmUNPTO*', @AuditRecordID
  404:                                  IF @AdminUNPTO > @PTOBalance1
  405:                                  BEGIN
  406:                          Set @PTOBalance1 = 0
  407:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  380:                          END
  382:                          IF @PTOTaken > 0 and @PTOBalance1 > 0
  383:                          BEGIN
  384:                                  IF @PTOTaken > @PTOBalance1
  385:                                  BEGIN
  386:            -- Remove scheduled PTO and Add Unpaid scheduled PTO.
  387:                                          --
  388:                          Set @PTOTaken = @PTOBalance1
  389:                          Set @PTOBalance1 = 0
  390:                                  Set @TempHours = @PTOTaken * -1
  391:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  392:   0, '2', 'PTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  393:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  394:   0, '>', 'UnPD PTO*', @PTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  395:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  396:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD PTO*'
  397:                                          where RecordID = @AuditRecordID
  398:                                  END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  409:                                  BEGIN
  410:                          Set @PTOBalance1 = @PTOBalance1 - @AdminUNPTO
  411:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  400:                                  BEGIN
  401:            -- Remove scheduled PTO and Add Unpaid scheduled PTO.
  402:                                          --
  403:                          Set @PTOBalance1 = @PTOBalance1 - @PTOTaken
  404:                                  Set @TempHours = @PTOTaken * -1
  405:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  406:   0, '2', 'PTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  407:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  408:   0, '>', 'UnPD PTO*', @PTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  409:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  410:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD PTO*'
  411:                                          where RecordID = @AuditRecordID
  412:                                  END
  413:          -- AutoApprove the UN PAID hours if the original hours were approved.
  414:          --
  415:          if exists (Select 1 from Timehistory..tblTimeHistDetail with (nolock)
  416:              where client = @Client
  417:              and groupcode = @Groupcode
  418:              and SSN = @SSN
  419:              and Payrollperiodenddate = @PPED
  420:              and ClockAdjustmentNo = '2'
  421:              and isnull(AprvlStatus,'') = 'A')
  422:          BEGIN
  423:            Update Timehistory..tblTimeHistDetail
  424:              Set AprvlStatus = 'A',AprvlStatus_UserID = 7584, AprvlStatus_Date = getdate()
  425:            where client = @Client
  426:              and groupcode = @Groupcode
  427:              and SSN = @SSN
  428:              and Payrollperiodenddate = @PPED
  429:              and isnull(AprvlStatus,'') <> 'A'
  430:              and ( (ClockAdjustmentNo = '>') OR (ClockADjustmentNo = '2' and Hours < 0.00 and UserCode = 'SYW') )
  431:          END  
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  412:                          END
  413:                          -- NonWorkPTO
  414:                    --
  415:                          IF @NonWorkPTO > 0 AND @PTOBalance1 > 0
  416:                          BEGIN
  417:                                  EXEC TimeHistory.[dbo].[usp_WEB1_DAVT_CheckUnpaidPTO_Weekly_Helper] @Client, @GroupCode, @SSN, 
  418:  @PPED, @MPD, @PTOBalance1, @NonWorkPTO, '2NW', 'NW-PTO*', @AuditRecordID
  420:                                  IF @NonWorkPTO > @PTOBalance1
  421:                                  BEGIN
  422:                          Set @PTOBalance1 = 0
  423:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  432:                          END
  433:                          IF @EILTaken > 0 and @PTOBalance1 > 0
  434:                          BEGIN
  435:                                  IF @EILTaken > @PTOBalance1
  436:                                  BEGIN
  437:            -- Remove EIL and Add Unpaid EIL
  438:                                          --
  439:                          Set @EILTaken = @PTOBalance1
  440:                          Set @PTOBalance1 = 0
  441:                                  Set @TempHours = @EILTaken * -1
  442:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  443:   0, '5', 'PdSckTm *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  444:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  445:   0, '-', 'UnPD PST*', @EILTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  446:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  447:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD EIL*'
  448:                                          where RecordID = @AuditRecordID
  449:                                  END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  425:                                  BEGIN
  426:                          Set @PTOBalance1 = @PTOBalance1 - @NonWorkPTO
  427:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  451:                                  BEGIN
  452:            -- Remove EIL and Add Unpaid EIL
  453:                                          --
  454:                          Set @PTOBalance1 = @PTOBalance1 - @EILTaken
  455:                                  Set @TempHours = @EILTaken * -1
  456:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  457:   0, '5', 'PdSckTm *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  458:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  459:   0, '-', 'UnPD PST*', @EILTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  460:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  461:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD EIL*'
  462:                                          where RecordID = @AuditRecordID
  463:                                  END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  428:                          END
  430:                          -- Bereavement
  431:                    --
  433:                          IF @Bereavement > 0 AND @PTOBalance1 > 0
  434:                          BEGIN
  435:                                  EXEC TimeHistory.[dbo].[usp_WEB1_DAVT_CheckUnpaidPTO_Weekly_Helper] @Client, @GroupCode, @SSN, 
  436:  @PPED, @MPD, @PTOBalance1, @Bereavement, '3', 'BEREAVE*', @AuditRecordID
  438:                                  IF @Bereavement > @PTOBalance1
  439:                                  BEGIN
  440:                          Set @PTOBalance1 = 0
  441:                                  END
  442:                                  ELSE
  443:                                  BEGIN
  444:                          Set @PTOBalance1 = @PTOBalance1 - @Bereavement
  445:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  464:                          END
  467:          END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  446:                          END
  449:                          IF @JuryDuty > 0 AND @PTOBalance1 > 0
  450:                          BEGIN
  451:                                  EXEC TimeHistory.[dbo].[usp_WEB1_DAVT_CheckUnpaidPTO_Weekly_Helper] @Client, @GroupCode, @SSN, 
  452:  @PPED, @MPD, @PTOBalance1, @JuryDuty, '4', 'JURYDUTY*', @AuditRecordID
  453:                                  IF @JuryDuty > @PTOBalance1
  454:                                  BEGIN
  455:                          Set @PTOBalance1 = 0
  456:                                  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
  468:          END
  469:  NEXT_RECORD:
  470:          FETCH NEXT FROM cSSNS INTO @Client, @Groupcode, @SSN, @PPED, @WeekLocked, @Hours
  471:  END
  473:  CLOSE cSSNS
  474:  DEALLOCATE cSSNS
  476:  if @ReturnRecs = 'Y'
  477:  BEGIN
  478:          --recalc Command.
  479:          --
  480:          select Client = 'DAVT', GroupCode, SSN, PayrollPeriodenddate = PPED, lastname = message, Step
  481:          from [TimeCurrent].[dbo].[tblWork_DAVT_UnpaidPTO_Audit] with (nolock)
  482:          where message like 'Recalc%'
  483:          and GroupCode = @GroupCode
  484:          and isnull(dateadded,'1/1/1970') >= @CalcStart
  486:  END     
*****

Resync Failed.  Files are too different.
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO_Weekly.sql
  457:                                  ELSE
  458:                                  BEGIN
  459:                          Set @PTOBalance1 = @PTOBalance1 - @JuryDuty
  460:                                  END
  461:                          END
  463:                          -- Take it from Unscheduled PTO first.
  464:                    --
  465:                          IF @uPTOTaken > 0 AND @PTOBalance1 > 0
  466:                          BEGIN
  467:                                  IF @uPTOTaken > @PTOBalance1
  468:                                  BEGIN
  469:            -- Remove Unscheduled PTO and Add Unpaid Unscheduled PTO.
  470:                                          --
  471:                          Set @uPTOTaken = @PTOBalance1
  472:                          Set @PTOBalance1 = 0
  473:                                  Set @TempHours = @uPTOTaken * -1
  474:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  475:   0, 'P', 'UNSCPTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  476:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  477:   0, '<', 'nPD UnSch*', @uPTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  478:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  479:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'nPD UnSch*'
  480:                                          where RecordID = @AuditRecordID
  481:                                  END
  482:                                  ELSE
  483:                                  BEGIN
  484:            -- Remove Unscheduled PTO and Add Unpaid Unscheduled PTO.
  485:                                          --
  486:                          Set @PTOBalance1 = @PTOBalance1 - @uPTOTaken
  487:                                  Set @TempHours = @uPTOTaken * -1
  488:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  489:   0, 'P', 'UNSCPTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  490:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  491:   0, '<', 'nPD UnSch*', @uPTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  492:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  493:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'nPD UnSch*'
  494:                                          where RecordID = @AuditRecordID
  495:                                  END
  496:          -- AutoApprove the UN PAID hours if the original hours were approved.
  497:          --
  498:          if exists (Select 1 from Timehistory..tblTimeHistDetail with (nolock)
  499:              where client = @Client
  500:              and groupcode = @Groupcode
  501:              and SSN = @SSN
  502:              and Payrollperiodenddate = @PPED
  503:              and ClockAdjustmentNo = 'P'
  504:              and isnull(AprvlStatus,'') = 'A')
  505:          BEGIN
  506:            Update Timehistory..tblTimeHistDetail
  507:              Set AprvlStatus = 'A',AprvlStatus_UserID = 7584, AprvlStatus_Date = getdate()
  508:            where client = @Client
  509:              and groupcode = @Groupcode
  510:              and SSN = @SSN
  511:              and Payrollperiodenddate = @PPED
  512:              and isnull(AprvlStatus,'') <> 'A'
  513:              and ( (ClockAdjustmentNo = '<') OR (ClockADjustmentNo = 'P' and Hours < 0.00 and UserCode = 'SYW') )
  514:          END  
  516:                          END
  518:                          IF @EILTaken > 0 and @PTOBalance1 > 0
  519:                          BEGIN
  520:                                  IF @EILTaken > @PTOBalance1
  521:                                  BEGIN
  522:            -- Remove EIL and Add Unpaid EIL
  523:                                          --
  524:                          Set @EILTaken = @PTOBalance1
  525:                          Set @PTOBalance1 = 0
  526:                                  Set @TempHours = @EILTaken * -1
  527:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  528:   0, '5', 'PdSckTm *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  529:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  530:   0, '-', 'UnPD PST*', @EILTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  531:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  532:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD EIL*'
  533:                                          where RecordID = @AuditRecordID
  534:                                  END
  535:                                  ELSE
  536:                                  BEGIN
  537:            -- Remove EIL and Add Unpaid EIL
  538:                                          --
  539:                          Set @PTOBalance1 = @PTOBalance1 - @EILTaken
  540:                                  Set @TempHours = @EILTaken * -1
  541:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  542:   0, '5', 'PdSckTm *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
  543:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
  544:   0, '-', 'UnPD PST*', @EILTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
  545:                                          Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
  546:                                                          Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD EIL*'
  547:                                          where RecordID = @AuditRecordID
  548:                                  END
  549:                          END
  551:                          IF @PTOTaken > 0 and @PTOBalance1 > 0
  552:                          BEGIN
  553:                                  IF @PTOTaken > @PTOBalance1
  554:                                  BEGIN
  555:            -- Remove scheduled PTO and Add Unpaid scheduled PTO.
  556:                                          --
  557:                          Set @PTOTaken = @PTOBalance1
  558:                          Set @PTOBalance1 = 0
  559:                                  Set @TempHours = @PTOTaken * -1
  560:                          EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO_WEEKLY.SQL
*****

