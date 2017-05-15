Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
    6:      )
    7:  AS 
    8:  /* Declare Local variables */
    9:      DECLARE @RecordID INT
   10:      DECLARE @Intime DATETIME
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
    6:      )
    7:  AS /* Declare Local variables */
    8:      DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
    9:      DECLARE @Intime DATETIME
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
   34:      SET @recordIDList = ''
   36:                  DECLARE @PPED1 DATETIME
   37:                  SET @PPED1 = DATEADD(DAY,-7, @PayrollPeriodEndDate)
   40:          SELECT  Distinct t.GroupCode ,
   41:                  t.SiteNo ,
   42:                  t.SSN
   43:                                  FROM TimeHistory..tblTimeHistDetail AS t WITH (NOLOCK)
   44:                                  INNER JOIN Timecurrent..tblClientGroups AS g
   45:                                  ON g.client = t.Client
   46:                                  AND g.groupcode = t.GroupCode
   47:                                  AND g.RecordStatus = '1'
   48:                                  INNER JOIN TimeHistory..tblPeriodEndDates AS p
   49:                                  ON p.client = t.Client
   50:                                  AND p.groupcode = t.GroupCode
   51:                                  AND p.PayrollPeriodEndDate = t.PayrollPeriodEndDate
   52:                                  AND p.status <> 'C'
   53:                                  WHERE t.Client = @Client
   54:                                  AND t.PayrollPeriodEndDate IN(@PayrollPeriodEndDate, @PPED1)
   55:                                  AND (t.InDay > 7 OR t.OutDay > 7 )
   57:      DECLARE outerCursor CURSOR STATIC
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
   33:      SET @recordIDList = ''
   34:      /*Outer cursor gets list of employees in all sites for that payweek,
   35:        reason is to avoind hittting THD without all its 4 indices
   36:        with this cursor we can select from THD with C,G,P,SSN
   39:        SELECT  Distinct SN.GroupCode ,
   40:                sn.SiteNo ,
   41:                ES.SSN
   42:        FROM    TimeCurrent..tblSiteNames AS SN with (nolock)
   43:        INNER JOIN TimeHistory..tblPeriodEndDates AS PED
   44:          ON PED.Client = SN.Client
   45:          AND PED.GroupCode = SN.GroupCode
   46:          AND PED.PayrollPeriodenddate = @PayrollPeriodEndDate
   47:          AND PED.Status <> 'C'
   48:        INNER JOIN TimeHistory..tblEmplSites AS ES with (nolock)
   49:          ON es.Client = SN.Client 
   50:           AND es.GroupCode = SN.Groupcode 
   51:           AND es.SiteNo = SN.SiteNo
   52:           AND es.Payrollperiodenddate = @PayrollPeriodEndDate
   53:        INNER Join TimeHistory..tblEmplNames as enh with (nolock)
   54:          on enh.Client = es.Client
   55:          and enh.Groupcode = es.groupcode
   56:          and enh.payrollperiodenddate = es.payrollperiodenddate
   57:          and enh.SSN = es.SSN
   58:          --and isnull(enh.MissingPunch,'0') <> '0'
   59:        Inner Join TimeHistory..tblTimeHistDetail as t with (nolock)
   60:          on t.client = es.Client
   61:          and t.groupcode = es.groupcode
   62:          and t.Payrollperiodenddate = @PayrollPeriodEndDate
   63:          and t.ssn = es.SSN
   64:          and t.siteno = es.siteno
   65:          and (t.Inday = 10 or t.outday = 10)
   66:        Where SN.Client = @Client
   67:  */
   69:      DECLARE outerCursor CURSOR STATIC
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
   58:      FOR
   59:          SELECT  Distinct t.GroupCode ,
   60:                  t.SiteNo ,
   61:                  t.SSN,
   62:                                                                  t.PayrollPeriodEndDate
   63:                                  FROM TimeHistory..tblTimeHistDetail AS t WITH (NOLOCK)
   64:                                  INNER JOIN Timecurrent..tblClientGroups AS g
   65:                                  ON g.client = t.Client
   66:                                  AND g.groupcode = t.GroupCode
   67:                                  AND g.RecordStatus = '1'
   68:                                  INNER JOIN TimeHistory..tblPeriodEndDates AS p
   69:                                  ON p.client = t.Client
   70:                                  AND p.groupcode = t.GroupCode
   71:                                  AND p.PayrollPeriodEndDate = t.PayrollPeriodEndDate
   72:                                  AND p.status <> 'C'
   73:                                  WHERE t.Client = @Client
   74:                                  AND t.PayrollPeriodEndDate IN(@PayrollPeriodEndDate, @PPED1)
   75:                                  AND (t.InDay > 7 OR t.OutDay > 7 )
   77:      OPEN outerCursor   
   78:      FETCH NEXT FROM outerCursor INTO @Groupcode, @SiteNo, @SSN, @PayrollPeriodEndDate
   80:      WHILE @@FETCH_STATUS = 0 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
   70:      FOR
   71:          SELECT  Distinct SN.GroupCode ,
   72:                  sn.SiteNo ,
   73:                  ES.SSN
   74:          FROM    TimeCurrent..tblSiteNames AS SN with (nolock)
   75:          INNER JOIN TimeHistory..tblPeriodEndDates AS PED
   76:            ON PED.Client = SN.Client
   77:            AND PED.GroupCode = SN.GroupCode
   78:            AND PED.PayrollPeriodenddate = @PayrollPeriodEndDate
   79:            AND PED.Status <> 'C'
   80:          INNER JOIN TimeHistory..tblEmplSites AS ES with (nolock)
   81:            ON es.Client = SN.Client 
   82:             AND es.GroupCode = SN.Groupcode 
   83:             AND es.SiteNo = SN.SiteNo
   84:             AND es.Payrollperiodenddate = @PayrollPeriodEndDate
   85:          INNER Join TimeHistory..tblEmplNames as enh with (nolock)
   86:            on enh.Client = es.Client
   87:            and enh.Groupcode = es.groupcode
   88:            and enh.payrollperiodenddate = es.payrollperiodenddate
   89:            and enh.SSN = es.SSN
   90:            --and isnull(enh.MissingPunch,'0') <> '0'
   91:          Inner Join TimeHistory..tblTimeHistDetail as t with (nolock)
   92:            on t.client = es.Client
   93:            and t.groupcode = es.groupcode
   94:            and t.Payrollperiodenddate = @PayrollPeriodEndDate
   95:            and t.ssn = es.SSN
   96:            and t.siteno = es.siteno
   97:            and (t.Inday = 10 or t.outday = 10)
   98:          Where SN.Client = @Client
   99:  --        and SN.GroupCOde = @GroupCode
  100:          --and SN.TimeZone = @TimeZone
  102:      OPEN outerCursor   
  103:      FETCH NEXT FROM outerCursor INTO @Groupcode, @SiteNo, @SSN
  105:      WHILE @@FETCH_STATUS = 0 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
   92:                  FROM    TimeHistory..tblTimeHistDetail AS THTD with(nolock)
   93:                  WHERE   THTD.Client = @Client
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
  117:                  FROM    TimeHistory..tblTimeHistDetail AS THTD with(nolock)
  118:                  INNER JOIN TimeHistory..tblEmplNames AS EN
  119:                  ON      THTD.Client = EN.Client
  120:                          AND THTD.GroupCode = EN.GroupCode
  121:                          AND THTD.SSN = EN.SSN
  122:                          AND THTD.PayrollPeriodEndDate = EN.PayrollPeriodEndDate
  123:                          AND EN.MissingPunch = '1'
  124:                  WHERE   THTD.Client = @Client
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
   97:                          AND THTD.PayrollPeriodEndDate = @PayrollPeriodEndDate
   98:                          AND (THTD.InDay > 7 OR THTD.OutDay > 7)
  100:              OPEN cVoidCursor   
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
  128:                          AND THTD.PayrollPeriodEndDate = @PayrollPeriodEndDate
  129:                          AND (THTD.InDay = 10 OR THTD.OutDay = 10)
  131:              OPEN cVoidCursor   
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
  237:                      IF @Intime = @NULL_TIME
  238:                          AND @InDay > 7
  239:                          BEGIN
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
  268:                      IF @Intime = @NULL_TIME
  269:                          AND @InDay = 10 
  270:                          BEGIN
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
  257:                      IF @Outtime = @NULL_TIME
  258:                          AND @OutDay > 7 
  259:                          BEGIN
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
  288:                      IF @Outtime = @NULL_TIME
  289:                          AND @OutDay = 10 
  290:                          BEGIN
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
  320:                -------------------------------------------------------------------------------------------------
  322:              FETCH NEXT FROM outerCursor INTO @groupcode, @SiteNo, @SSN,@PayrollPeriodEndDate
  323:          END   
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
  351:                -------------------------------------------------------------------------------------------------
  353:              FETCH NEXT FROM outerCursor INTO @groupcode, @SiteNo, @SSN
  354:          END   
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_VoidMissingPunches_Void_ALL.sql
  333:          @RecordIDList ,
  334:          'AFTER',
  335:                                  @Client 
  338:      ERR_HANDLER:
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_VOIDMISSINGPUNCHES_VOID_ALL.SQL
  364:          @RecordIDList ,
  365:          'AFTER'
  368:      ERR_HANDLER:
*****

