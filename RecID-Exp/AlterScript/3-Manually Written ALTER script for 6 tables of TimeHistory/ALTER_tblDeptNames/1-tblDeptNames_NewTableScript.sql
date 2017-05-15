USE [TimeHistory]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblDeptNamesNew]') AND type in (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblDeptNamesNew table ...'
	CREATE TABLE [dbo].[tblDeptNamesNew](
	[RecordID] [int] IDENTITY(1,1) NOT NULL,
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL,
	[PayrollPeriodEndDate] [datetime] NOT NULL,
	[SiteNo] [INT] NOT NULL,
	[DeptNo] [INT] NOT NULL,
	[DeptName] [varchar](30) NULL,
	[ClientDeptCode] [varchar](100) NULL,
	CONSTRAINT [PK_tblDeptNamesNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO


IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblDeptNamesNew]') AND name = N'IX_tblDeptNames_ClientGrpCdPPEndSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblDeptNames_ClientGrpCdPPEndSite index ...'
	CREATE UNIQUE CLUSTERED INDEX [IX_tblDeptNames_ClientGrpCdPPEndSite] ON [dbo].[tblDeptNamesNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC,
		[DeptNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeHistory]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblDeptNamesNew ON
SET NOCOUNT ON

INSERT INTO [dbo].[tblDeptNamesNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[PayrollPeriodEndDate]
           ,[SiteNo]
           ,[DeptNo]
           ,[DeptName]
           ,[ClientDeptCode])
SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[PayrollPeriodEndDate]
      ,[SiteNo]
      ,[DeptNo]
      ,[DeptName]
      ,[ClientDeptCode]
  FROM [dbo].[tblDeptNames]

Use TimeHistory
GO
