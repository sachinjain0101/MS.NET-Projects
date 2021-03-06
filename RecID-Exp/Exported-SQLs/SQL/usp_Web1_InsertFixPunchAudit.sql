USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_InsertFixPunchAudit]    Script Date: 3/31/2015 11:53:40 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_Web1_InsertFixPunchAudit]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_InsertFixPunchAudit] AS' 
END
GO

ALTER  procedure [dbo].[usp_Web1_InsertFixPunchAudit]
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




GO
