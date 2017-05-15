CREATE  PROCEDURE [dbo].[usp_APP_KronosPunchExport_Standard] 
(
	@Client varchar(4),
	@GroupCode int,
	@DummyDate datetime -- GenericDataExport app sends this but it's not needed.
)
AS


SET NOCOUNT ON

DECLARE @EmployeeNo varchar(100)
DECLARE @SSN int
DECLARE @DivisionId varchar(32)
DECLARE @ClientDeptCode varchar(100)
DECLARE @TransDate datetime
DECLARE @InDay tinyint
DECLARE @OutDay tinyint
DECLARE @InTime datetime
DECLARE @OutTime datetime
DECLARE @Hours numeric(5,2)
DECLARE @Status int
DECLARE @THDRecordId BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @StartDate datetime
DECLARE @EndDate datetime
DECLARE @BillRate numeric(7,2)
DECLARE @PurchOrderNo varchar(30)
DECLARE @CSVLine varchar(1000)
DECLARE @MaintDateTime datetime

SELECT @MaintDateTime = GetDate()
SELECT @EndDate = CONVERT(nvarchar(20), GetDate(), 101)
SELECT @StartDate = DateAdd(ww,-3,@EndDate)

CREATE TABLE #tmpPunchFile (LineOut varchar(1000))

CREATE TABLE #tmpTHDSnapShot( THDRecordId BIGINT,  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
                              SSN int,
                              FileNo varchar(100),
                              DivisionId varchar(32),
                              ClientDeptCode varchar(100),
                              TransDate datetime,
                              InDay tinyint,
                              OutDay tinyint,
                              InTime datetime,
                              OutTime datetime,
                              BillRate numeric(7,2),
                              Hours numeric(5,2),
                              PurchOrderNo varchar(30))

CREATE TABLE #tmpWorkArea ( THDRecordId BIGINT,  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
                            SSN int,
                            FileNo varchar(100),
                            DivisionId varchar(32),
                            ClientDeptCode varchar(100),
                            TransDate datetime,
                            InDay tinyint,
                            OutDay tinyint,
                            InTime datetime,
                            OutTime datetime,
                            BillRate numeric(7,2),
                            Hours numeric(5,2),
                            PurchOrderNo varchar(30),
                            Status int)

INSERT INTO #tmpTHDSnapShot
SELECT thd.RecordID,en.SSN, en.FileNo,sn.DivisionID ,gd.ClientDeptCode2,
       thd.TransDate,thd.InDay, thd.OutDay, thd.InTime,thd.OutTime,isnull(thd.BillRate,0.00),thd.Hours,ed.PurchOrderNo
FROM TimeHistory..tblTimeHistDetail thd
INNER JOIN TimeCurrent..tblEmplNames en
ON thd.Client = en.Client
AND thd.GroupCode = en.GroupCode
AND thd.SSN = en.SSN
INNER JOIN TimeCurrent..tblGroupDepts gd
ON thd.Client = gd.Client
AND thd.GroupCode = gd.GroupCode
AND thd.DeptNo = gd.DeptNo
INNER JOIN TimeCurrent..tblEmplNames_Depts ed
ON thd.Client = ed.Client
AND thd.GroupCode = ed.GroupCode
AND thd.SSN = ed.SSN
AND thd.DeptNo = ed.Department
INNER JOIN TimeCurrent..tblSiteNames sn
ON thd.Client = sn.Client
AND thd.GroupCode = sn.GroupCode
AND thd.SiteNo = sn.SiteNo
WHERE thd.Client = @Client
AND thd.GroupCode = @GroupCode
AND thd.PayrollPeriodEndDate <= DateAdd(dd,7,GetDate())
AND thd.TransDate between @StartDate AND @EndDate
AND thd.ClockAdjustmentNo in ('',' ')
AND ((dbo.PunchDateTime2(thd.TransDate, thd.Inday, thd.InTime) > '1/22/2008 11:00') OR
		 (dbo.PunchDateTime2(thd.TransDate, thd.Outday, thd.OutTime) > '1/22/2008 11:00'))
AND (thd.InDay <> 10 AND thd.OutDay <> '10')

-- Populate the work table with what's already been exported 
INSERT INTO #tmpWorkArea (THDRecordId,SSN,FileNo,DivisionId,ClientDeptCode,TransDate,InDay,OutDay,InTime,OutTime,BillRate,Hours,PurchOrderNo,Status)
SELECT THDRecordId,SSN,FileNo,DivisionId,ClientDeptCode,TransDate,InDay,OutDay,InTime,OutTime,BillRate,Hours,IsNull(PurchOrderNo,''),0
FROM TimeHistory..tblKronosPunchExport
WHERE Client = @Client
AND GroupCode = @GroupCode
AND TransDate between @StartDate AND @EndDate

-- Add what's currently in timeHistDetail
INSERT INTO #tmpWorkArea (THDRecordId,SSN,FileNo,DivisionId,ClientDeptCode,TransDate,InDay,OutDay,InTime,OutTime,BillRate,Hours,PurchOrderNo,Status)
SELECT THDRecordId,SSN,FileNo,DivisionId,ClientDeptCode,TransDate,InDay,OutDay,InTime,OutTime,BillRate,Hours,IsNull(PurchOrderNo,''),1
FROM #tmpTHDSnapShot

-- For split punches, outtime for the first part of the punch will be
-- the same as intime for the second part.  Kronos cannot handle this, so
-- add 1 minute to the intime for the second part.
UPDATE b
SET b.InTime = DateAdd(mi,1,b.InTime) 
FROM #tmpWorkArea a, #tmpWorkArea b
WHERE a.SSN = b.SSN
AND a.TransDate = b.TransDate
AND a.Status = b.Status
AND a.OutTime = b.InTime

-- Now delete any punches that haven't changed since the last export
DELETE #tmpWorkArea
WHERE thdRecordId in (
SELECT thdRecordId 
FROM #tmpWorkArea
GROUP BY thdRecordId, InTime, OutTime, BillRate,Hours,DivisionId,ClientDeptCode,PurchOrderNo
HAVING count(*) = 2)

-- Anything left needs to be exported to Kronos.

-- Status 0 means it was previously sent but has since changed, so send a delete record.
-- Status 1 means it's new or changed, so send an add record.
DECLARE csrPunch CURSOR READ_ONLY
FOR SELECT FileNo,DivisionId,ClientDeptCode,
           TransDate,InDay,OutDay,InTime,OutTime,BillRate,Hours,PurchOrderNo,Status
	  FROM #tmpWorkArea
	  ORDER BY Status, FileNo, TransDate, InTime

OPEN csrPunch
FETCH NEXT FROM csrPunch INTO @EmployeeNo, @DivisionId, @ClientDeptCode, @TransDate, @InDay, @OutDay, @InTime, @OutTime, @BillRate, @Hours, @PurchOrderNo, @Status

WHILE (@@fetch_status <> -1)
BEGIN
  IF (@@fetch_status <> -2)
  BEGIN
    /* Send delete records before add records */
    IF @Status = 0
      /* 
        All records include employee number (fileNo), building (DivisionId), Dept (clientDeptCode), Date, Time, BillRate, PurchOrderNo and a record type.
        Send separate records for the in punch and the out punch.
      */
    BEGIN
      /* 
        For delete records, send blank building and dept and 8 as the record type.
      */
      SET @CSVLine = '"' + @EmployeeNo + '","","","' + CONVERT(nvarchar(20), @TransDate, 101) + '","' +  LEFT(CONVERT(nvarchar(20), @InTime, 108),5) + '",8'
      INSERT INTO #tmpPunchFile
      SELECT @CSVLine   
      
      SET @CSVLine = '"' + @EmployeeNo + '","","","' + CONVERT(nvarchar(20), @TransDate, 101) + '","' + LEFT(CONVERT(nvarchar(20), @OutTime, 108),5) + '",8'
      INSERT INTO #tmpPunchFile
      SELECT @CSVLine        
    END
    ELSE IF @Hours > 0
    BEGIN
      /*
        For add records, send all fields populated for the in punch with 6 as the record type.
      */
			IF (dbo.PunchDateTime2(@TransDate, @InDay, @InTime) >= '1/22/2008 11:00')
			BEGIN				
	      SET @CSVLine = '"' + @EmployeeNo + '","' + @DivisionId + '","' + @ClientDeptCode + '","' + CONVERT(nvarchar(20), @TransDate, 101) + '","' + LEFT(CONVERT(nvarchar(20), @InTime, 108),5) + '",6,' + cast(@BillRate as varchar) + ',"' + @PurchOrderNo + '"'
	      INSERT INTO #tmpPunchFile
	      SELECT @CSVLine        
			END           
      /*
        If this was an overnight shift, the TransDate should be  
        the next day.
      */
      IF @InDay <> @OutDay
      BEGIN
        SET @TransDate = DateAdd(dd,1,@TransDate)
      END
      /*
        Send blank building and dept to indicate that this is an out punch.          
      */      
      SET @CSVLine = '"' + @EmployeeNo + '","","","' + CONVERT(nvarchar(20), @TransDate, 101) + '","' + LEFT(CONVERT(nvarchar(20), @OutTime, 108),5) + '",6'
      INSERT INTO #tmpPunchFile
      SELECT @CSVLine        
    END      
  END
  FETCH NEXT FROM csrPunch INTO @EmployeeNo, @DivisionId, @ClientDeptCode, @TransDate, @InDay, @OutDay, @InTime, @OutTime, @BillRate, @Hours, @PurchOrderNo, @Status
END
CLOSE csrPunch
DEALLOCATE csrPunch

-- Refresh the punch export table with what's currently in TimeHistDetail
DELETE FROM TimeHistory..tblKronosPunchExport
WHERE Client = @Client
AND GroupCode = @GroupCode
AND TransDate between @StartDate and @EndDate

INSERT INTO TimeHistory..tblKronosPunchExport (THDRecordId,Client,GroupCode,SSN,FileNo,DivisionId,ClientDeptCode,TransDate,InTime,OutTime,BillRate,Hours,PurchOrderNo,MaintDateTime)
SELECT THDRecordId,@Client,@GroupCode,SSN,FileNo,DivisionId,ClientDeptCode,TransDate,InTime,OutTime,BillRate,Hours,PurchOrderNo,@MaintDateTime
FROM #tmpTHDSnapShot

-- Refresh the employee export table with the employees contained in the punch export file
DELETE FROM TimeHistory..tblKronosEmployeeExport
WHERE Client = @Client
AND GroupCode = @GroupCode

INSERT INTO TimeHistory..tblKronosEmployeeExport
SELECT DISTINCT @Client,@GroupCode,SSN,@MaintDateTime
FROM #tmpWorkArea

EXEC Scheduler..usp_APP_AddTrigger @Client, @GroupCode, @DummyDate, 'Upload', 'N'

-- Return the lines to be written to the punch export file

SELECT *
FROM #tmpPunchFile

DROP TABLE #tmpTHDSnapShot
DROP TABLE #tmpWorkArea
DROP TABLE #tmpPunchFile


