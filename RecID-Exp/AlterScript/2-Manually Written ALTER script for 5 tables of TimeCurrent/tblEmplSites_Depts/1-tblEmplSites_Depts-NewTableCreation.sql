USE [TimeCurrent]
GO
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND type in (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblEmplSites_DeptsNew table ...'
	CREATE TABLE [dbo].[tblEmplSites_DeptsNew](
	[RecordID] [int] IDENTITY(1,1) NOT NULL,
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL,
	[SiteNo] [INT] NOT NULL,
	[SSN] [int] NOT NULL,
	[DeptSeq] [smallint] NULL,
	[DeptNo] [INT] NOT NULL,
	[AssignmentNo] [varchar](32) NULL,
	[JobAssignmentNo] [varchar](7) NULL,
	[PayRate] [numeric](7, 2) NULL,
	[BillRate] [numeric](7, 2) NULL,
	[NewPNE_Entry] [char](1) NULL,
	[RecordStatus] [char](1) NULL,
	[DateLastUpdated] [datetime] NULL,
	[AssignmentStartDate] [datetime] NULL,
	[PurchOrderNo] [varchar](30) NULL,
	[InLastClkBkp] [char](1) NOT NULL CONSTRAINT [DF_tblEmplSites_Depts_InLastClkBkpNew]  DEFAULT ('0'),
	[MaintUserName] [varchar](20) NULL,
	[BillingOvertimeCalcFactor] [numeric](15, 10) NULL,
	[Timesheetimage] [varchar](80) NULL,
	[BillingDoubleTimeCalcFactor] [numeric](15, 10) NULL,
	 CONSTRAINT [PK_tblEmplSites_RecIdNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_tblEmplSites_ClientGrpCdSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_ClientGrpCdSite index ...'
	CREATE CLUSTERED INDEX [IX_tblEmplSites_ClientGrpCdSite] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[GroupCode] ASC,
		[SSN] ASC,
		[SiteNo] ASC,
		[Client] ASC,
		[DeptNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO
USE [TimeCurrent]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblEmplSites_DeptsNew ON
SET NOCOUNT ON
INSERT INTO [dbo].[tblEmplSites_DeptsNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[SiteNo]
           ,[SSN]
           ,[DeptSeq]
           ,[DeptNo]
           ,[AssignmentNo]
           ,[JobAssignmentNo]
           ,[PayRate]
           ,[BillRate]
           ,[NewPNE_Entry]
           ,[RecordStatus]
           ,[DateLastUpdated]
           ,[AssignmentStartDate]
           ,[PurchOrderNo]
           ,[InLastClkBkp]
           ,[MaintUserName]
           ,[BillingOvertimeCalcFactor]
           ,[Timesheetimage]
           ,[BillingDoubleTimeCalcFactor])
SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[SiteNo]
      ,[SSN]
      ,[DeptSeq]
      ,[DeptNo]
      ,[AssignmentNo]
      ,[JobAssignmentNo]
      ,[PayRate]
      ,[BillRate]
      ,[NewPNE_Entry]
      ,[RecordStatus]
      ,[DateLastUpdated]
      ,[AssignmentStartDate]
      ,[PurchOrderNo]
      ,[InLastClkBkp]
      ,[MaintUserName]
      ,[BillingOvertimeCalcFactor]
      ,[Timesheetimage]
      ,[BillingDoubleTimeCalcFactor]
  FROM [dbo].[tblEmplSites_Depts]

  IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'ix_emplSites_Dept_SiteNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_emplSites_Dept_SiteNo index ...'
	CREATE NONCLUSTERED INDEX [ix_emplSites_Dept_SiteNo] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_tblEmplSites_Depts_CliGrpCdDeptNoSSNSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_Depts_CliGrpCdDeptNoSSNSite index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_Depts_CliGrpCdDeptNoSSNSite] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[DeptNo] ASC,
		[SSN] ASC,
		[SiteNo] ASC
	)
	INCLUDE ( 	[BillingOvertimeCalcFactor]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, 
	ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_tblEmplSites_Depts_CliGrpCdRecStat')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_Depts_CliGrpCdRecStat index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_Depts_CliGrpCdRecStat] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[RecordStatus] ASC
	)
	INCLUDE ( 	[SiteNo],
	[SSN],
	[DeptNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'ix_tblEmplSites_Depts_DeptNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_tblEmplSites_Depts_DeptNo index ...'
	CREATE NONCLUSTERED INDEX [ix_tblEmplSites_Depts_DeptNo] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[DeptNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_TblEmplSites_Depts_PNE')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_TblEmplSites_Depts_PNE index ...'
	CREATE NONCLUSTERED INDEX [IX_TblEmplSites_Depts_PNE] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[NewPNE_Entry] ASC,
		[RecordStatus] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_tblEmplSites_Depts_SiteCliGrpCdRecStatSSNDept')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_Depts_SiteCliGrpCdRecStatSSNDept index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_Depts_SiteCliGrpCdRecStatSSNDept] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[SiteNo] ASC,
		[Client] ASC,
		[GroupCode] ASC,
		[RecordStatus] ASC,
		[SSN] ASC,
		[DeptNo] ASC
	)
	INCLUDE ( 	[RecordID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) 
	ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'tblemplsites_depts0')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblemplsites_depts0 index ...'
	CREATE NONCLUSTERED INDEX [tblemplsites_depts0] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[SSN] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90)
	END
GO