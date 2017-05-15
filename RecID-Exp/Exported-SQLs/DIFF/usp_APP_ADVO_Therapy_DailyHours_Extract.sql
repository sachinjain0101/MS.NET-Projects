Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_ADVO_Therapy_DailyHours_Extract.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_ADVO_THERAPY_DAILYHOURS_EXTRACT.SQL
Resync Failed.  Files are too different.
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_ADVO_Therapy_DailyHours_Extract.sql
    1:  CREATE Procedure [dbo].[usp_APP_ADVO_Therapy_DailyHours_Extract] 
    2:  (
    3:          @Client char(4) = 'ADVO',
    4:          @GroupCode int = 0,
    5:          @PPED2 datetime = '1/1/2000'
    6:  )
    7:  AS
   10:  SET NOCOUNT ON
   12:  DECLARE @Group int
   13:  DECLARE @PPED datetime
   14:  DECLARE @StartDate datetime
   15:  Set @Startdate = convert(varchar(12), getdate(), 101 )
   16:  Set @StartDate = dateadd(day,-15,@StartDate)
   19:  Create Table #tmpOut
   20:  (
   21:    GroupCode int,
   22:    SSN int,
   23:    HomeFacility varchar(20),
   24:    EmplID varchar(20),
   25:    Dept varchar(20),
   26:    TransDate datetime,
   27:    AdjCode varchar(20),
   28:    Hours numeric(9,2),
   29:    BorrowedFacility varchar(20)
   30:  )
   32:  DECLARE cGroups CURSOR
   33:  READ_ONLY
   34:  FOR 
   35:  select GroupCode, PayrollPeriodenddate 
   36:  from TimeHistory..tblPeriodenddates 
   37:  where client = 'ADVO' 
   38:  and PayrollPeriodenddate >= @StartDate --dateadd(day, -15, getdate() )
   39:  AND groupcode <> 730053
   41:  OPEN cGroups
   43:  FETCH NEXT FROM cGroups INTO @Group, @PPED
   44:  WHILE (@@fetch_status <> -1)
   45:  BEGIN
   46:          IF (@@fetch_status <> -2)
   47:          BEGIN
   48:      --EXEC usp_APP_PRECHECK_Upload @Client, @Group, @PPED, 'N'
   49:      --if @@error <> 0 
   50:      --  return
   52:      SELECT      thd.Groupcode, thd.ssn,
   53:          HomeFacility = sn.ClientFacility,
   54:          en.AssignmentNo,
   55:          Dept = left(cd.ClientDeptCode,4), -- substring(cd.ClientDeptCode, 1,2) as Dept,
   56:          cast(ua.ADP_HoursCode as varchar(20) ) as UploadAdjustmentCode,
   57:          CASE WHEN thd.ClockAdjustmentNo in ('1', '8', '', NULL) then '1'
   58:                          ELSE thd.ClockAdjustmentNo END ClockadjustmentNo,
   59:        AdjCode = thd.ClockAdjustmentNo,
   60:          thd.Hours,
   61:          thd.RegHours,
   62:          thd.OT_Hours,
   63:        thd.RecordID,
   64:        thd.TransDate,
   65:        InDateTime = dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime),
   66:            BorrowedGroup = thd.CrossoverOtherGroup,
   67:        BorrowedFacility = sn.ClientFacility -- Default it to the home facility
   68:      INTO #advoTemp      
   69:      FROM tblTimeHistDetail thd with (nolock)
   70:      INNER JOIN TimeCurrent..tblEmplNames en with (nolock)
   71:      ON en.client = thd.client
   72:      AND en.groupCode = thd.groupCode
   73:      AND en.ssn = thd.ssn
   74:      --AND en.recordStatus = '1'
   75:      INNER JOIN TimeCurrent..tblSiteNames sn with (nolock)
   76:      ON sn.client = thd.client
   77:      AND sn.groupCode = thd.groupCode
   78:      AND sn.siteNo = thd.siteNo
   79:      --AND sn.recordStatus = '1'
   80:      INNER JOIN TimeCurrent..tblGroupDepts cd with (nolock)
   81:      ON cd.client = thd.client
   82:      AND cd.groupCode = thd.groupCode
   83:      AND cd.deptNo = thd.deptNo
   84:      --AND cd.recordStatus = '1'
   85:      INNER JOIN TimeCurrent..tblAdjCodes ua with (nolock)
   86:      ON ua.client = thd.client
   87:      AND ua.groupCode = thd.groupCode
   88:      AND ua.clockAdjustmentNo = CASE WHEN thd.clockAdjustmentNo IN ('1', '8', '', 'S', NULL) THEN '1'
   89:                                  ELSE thd.clockAdjustmentNo END
   90:      --AND ua.recordStatus = '1'
   91:      WHERE thd.client = @client
   92:      AND thd.groupCode = @group
   93:      AND thd.PayrollPeriodEndDate = @PPED
   94:      AND thd.TransDate >= @StartDate
   95:      --and substring(cd.ClientDeptCode, 1,4) in('6505','6506','6510','7005','7006','7505','7506','7510','8005','8006')
   97:          UPDATE #advoTemp
   98:          SET #advoTemp.BorrowedFacility = sn.ClientFacility
   99:          FROM #advoTemp
  100:          INNER Join TimeCurrent..tblSiteNames sn
  101:          ON #advoTemp.BorrowedGroup = sn.GroupCode
  102:          WHERE sn.Client = @Client
  103:      AND isNull(ClientFacility,'') <> ''
  105:   /*   
  106:      Update #advoTemp
  107:        Set #advoTemp.TherapySite = case when isNULL(rc.ReasonCode,'') in('','1') then '--' else rc.ReasonDescription end
  108:      from #advoTemp
  109:      Left Join TimeHistory..tblTimeHistDetail_Reasons as tr1 with (nolock)
  110:      on tr1.Client = @Client
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_ADVO_THERAPY_DAILYHOURS_EXTRACT.SQL
    1:  Create PROCEDURE  usp_APP_ADVO_Therapy_Actual_DailyHours_Extract
    2:   @client VARCHAR(4)
    3:  , @GroupCode INT 
    4:  , @PayrollPeriodEndDate datetime
    5:  AS
    6:  SET NOCOUNT ON ;
    7:  --SET STATISTICS IO,TIME Off;
    8:  SET @GroupCode =0
    9:  --DECLARE @client VARCHAR(4) = 'advo'
   10:  --, @GroupCode INT =0
   11:  --, @PayrollPeriodEndDate datetime = '1/1/2000'
   14:    DECLARE @Group INT;
   15:      DECLARE @PPED VARCHAR (100);
   16:      DECLARE @StartDate DATETIME;
   17:      SET @StartDate = CONVERT(VARCHAR(12), GETDATE(), 101);
   18:      SET @StartDate = DATEADD(month, -1, @StartDate);
   20:           SELECT   @PPED =  MIN(PayrollPeriodEndDate)
   21:          FROM    TimeHistory..tblPeriodEndDates  
   22:          WHERE   Client = 'ADVO' AND PayrollPeriodEndDate >= @StartDate --dateadd(day, -15, getdate() )
   23:                  AND GroupCode  <> 730053
   25:          --SELECT transdate,inday,THD.OutDay,DATEPART(WEEKDAY, thd.TransDate),* 
   26:          --                                      FROM Timehistory.dbo.tblTimeHistDetail THD WITH(NOLOCK) 
   27:          --                                      WHERE thd.Client = 'ADVO' AND THD.GroupCode <> 730053 
   28:          --                                      --AND THD.TransDate = DATEADD(DAY, -7,thd.PayrollPeriodEndDate)
   29:          --                                      AND outday > DATEPART(WEEKDAY, thd.TransDate)
   30:          --                                       AND thd.PayrollPeriodEndDate = @PPED AND thd.TransDate >= @StartDate;
   34:  --SELECT @PPED
   35:  BEGIN TRY DROP TABLE #splits END TRY BEGIN CATCH END CATCH
   36:  DECLARE @datatable AS TABLE
   37:                                                          ( THD_RecordID BIGINT  --< THD_RecordID data type is converted from INT
   38:   to BIGINT by Srinsoft on 29July2016 >--
   39:                                                           , client VARCHAR(4)
   40:                                                          , Groupcode INT
   41:                                                          , SSN VARCHAR(50)
   42:                                                          , siteno INT
   43:                                                          , deptno INT
   44:                                                          , Transdate DATETIME
   45:                                                          , PPED datetime
   46:                                                          , inday INT
   47:                                                          , intime DATETIME
   48:                                                          , endofday DATETIME
   49:                                                          , startofday DATETIME
   50:                                                          , outday INT
   51:                                                          , outime DATETIME
   52:                                                          , ClockAdjustmentNo VARCHAR(3)
   53:                                                          ,reghrs NUMERIC
   54:                                                          ,ot_hrs NUMERIC
   55:                                                          ,new_reghours NUMERIC   
   56:                                                          ); 
   58:  INSERT  INTO @datatable
   59:          ( THD_RecordID
   60:          , client
   61:          , Groupcode
   62:          , SSN
   63:          , siteno
   64:          , deptno
   65:          , Transdate
   66:          , PPED
   67:          , inday
   68:          , intime
   69:          , endofday
   70:          , startofday
   71:          , outday
   72:          , outime
   73:          , ClockAdjustmentNo
   74:                  ,reghrs
   75:                  ,ot_hrs
   76:                  ,new_reghours )
   77:          SELECT  THD.RecordID
   78:                , THD.Client
   79:                , THD.GroupCode
   80:                , THD.SSN
   81:                , THD.SiteNo
   82:                , THD.DeptNo
   83:                , THD.TransDate
   84:                , THD.PayrollPeriodEndDate
   85:                , THD.InDay
   86:                , INTIME = DATEADD(DAY, 2, THD.TransDate) + CAST(THD.InTime AS DATETIME)
   87:                , Endofday = THD.TransDate + CAST('23:59:59' AS DATETIME)
   88:                , StartofDay = DATEADD(DAY, 1, THD.TransDate)
   89:                , THD.OutDay
   90:                , outime = DATEADD(DAY, 3, THD.TransDate) + CAST(THD.OutTime AS DATETIME)
   91:                , THD.ClockAdjustmentNo
   92:                            , thd.RegHours
   93:                            , thd.OT_Hours
   94:                            , 0.00
   95:          FROM    TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK )
   96:          WHERE   Client = @client --
   97:                  AND THD.GroupCode <> 730053--
   98:                  AND THD.InDay <> THD.OutDay --
   99:                  AND THD.AdjustmentName NOT IN ( 'Salary', 'Break' ) --
  100:                  AND THD.PayrollPeriodEndDate >= @PPED --@PayrollPeriodEndDate
  101:                  AND THD.TransDate >= @StartDate AND THD.TransDate <= DATEADD(DAY, -1, GETDATE())--
  102:                  --AND thd.outday<> 0
  103:                  AND THD.TransType <> 7--
  104:                  AND Hours <> 0--
  105:                  AND THD.PayrollPeriodEndDate <> THD.TransDate --handled later in order to pull in the payperiod transacation da
  106:  y before the range
  107:  ;WITH splittime AS (
  108:  --Collect the time for the inday
*****

