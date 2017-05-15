Create PROCEDURE [dbo].[usp_APP_AllMedical_QtrHourRnd]
	@Client varchar(4), 
	@GroupCode int,
	@PPED datetime, 
	@SSN int 
AS

SET NOCOUNT ON
--*/

DECLARE @InDay tinyint
DECLARE @InTime datetime
DECLARE @ActualInTime datetime
DECLARE @OutDay tinyint
DECLARE @OutTime datetime
DECLARE @ActualOutTime datetime
DECLARE @TransDate datetime
DECLARE @RecordId BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @EndOfDay varchar(4)
DECLARE @NewInTime datetime
DECLARE @ActualInTimeDatePartBefore varchar(10)
DECLARE @ActualInTimeDatePartAfter varchar(10)
DECLARE @NewOutTime datetime
DECLARE @ActualOutTimeDatePartBefore varchar(10)
DECLARE @ActualOutTimeDatePartAfter varchar(10)
DECLARE @NewTransDate datetime
DECLARE @NewPPED datetime
declare @tmp int

DECLARE txnCursor CURSOR READ_ONLY
FOR SELECT 	thd.InDay, thd.InTime, thd.ActualInTime, thd.OutDay, thd.OutTime, 
						thd.ActualOutTime, thd.TransDate, thd.RecordId, 
						right('0000' + cast(sn.CloseHour as varchar), 4)
		FROM TimeHistory.dbo.tblTimeHistDetail thd
		INNER JOIN TimeCurrent.dbo.tblSiteNames sn
		ON sn.Client = thd.Client
		AND sn.GroupCode = thd.GroupCode
		AND sn.SiteNo = thd.SiteNo
		INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea
		ON ea.Client = thd.Client
		AND ea.GroupCode = thd.GroupCode
		AND ea.SSN = thd.SSN
		AND ea.SiteNo = thd.SiteNo
		AND ea.DeptNo = thd.DeptNo
		AND ea.QtrHrRound = '1'
		WHERE thd.Client = @Client
		AND thd.GroupCode = @GroupCode
		AND thd.PayrollPeriodEndDate = @PPED
		AND thd.SSN = @SSN
		AND thd.InDay <> 10
		AND thd.OutDay <> 10
		AND thd.Hours <> 0
		AND thd.ClockAdjustmentNo IN ('', ' ')

OPEN txnCursor

FETCH NEXT FROM txnCursor INTO @InDay, @InTime, @ActualInTime, @OutDay, @OutTime, @ActualOutTime, @TransDate, @RecordId, @EndOfDay
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		--------------------------
		-- Round the In Punch
		--------------------------
		
		-- If we find another punch
		IF EXISTS (	SELECT 1
								FROM TimeHistory..tblTimeHistDetail
								WHERE Client = @Client
								AND GroupCode = @GroupCode
								AND SSN = @SSN
								AND PayrollPeriodEndDate = @PPED
								AND ClockAdjustmentNo IN ('', ' ')
								AND RecordId <> @RecordID
								AND DateDiff(mi, ActualOutTime, @ActualInTime) between -14 and 14)
		BEGIN
			-- If we find an out punch that is within 14 minutes of this in punch, then set the rounded time to the actual time
			SELECT @NewInTime = '1899-12-30 ' + cast(datepart(hh, @ActualInTime) as varchar) + ':' + cast(datepart(mi, @ActualInTime) as varchar) + ':' + cast(datepart(ss, @ActualInTime) as varchar)

			UPDATE TimeHistory.dbo.tblTimeHistDetail
			SET InTime = @NewInTime
			WHERE RecordId = @RecordId	
			AND InTime <> @NewInTime
		END
		ELSE
		BEGIN
			--print 'In Time: ' + cast(@ActualInTime as varchar)
			-- If we don't find an out punch within 14 minutes of this in punch, then go ahead and round the in punch
			SELECT @NewInTime = TimeCurrent.dbo.fn_RoundQtrHr(@ActualInTime)
			--print '@NewInTime: ' + cast(@NewInTime as varchar)
			SELECT @NewInTime = '1899-12-30 ' + cast(datepart(hh, @NewInTime) as varchar) + ':' + cast(datepart(mi, @NewInTime) as varchar) + ':' + cast(datepart(ss, @NewInTime) as varchar)
			--print '@NewInTime: ' + cast(@NewInTime as varchar)

			UPDATE TimeHistory.dbo.tblTimeHistDetail
			SET InTime = @NewInTime
			WHERE RecordId = @RecordId	
			AND InTime <> @NewInTime

--			print '@NewInTime: ' + right('00' + cast(DatePart(hh, @NewInTime) as varchar), 2) + right('00' + cast(DatePart(mi, @NewInTime) as varchar), 2)
--			print '@EndOfDay: ' + @EndOfDay
--			print DatePart(mi, @ActualInTime)
--			print DateAdd(dd, 1, convert(varchar(10), @ActualInTime, 101))

			--print 'IF1: ' + right('00' + cast(DatePart(hh, @NewInTime) as varchar), 2) + right('00' + cast(DatePart(mi, @NewInTime) as varchar), 2)
			--print 'IF2: ' + cast(DatePart(mi, @ActualInTime) as varchar)

			-- If the punch was rounded up to midnight then we need to increment the day counter so that the time will calulate correctly
			IF ((right('00' + cast(DatePart(hh, @NewInTime) as varchar), 2) + right('00' + cast(DatePart(mi, @NewInTime) as varchar), 2) = '0000') AND
					(DatePart(mi, @ActualInTime) <> 0))
			BEGIN
				UPDATE TimeHistory.dbo.tblTimeHistDetail
				SET InDay = CASE WHEN InDay BETWEEN 1 AND 6 THEN InDay + 1 ELSE 1 END
				WHERE RecordId = @RecordId					
			END

			-- If the punch was rounded up to the start of the day, then we need to increment the TransDate by 1 to force it in to the new week
			IF ((right('00' + cast(DatePart(hh, @NewInTime) as varchar), 2) + right('00' + cast(DatePart(mi, @NewInTime) as varchar), 2) = @EndOfDay) AND
					(DatePart(mi, @ActualInTime) <> 0) AND
					(NOT EXISTS(SELECT 1
											FROM TimeHistory..tblTimeHistDetail
											WHERE Client = @Client
											AND GroupCode = @GroupCode
											AND SSN = @SSN
											AND PayrollPeriodEndDate IN (@PPED, DateAdd(dd, -7, @PPED))
											AND ClockAdjustmentNo IN ('', ' ')
											AND RecordId <> @RecordID
											AND DateDiff(mi, ActualOutTime, @ActualInTime) between 0 and 90)))
			BEGIN
--				print 'here'

				SELECT @NewTransDate = DateAdd(dd, 1, convert(varchar(10), @ActualInTime, 101))
				SELECT @NewPPED = DateAdd(dd, 7, @PPED)

				IF (@TransDate <> @NewTransDate)
				BEGIN
--					print '@NewTransDate: ' + cast(@NewTransDate as varchar)

					UPDATE TimeHistory.dbo.tblTimeHistDetail
					SET TransDate = @NewTransDate,
							PayrollPeriodEndDate = CASE WHEN @NewTransDate > @PPED THEN @NewPPED ELSE PayrollPeriodEndDate END
					WHERE RecordId = @RecordId	
	
					IF (@NewTransDate > @PPED)
					BEGIN
--						print 'setting up new week'
						DECLARE @JobId int
						DECLARE @DefaultQue int
						DECLARE @DefaultPriority int
						DECLARE @DefaultClass int

						-- Set up the new payweek if we just forwarded a punch into it	
						EXEC TimeCurrent.dbo.usp_SetupPayWeek_ClockImporter @Client, @GroupCode, @NewPPED

						-- Recalc the employee in the next week
						UPDATE TimeHistory.dbo.tblEmplNames
						SET NeedsRecalc = '1'
						WHERE Client = @Client
						AND GroupCode = @GroupCode
						AND PayrollPeriodEndDate = @NewPPED
						AND SSN = @SSN

						SELECT  @DefaultQue = DefaultQue, 
						        @DefaultPriority = DefaultPriority, 
						        @DefaultClass = DefaultClass
						FROM Scheduler..tblPrograms
						WHERE ProgramName = 'EMPLCALC'
						
						INSERT INTO Scheduler..tbljobs(ProgramName, TimeRequested, TimeQued, Client, GroupCode, PayrollPeriodEndDate)
						VALUES ('EMPLCALC', getDate(), getDate(), @Client, @GroupCode, @NewPPED)
						
						SELECT @JobID = SCOPE_IDENTITY()
						
						INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm) VALUES (@JobID, 'CLIENT', @Client)						
						INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm) VALUES (@JobID, 'GROUP', @GroupCode)						
						INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm) VALUES (@JobID, 'DATE', CONVERT(varchar(10), @NewPPED, 101))						
						INSERT INTO Scheduler..tbljobQue(JobID, Priority, Que, Class) VALUES (@JobID, @DefaultPriority, @DefaultQue, @DefaultClass)

					END
				END
			END
		END

		--------------------------
		-- Round the Out Punch
		--------------------------

		-- If we find another punch
		IF EXISTS (	SELECT 1
								FROM TimeHistory..tblTimeHistDetail
								WHERE Client = @Client
								AND GroupCode = @GroupCode
								AND SSN = @SSN
								AND PayrollPeriodEndDate = @PPED
								AND ClockAdjustmentNo IN ('', ' ')
								AND RecordId <> @RecordID
								AND DateDiff(mi, @ActualOutTime, ActualInTime) between -14 and 14)
		BEGIN
			-- If we find an out punch that is within 14 minutes of this in punch, then set the rounded time to the actual time
			SELECT @NewOutTime = '1899-12-30 ' + cast(datepart(hh, @ActualOutTime) as varchar) + ':' + cast(datepart(mi, @ActualOutTime) as varchar) + ':' + cast(datepart(ss, @ActualOutTime) as varchar)

			UPDATE TimeHistory.dbo.tblTimeHistDetail
			SET OutTime = @NewOutTime
			WHERE RecordId = @RecordId	
			AND OutTime <> @NewOutTime
		END
		ELSE
		BEGIN
			-- If we don't find an out punch within 14 minutes of this in punch, then go ahead and round the out punch
			SELECT @ActualOutTimeDatePartBefore = cast(datepart(yyyy, @ActualOutTime) as varchar) + '-' + cast(datepart(mm, @ActualOutTime) as varchar) + '-' + cast(datepart(dd, @ActualOutTime) as varchar)
			SELECT @NewOutTime = TimeCurrent.dbo.fn_RoundQtrHr (@ActualOutTime)
			SELECT @ActualOutTimeDatePartAfter = cast(datepart(yyyy, @NewOutTime) as varchar) + '-' + cast(datepart(mm, @NewOutTime) as varchar)+ '-' + cast(datepart(dd, @NewOutTime) as varchar)
			SELECT @NewOutTime = '1899-12-30 ' + cast(datepart(hh, @NewOutTime) as varchar) + ':' + cast(datepart(mi, @NewOutTime) as varchar) + ':' + cast(datepart(ss, @NewOutTime) as varchar)

			UPDATE TimeHistory.dbo.tblTimeHistDetail
			SET OutTime = @NewOutTime,
					TransDate = CASE WHEN @ActualOutTimeDatePartAfter <> @ActualOutTimeDatePartBefore THEN DateAdd(dd, -1, TransDate) ELSE TransDate END
			WHERE RecordId = @RecordId	
			AND OutTime <> @NewOutTime
		END

		UPDATE TimeHistory..tblTimeHistDetail
		SET Hours = CAST(datediff(mi, TimeHistory.dbo.PunchDateTime2(TransDate, InDay, InTime), TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, OutTime)) as numeric (7,2)) / 60
		WHERE RecordId = @RecordId
		AND Hours <> CAST(datediff(mi, TimeHistory.dbo.PunchDateTime2(TransDate, InDay, InTime), TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, OutTime)) as numeric (7,2)) / 60

	END
	FETCH NEXT FROM txnCursor INTO @InDay, @InTime, @ActualInTime, @OutDay, @OutTime, @ActualOutTime, @TransDate, @RecordId, @EndOfDay
END
CLOSE txnCursor
DEALLOCATE txnCursor


