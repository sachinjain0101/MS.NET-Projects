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
	-- rename Primary Key to OLD
	------------------------------------
    IF ( OBJECT_ID('PK_tblDeptNamesOld') IS NULL
         AND OBJECT_ID('PK_tblDeptNames') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNames ...';
            EXEC dbo.sp_rename 'PK_tblDeptNames',
                'PK_tblDeptNamesOld', 'OBJECT';
        END;

	IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNamesOld'
                                AND si.object_id = OBJECT_ID('tblDeptNames') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNames'
                                AND si.object_id = OBJECT_ID('tblDeptNames') )
         AND OBJECT_ID('tblDeptNamesOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNames index ...';
            EXEC dbo.sp_rename 'tblDeptNames.PK_tblDeptNames',
                'PK_tblDeptNamesOld', 'INDEX';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblDeptNames') IS NULL
         AND OBJECT_ID('PK_tblDeptNamesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNamesNew ...';
            EXEC dbo.sp_rename 'PK_tblDeptNamesNew',
                'PK_tblDeptNames', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNames'
                                AND si.object_id = OBJECT_ID('tblDeptNamesNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNamesNew'
                                AND si.object_id = OBJECT_ID('tblDeptNamesNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNames index ...';
            EXEC dbo.sp_rename 'tblDeptNamesNew.PK_tblDeptNamesNew',
                'PK_tblDeptNames', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblDeptNamesOld') IS NULL
         AND OBJECT_ID('tblDeptNames') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblDeptNames ...';
            EXEC dbo.sp_rename 'tblDeptNames', 'tblDeptNamesOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblDeptNames') IS NULL
         AND OBJECT_ID('tblDeptNamesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblDeptNamesNew ...';
            EXEC dbo.sp_rename 'tblDeptNamesNew', 'tblDeptNames',
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