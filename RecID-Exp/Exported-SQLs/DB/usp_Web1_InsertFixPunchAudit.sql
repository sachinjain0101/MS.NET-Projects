CREATE  procedure [dbo].[usp_Web1_InsertFixPunchAudit]
(
    @Client char(4)
  , @GroupCode int
  , @SiteNo INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 14Sept2016 >--
  , @DeptNo INT  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 14Sept2016 >--
  , @SSN int
  , @OrigRecordId int 
  , @UserID varchar(10)
  , @PunchType char(1) 
  , @PunchDateTime datetime
  , @FixedBy varchar(3)
)
AS


SET NOCOUNT ON

Insert into TimeHistory..tblFixPunchAudit
values (@Client, @GroupCode, @SiteNo, @DeptNo, @SSN, @OrigRecordId,@UserID,@PunchType,@PunchDateTime,@FixedBy,getdate())




