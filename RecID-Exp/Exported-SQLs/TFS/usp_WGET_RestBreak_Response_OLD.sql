Create PROCEDURE [dbo].[usp_WGET_RestBreak_Response_OLD]
(
  @TermID varchar(20),
  @Ver varchar(20),
  @Request varchar(20),
  @SerialNo varchar(20),
  @IPAddress varchar(32),
  @EmplBadge varchar(20),
  @ThisPunch varchar(20),
  @Answer varchar(20),
  @thdRecordId BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
)
AS

SET NOCOUNT ON

DECLARE @Client varchar(4)
DECLARE @Groupcode int
DECLARE @SSN int
DECLARE @PPED DATETIME
DECLARE @TransDate DATETIME
DECLARE @DeptNo INT
DECLARE @MPD DATETIME 
DECLARE @Amount NUMERIC(7, 2)
DECLARE @AdjCode CHAR(1)
DECLARE @SiteNo INT
DECLARE @SiteState VARCHAR(4)
DECLARE @Comment VARCHAR(200)
DECLARE @MissedDuetoWork int
DECLARE @MissedChoice int
DECLARE @Source INT

Set @Source = 13

Select @Client = Client, 
  @Groupcode = GroupCode,
  @SiteState = SiteState
from TImeCurrent..tblSiteNames with(nolock)
where exportmailbox = @TermID


SELECT  
  @PPED = Payrollperiodenddate ,
  @SSN = SSN,
  @Transdate = TransDate ,
  @SiteNo = Siteno ,
  @DeptNo = DeptNo ,
  @MPD = Masterpayrolldate
FROM TImeHistory..tblTimeHistDetail WITH ( NOLOCK )
WHERE 
  Client = @client 
and groupcode = @Groupcode
and Recordid >= @thdRecordID


IF isnull(@SSN,0) = 0
BEGIN
  -- Need to record some type of error here.
  INSERT INTO Audit.[dbo].[tblSimpleAuditLog]([DateTimeAdded],[LogSource],[LogID1],[LogID2],[LogID3],[LogID4],[LogID5],[LogMessage])
  VALUES(getdate(), 'Pendo-usp_WGET_RestBreak_Response',@TermID,@Request,ltrim(str(@EmplBadge)),@ThisPunch,ltrim(str(@thdRecordId)),'thd Record not found. SSN Invalid' )
  RETURN
END

-- The @Answer contains the missed breaks entered on the clock by the employee
--  First char = number of missed breaks 
--
if LEN(@Answer) <> 1
BEGIN
  -- Need to record some type of error here.
  Set @Comment = 'Bad Answer from clock [' + @Answer + ']'
  INSERT INTO Audit.[dbo].[tblSimpleAuditLog]([DateTimeAdded],[LogSource],[LogID1],[LogID2],[LogID3],[LogID4],[LogID5],[LogMessage])
  VALUES(getdate(), 'Pendo-usp_WGET_RestBreak_Response',@TermID,@Request,ltrim(str(@EmplBadge)),@ThisPunch,ltrim(str(@thdRecordId)),@Comment )
  RETURN
END

Set @MissedDuetoWork = left(@Answer,1) 
--Set @MissedChoice = right(@Answer,1)

IF @SiteState = 'WA'
BEGIN  
  SET @AdjCode = '0'
  SET @Amount = round(@MissedDuetoWork * 10.00/60.00,2)	
END
IF @SiteState = 'CA'
BEGIN  
  SET @AdjCode = 'H'
  SET @Amount = 0
END

/*
IF @MissedChoice > 0 
BEGIN

  SET @Comment = 'REST BREAK RESPONSE - ' + CONVERT(VARCHAR(12), @Transdate, 101) + ' : Employee entered ' + ltrim(str(@MissedChoice)) + 
  + ' missed rest break' + CASE WHEN @MissedDuetoWork > 1 THEN 's' ELSE '' END + ' by choice.'

  INSERT  INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
          ( [Client] ,
            [GroupCode] ,
            [PayrollPeriodEndDate] ,
            [SSN] ,
            [CreateDate] ,
            [Comments] ,
            [UserID] ,
            [UserName] ,
            [ManuallyAdded] ,
            [SiteNo] ,
            [DeptNo] ,
            [CommentSourceID]
          )
  VALUES  ( @Client ,
            @Groupcode ,
            @PPED ,
            @SSN ,
            GETDATE() ,
            @Comment ,
            0 ,
            'Employee at Clock' ,
            0 ,
            @SiteNo ,
            @DeptNo ,
            @Source
          )

END
*/

IF @MissedDuetoWork > 0 
BEGIN

  DECLARE @AdjustmentName varchar(10)
  Set @AdjustmentName = left('NO_RSTBRK' + ltrim(str(@MissedDueToWork)) ,10)

  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD]
      @Client ,
      @GroupCode ,
      @PPED ,
      @SSN ,
      @SiteNo ,
      @DeptNo ,
      @AdjCode ,
      @AdjustmentName,
      @Amount ,
      0.00 ,
      @TransDate ,
      @MPD ,
      'SYS' ,
      'N'

  SET @Comment = 'REST BREAK RESPONSE - ' + CONVERT(VARCHAR(12), @Transdate, 101) + ' : Employee entered ' + ltrim(str(@MissedDuetoWork)) + 
  + ' missed rest break' + CASE WHEN @MissedDuetoWork > 1 THEN 's' ELSE '' END + ' due to work.'

  INSERT  INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
          ( [Client] ,
            [GroupCode] ,
            [PayrollPeriodEndDate] ,
            [SSN] ,
            [CreateDate] ,
            [Comments] ,
            [UserID] ,
            [UserName] ,
            [ManuallyAdded] ,
            [SiteNo] ,
            [DeptNo] ,
            [CommentSourceID]
          )
  VALUES  ( @Client ,
            @Groupcode ,
            @PPED ,
            @SSN ,
            GETDATE() ,
            @Comment ,
            0 ,
            'Employee at Clock' ,
            0 ,
            @SiteNo ,
            @DeptNo ,
            @Source
          )

  select Client = @Client, GroupCode = @groupcode, PPED = @PPED, SSN = @SSN 

END


