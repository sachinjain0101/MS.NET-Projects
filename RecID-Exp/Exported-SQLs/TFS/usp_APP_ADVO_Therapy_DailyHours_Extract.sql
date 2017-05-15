Create PROCEDURE  usp_APP_ADVO_Therapy_Actual_DailyHours_Extract
 @client VARCHAR(4)
, @GroupCode INT 
, @PayrollPeriodEndDate datetime
AS
SET NOCOUNT ON ;
--SET STATISTICS IO,TIME Off;
SET @GroupCode =0
--DECLARE @client VARCHAR(4) = 'advo'
--, @GroupCode INT =0
--, @PayrollPeriodEndDate datetime = '1/1/2000'


  DECLARE @Group INT;
    DECLARE @PPED VARCHAR (100);
    DECLARE @StartDate DATETIME;
    SET @StartDate = CONVERT(VARCHAR(12), GETDATE(), 101);
    SET @StartDate = DATEADD(month, -1, @StartDate);

	 SELECT   @PPED =  MIN(PayrollPeriodEndDate)
        FROM    TimeHistory..tblPeriodEndDates  
        WHERE   Client = 'ADVO' AND PayrollPeriodEndDate >= @StartDate --dateadd(day, -15, getdate() )
                AND GroupCode  <> 730053
	
	--SELECT transdate,inday,THD.OutDay,DATEPART(WEEKDAY, thd.TransDate),* 
	--					FROM Timehistory.dbo.tblTimeHistDetail THD WITH(NOLOCK) 
	--					WHERE thd.Client = 'ADVO' AND THD.GroupCode <> 730053 
	--					--AND THD.TransDate = DATEADD(DAY, -7,thd.PayrollPeriodEndDate)
	--					AND outday > DATEPART(WEEKDAY, thd.TransDate)
	--					 AND thd.PayrollPeriodEndDate = @PPED AND thd.TransDate >= @StartDate;
	
	
				
--SELECT @PPED
BEGIN TRY DROP TABLE #splits END TRY BEGIN CATCH END CATCH
DECLARE @datatable AS TABLE
							( THD_RecordID BIGINT  --< THD_RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
							 , client VARCHAR(4)
							, Groupcode INT
							, SSN VARCHAR(50)
							, siteno INT
							, deptno INT
							, Transdate DATETIME
							, PPED datetime
							, inday INT
							, intime DATETIME
							, endofday DATETIME
							, startofday DATETIME
							, outday INT
							, outime DATETIME
							, ClockAdjustmentNo VARCHAR(3)
							,reghrs NUMERIC
							,ot_hrs NUMERIC
							,new_reghours NUMERIC	
							); 

INSERT  INTO @datatable
        ( THD_RecordID
        , client
        , Groupcode
        , SSN
        , siteno
        , deptno
        , Transdate
        , PPED
        , inday
        , intime
        , endofday
        , startofday
        , outday
        , outime
        , ClockAdjustmentNo
		,reghrs
		,ot_hrs
		,new_reghours )
        SELECT  THD.RecordID
              , THD.Client
              , THD.GroupCode
              , THD.SSN
              , THD.SiteNo
              , THD.DeptNo
              , THD.TransDate
              , THD.PayrollPeriodEndDate
              , THD.InDay
              , INTIME = DATEADD(DAY, 2, THD.TransDate) + CAST(THD.InTime AS DATETIME)
              , Endofday = THD.TransDate + CAST('23:59:59' AS DATETIME)
              , StartofDay = DATEADD(DAY, 1, THD.TransDate)
              , THD.OutDay
              , outime = DATEADD(DAY, 3, THD.TransDate) + CAST(THD.OutTime AS DATETIME)
              , THD.ClockAdjustmentNo
			  , thd.RegHours
			  , thd.OT_Hours
			  , 0.00
        FROM    TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK )
        WHERE   Client = @client --
                AND THD.GroupCode <> 730053--
                AND THD.InDay <> THD.OutDay --
                AND THD.AdjustmentName NOT IN ( 'Salary', 'Break' ) --
                AND THD.PayrollPeriodEndDate >= @PPED --@PayrollPeriodEndDate
                AND THD.TransDate >= @StartDate AND THD.TransDate <= DATEADD(DAY, -1, GETDATE())--
		--AND thd.outday<> 0
                AND THD.TransType <> 7--
                AND Hours <> 0--
                AND THD.PayrollPeriodEndDate <> THD.TransDate --handled later in order to pull in the payperiod transacation day before the range
;WITH splittime AS (
--Collect the time for the inday
						SELECT THD_RecordID,Client
							 , GroupCode
							 , SSN
							 , siteno
							 , deptno
							 , TransDate
							 , ClockAdjustmentNo
							 , hours =(DATEDIFF(SECOND,intime,endofday)/60.0)/60.00
							 , origin = 'INDAY'
						FROM @datatable

			UNION ALL 
--Collect the time for the outday

						SELECT THD_RecordID, Client
							 , GroupCode
							 , SSN
							 , siteno
							 , deptno
							 , TransDate = DATEADD(DAY ,1,TransDate)
							 , ClockAdjustmentNo
							 , hours =(DATEDIFF(SECOND,StartofDay,outime )/60.0)/60.00
							 , 'OUTDAY'
						FROM @datatable

			UNION ALL 
-- add back in the breaks

						SELECT THD.RecordID, THD.client
							  ,THD.GroupCode
							  ,THD.ssn
							  ,THD.siteno
							  ,THD.DeptNo
							  ,THD.TransDate
							  ,THD.ClockAdjustmentNo
							  ,THD.Hours 
							  ,'Breaks'
						FROM Timehistory.dbo.tblTimeHistDetail THD  WITH (NOLOCK)
						WHERE client = @client
						AND THD.GroupCode <> 730053
						AND THD.AdjustmentName ='BREAK'
						AND THD.PayrollPeriodEndDate >= @PPED
						AND THD.TransType <> 7
						AND thd.Hours <> 0
						AND thd.TransDate BETWEEN @StartDate AND  DATEADD(DAY,-1,GETDATE())
			UNION ALL 
-- add in time that was checked in and out on the same day 

						SELECT THD.RecordID,client
						,THD.GroupCode
						,THD.SSN
						,thd.SiteNo
						,THD.DeptNo
						,TransDate = IIF(DATEPART(WEEKDAY,THD.TransDate) = THD.InDay,THD.TransDate,DATEADD(DAY,1,THD.TransDate))
						,THD.ClockAdjustmentNo
						,THD.Hours
						,'SameDay'
						FROM Timehistory.dbo.tblTimeHistDetail THD   WITH (NOLOCK)
						WHERE client = @client 
							AND THD.GroupCode <> 730053
							AND THD.PayrollPeriodEndDate >= @PPED
							AND THD.InDay = THD.OutDay 
							AND THD.AdjustmentName NOT IN ('Break','salary')
							AND THD.TransType <>7
							AND thd.hours <> 0
							AND thd.TransDate BETWEEN @StartDate AND  DATEADD(DAY,-1,GETDATE())
			
			UNION ALL 
--crossover out day 
						SELECT  THD.RecordID,THD.client
								,THD.GroupCode
								,THD.SSN
								,thd.SiteNo
								,THD.DeptNo
							  , TransDate = DATEADD(DAY, 1, THD.TransDate)
							  ,THD.ClockAdjustmentNo
							  , Hours = ( DATEDIFF(SECOND, IIF(THD.InDay = DATEPART(WEEKDAY, THD.TransDate), '1899-12-30 00:00:00.000', THD.InTime), THD.OutTime) / 60.0 ) / 60.0
							  ,'PriorPayPeriod_Outday'
						FROM    TimeHistory.dbo.tblPeriodEndDates WITH ( NOLOCK )
						INNER JOIN TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK ) ON tblPeriodEndDates.Client = THD.Client AND THD.GroupCode = dbo.tblPeriodEndDates.GroupCode AND dbo.tblPeriodEndDates.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
						WHERE   tblPeriodEndDates.Client = 'ADVO' 
								AND dbo.tblPeriodEndDates.PayrollPeriodEndDate >= @StartDate 
								AND dbo.tblPeriodEndDates.GroupCode <> 730053 
								AND THD.TransDate >= @StartDate AND thd.Transdate <= DATEADD(DAY,-1,GETDATE())
								AND dbo.tblPeriodEndDates.PayrollPeriodEndDate = THD.TransDate 
								AND ( THD.OutDay > DATEPART(WEEKDAY, THD.TransDate) and THD.InDay = DATEPART(WEEKDAY, THD.TransDate) ) 
							    AND THD.Hours <> 0

			UNION ALL 
-- cross over inday 
			
						SELECT THD.RecordID, THD.client
								,THD.GroupCode
								,THD.SSN
								,thd.SiteNo
								,THD.DeptNo
							  , TransDate 
							  ,THD.ClockAdjustmentNo
							  , Hours = ( DATEDIFF(SECOND, DATEADD(DAY,2,THD.InTime), CAST('1899-12-30 23:59:59.999'AS TIME)) / 60.0 ) / 60.0
							  ,'PriorPayPeriod_inDay'
						FROM    TimeHistory..tblPeriodEndDates WITH ( NOLOCK )
						INNER JOIN TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK ) ON tblPeriodEndDates.Client = THD.Client AND THD.GroupCode = dbo.tblPeriodEndDates.GroupCode AND dbo.tblPeriodEndDates.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
						WHERE   tblPeriodEndDates.Client = 'ADVO' 
								AND dbo.tblPeriodEndDates.PayrollPeriodEndDate >= @StartDate 
								AND dbo.tblPeriodEndDates.GroupCode <> 730053 
								AND THD.TransDate >= @StartDate AND thd.Transdate <= DATEADD(DAY,-1,GETDATE())
								AND dbo.tblPeriodEndDates.PayrollPeriodEndDate = THD.TransDate 
								AND THD.Hours <> 0
								AND THD.InDay = DATEPART(WEEKDAY, THD.TransDate)
								AND THD.OutDay > DATEPART(WEEKDAY, THD.TransDate)


					UNION ALL 
--add in Salary Pay
						SELECT THD.RecordID,client
						,THD.GroupCode
						,THD.SSN
						,thd.SiteNo
						,THD.DeptNo
						,THD.TransDate
						,THD.ClockAdjustmentNo
						,THD.Hours
						,'Salary'
						FROM Timehistory.dbo.tblTimeHistDetail THD   WITH (NOLOCK)
						WHERE client = @client 
							AND THD.GroupCode <> 730053
							AND THD.PayrollPeriodEndDate >= @PPED
							AND THD.AdjustmentName  ='salary'
							AND thd.TransDate BETWEEN @StartDate AND  DATEADD(DAY,-1,GETDATE())

						),
						

--SELECT * FROM splittime

THDReg AS (		
				SELECT TOP 9000000
						 THD_RecordID
						, r.client
						, r.Groupcode
						, r.SSN
						, Dept = LEFT(cd.ClientDeptCode, 4)
						, sn.ClientFacility
						, en.AssignmentNo
						, r.siteno
						, r.deptno
						, Transdate = FORMAT(r.Transdate,'MM/dd/yyyy')
						, UploadAdjustmentCode = CAST(ua.ADP_HoursCode AS VARCHAR(20))
						, ClockadjustmentNo =  CASE WHEN thd.ClockAdjustmentNo IN ( '1', '8', '', 'S', NULL ) THEN '1' ELSE thd.ClockAdjustmentNo end
						, hours = CAST(ROUND(r.hours,2) AS NUMERIC(9,2))
						, thd.RegHours
						, thd.OT_Hours
						, New_Reghours = CAST(ROUND(IIF(r.origin ='Sameday' OR r.origin= 'Breaks'
														,thd.RegHours
														,IIF(THD.RegHours > r.hours
																,r.hours
																,thd.RegHours
															)
														),2
													) AS NUMERIC(9,2)
											  )
						, TherapySite =  CASE WHEN ISNULL(rc.ReasonCode, '') IN ( '', '1' ) THEN ClientFacility ELSE rc.ReasonDescription END
						, r.origin
				FROM splittime r
				INNER JOIN TimeCurrent.dbo.tblEmplNames en WITH ( NOLOCK ) ON en.Client = r.Client AND en.GroupCode = r.GroupCode AND en.SSN = r.SSN AND en.RecordStatus = '1'
				INNER JOIN TimeCurrent.dbo.tblSiteNames sn WITH ( NOLOCK ) ON sn.Client = r.Client AND sn.GroupCode = r.GroupCode AND sn.SiteNo = r.SiteNo
				INNER JOIN TimeCurrent.dbo.tblGroupDepts cd WITH ( NOLOCK ) ON cd.Client = r.Client AND cd.GroupCode = r.GroupCode AND cd.DeptNo = r.DeptNo
				LEFT outer JOIN TimeCurrent.dbo.tblAdjCodes ua WITH ( NOLOCK ) ON ua.Client = r.Client AND ua.GroupCode = r.GroupCode AND ua.ClockAdjustmentNo = CASE WHEN r.ClockAdjustmentNo IN ( '1', '8', '', 'S', NULL ) THEN '1' ELSE r.ClockAdjustmentNo END
				inner JOIN Timehistory.dbo.tblTimeHistDetail THD WITH (NOLOCK) ON thd.RecordID = r.THD_RecordID AND r.client = thd.client AND THD.GroupCode = r.Groupcode AND thd.SiteNo = r.siteno AND thd.DeptNo = r.deptno AND thd.PayrollPeriodEndDate <= GETDATE() AND thd.SSN = r.SSN
				LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_Reasons AS tr1 WITH ( NOLOCK ) ON tr1.Client = thd.Client AND tr1.GroupCode = thd.GroupCode AND tr1.PPED = @PPED AND tr1.SSN =  thd.SSN AND tr1.AdjustmentRecordID = thd.RecordID
                LEFT JOIN TimeCurrent.dbo.tblReasonCodes AS rc WITH ( NOLOCK ) ON rc.Client = tr1.Client AND rc.GroupCode = tr1.GroupCode AND rc.ReasonCodeID = tr1.ReasonCodeID
				--WHERE r.Transdate >= @StartDate  AND r.Transdate <= DATEADD(DAY,-1,GETDATE())--IN('2016-02-11','2016-02-10','2016-02-12') AND r.SSN = 15406900
				--ORDER BY r.THD_RecordID,r.client,r.Groupcode,r.SSN,r.siteno,r.deptno,r.Transdate,r.ClockAdjustmentNo
			) 
		--		SELECT *FROM THDReg
		,
OTHrs AS (
			SELECT THD_RecordID
				 , client
				 , Groupcode
				 , SSN
				 , Dept
				 , ClientFacility
				 , AssignmentNo
				 , siteno
				 , deptno
				 , Transdate
				 , UploadAdjustmentCode
				 , ClockadjustmentNo
				 , hours
				 , RegHours
				 , OT_Hours
				 , New_Reghours
				 , New_OT_Hours = IIF( THDReg.OT_Hours > 0 AND  hours -THDReg.RegHours > 0 ,hours - THDReg.RegHours,0)
				 , TherapySite
				 , origin  
			FROM THDReg
			WHERE Transdate >= @StartDate
),

Final AS (
SELECT THDReg.THD_RecordID ,
     THDReg.client,
      THDReg.Groupcode
     , THDReg.SSN
     , THDReg.ClientFacility
	 , EmplID = THDReg.AssignmentNo
     , THDReg.Dept
     , THDReg.Transdate
	 , THDReg.UploadAdjustmentCode
	 , ADJcode = THDReg.ClockadjustmentNo
     , Hours = THDReg.New_Reghours
     , WorkedSite = THDReg.TherapySite
FROM THDReg

UNION ALL 
SELECT OTHrs.THD_RecordID ,
       OTHrs.client
     , OTHrs.Groupcode
     , OTHrs.SSN
	 , OTHrs.ClientFacility
     , OTHrs.AssignmentNo
     , OTHrs.Dept
     , OTHrs.Transdate
	 , '02'
	 , '02'
     , OTHrs.New_OT_Hours
     , OTHrs.TherapySite
  FROM OTHrs
 
  ) 

  SELECT   Final.Groupcode
       , Final.SSN
       , Final.ClientFacility
       , Final.EmplID
       , Final.Dept
       , Final.Transdate
	   , AdjCode =  Final.UploadAdjustmentCode
       , Hours =SUM(Final.Hours)
       , Final.WorkedSite 
	   , LineOut = '"' + ClientFacility + '",' + '"' + EmplID + '",' + '"' + Dept + '",' + '"' + WorkedSite + '",' + '"' + TransDate + '",' + RTRIM(LTRIM(SUM(Final.Hours))) + ',' + '"' + LTRIM(RTRIM(Final.UploadAdjustmentCode)) + '"'
	   FROM final 
	 
	   --WHERE SSN = 416213322
	   GROUP BY  Final.Groupcode
       , Final.SSN
       , Final.ClientFacility
       , Final.EmplID
       , Final.Dept
       , Final.Transdate 
	   , Final.UploadAdjustmentCode
       , Final.WorkedSite 
	   HAVING SUM(final.hours) <> 0
	  -- ORDER BY Final.Groupcode,ssn,Final.Dept,Final.Transdate,AdjCode

	 
