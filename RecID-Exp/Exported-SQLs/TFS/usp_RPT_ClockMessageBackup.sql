Create PROCEDURE [dbo].[usp_RPT_ClockMessageBackup]
(
@Client varchar(4),
@Group int
)
AS
--*/
SET NOCOUNT ON
/*
DECLARE @Group as int
DECLARE @Client as varchar(4)

SELECT @Client = 'RAND'
SELECT @Group = 599901

*/
DECLARE @SiteNo as INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 26Aug2016 >--
DECLARE @SiteName as varchar(30)
DECLARE @ExportMailBox as varchar(20) 
DECLARE @MsgInfo varchar(1000)
DECLARE @MsgID char(40)
DECLARE @DtCreateMsg datetime
DECLARE @tempDate varchar(16)
DECLARE @tmpHrs varchar(8)
DECLARE @tempTime varchar(5)
DECLARE @tempChar char(1)
DECLARE @tempDate1 datetime
DECLARE @ClockType char(1)

SELECT @tempDate1 = getdate() - 5
--SELECT @Client = 'RAND'
--SELECT @Group = 300200
--print @tempDate1

CREATE Table #TempTable(
MsgId char(40),
Client varchar(4),
GroupCode int,
SiteNo INT,  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 26Aug2016 >--
SiteName  varchar(30),
ExportMailBox  varchar(20),
Email_Chk_1  varchar(5),
Email_Chk_2  varchar(5),
Email_Chk_3  varchar(5),
AutoClose  char(1),
AllowCloseExcep  char(1),
InFastMode char(1),
OutFastMode char(1),
PrintReceipt varchar(5),
Purge char(1),
Terminate char(1),
NextXmit varchar(16),
Nextclose varchar(16),
OTScheduling char(1),
WklyHrsBefOT varchar(5),
WklyHrsBefDT varchar(5),
DailyHrsBefOT varchar(5),
DailyHrsBefDT varchar(5),
SchedIn varchar(5),
SchedOut varchar(5),
MngrPass varchar(4),
FirstBack varchar(5),
SecondBack varchar(5),
ThirdBack varchar(5),
FourthBack varchar(5)
)

DECLARE MBoxCursor CURSOR FOR
	SELECT SiteNo,SiteName, ExportMailBox + 'BU'
	FROM timecurrent..tblsitenames 
	WHERE groupcode = @Group
				AND client =  @Client
				AND recordstatus = '1'
        AND ClockType = 'T'

OPEN MBoxCursor
FETCH NEXT FROM MBoxCursor 
	INTO @SiteNo, @SiteName, @ExportMailBox
WHILE @@FETCH_STATUS = 0 
BEGIN
	SELECT TOP 1 @MsgID = MessageID, @DtCreateMsg = DateCreatedMessage
		FROM messages..tblmessages m
		WHERE datecreatedmessage > @tempDate1
		AND mailboxid = @ExportMailBox
		ORDER BY recordid DESC

	IF @MsgID IS NOT NULL 
	BEGIN
		IF @DtCreateMsg IS NOT NULL 
		BEGIN
			INSERT INTO #TempTable values
			(@MsgID,@client,@group,@siteno,@sitename,@exportmailbox,'','','','','','','','','','','','','','','','','','','','','','','','')
		
			--email check first
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20062',@MsgID)
			SELECT @tempTime = right(@MsgInfo,4)
			If len(@tempTime) = 4 AND isNumeric(@tempTime) = 1
				SELECT @tempTime = left(@tempTime,2) + ':' + right(@tempTime,2)
			else
				SELECT @tempTime = ''
			UPDATE #TempTable SET Email_Chk_1 = @tempTime WHERE ExportMailBox = @ExportMailBox
		
			--email check second
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20796',@MsgID)
			SELECT @tempTime = right(@MsgInfo,4)
			If len(@tempTime) = 4 AND isNumeric(@tempTime) = 1
				SELECT @tempTime = left(@tempTime,2) + ':' + right(@tempTime,2)
			else
				SELECT @tempTime = ''
			UPDATE #TempTable SET Email_Chk_2 = @tempTime WHERE ExportMailBox = @ExportMailBox
		
			--email check third
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20237',@MsgID)
			SELECT @tempTime = right(@MsgInfo,4)
			If len(@tempTime) = 4 AND isNumeric(@tempTime) = 1
				SELECT @tempTime = left(@tempTime,2) + ':' + right(@tempTime,2)
			else
				SELECT @tempTime = ''
		
			UPDATE #TempTable SET Email_Chk_3 = @tempTime WHERE ExportMailBox = @ExportMailBox
		
			--autoclose
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20080',@MsgID)
			IF Substring(@MsgInfo,13,1) = 'Y' or Substring(@MsgInfo,13,1) = 'N'
				SELECT @TempChar = Substring(@MsgInfo,13,1)
			else
				SELECT @TempChar = ''
			UPDATE #TempTable SET AutoClose = @tempChar WHERE ExportMailBox = @ExportMailBox
		
			--exceptions
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20080',@MsgID)
			IF Substring(@MsgInfo,78,1) = 'Y' or Substring(@MsgInfo,78,1) = 'N'
				SELECT @TempChar = Substring(@MsgInfo,78,1)
			else
				SELECT @TempChar = ''
			UPDATE #TempTable SET AllowCloseExcep = @TempChar  WHERE ExportMailBox = @ExportMailBox
		
			--InFastMode
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20080',@MsgID)
			IF Substring(@MsgInfo,63,1) = 'Y' or Substring(@MsgInfo,63,1) = 'N'
				SELECT @TempChar = Substring(@MsgInfo,63,1)
			else
				SELECT @TempChar = ''
			UPDATE #TempTable SET InFastMode = @TempChar WHERE ExportMailBox = @ExportMailBox
		
			--OutFastMode
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20080',@MsgID)
			IF Substring(@MsgInfo,64,1) = 'Y' or Substring(@MsgInfo,64,1) = 'N'
				SELECT @TempChar = Substring(@MsgInfo,64,1)
			else
				SELECT @TempChar = ''
			UPDATE #TempTable SET OutFastMode = @TempChar WHERE ExportMailBox = @ExportMailBox
		
			--PrintReceipt
			DECLARE @TempMsg varchar(5)
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20080',@MsgID)
			IF (Substring(@MsgInfo,2,1) = '1')OR( Substring(@MsgInfo,2,1) = '2')
				SELECT @TempMsg = 'Disp '
			ELSE IF Substring(@MsgInfo,2,1) = '3' 
				SELECT @TempMsg = 'Print'
			ELSE IF Substring(@MsgInfo,2,1) = '3' 
				SELECT @TempMsg = '-'
			ELSE
				SELECT @TempMsg = '-'
				
			UPDATE #TempTable SET PrintReceipt = @TempMsg WHERE ExportMailBox = @ExportMailBox
		
			--Purge
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20080',@MsgID)
			IF Substring(@MsgInfo,84,1) = 'Y' or Substring(@MsgInfo,84,1) = 'N'
				SELECT @TempChar = Substring(@MsgInfo,84,1)
			else
				SELECT @TempChar = ''
			UPDATE #TempTable SET Purge = Substring(@MsgInfo,84,1) WHERE ExportMailBox = @ExportMailBox
		
			--Terminate
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20080',@MsgID)
			IF Substring(@MsgInfo,85,1) = 'Y' or Substring(@MsgInfo,85,1) = 'N'
				SELECT @TempChar = Substring(@MsgInfo,85,1)
			else
				SELECT @TempChar = ''
			UPDATE #TempTable SET Terminate = @TempChar WHERE ExportMailBox = @ExportMailBox
		
			--Xmite 
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20295',@MsgID)
			IF (IsNull(@msginfo, '') = '')
			BEGIN
				UPDATE #TempTable SET NextXmit = '' WHERE ExportMailBox = @ExportMailBox
			END
			ELSE
			BEGIN
				SELECT @tempDate = convert(varchar(10), (dateadd(dd, cast(substring(@msginfo, 6, 3) as int), '01/01/' + substring(@msginfo, 2, 4))) ,101) 
				SELECT @tempDate = @tempDate + ' ' + substring(@msginfo,9,2) +':' + substring(@msginfo,11,2)
				UPDATE #TempTable SET NextXmit = @tempDate WHERE ExportMailBox = @ExportMailBox
			END
			--print @tempDate
		  
			-- Next Close
			IF (IsNull(@msginfo, '') = '')
			BEGIN
				UPDATE #TempTable SET NextXmit = '' WHERE ExportMailBox = @ExportMailBox
			END
			ELSE
			BEGIN
				SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20294',@MsgID)
				SELECT @tempDate = convert(varchar(10),dateadd(dd,cast(substring(@msginfo,6,3) as int),'01/01/'+substring(@msginfo,2,4)),101) + ' ' + substring(@msginfo,9,2) +':' + substring(@msginfo,11,2)
				--print @tempDate
			  UPDATE #TempTable SET NextClose = @tempDate WHERE ExportMailBox = @ExportMailBox
			END
		--	print dateadd(left(2,substring(@msginfo,2,11)
			--UPDATE #TempTable SET Terminate = Substring(@MsgInfo,83,1) WHERE ExportMailBox = @ExportMailBox
		
			--OT scheduling
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20487',@MsgID)	
			IF Substring(@MsgInfo,2,1) = 'Y' or Substring(@MsgInfo,2,1) = 'N'
				SELECT @TempChar = Substring(@MsgInfo,2,1)
			else
				SELECT @TempChar = ''
		  UPDATE #TempTable SET OTScheduling = 	substring(@MsgInfo,2,1) 
			WHERE ExportMailBox = @ExportMailBox
		
			--weekly hrs before OT
			SELECT @tmpHrs = right(("0000" + substring(@MsgInfo,3,4)),4)
			SELECT @tmpHrs = substring(@tmpHrs,1,2) + '.' + substring(@tmpHrs,3,2)
		  UPDATE #TempTable SET WklyHrsBefOT = 	@tmpHrs 
			WHERE ExportMailBox = @ExportMailBox
		
			--weekly hrs before DT
			SELECT @tmpHrs = right(("0000" + substring(@MsgInfo,7,4)),4)
			SELECT @tmpHrs = substring(@tmpHrs,1,2) + '.' + substring(@tmpHrs,3,2)
		  UPDATE #TempTable SET WklyHrsBefDT = 	@tmpHrs
			WHERE ExportMailBox = @ExportMailBox
		
			--weekly hrs before DT
			SELECT @tmpHrs = right(("0000" + substring(@MsgInfo,11,4)),4)
			SELECT @tmpHrs = substring(@tmpHrs,1,2) + '.' + substring(@tmpHrs,3,2)
		  UPDATE #TempTable SET DailyHrsBefOT = 	@tmpHrs
			WHERE ExportMailBox = @ExportMailBox
		
			--weekly hrs before DT
			SELECT @tmpHrs = right(("0000" + substring(@MsgInfo,15,4)),4)
			SELECT @tmpHrs = substring(@tmpHrs,1,2) + '.' + substring(@tmpHrs,3,2)
		  UPDATE #TempTable SET DailyHrsBefDT = 	@tmpHrs 
			WHERE ExportMailBox = @ExportMailBox
		
			-- In out Windows
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^20271',@MsgID)
			DECLARE @Sched char(1)
			SELECT @Sched = substring(@MsgInfo,2,1)
			
			IF @Sched = 4 OR @Sched = 3 OR @Sched = 2
			BEGIN	
				IF @Sched = 4 OR @Sched = 2
				BEGIN 
					SELECT @tempTime = substring(@MsgInfo,3,4)
					UPDATE #TempTable SET SchedIn = left(@tempTime,2)+':'+right(@tempTime,2) 
					WHERE ExportMailBox = @ExportMailBox
				END
				IF @Sched = 4 OR @Sched = 3
				BEGIN
					SELECT @tempTime = substring(@MsgInfo,7,4)
					UPDATE #TempTable SET SchedOut =	left(@tempTime,2)+':'+right(@tempTime,2) 
					WHERE ExportMailBox = @ExportMailBox
				END
			END
			-- Manager Password
			DECLARE @TempPswd varchar(4)
			SELECT @TempPswd = '0000'
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^V=USR',@MsgID)	
		  UPDATE #TempTable SET MngrPass = 	right(@TempPswd + substring(@MsgInfo,2,4) ,4)
			WHERE ExportMailBox = @ExportMailBox
		
			declare @temp int
			declare @tempCheck varchar(1000)
			declare @count int 	
			select @count = 1 
			select @temp = -1
		
			SELECT @MsgInfo = Messages.dbo.fncGetAddr('^V=SRS',@MsgID)	
			IF len(@MsgInfo) > 12
			BEGIN
				SELECT @MsgInfo =substring(@MsgInfo,2,len(@MsgInfo)-2)
			
				WHILE @temp <> 0
				BEGIN
					SELECT @temp = charindex('\',@MsgInfo)
					--print substring(@MsgInfo,9,4)
					IF @count = 1
					BEGIN
						SELECT @tempTime = substring(@MsgInfo,9,4)
					  UPDATE #TempTable SET FirstBack = 	left(@tempTime,2) + ':' + right(@tempTime,2)
						WHERE ExportMailBox = @ExportMailBox		
					END
					IF @count = 2
					BEGIN
						SELECT @tempTime =  substring(@MsgInfo,9,4)
					  UPDATE #TempTable SET SecondBack= left(@tempTime,2)+':'+right(@tempTime,2)
						WHERE ExportMailBox = @ExportMailBox		
					END
					IF @count = 3
					BEGIN
						SELECT @tempTime = substring(@MsgInfo,9,4)
					  UPDATE #TempTable SET ThirdBack= 	left(@tempTime,2) + right(@tempTime,2)
						WHERE ExportMailBox = @ExportMailBox		
					END
					IF @count = 4
					BEGIN
						SELECT @tempTime = substring(@MsgInfo,9,4)
					  UPDATE #TempTable SET FourthBack = 		left(@tempTime,2) + right(@tempTime,2)
						WHERE ExportMailBox = @ExportMailBox		
					END
			
					SELECT @MsgInfo = substring(@MsgInfo,@temp+1,len(@MsgInfo)-@temp)
					SELECT @count = @count + 1
				END
			END
		END
	END
	--print @Hrs
	--print @Sched
	FETCH NEXT FROM MBoxCursor 
		INTO @SiteNo, @SiteName, @ExportMailBox
END

CLOSE MBoxCursor
DEALLOCATE MBoxCursor

select * from #tempTable
drop table #tempTable




