
USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_DAVT_MonthlyACT_Extract]    Script Date: 9/27/2016 2:32:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[usp_APP_DAVT_MonthlyACT_Extract]

AS

Set nocount on

DECLARE @PPEDStart datetime
DECLARE @PPEDEnd Datetime
DECLARE @TransStart datetime
DECLARE @Transend datetime

Set @PPEDEnd = ltrim(str(month(getdate()))) + '/01/' + ltrim(str(year(getdate())))  -- Get start of current month
Set @PPEDStart = dateadd(month,-1,@PPEDEnd) --Minus one month.
Set @PPEDEnd = dateadd(day,7,@PPEDEnd)
Set @TransStart = @PPEDStart
Set @TransEnd = dateadd(month,1,@TransStart)

--Print @PPEDStart
--Print @PPEDEnd
--PRint @TransStart
--Print @TransEnd

--Drop Table #tmpShiftCounts

select t.Client, t.Payrollperiodenddate, t.GroupCode, t.SSn, t.TransDAte, ShiftCount = sum(case when t.Inclass = 'S' then 1 else 0 end ) 
into #tmpShiftCounts
from TimeHistory..tblTimeHIstDetail as t with(nolock)
Inner Join TimeCurrent..tblClientGroups as g with (nolock)
on g.client = t.client and g.groupcode = t.groupcode 
Inner Join TimeCurrent..tblEmplNames as en with (nolock)
on en.client = t.client and en.groupcode = t.groupcode and en.ssn = t.ssn and en.PrimaryDept in(50,52,4)
and en.Paytype = '0'
where t.client = 'DAVT' 
--and t.groupcode = 509600 
and t.PayrollPeriodEndDate >= @PPEDStart
and t.PayrollPeriodEndDate <= @PPEDEnd
and t.transdate >= @TransStart
and t.transdate < @TransEnd
and t.clockadjustmentno in('1','8','F','K','M','O','Q','R','T','U','V','W','Y','Z','',' ')
and t.hours <> 0.00
group by t.Client, t.Payrollperiodenddate, t.GroupCode, t.SSn, t.TransDAte
having sum(case when t.Inclass = 'S' then 1 else 0 end )  > 1

DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
DECLARE @savClockOutTime datetime
DECLARE @savClockInTime datetime
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @savRecordID BIGINT  --< @savRecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
DECLARE @DiffMins int
DECLARE @Hours numeric(9,2)
DECLARE @ShiftSegment int
DECLARE @ShiftSegmentID char(1)
DECLARE @AdjNo varchar(3) --< Srinsoft 08/10/2015 Changed @AdjNo char(1) to varchar(3) >--
DECLARE @BreakMins INT
DECLARE @savBreakMins int
DECLARE @Client varchar(4)
DECLARE @Groupcode int
DECLARE @SSN int
DECLARE @PPED datetime


DECLARE cEmpls CURSOR
READ_ONLY
FOR 
select Distinct Client, Payrollperiodenddate, GroupCOde, SSN from #tmpShiftCounts 

OPEN cEmpls

FETCH NEXT FROM cEmpls INTO @Client, @PPED, @GroupCode, @SSN
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

      --Print @SSN
      -- First Set IN and OUT Classes to indicate Lunch Punches for this time card. We have to do this every time because the old trans clocks do not set this
      -- value.
      -- 
      DECLARE cTHD1 CURSOR
      READ_ONLY
      FOR 
      select t.RecordID, 
      ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
      ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
      t.ClockADjustmentNo
      from Timehistory..tblTimeHistDetail as t with (nolock)
      where t.client = @Client
      and t.groupcode = @GroupCode
      and t.SSN = @SSN
      and t.Payrollperiodenddate = @PPED
      and t.Hours <> 0.00
      and t.InDay < 8 and t.OutDay < 8
      order by TransDate, ClockAdjustmentNo, ClockInTime

      SET @savClockOutTime = NULL
      SET @ShiftSegment = 1
      SET @ShiftSegmentID = @ShiftSegment

      OPEN cTHD1

      FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @AdjNo
      WHILE (@@fetch_status <> -1)
      BEGIN
	      IF (@@fetch_status <> -2)
	      BEGIN
		      IF @AdjNo <> '' 
		      BEGIN
            Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID
			      GOTO NextDetail
		      END

          IF @savClockOutTime is NULL
          BEGIN
            Set @savClockOutTime = @ClockOutTime
            Set @savRecordID = @RecordID
            Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
          END
          ELSE
          BEGIN
            Set @DiffMins = datediff(minute, @savClockOutTime, @ClockInTime )
            IF @DiffMins >= 30 and @DiffMins <= 90 
            BEGIN
              -- Set InClass to "L" ( Lunch punch )
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
            END
            IF @DiffMins >= 0 and @DiffMins < 30
            BEGIN
              -- Set InClass to "|" ( Split punch or Non-Lunch break)
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
            END
            IF @DiffMins > 90
            BEGIN
              -- Set InClass to "S" ( Shift Start / Shift End punch )
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
				      SET @ShiftSegment = @ShiftSegment + 1

              IF @ShiftSegment <= 9
                Set @ShiftSegmentID = @ShiftSegment
				      IF @ShiftSegment = 10
					      Set @ShiftSegmentID = 'A'
				      IF @ShiftSegment = 11
					      Set @ShiftSegmentID = 'B'
				      IF @ShiftSegment = 12
					      Set @ShiftSegmentID = 'C'
				      IF @ShiftSegment = 13
					      Set @ShiftSegmentID = 'D'
				      IF @ShiftSegment = 14
					      Set @ShiftSegmentID = 'E'
				      IF @ShiftSegment = 15
					      Set @ShiftSegmentID = 'F'
				      IF @ShiftSegment = 16
					      Set @ShiftSegmentID = 'G'

              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
            END
            Set @savRecordID = @RecordID
            Set @savClockOutTime = @ClockOutTime
          END
	      NextDetail:
	      END
	      FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @AdjNo
      END

      CLOSE cTHD1
      DEALLOCATE cTHD1


	END
	FETCH NEXT FROM cEmpls INTO @Client, @PPED, @GroupCode, @SSN
END

CLOSE cEmpls
DEALLOCATE cEmpls

Drop Table #tmpShiftCounts

Truncate table refreshwork.dbo.tblWork_DAVT_MonthACTExtract

Insert into Refreshwork.dbo.tblWork_DAVT_MonthACTExtract
        ( SiteNo,
          FileNo,
          EmplName,
          PrimaryDept,
          DeptName,
          PPED,
          TransDate,
          Amount,
          ShiftID,
					ExtractID
        )
select 
CostCenter = case when sn.UploadAssiteno = 0 then t.Siteno else sn.UploadASSIteNo end,
EmplID = en.FileNo,
Name = '"' + en.LastName + ',' + en.FirstName + '"',
en.PrimaryDept, 
gd.DeptName_Long,
PayWeek = convert(varchar(12),t.Payrollperiodenddate,101),
TransDate = convert(varchar(12),t.TransDate,101),
Amount = sum(t.Hours),
ShiftID = isnull(t.CountAsOT,'1'),
ExtractID = 0
from Timehistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeCurrent..tblClientGroups as g with(nolock)
on g.client = t.client
and g.groupcode = t.groupcode 
Inner Join TImeCUrrent..tblSiteNames as sn with (nolock)
on sn.Client = t.client
and sn.Siteno = t.siteno 
Inner Join TimeCUrrent..tblEmplNames as en with (nolock)
on en.client = t.client 
and en.groupcode = t.groupcode 
and en.ssn = t.ssn 
and en.paytype = '0'
and en.PrimaryDept in(50,52,4)
and en.FileNo <> ''
Inner Join TimeCurrent..tblGroupDepts as gd with(Nolock)
on gd.client = en.client
and gd.groupcode = en.groupcode
and gd.deptno = en.primarydept
where t.client = 'DAVT' 
--and t.groupcode = 509600 
and t.PayrollPeriodEndDate >= @PPEDStart
and t.PayrollPeriodEndDate <= @PPEDEnd
and t.transdate >= @TransStart
and t.transdate < @TransEnd
and t.clockadjustmentno in('1','8','F','K','M','O','Q','R','T','U','V','W','Y','Z','',' ')
and t.hours <> 0.00
group by
t.Groupcode, 
case when sn.UploadAssiteno = 0 then t.Siteno else sn.UploadASSIteNo end,
en.FileNo,
en.LastName ,en.FirstName,
t.Payrollperiodenddate,
t.TransDate,
en.PrimaryDept, gd.DeptName_Long,
isnull(t.CountAsOT,'1')
--having sum(t.Hours) > 14.00
order by emplid, PayWeek, Transdate,shiftid 

-- *******************************************************
-- DO CHRONIC EXTRACT NOW
-- *******************************************************
select t.Client, t.Payrollperiodenddate, t.GroupCode, t.SSn, t.TransDAte, ShiftCount = sum(case when t.Inclass = 'S' then 1 else 0 end ) 
into #tmpShiftCountsC
from TimeHistory..tblTimeHIstDetail as t with(nolock)
Inner Join TimeCurrent..tblClientGroups as g with (nolock)
on g.client = t.client and g.groupcode = t.groupcode 
Inner Join TimeCurrent..tblEmplNames as en with (nolock)
on en.client = t.client and en.groupcode = t.groupcode and en.ssn = t.ssn and en.PrimaryDept in(1,30,33)
and en.Paytype = '0'
where t.client = 'DAVT' 
--and t.groupcode = 509600 
and t.PayrollPeriodEndDate >= @PPEDStart
and t.PayrollPeriodEndDate <= @PPEDEnd
and t.transdate >= @TransStart
and t.transdate < @TransEnd
and t.clockadjustmentno in('1','8','F','K','M','O','Q','R','T','U','V','W','Y','Z','',' ')
and t.hours <> 0.00
group by t.Client, t.Payrollperiodenddate, t.GroupCode, t.SSn, t.TransDAte
having sum(case when t.Inclass = 'S' then 1 else 0 end )  > 1

DECLARE cEmpls CURSOR
READ_ONLY
FOR 
select Distinct Client, Payrollperiodenddate, GroupCOde, SSN from #tmpShiftCountsC 

OPEN cEmpls

FETCH NEXT FROM cEmpls INTO @Client, @PPED, @GroupCode, @SSN
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

      --Print @SSN
      -- First Set IN and OUT Classes to indicate Lunch Punches for this time card. We have to do this every time because the old trans clocks do not set this
      -- value.
      -- 
      DECLARE cTHD1 CURSOR
      READ_ONLY
      FOR 
      select t.RecordID, 
      ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
      ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
      t.ClockADjustmentNo
      from Timehistory..tblTimeHistDetail as t with (nolock)
      where t.client = @Client
      and t.groupcode = @GroupCode
      and t.SSN = @SSN
      and t.Payrollperiodenddate = @PPED
      and t.Hours <> 0.00
      and t.InDay < 8 and t.OutDay < 8
      order by TransDate, ClockAdjustmentNo, ClockInTime

      SET @savClockOutTime = NULL
      SET @ShiftSegment = 1
      SET @ShiftSegmentID = @ShiftSegment

      OPEN cTHD1

      FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @AdjNo
      WHILE (@@fetch_status <> -1)
      BEGIN
	      IF (@@fetch_status <> -2)
	      BEGIN
		      IF @AdjNo <> '' 
		      BEGIN
            Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID
			      GOTO NextDetailC
		      END

          IF @savClockOutTime is NULL
          BEGIN
            Set @savClockOutTime = @ClockOutTime
            Set @savRecordID = @RecordID
            Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
          END
          ELSE
          BEGIN
            Set @DiffMins = datediff(minute, @savClockOutTime, @ClockInTime )
            IF @DiffMins >= 30 and @DiffMins <= 90 
            BEGIN
              -- Set InClass to "L" ( Lunch punch )
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
            END
            IF @DiffMins >= 0 and @DiffMins < 30
            BEGIN
              -- Set InClass to "|" ( Split punch or Non-Lunch break)
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
            END
            IF @DiffMins > 90
            BEGIN
              -- Set InClass to "S" ( Shift Start / Shift End punch )
              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
				      SET @ShiftSegment = @ShiftSegment + 1

              IF @ShiftSegment <= 9
                Set @ShiftSegmentID = @ShiftSegment
				      IF @ShiftSegment = 10
					      Set @ShiftSegmentID = 'A'
				      IF @ShiftSegment = 11
					      Set @ShiftSegmentID = 'B'
				      IF @ShiftSegment = 12
					      Set @ShiftSegmentID = 'C'
				      IF @ShiftSegment = 13
					      Set @ShiftSegmentID = 'D'
				      IF @ShiftSegment = 14
					      Set @ShiftSegmentID = 'E'
				      IF @ShiftSegment = 15
					      Set @ShiftSegmentID = 'F'
				      IF @ShiftSegment = 16
					      Set @ShiftSegmentID = 'G'

              Update TimeHistory..tblTimeHistDetail Set CountAsOT = @ShiftSegmentID where recordid = @recordID 
            END
            Set @savRecordID = @RecordID
            Set @savClockOutTime = @ClockOutTime
          END
	      NextDetailC:
	      END
	      FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @AdjNo
      END

      CLOSE cTHD1
      DEALLOCATE cTHD1


	END
	FETCH NEXT FROM cEmpls INTO @Client, @PPED, @GroupCode, @SSN
END

CLOSE cEmpls
DEALLOCATE cEmpls

Drop Table #tmpShiftCountsC

--Truncate table refreshwork.dbo.tblWork_DAVT_MonthACTExtract

Insert into Refreshwork.dbo.tblWork_DAVT_MonthACTExtract
        ( SiteNo,
          FileNo,
          EmplName,
          PrimaryDept,
          DeptName,
          PPED,
          TransDate,
          Amount,
          ShiftID,
					ExtractID
        )
select 
CostCenter = case when sn.UploadAssiteno = 0 then t.Siteno else sn.UploadASSIteNo end,
EmplID = en.FileNo,
Name = '"' + en.LastName + ',' + en.FirstName + '"',
en.PrimaryDept, 
gd.DeptName_Long,
PayWeek = convert(varchar(12),t.Payrollperiodenddate,101),
TransDate = convert(varchar(12),t.TransDate,101),
Amount = sum(t.Hours),
ShiftID = isnull(t.CountAsOT,'1'),
ExtractID = 1
from Timehistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeCurrent..tblClientGroups as g with(nolock)
on g.client = t.client
and g.groupcode = t.groupcode 
Inner Join TImeCUrrent..tblSiteNames as sn with (nolock)
on sn.Client = t.client
and sn.Siteno = t.siteno 
Inner Join TimeCUrrent..tblEmplNames as en with (nolock)
on en.client = t.client 
and en.groupcode = t.groupcode 
and en.ssn = t.ssn 
and en.paytype = '0'
and en.PrimaryDept in(1,30,33)
and en.FileNo <> ''
Inner Join TimeCurrent..tblGroupDepts as gd with(Nolock)
on gd.client = en.client
and gd.groupcode = en.groupcode
and gd.deptno = en.primarydept
where t.client = 'DAVT' 
--and t.groupcode = 509600 
and t.PayrollPeriodEndDate >= @PPEDStart
and t.PayrollPeriodEndDate <= @PPEDEnd
and t.transdate >= @TransStart
and t.transdate < @TransEnd
and t.clockadjustmentno in('1','8','F','K','M','O','Q','R','T','U','V','W','Y','Z','',' ')
and t.hours <> 0.00
group by
t.Groupcode, 
case when sn.UploadAssiteno = 0 then t.Siteno else sn.UploadASSIteNo end,
en.FileNo,
en.LastName ,en.FirstName,
t.Payrollperiodenddate,
t.TransDate,
en.PrimaryDept, gd.DeptName_Long,
isnull(t.CountAsOT,'1')
--having sum(t.Hours) > 14.00
order by emplid, PayWeek, Transdate,shiftid 


DECLARE @FileName varchar(40)
DECLARE @JobID INT
DECLARE @MessageBody VARCHAR(400)

--Set @FileName = 'DAVT_MonthlyACTFileChronic_' + LTRIM(str(year(@TransStart))) + '_' + ltrim(str(month(@TransStart))) + '.csv'
Set @FileName = 'DAVT_MonthlyACTFileChronic.csv'

-- Add the generic export job to send the file to the Davita FTP Site.
--
SET @MessageBody = 'ACT Chronic Monthly extract for ' + DATENAME(MONTH,@TransStart) + ' ' + str(YEAR(@TransStart)) + ' is attached.'


INSERT INTO [Scheduler].[dbo].[tblJobs]([ProgramName], [TimeRequested], [TimeQued], [TimeStarted], [TimeCompleted],  [Client], [GroupCode], [Weekly])
VALUES('GenericDataExport',getdate(),null,null,null,@Client, 0,'1')
Set @JobID = scope_identity()

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'DATE', convert(varchar(12),@PPED,101) )

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'GROUP', '0')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'CLIENT', @Client)

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'FILENAME', @FileName )

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
Select @JobID, 'FILEPATH', UnCPath from Scheduler..tblSysPaths where KeyWord = 'DAVT_DailyExtract'

-- Main SP to extract data and load CSV file.
INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'REF1', 'EXEC TimeHistory..usp_APP_DAVT_MonthlyACT_Extract_DumpFileChronic')

-- FTP SP to FTP the file via Batch7 or Batch8
INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'REF5', '')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'REF2', '1')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'XMAIL','Alexander.Behzadi@davita.com,Nicole.Delphia@davita.com')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'ZIPFILE', '1')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'MESSAGEBODY', @MessageBody)

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'SUBJECTLINE', @MessageBody)


Print @JobID

-- Add the generic export job to send the file to the Davita FTP Site.
--
SET @MessageBody = 'ACT Acute Monthly extract for ' + DATENAME(MONTH,@TransStart) + ' ' + str(YEAR(@TransStart)) + ' is attached.'

INSERT INTO [Scheduler].[dbo].[tblJobs]([ProgramName], [TimeRequested], [TimeQued], [TimeStarted], [TimeCompleted],  [Client], [GroupCode], [Weekly])
VALUES('GenericDataExport',getdate(),null,null,null,@Client, 0,'1')
Set @JobID = scope_identity()

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'DATE', convert(varchar(12),@PPED,101) )

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'GROUP', '0')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'CLIENT', @Client)

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'FILENAME', 'DAVT_MonthlyACTFile.csv')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
Select @JobID, 'FILEPATH', UnCPath from Scheduler..tblSysPaths where KeyWord = 'DAVT_DailyExtract'

-- Main SP to extract data and load CSV file.
INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'REF1', 'EXEC TimeHistory..usp_APP_DAVT_MonthlyACT_Extract_DumpFile')

-- FTP SP to FTP the file via Batch7 or Batch8
INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'REF5', '')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'REF2', '1')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'XMAIL','Alexander.Behzadi@davita.com,Douglas.Kauffman@davita.com,Nicole.Delphia@davita.com')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'ZIPFILE', '1')

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'MESSAGEBODY', @MessageBody)

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@JobID, 'SUBJECTLINE', @MessageBody)

Print @JobID



