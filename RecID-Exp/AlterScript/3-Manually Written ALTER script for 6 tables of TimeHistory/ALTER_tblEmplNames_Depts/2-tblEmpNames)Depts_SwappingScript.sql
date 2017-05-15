USE [TimeHistory];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRAN;


BEGIN TRY

------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblEmplNames_Depts_ExcludeFromUploadOld') IS NULL
         AND OBJECT_ID('DF_tblEmplNames_Depts_ExcludeFromUpload') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplNames_Depts_ExcludeFromUpload ...';
            EXEC dbo.sp_rename 'DF_tblEmplNames_Depts_ExcludeFromUpload',
                'DF_tblEmplNames_Depts_ExcludeFromUploadOld', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplNames_DeptsOld') IS NULL
         AND OBJECT_ID('PK_tblEmplNames_Depts') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts ...';
            EXEC dbo.sp_rename 'PK_tblEmplNames_Depts',
                'PK_tblEmplNames_DeptsOld', 'OBJECT';
        END;

	IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_DeptsOld'
                                AND si.object_id = OBJECT_ID('tblEmplNames_Depts') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_Depts'
                                AND si.object_id = OBJECT_ID('tblEmplNames_Depts') )
         AND OBJECT_ID('tblEmplNames_DeptsOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts index ...';
            EXEC dbo.sp_rename 'tblEmplNames_Depts.PK_tblEmplNames_Depts',
                'PK_tblEmplNames_DeptsOld', 'INDEX';
        END;

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblEmplNames_Depts_ExcludeFromUpload') IS NULL
         AND OBJECT_ID('DF_tblEmplNames_Depts_ExcludeFromUploadNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplNames_Depts_ExcludeFromUpload ...';
            EXEC dbo.sp_rename 'DF_tblEmplNames_Depts_ExcludeFromUploadNew',
                'DF_tblEmplNames_Depts_ExcludeFromUpload', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplNames_Depts') IS NULL
         AND OBJECT_ID('PK_tblEmplNames_DeptsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts ...';
            EXEC dbo.sp_rename 'PK_tblEmplNames_DeptsNew',
                'PK_tblEmplNames_Depts', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_Depts'
                                AND si.object_id = OBJECT_ID('tblEmplNames_DeptsNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_DeptsNew'
                                AND si.object_id = OBJECT_ID('tblEmplNames_DeptsNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts index ...';
            EXEC dbo.sp_rename 'tblEmplNames_DeptsNew.PK_tblEmplNames_DeptsNew',
                'PK_tblEmplNames_Depts', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblEmplNames_DeptsOld') IS NULL
         AND OBJECT_ID('tblEmplNames_Depts') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplNames_Depts ...';
            EXEC dbo.sp_rename 'tblEmplNames_Depts', 'tblEmplNames_DeptsOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblEmplNames_Depts') IS NULL
         AND OBJECT_ID('tblEmplNames_DeptsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplNames_DeptsNew ...';
            EXEC dbo.sp_rename 'tblEmplNames_DeptsNew', 'tblEmplNames_Depts',
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