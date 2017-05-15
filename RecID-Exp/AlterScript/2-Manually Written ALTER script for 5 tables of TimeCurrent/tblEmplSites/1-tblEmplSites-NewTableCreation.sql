USE [TimeCurrent]
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
	[DateLastUpdated] [datetime] NULL,
	[MaintDateTime] [datetime] NULL,
	[ShiftDiffClass] [char](1) NOT NULL CONSTRAINT [DF_tblEmplSites_ShiftDiffClassNew]  DEFAULT (''),
	[NewRecord] [tinyint] NOT NULL CONSTRAINT [DF_tblEmplSites_NewRecordNew]  DEFAULT (1),
	[MaintUserName] [varchar](20) NULL,
	[EmplClassID] [int] NULL,
	 CONSTRAINT [PK_tblEmplSitesNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_ClientGrpSiteSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_ClientGrpSiteSSN index ...'
	CREATE UNIQUE CLUSTERED INDEX [IX_tblEmplSites_ClientGrpSiteSSN] ON [dbo].[tblEmplSitesNew]
	(
		[GroupCode] ASC,
		[SSN] ASC,
		[SiteNo] ASC,
		[Client] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblEmplSitesNew ON
SET NOCOUNT ON
INSERT INTO [dbo].[tblEmplSitesNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
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
           ,[DateLastUpdated]
           ,[MaintDateTime]
           ,[ShiftDiffClass]
           ,[NewRecord]
           ,[MaintUserName]
           ,[EmplClassID])

SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
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
      ,[DateLastUpdated]
      ,[MaintDateTime]
      ,[ShiftDiffClass]
      ,[NewRecord]
      ,[MaintUserName]
      ,[EmplClassID]
  FROM [dbo].[tblEmplSites]

  IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites] ON [dbo].[tblEmplSitesNew]
	(
		[SSN] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_RecStatSiteGrpCdCliSSNStatus')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_RecStatSiteGrpCdCliSSNStatus index ...'
	
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_RecStatSiteGrpCdCliSSNStatus] ON [dbo].[tblEmplSitesNew]
	(
		[RecordStatus] ASC,
		[SiteNo] ASC,
		[GroupCode] ASC,
		[Client] ASC,
		[SSN] ASC,
		[Status] ASC
	)
	INCLUDE ( 	[RecordID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) 
	ON	[PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_SiteCliRecStatStatGrpCdSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_SiteCliRecStatStatGrpCdSSN index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_SiteCliRecStatStatGrpCdSSN] ON [dbo].[tblEmplSitesNew]
	(
		[SiteNo] ASC,
		[Client] ASC,
		[RecordStatus] ASC,
		[Status] ASC,
		[GroupCode] ASC,
		[SSN] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSitesNew]') AND name = N'IX_tblEmplSites_SSNGrpCD')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_SSNGrpCD index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_SSNGrpCD] ON [dbo].[tblEmplSitesNew]
	(
		[SSN] ASC,
		[GroupCode] ASC,
		[SiteNo] ASC,
		[Client] ASC,
		[EmplClassID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
