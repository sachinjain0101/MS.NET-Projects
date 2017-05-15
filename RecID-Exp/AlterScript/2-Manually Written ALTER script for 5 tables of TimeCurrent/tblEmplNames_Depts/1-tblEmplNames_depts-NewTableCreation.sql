USE [TimeCurrent]
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
	[SSN] [int] NOT NULL,
	[DeptSeq] [smallint] NOT NULL,
	[Department] [INT] NOT NULL,
	[PayRate] [numeric](7, 2) NULL,
	[BillRate] [numeric](7, 2) NULL,
	[ManagerAuth] [char](1) NULL,
	[NewPNE_Entry] [char](1) NULL,
	[RecordStatus] [char](1) NULL,
	[DateLastUpdated] [datetime] NULL,
	[AssignmentNo] [varchar](32) NULL,
	[AssignmentStartDate] [datetime] NULL,
	[PurchOrderNo] [varchar](30) NULL,
	[LastReviewDate] [datetime] NULL,
	[MaintUserName] [varchar](20) NULL,
	[RateEffectiveDate] [datetime] NULL,
	[Custom1] [varchar](50) NULL,
	[Custom2] [varchar](50) NULL,
	[OTMult] [numeric](15, 10) NULL,
	[DTMult] [numeric](15, 10) NULL,
	[VMS_ID] [varchar](32) NULL,
	[vmsCostCenter] [varchar](32) NULL,
	[ACA_Rate] [numeric](9, 2) NULL,
	CONSTRAINT [PK_tblEmplNames_Depts_RecIdNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplNames_DeptsNew]') AND name = N'IX_tblEmplNames_Depts_ClientGrpSsnDept')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplNames_Depts_ClientGrpSsnDept index ...'
	CREATE UNIQUE CLUSTERED INDEX [IX_tblEmplNames_Depts_ClientGrpSsnDept] ON [dbo].[tblEmplNames_DeptsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SSN] ASC,
		[Department] ASC,
		[RecordStatus] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeCurrent]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblEmplNames_DeptsNew ON
SET NOCOUNT ON
INSERT INTO [dbo].[tblEmplNames_DeptsNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[SSN]
           ,[DeptSeq]
           ,[Department]
           ,[PayRate]
           ,[BillRate]
           ,[ManagerAuth]
           ,[NewPNE_Entry]
           ,[RecordStatus]
           ,[DateLastUpdated]
           ,[AssignmentNo]
           ,[AssignmentStartDate]
           ,[PurchOrderNo]
           ,[LastReviewDate]
           ,[MaintUserName]
           ,[RateEffectiveDate]
           ,[Custom1]
           ,[Custom2]
           ,[OTMult]
           ,[DTMult]
           ,[VMS_ID]
           ,[vmsCostCenter]
           ,[ACA_Rate])
SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[SSN]
      ,[DeptSeq]
      ,[Department]
      ,[PayRate]
      ,[BillRate]
      ,[ManagerAuth]
      ,[NewPNE_Entry]
      ,[RecordStatus]
      ,[DateLastUpdated]
      ,[AssignmentNo]
      ,[AssignmentStartDate]
      ,[PurchOrderNo]
      ,[LastReviewDate]
      ,[MaintUserName]
      ,[RateEffectiveDate]
      ,[Custom1]
      ,[Custom2]
      ,[OTMult]
      ,[DTMult]
      ,[VMS_ID]
      ,[vmsCostCenter]
      ,[ACA_Rate]
  FROM [dbo].[tblEmplNames_Depts]

  GO
  IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplNames_DeptsNew]') AND name = N'ix_tblemplnames_depts_clgrpDept')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_tblemplnames_depts_clgrpDept index ...'
	CREATE NONCLUSTERED INDEX [ix_tblemplnames_depts_clgrpDept] ON [dbo].[tblEmplNames_DeptsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[Department] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplNames_DeptsNew]') AND name = N'IX_tblEmplnames_Depts_PNE')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplnames_Depts_PNE index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplnames_Depts_PNE] ON [dbo].[tblEmplNames_DeptsNew]
	(
		[NewPNE_Entry] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO