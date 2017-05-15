USE [TimeHistory]
GO
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND type in (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblEmplSitesNew table ...'
	CREATE TABLE [dbo].[tblEmplSitesNew](
	[RecordID] [int] IDENTITY(1,1) NOT NULL,
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL,
	[PayrollPeriodEndDate] [datetime] NOT NULL,
	[SiteNo] [INT] NOT NULL,
	[SSN] [int] NOT NULL,
	[Status] [char](1) NULL,
	[AgencyNo] [smallint] NULL,
	[ShiftClass] [smallint] NULL,
	[ScheduledShift] [smallint] NULL,
	[OpenDepartments] [smallint] NULL,
	[PayType] [tinyint] NULL,
	[ScheduledDays] [smallint] NULL,
	[BaseHours] [numeric](5, 2) NULL,
	[ShiftDiff] [char](1) NULL,
	[Borrowed] [char](1) NULL,
	[NewPNE_Entry] [char](1) NULL,
	[RecordStatus] [char](1) NULL,
	[ShiftDiffClass] [char](1) NULL CONSTRAINT [DF_tblEmplSites_ShiftDiffClassNew]  DEFAULT (''),
	[EmplClassID] [int] NULL,
	[EmplApprovalDate] [datetime] NULL,
 CONSTRAINT [PK_tblEmplSitesNew] PRIMARY KEY NONCLUSTERED 
(
	[RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_ClientGrpCdPPEndDateSiteNoSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_ClientGrpCdPPEndDateSiteNoSSN index ...'
	CREATE CLUSTERED INDEX [IX_tblEmplSites_ClientGrpCdPPEndDateSiteNoSSN] ON [dbo].[tblEmplSitesNew]
	(
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SSN] ASC,
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeHistory]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblEmplSitesNew ON
SET NOCOUNT ON

INSERT INTO [dbo].[tblEmplSitesNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[PayrollPeriodEndDate]
           ,[SiteNo]
           ,[SSN]
           ,[Status]
           ,[AgencyNo]
           ,[ShiftClass]
           ,[ScheduledShift]
           ,[OpenDepartments]
           ,[PayType]
           ,[ScheduledDays]
           ,[BaseHours]
           ,[ShiftDiff]
           ,[Borrowed]
           ,[NewPNE_Entry]
           ,[RecordStatus]
           ,[ShiftDiffClass]
           ,[EmplClassID]
           ,[EmplApprovalDate])

SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[PayrollPeriodEndDate]
      ,[SiteNo]
      ,[SSN]
      ,[Status]
      ,[AgencyNo]
      ,[ShiftClass]
      ,[ScheduledShift]
      ,[OpenDepartments]
      ,[PayType]
      ,[ScheduledDays]
      ,[BaseHours]
      ,[ShiftDiff]
      ,[Borrowed]
      ,[NewPNE_Entry]
      ,[RecordStatus]
      ,[ShiftDiffClass]
      ,[EmplClassID]
      ,[EmplApprovalDate]
  FROM [dbo].[tblEmplSites]

  USE TimeHistory
  GO


IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_ClientGrpCdPPEndDate')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_ClientGrpCdPPEndDate index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_ClientGrpCdPPEndDate] ON [dbo].[tblEmplSitesNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC
	)
	INCLUDE ( 	[SiteNo],
	[SSN]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_ClientGrpCdSSNStatus')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_ClientGrpCdSSNStatus index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_ClientGrpCdSSNStatus] ON [dbo].[tblEmplSitesNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SSN] ASC,
		[Status] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_CliSiteGrpCdPPEDStatSSNEmpClsID')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_CliSiteGrpCdPPEDStatSSNEmpClsID index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_CliSiteGrpCdPPEDStatSSNEmpClsID] ON [dbo].[tblEmplSitesNew]
	(
		[Client] ASC,
		[SiteNo] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[Status] ASC,
		[SSN] ASC,
		[EmplClassID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_GrpCdCliPPEDSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_GrpCdCliPPEDSite index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_GrpCdCliPPEDSite] ON [dbo].[tblEmplSitesNew]
	(
		[GroupCode] ASC,
		[Client] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'ix_tblEmplSites_ssn_pped')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_tblEmplSites_ssn_pped index ...'
	CREATE NONCLUSTERED INDEX [ix_tblEmplSites_ssn_pped] ON [dbo].[tblEmplSitesNew]
	(
		[SSN] ASC,
		[PayrollPeriodEndDate] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO