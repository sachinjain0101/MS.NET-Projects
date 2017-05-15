Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
   72:    , PayBillCode   VARCHAR(10)
   73:    , RecordID      INT
   74:    , AmountType    CHAR(1)       -- Hours, Dollars, etc. ( Units )
   75:    , Line1         VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
   71:    , PayBillCode   VARCHAR(10)
   72:    , RecordID      BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 05Aug2016 >--
   73:    , AmountType    CHAR(1)       -- Hours, Dollars, etc. ( Units )
   74:    , AgencyName    VARCHAR(50)
   75:    , Line1         VARCHAR(1000) --Required in VB6: GenericPayrollUpload program
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  125:      , ac.AdjustmentType 
  126:      , [Line1]=''
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  125:      , ac.AdjustmentType 
  126:          , AgencyName=ISNULL(ag.AgencyName,'')
  127:      , [Line1]=''
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  142:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  143:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  143:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  144:                  LEFT JOIN TimeCurrent..tblAgencies ag
  145:              ON  [edh].Client = [ag].Client
  146:              AND [edh].GroupCode = [ag].GroupCode
  147:                          AND en.AgencyNo=ag.Agency
  148:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  147:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  148:                                                  AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  149:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  152:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  153:                                                  --AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  154:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  186:      , ac.AdjustmentType 
  188:  -- REG Non-Worked (vacation, pto, sick, holiday, etc.)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  191:      , ac.AdjustmentType 
  192:      , ISNULL(ag.AgencyName,'') 
  194:  -- REG Non-Worked (vacation, pto, sick, holiday, etc.)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  235:      , ac.AdjustmentType 
  236:      , [Line1]=''
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  241:      , ac.AdjustmentType 
  242:          , AgencyName=ISNULL(ag.AgencyName,'')
  243:      , [Line1]=''
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  252:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  253:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  259:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  260:                  LEFT JOIN TimeCurrent..tblAgencies ag
  261:              ON  [edh].Client = [ag].Client
  262:              AND [edh].GroupCode = [ag].GroupCode
  263:                          AND en.AgencyNo=ag.Agency
  264:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  257:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  258:                                                  AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  259:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  268:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  269:                                                  --AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  270:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  296:      , ac.AdjustmentType 
  298:  -- OT
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  307:      , ac.AdjustmentType 
  308:          ,ISNULL(ag.AgencyName,'')
  310:  -- OT
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  345:      , ac.AdjustmentType 
  346:      , [Line1]=''
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  357:      , ac.AdjustmentType 
  358:          , AgencyName=ISNULL(ag.AgencyName,'')
  359:      , [Line1]=''
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  362:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  363:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  375:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  376:                  LEFT JOIN TimeCurrent..tblAgencies ag
  377:              ON  [edh].Client = [ag].Client
  378:              AND [edh].GroupCode = [ag].GroupCode
  379:                          AND en.AgencyNo=ag.Agency
  380:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  367:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  368:                                                  AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  369:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  384:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  385:                                                  --AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  386:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  405:      , ac.AdjustmentType 
  407:  -- DT
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  422:      , ac.AdjustmentType 
  423:      , ISNULL(ag.AgencyName,'')     
  425:  -- DT
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  454:      , ac.AdjustmentType 
  455:      , [Line1]=''
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  472:      , ac.AdjustmentType 
  473:          , AgencyName=ISNULL(ag.AgencyName,'')
  474:      , [Line1]=''
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  471:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  472:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  490:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  491:                  LEFT JOIN TimeCurrent..tblAgencies ag
  492:              ON  [edh].Client = [ag].Client
  493:              AND [edh].GroupCode = [ag].GroupCode
  494:                          AND en.AgencyNo=ag.Agency
  495:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  476:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  477:                                                  AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  478:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  499:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  500:                                                  --AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  501:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  515:      , ac.AdjustmentType 
  517:  -- DOLLARS      
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  538:      , ac.AdjustmentType 
  539:      , ISNULL(ag.AgencyName,'') 
  541:  -- DOLLARS      
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  559:      , ac.AdjustmentType 
  560:      , [Line1]=''
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  583:      , ac.AdjustmentType 
  584:          , AgencyName=ISNULL(ag.AgencyName,'')
  585:      , [Line1]=''
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  576:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  577:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  601:              AND [edh].PayrollPeriodEndDate = [hd].PayrollPeriodEndDate
  602:                  LEFT JOIN TimeCurrent..tblAgencies ag
  603:              ON  [edh].Client = [ag].Client
  604:              AND [edh].GroupCode = [ag].GroupCode
  605:                          AND en.AgencyNo=ag.Agency
  606:          INNER JOIN [TimeHistory].dbo.tblEmplNames AS enh
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  581:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  582:                                                  AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  583:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  610:              AND [enh].[PayrollPeriodEndDate] = [hd].[PayrollPeriodEndDate]
  611:                                                  --AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  612:          INNER JOIN TimeCurrent.dbo.tblAdjCodes AS ac
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  614:      , ac.AdjustmentType 
  616:  DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  643:      , ac.AdjustmentType 
  644:      , ISNULL(ag.AgencyName,'') 
  646:  DELETE FROM #tmpExport WHERE PayAmount = 0.0 AND BillAmount = 0.0 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  688:      , 'U'
  689:      , [Line1]=''
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  718:      , 'U'
  719:          , AgencyName=ISNULL(ag.AgencyName,'')
  720:      , [Line1]=''
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  701:              AND [enh].[PayrollPeriodEndDate] = [udf].[PayrollPeriodEndDate]
  702:                                                  AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  703:          LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed WITH (NOLOCK)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  732:              AND [enh].[PayrollPeriodEndDate] = [udf].[PayrollPeriodEndDate]
  733:                                                  --AND isnull([ENH].PayRecordsSent,'1/1/1970') = '1/1/1970' 
  734:                  LEFT JOIN TimeCurrent..tblAgencies ag
  735:              ON  [enh].Client = [ag].Client
  736:              AND [enh].GroupCode = [ag].GroupCode
  737:                          AND en.AgencyNo=ag.Agency
  738:          LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts AS ed WITH (NOLOCK)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  741:      , [udf].[TransDate]
  743:  END
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  776:      , [udf].[TransDate]
  777:          , ISNULL(ag.AgencyName,'')
  778:  END
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  787:              + SourceTime   + @Delim
  788:              + SourceApprove
  790:  UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  822:              + SourceTime   + @Delim
  823:              + SourceApprove + @Delim
  824:                          + AgencyName 
  826:  UPDATE #tmpExport  SET EmployeeID = '' WHERE AssignmentNo = 'MISSING'
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_EVOL.sql
  794:  'FirstName|LastName|EmplID|Assignment|WeekEnding|TransDate|PayCode|PayAmt|BillAmt|Project|ApprName|ApprEmail|ApprDate|PayGroup|
  795:  TimeSource|ApprSource')
  797:  SELECT * FROM #tmpExport 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_EVOL.SQL
  830:  'FirstName|LastName|EmplID|Assignment|WeekEnding|TransDate|PayCode|PayAmt|BillAmt|Project|ApprName|ApprEmail|ApprDate|PayGroup|
  831:  TimeSource|ApprSource|AgencyName')
  833:  SELECT * FROM #tmpExport 
*****

