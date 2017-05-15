USE [TimeHistory];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO


------------------------------------
-- first rename OLD dependant objects (PK, FKs, Indexes, Triggers, and Defaults)
------------------------------------
BEGIN TRAN;


BEGIN TRY
	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblSiteNames_ExcludeFromUploadOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_ExcludeFromUpload') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_ExcludeFromUpload ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_ExcludeFromUpload',
                'DF_tblSiteNames_ExcludeFromUploadOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_GroupCodeOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_GroupCode') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_GroupCode ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_GroupCode',
                'DF_tblSiteNames_GroupCodeOld', 'OBJECT';
        END;
	IF ( OBJECT_ID('DF_tblSiteNames_SemiMoPayrollClosedOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_SemiMoPayrollClosed') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_SemiMoPayrollClosed ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_SemiMoPayrollClosed',
                'DF_tblSiteNames_SemiMoPayrollClosedOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_ShiftClassificationOnOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_ShiftClassificationOn') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_ShiftClassificationOn ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_ShiftClassificationOn',
                'DF_tblSiteNames_ShiftClassificationOnOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_SiteNoOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_SiteNo') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_SiteNo ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_SiteNo',
                'DF_tblSiteNames_SiteNoOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_WeekClosedOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_WeekClosed') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_WeekClosed ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_WeekClosed',
                'DF_tblSiteNames_WeekClosedOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_WeekClosedUserIDOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_WeekClosedUserID') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_WeekClosedUserID ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_WeekClosedUserID',
                'DF_tblSiteNames_WeekClosedUserIDOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_WeekClosedUserNameOld') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_WeekClosedUserName') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_WeekClosedUserName ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_WeekClosedUserName',
                'DF_tblSiteNames_WeekClosedUserNameOld', 'OBJECT';
        END;

	------------------------------------
	-- rename Unique Key
	------------------------------------
    IF ( OBJECT_ID('IX_tblSiteNames_UCOld') IS NULL
         AND OBJECT_ID('IX_tblSiteNames_UC') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: IX_tblSiteNames_UC ...';
            EXEC dbo.sp_rename 'IX_tblSiteNames_UC',
                'IX_tblSiteNames_UCOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'IX_tblSiteNames_UCOld'
                                AND si.object_id = OBJECT_ID('tblSiteNames') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'IX_tblSiteNames_UC'
                                AND si.object_id = OBJECT_ID('tblSiteNames') )
         AND OBJECT_ID('tblSiteNamesOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: IX_tblSiteNames_UC index ...';
            EXEC dbo.sp_rename 'tblSiteNames.IX_tblSiteNames_UC',
                'IX_tblSiteNames_UCOld', 'INDEX';
        END;
	
	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblSiteNamesOld') IS NULL
         AND OBJECT_ID('PK_tblSiteNames') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblSiteNames ...';
            EXEC dbo.sp_rename 'PK_tblSiteNames',
                'PK_tblSiteNamesOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblSiteNamesOld'
                                AND si.object_id = OBJECT_ID('tblSiteNames') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblSiteNames'
                                AND si.object_id = OBJECT_ID('tblSiteNames') )
         AND OBJECT_ID('tblSiteNamesOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblSiteNames index ...';
            EXEC dbo.sp_rename 'tblSiteNames.PK_tblSiteNames',
                'PK_tblSiteNamesOld', 'INDEX';
        END;

	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblSiteNames_ExcludeFromUpload') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_ExcludeFromUploadNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_ExcludeFromUpload ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_ExcludeFromUploadNew',
                'DF_tblSiteNames_ExcludeFromUpload', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_GroupCode') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_GroupCodeNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_GroupCode ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_GroupCodeNew',
                'DF_tblSiteNames_GroupCode', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_SemiMoPayrollClosed') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_SemiMoPayrollClosedNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_SemiMoPayrollClosed ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_SemiMoPayrollClosedNew',
                'DF_tblSiteNames_SemiMoPayrollClosed', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_ShiftClassificationOn') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_ShiftClassificationOnNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_ShiftClassificationOn ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_ShiftClassificationOnNew',
                'DF_tblSiteNames_ShiftClassificationOn', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_SiteNo') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_SiteNoNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_SiteNo ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_SiteNoNew',
                'DF_tblSiteNames_SiteNo', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_WeekClosed') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_WeekClosedNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_WeekClosed ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_WeekClosedNew',
                'DF_tblSiteNames_WeekClosed', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_WeekClosedUserID') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_WeekClosedUserIDNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_WeekClosedUserID ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_WeekClosedUserIDNew',
                'DF_tblSiteNames_WeekClosedUserID', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblSiteNames_WeekClosedUserName') IS NULL
         AND OBJECT_ID('DF_tblSiteNames_WeekClosedUserNameNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblSiteNames_WeekClosedUserName ...';
            EXEC dbo.sp_rename 'DF_tblSiteNames_WeekClosedUserNameNew',
                'DF_tblSiteNames_WeekClosedUserName', 'OBJECT';
        END;

	------------------------------------
	-- rename Unique Key
	------------------------------------
    IF ( OBJECT_ID('IX_tblSiteNames_UC') IS NULL
         AND OBJECT_ID('IX_tblSiteNames_UCNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: IX_tblSiteNames_UC ...';
            EXEC dbo.sp_rename 'IX_tblSiteNames_UCNew',
                'IX_tblSiteNames_UC', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'IX_tblSiteNames_UC'
                                AND si.object_id = OBJECT_ID('tblSiteNamesNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'IX_tblSiteNames_UCNew'
                                AND si.object_id = OBJECT_ID('tblSiteNamesNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: IX_tblSiteNames_UC index ...';
            EXEC dbo.sp_rename 'tblSiteNamesNew.IX_tblSiteNames_UCNew',
                'IX_tblSiteNames_UC', 'INDEX';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblSiteNames') IS NULL
         AND OBJECT_ID('PK_tblSiteNamesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblSiteNames ...';
            EXEC dbo.sp_rename 'PK_tblSiteNamesNew',
                'PK_tblSiteNames', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblSiteNames'
                                AND si.object_id = OBJECT_ID('tblSiteNamesNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblSiteNamesNew'
                                AND si.object_id = OBJECT_ID('tblSiteNamesNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblSiteNames index ...';
            EXEC dbo.sp_rename 'tblSiteNamesNew.PK_tblSiteNamesNew',
                'PK_tblSiteNames', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblSiteNamesOld') IS NULL
         AND OBJECT_ID('tblSiteNames') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblSiteNames ...';
            EXEC dbo.sp_rename 'tblSiteNames', 'tblSiteNamesOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblSiteNames') IS NULL
         AND OBJECT_ID('tblSiteNamesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblSiteNamesNew ...';
            EXEC dbo.sp_rename 'tblSiteNamesNew', 'tblSiteNames',
                'OBJECT';
        END;

END TRY
BEGIN CATCH

    IF ( @@TRANCOUNT > 0 )
        BEGIN
            ROLLBACK TRAN;
        END;

    DECLARE @ErrorMessage NVARCHAR(4000);
    SET @ErrorMessage = 'ERROR on Line ' + CONVERT(VARCHAR(20), ERROR_LINE())
        + ': ' + ERROR_MESSAGE();
    RAISERROR(@ErrorMessage, 16, 1);

END CATCH;


IF ( @@TRANCOUNT > 0 )
    BEGIN
        COMMIT TRAN;
    END;
GO
