USE [TimeCurrent]
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
	[SiteNo] [INT] NOT NULL,
	[DeptNo] [INT] NOT NULL,
	[DeptName] [varchar](30) NULL CONSTRAINT [DF_tblDeptNames_DeptNameNew]  DEFAULT (' '),
	[DeptName_Long] [varchar](50) NOT NULL CONSTRAINT [DF_tblDeptNames_DeptName_LongNew]  DEFAULT (''),
	[RecordStatus] [char](1) NULL,
	[DateLastUpdated] [datetime] NULL,
	[ClientDeptCode] [varchar](100) NULL,
	[MaintUserName] [varchar](20) NULL,
	[MaintUserID] [int] NULL,
	[MaintDateTime] [datetime] NULL,
	[NewPNE_Entry] [char](1) NULL,
	[SweptDateTime] [datetime] NULL,
	[AppliesToShiftDiff] [char](1) NOT NULL CONSTRAINT [DF_tblDeptNames_AppliesToShiftDiffNew]  DEFAULT (0),
	CONSTRAINT [PK_tblDeptNamesNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblDeptNamesNew]') AND name = N'IX_tblDeptNames_ClientDeptCode')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblDeptNames_ClientDeptCode index ...'
	CREATE UNIQUE CLUSTERED INDEX [IX_tblDeptNames_ClientDeptCode] ON [dbo].[tblDeptNamesNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[DeptNo] ASC,
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeCurrent]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblDeptNamesNew ON
SET NOCOUNT ON

INSERT INTO [dbo].[tblDeptNamesNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[SiteNo]
           ,[DeptNo]
           ,[DeptName]
           ,[DeptName_Long]
           ,[RecordStatus]
           ,[DateLastUpdated]
           ,[ClientDeptCode]
           ,[MaintUserName]
           ,[MaintUserID]
           ,[MaintDateTime]
           ,[NewPNE_Entry]
           ,[SweptDateTime]
           ,[AppliesToShiftDiff])
SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[SiteNo]
      ,[DeptNo]
      ,[DeptName]
      ,[DeptName_Long]
      ,[RecordStatus]
      ,[DateLastUpdated]
      ,[ClientDeptCode]
      ,[MaintUserName]
      ,[MaintUserID]
      ,[MaintDateTime]
      ,[NewPNE_Entry]
      ,[SweptDateTime]
      ,[AppliesToShiftDiff]
  FROM [dbo].[tblDeptNames]

  IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblDeptNamesNew]') AND name = N'IX_tblDeptNames_ClientGrpCodeSiteRecStat')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblDeptNames_ClientGrpCodeSiteRecStat index ...'
	CREATE NONCLUSTERED INDEX [IX_tblDeptNames_ClientGrpCodeSiteRecStat] ON [dbo].[tblDeptNamesNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SiteNo] ASC,
		[RecordStatus] ASC
	)
	INCLUDE ( 	[DeptNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblDeptNamesNew]') AND name = N'ix_tblDeptNames_deptSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_tblDeptNames_deptSite index ...'
	CREATE NONCLUSTERED INDEX [ix_tblDeptNames_deptSite] ON [dbo].[tblDeptNamesNew]
	(
		[DeptNo] ASC,
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblDeptNamesNew]') AND name = N'IX_TblDeptNames_PNE')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_TblDeptNames_PNE index ...'
	CREATE NONCLUSTERED INDEX [IX_TblDeptNames_PNE] ON [dbo].[tblDeptNamesNew]
	(
		[NewPNE_Entry] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

--IF NOT EXISTS (select s.* from sys.triggers s inner join sys.objects o on s.parent_id = o.object_id where s.name= N'trg_DeptNames_SyncMultiSupplier' and o.name='tblDeptNamesNew')
--	BEGIN

		--------------------------------------
		--Creating Triggers for new table
		--------------------------------------
		PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create trg_DeptNames_SyncMultiSupplier Trigger ...';

		go
		CREATE TRIGGER [dbo].[trg_DeptNames_SyncMultiSupplierNew] ON [dbo].[tblDeptNamesNew]

		AFTER INSERT, UPDATE

		AS

		DECLARE @Client VARCHAR(4)
		DECLARE @GoupCode INT

		SELECT @Client = Client,
			   @GoupCode = GroupCode
		FROM Inserted

		UPDATE TimeCurrent..tblClients_Sharing_GroupMapping
		SET NeedsSync = '1'
		WHERE SharingID IN (
		SELECT csgm.SharingID
		FROM TimeCurrent..tblClients_Sharing cs
		INNER JOIN TimeCurrent..tblClients_Sharing_GroupMapping csgm
		ON cs.SharingID = csgm.SharingID
		INNER JOIN TimeCurrent..tblClientGroups cgBuyer
		ON cgBuyer.RecordId = csgm.BuyerClientGroupsRecordID
		INNER JOIN TimeCurrent..tblClientGroups cgSupplier
		ON cgSupplier.RecordId = csgm.SupplierClientGroupsRecordID
		WHERE (cs.DestinationClient = @Client AND cgSupplier.GroupCode = @GoupCode)
		OR (cs.SourceClient = @Client AND cgBuyer.GroupCode = @GoupCode)
		)

		PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create trg_DeptNamesInsUpd Trigger ...';

		GO
			CREATE TRIGGER [dbo].[trg_DeptNamesInsUpdNew] ON [dbo].[tblDeptNamesNew]
			FOR INSERT, UPDATE
			AS
			SET NOCOUNT ON
 
			DECLARE @AudHostName varchar(100)
			DECLARE @AudProgName varchar(100)
 
			SELECT @AudHostName = RTRIM(HostName), @AudProgName = RTRIM(Program_Name)
			FROM master..sysprocesses
			WHERE spid = @@spid
 
			IF (@AudProgName IN ('','SetupClients','.Net SqlClient Data Provider'))
			BEGIN
 
			DECLARE @OldMaintDateTime datetime
			DECLARE @NewMaintDateTime datetime
			DECLARE @MaintDateTime datetime
			DECLARE @MaintUserName varchar(20)
			DECLARE @AuditId integer
			DECLARE @AuditMasterObjectId integer
			DECLARE @AuditMasterTableId integer
			DECLARE @UserAction char(1)
			DECLARE @TableName varchar(100)
			DECLARE @OldRecordId integer
			DECLARE @NewRecordId integer
			DECLARE @OldSiteNo INT
			DECLARE @NewSiteNo INT
			DECLARE @OldRecordStatus char(1)
			DECLARE @NewRecordStatus char(1)
			DECLARE @OldAppliesToShiftDiff char(1)
			DECLARE @NewAppliesToShiftDiff char(1)
			DECLARE @OldClientDeptCode varchar(32)
			DECLARE @NewClientDeptCode varchar(32)
			DECLARE @OldDeptNo INT
			DECLARE @NewDeptNo INT
			DECLARE @OldClient char(4)
			DECLARE @NewClient char(4)
			DECLARE @OldDeptName_Long varchar(50)
			DECLARE @NewDeptName_Long varchar(50)
			DECLARE @OldDeptName varchar(30)
			DECLARE @NewDeptName varchar(30)
			DECLARE @OldGroupCode varchar(20)
			DECLARE @NewGroupCode varchar(20)
 
			SELECT @TableName = 'tblDeptNames'
 
			DECLARE colCursor CURSOR
			READ_ONLY
			FOR SELECT old.RecordId, new.RecordId, old.SiteNo, new.SiteNo, old.RecordStatus, new.RecordStatus, old.AppliesToShiftDiff, new.AppliesToShiftDiff, old.ClientDeptCode, new.ClientDeptCode, old.DeptNo, new.DeptNo, old.Client, new.Client, old.DeptName_Long, new.DeptName_Long, old.DeptName, new.DeptName, CAST(old.GroupCode as varchar), CAST(new.GroupCode as varchar), old.MaintDateTime, new.MaintDateTime, new.MaintUserName
				FROM inserted as new
				LEFT JOIN deleted as old
				ON old.RecordId = new.RecordId
				WHERE IsNull(new.Client, '') NOT IN('TEST','DEMO')
				AND IsNull(new.GroupCode, 0) < 999899
 
			OPEN colCursor
 
			FETCH NEXT FROM colCursor INTO @OldRecordId, @NewRecordId, @OldSiteNo, @NewSiteNo, @OldRecordStatus, @NewRecordStatus, @OldAppliesToShiftDiff, @NewAppliesToShiftDiff, @OldClientDeptCode, @NewClientDeptCode, @OldDeptNo, @NewDeptNo, @OldClient, @NewClient, @OldDeptName_Long, @NewDeptName_Long, @OldDeptName, @NewDeptName, @OldGroupCode, @NewGroupCode, @OldMaintDateTime, @NewMaintDateTime, @MaintUserName
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2)
				BEGIN
 
			   -- Initialze user action to Update
			   SELECT @UserAction = 'U'
 
			   SELECT @AuditId = NULL
 
				  IF (@OldRecordId IS NULL)
					-- Action = Insert
					SELECT @UserAction = 'I'
				  ELSE
				  BEGIN
					IF (UPDATE(RecordStatus))
					BEGIN
					  IF (IsNull(@OldRecordStatus, '0') = '0' AND IsNull(@NewRecordStatus, '0') = '1')
					  BEGIN
						-- Action = Enable
						SELECT @UserAction = 'E'
					  END
					  ELSE
					  BEGIN
						IF (IsNull(@OldRecordStatus, '0') = '1' AND IsNull(@NewRecordStatus, '0') = '0')
  					  BEGIN
  						-- Action = Disable
  						SELECT @UserAction = 'D'
  					  END
					  END
					END
				  END
 
				  -- If the maintenance datetime on the new record is the same as the old record then chances
				  -- are that MaintDateTime was not set, therefore we will
				  IF (IsNull(@OldMaintDateTime, '1/1/1900') = IsNull(@NewMaintDateTime, '1/1/1900'))
					 SELECT @MaintDateTime = GetDate()
				  ELSE
					 SELECT @MaintDateTime = @NewMaintDateTime
 
				  IF NOT (UPDATE(MaintUserName))
					SELECT @MaintUsername = ''
 
				  IF (@OldSiteNo = @NewSiteNo)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'SiteNo', @OldSiteNo, @NewSiteNo, 'TimeCurrent'
 
				  IF (@OldRecordStatus = @NewRecordStatus)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
				  BEGIN
					IF (@OldRecordStatus IS NULL AND @NewRecordStatus IS NULL)
  					  -- Just doing this so I can do nothing
  					  SELECT @TableName = @TableName
					ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'RecordStatus', @OldRecordStatus, @NewRecordStatus, 'TimeCurrent'
				  END
 
				  IF (@OldAppliesToShiftDiff = @NewAppliesToShiftDiff)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'AppliesToShiftDiff', @OldAppliesToShiftDiff, @NewAppliesToShiftDiff, 'TimeCurrent'
 
				  IF (@OldClientDeptCode = @NewClientDeptCode)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
				  BEGIN
					IF (@OldClientDeptCode IS NULL AND @NewClientDeptCode IS NULL)
  					  -- Just doing this so I can do nothing
  					  SELECT @TableName = @TableName
					ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'ClientDeptCode', @OldClientDeptCode, @NewClientDeptCode, 'TimeCurrent'
				  END
 
				  IF (@OldDeptNo = @NewDeptNo)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'DeptNo', @OldDeptNo, @NewDeptNo, 'TimeCurrent'
 
				  IF (@OldClient = @NewClient)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'Client', @OldClient, @NewClient, 'TimeCurrent'
 
				  IF (@OldDeptName_Long = @NewDeptName_Long)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'DeptName_Long', @OldDeptName_Long, @NewDeptName_Long, 'TimeCurrent'
 
				  IF (@OldDeptName = @NewDeptName)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
				  BEGIN
					IF (@OldDeptName IS NULL AND @NewDeptName IS NULL)
  					  -- Just doing this so I can do nothing
  					  SELECT @TableName = @TableName
					ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'DeptName', @OldDeptName, @NewDeptName, 'TimeCurrent'
				  END
 
				  IF (@OldGroupCode = @NewGroupCode)
					 -- Just doing this so I can do nothing
					 SELECT @TableName = @TableName
				  ELSE
					exec Audit.dbo.usp_WebPNE_AuditLog_Column @TableName, @UserAction, @MaintDateTime, @MaintUsername, @AudHostName, @AudProgName, @AuditId OUTPUT, @AuditMasterObjectId OUTPUT, @AuditMasterTableId OUTPUT, @NewRecordId, 'GroupCode', @OldGroupCode, @NewGroupCode, 'TimeCurrent'
 
				END
				FETCH NEXT FROM colCursor INTO @OldRecordId, @NewRecordId, @OldSiteNo, @NewSiteNo, @OldRecordStatus, @NewRecordStatus, @OldAppliesToShiftDiff, @NewAppliesToShiftDiff, @OldClientDeptCode, @NewClientDeptCode, @OldDeptNo, @NewDeptNo, @OldClient, @NewClient, @OldDeptName_Long, @NewDeptName_Long, @OldDeptName, @NewDeptName, @OldGroupCode, @NewGroupCode, @OldMaintDateTime, @NewMaintDateTime, @MaintUserName
			END
			CLOSE colCursor
			DEALLOCATE colCursor	
 
			END
 

			GO

--	END
--GO


