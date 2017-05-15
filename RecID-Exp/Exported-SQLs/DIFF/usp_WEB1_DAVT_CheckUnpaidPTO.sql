Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
   98:    (
   99:      RecordID int,
  100:      GroupCOde int,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
   97:    (
   98:      RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
   99:      GroupCOde int,
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  363:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  364:   'P', 'UNSCPTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  365:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  366:   '<', 'UnPD UnSch', @uPTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  367:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  362:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  363:   'P', 'UNSCPTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  364:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  365:   '<', 'UnPD UnSch', @uPTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  366:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  376:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  377:   'P', 'UNSCPTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  378:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  379:   '<', 'UnPD UnSch', @uPTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  380:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  375:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  376:   'P', 'UNSCPTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  377:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  378:   '<', 'UnPD UnSch', @uPTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  379:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  412:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  413:   '2', 'PTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  414:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  415:   '>', 'UnPD PTO', @PTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  416:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  411:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  412:   '2', 'PTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  413:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  414:   '>', 'UnPD PTO', @PTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  415:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  424:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  425:   '2', 'PTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  426:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  427:   '>', 'UnPD PTO', @PTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N','N','N','1'
  428:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  423:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  424:   '2', 'PTO', @TempHours, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  425:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDStart, @SSN, 0, 0,
  426:   '>', 'UnPD PTO', @PTOTaken, 0.00, @PPEDStart, @PPEDEnd, 'SYS', 'N'
  427:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  487:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  488:  P', 'UNSCPTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  489:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  490:  <', 'UnPD UnSch', @uPTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  491:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  486:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  487:  P', 'UNSCPTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  488:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  489:  <', 'UnPD UnSch', @uPTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  490:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  500:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  501:  P', 'UNSCPTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  502:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  503:  <', 'UnPD UnSch', @uPTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  504:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  499:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  500:  P', 'UNSCPTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  501:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  502:  <', 'UnPD UnSch', @uPTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  503:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  536:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  537:  2', 'PTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  538:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  539:  >', 'UnPD PTO', @PTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  540:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  535:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  536:  2', 'PTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  537:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  538:  >', 'UnPD PTO', @PTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  539:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WEB1_DAVT_CheckUnpaidPTO.sql
  548:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  549:  2', 'PTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  550:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  551:  >', 'UnPD PTO', @PTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N','N','N','1'
  552:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DAVT_CHECKUNPAIDPTO.SQL
  547:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  548:  2', 'PTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  549:                  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPEDEnd, @SSN, 0, 0, '
  550:  >', 'UnPD PTO', @PTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
  551:            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Me
*****

