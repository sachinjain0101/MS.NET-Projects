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
    IF ( OBJECT_ID('DF_tblEmplSites_ShiftDiffClassOld') IS NULL
         AND OBJECT_ID('DF_tblEmplSites_ShiftDiffClass') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplSites_ShiftDiffClass ...';
            EXEC dbo.sp_rename 'DF_tblEmplSites_ShiftDiffClass',
                'DF_tblEmplSites_ShiftDiffClassOld', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplSitesOld') IS NULL
         AND OBJECT_ID('PK_tblEmplSites') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites ...';
            EXEC dbo.sp_rename 'PK_tblEmplSites',
                'PK_tblEmplSitesOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSitesOld'
                                AND si.object_id = OBJECT_ID('tblEmplSites') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites'
                                AND si.object_id = OBJECT_ID('tblEmplSites') )
         AND OBJECT_ID('tblEmplSitesOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites index ...';
            EXEC dbo.sp_rename 'tblEmplSites.PK_tblEmplSites',
                'PK_tblEmplSitesOld', 'INDEX';
        END;

	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblEmplSites_ShiftDiffClass') IS NULL
         AND OBJECT_ID('DF_tblEmplSites_ShiftDiffClassNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplSites_ShiftDiffClass ...';
            EXEC dbo.sp_rename 'DF_tblEmplSites_ShiftDiffClassNew',
                'DF_tblEmplSites_ShiftDiffClass', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplSites') IS NULL
         AND OBJECT_ID('PK_tblEmplSitesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites ...';
            EXEC dbo.sp_rename 'PK_tblEmplSitesNew',
                'PK_tblEmplSites', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites'
                                AND si.object_id = OBJECT_ID('tblEmplSitesNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSitesNew'
                                AND si.object_id = OBJECT_ID('tblEmplSitesNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites index ...';
            EXEC dbo.sp_rename 'tblEmplSitesNew.PK_tblEmplSitesNew',
                'PK_tblEmplSites', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblEmplSitesOld') IS NULL
         AND OBJECT_ID('tblEmplSites') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplSites ...';
            EXEC dbo.sp_rename 'tblEmplSites', 'tblEmplSitesOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblEmplSites') IS NULL
         AND OBJECT_ID('tblEmplSitesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplSitesNew ...';
            EXEC dbo.sp_rename 'tblEmplSitesNew', 'tblEmplSites',
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