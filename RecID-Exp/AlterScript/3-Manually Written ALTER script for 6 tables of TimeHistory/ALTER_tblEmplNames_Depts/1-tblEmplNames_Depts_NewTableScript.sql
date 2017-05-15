USE [TimeHistory]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplNames_DeptsNew]') AND type in (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblEmplNames_DeptsNew table ...'
	CREATE TABLE [dbo].[tblEmplNames_DeptsNew](
	[RecordID] [int] IDENTITY(1,1) NOT NULL,
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL,
	[PayrollPeriodEndDate] [datetime] NOT NULL,
	[SSN] [int] NOT NULL,
	[DeptSeq] [smallint] NOT NULL,
	[Department] [INT] NOT NULL,
	[PayRate] [numeric](7, 2) NULL,
	[BillRate] [numeric](7, 2) NULL,
	[ManagerAuth] [char](1) NULL,
	[NewPNE_Entry] [char](1) NULL,
	[AssignmentNo] [varchar](32) NULL,
	[AssignmentStartDate] [datetime] NULL,
	[PurchOrderNo] [varchar](30) NULL,
	[RecordStatus] [char](1) NULL,
	[ExcludeFromUpload] [char](1) NULL CONSTRAINT [DF_tblEmplNames_Depts_ExcludeFromUploadNew]  DEFAULT (0),
	[ExcludeFromUpload_UserID] [int] NULL,
	[ExcludeFromUpload_DateTime] [datetime] NULL,
	[Custom1] [varchar](50) NULL,
	[Custom2] [varchar](50) NULL,
	[VMS_ID] [varchar](32) NULL,
	[vmsCostCenter] [varchar](32) NULL,
	[AprvlStatus] [varchar](1) NULL,
	[ACA_Rate] [numeric](9, 2) NULL,
	CONSTRAINT [PK_tblEmplNames_DeptsNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplNames_DeptsNew]') AND name = N'IX_tblEmplNames_Depts_ClientGrpPPSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplNames_Depts_ClientGrpPPSSN index ...'
		CREATE UNIQUE CLUSTERED INDEX [IX_tblEmplNames_Depts_ClientGrpPPSSN] ON [dbo].[tblEmplNames_DeptsNew]
		(
			[Client] ASC,
			[GroupCode] ASC,
			[PayrollPeriodEndDate] ASC,
			[SSN] ASC,
			[DeptSeq] ASC,
			[Department] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90)
		 ON	[PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeHistory]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblEmplNames_DeptsNew ON
SET NOCOUNT ON

INSERT INTO [dbo].[tblEmplNames_DeptsNew]
           ([Client]
           ,[GroupCode]
           ,[PayrollPeriodEndDate]
           ,[SSN]
           ,[DeptSeq]
           ,[Department]
           ,[PayRate]
           ,[BillRate]
           ,[ManagerAuth]
           ,[NewPNE_Entry]
           ,[AssignmentNo]
           ,[AssignmentStartDate]
           ,[PurchOrderNo]
           ,[RecordStatus]
           ,[ExcludeFromUpload]
           ,[ExcludeFromUpload_UserID]
           ,[ExcludeFromUpload_DateTime]
           ,[Custom1]
           ,[Custom2]
           ,[VMS_ID]
           ,[vmsCostCenter]
           ,[AprvlStatus]
           ,[ACA_Rate])
SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[PayrollPeriodEndDate]
      ,[SSN]
      ,[DeptSeq]
      ,[Department]
      ,[PayRate]
      ,[BillRate]
      ,[ManagerAuth]
      ,[NewPNE_Entry]
      ,[AssignmentNo]
      ,[AssignmentStartDate]
      ,[PurchOrderNo]
      ,[RecordStatus]
      ,[ExcludeFromUpload]
      ,[ExcludeFromUpload_UserID]
      ,[ExcludeFromUpload_DateTime]
      ,[Custom1]
      ,[Custom2]
      ,[VMS_ID]
      ,[vmsCostCenter]
      ,[AprvlStatus]
      ,[ACA_Rate]
  FROM [dbo].[tblEmplNames_Depts]

USE TimeHistory
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplNames_DeptsNew]') AND name = N'ix_tblempldept_excludeupload')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_tblempldept_excludeupload index ...'
	CREATE NONCLUSTERED INDEX [ix_tblempldept_excludeupload] ON [dbo].[tblEmplNames_DeptsNew]
	(
		[ExcludeFromUpload] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
