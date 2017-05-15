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
    IF ( OBJECT_ID('DF__tblEmplSi__TECom__683505ECOld') IS NULL
         AND OBJECT_ID('DF__tblEmplSi__TECom__683505EC') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF__tblEmplSi__TECom__683505EC ...';
            EXEC dbo.sp_rename 'DF__tblEmplSi__TECom__683505EC',
                'DF__tblEmplSi__TECom__683505ECOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF__tblEmplSi__TECom__69292A25Old') IS NULL
         AND OBJECT_ID('DF__tblEmplSi__TECom__69292A25') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF__tblEmplSi__TECom__69292A25 ...';
            EXEC dbo.sp_rename 'DF__tblEmplSi__TECom__69292A25',
                'DF__tblEmplSi__TECom__69292A25Old', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplSites_DeptsOld') IS NULL
         AND OBJECT_ID('PK_tblEmplSites_Depts') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_Depts ...';
            EXEC dbo.sp_rename 'PK_tblEmplSites_Depts',
                'PK_tblEmplSites_DeptsOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_DeptsOld'
                                AND si.object_id = OBJECT_ID('tblEmplSites_Depts') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_Depts'
                                AND si.object_id = OBJECT_ID('tblEmplSites_Depts') )
         AND OBJECT_ID('tblEmplSites_DeptsOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_Depts index ...';
            EXEC dbo.sp_rename 'tblEmplSites_Depts.PK_tblEmplSites_Depts',
                'PK_tblEmplSites_DeptsOld', 'INDEX';
        END;

	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF__tblEmplSi__TECom__683505EC') IS NULL
         AND OBJECT_ID('DF__tblEmplSi__TECom__683505ECNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF__tblEmplSi__TECom__683505EC ...';
            EXEC dbo.sp_rename 'DF__tblEmplSi__TECom__683505ECNew',
                'DF__tblEmplSi__TECom__683505EC', 'OBJECT';
        END;

	 IF ( OBJECT_ID('DF__tblEmplSi__TECom__69292A25') IS NULL
         AND OBJECT_ID('DF__tblEmplSi__TECom__69292A25New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF__tblEmplSi__TECom__69292A25 ...';
            EXEC dbo.sp_rename 'DF__tblEmplSi__TECom__69292A25New',
                'DF__tblEmplSi__TECom__69292A25', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplSites_Depts') IS NULL
         AND OBJECT_ID('PK_tblEmplSites_DeptsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_Depts ...';
            EXEC dbo.sp_rename 'PK_tblEmplSites_DeptsNew',
                'PK_tblEmplSites_Depts', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_Depts'
                                AND si.object_id = OBJECT_ID('tblEmplSites_DeptsNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_DeptsNew'
                                AND si.object_id = OBJECT_ID('tblEmplSites_DeptsNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_Depts index ...';
            EXEC dbo.sp_rename 'tblEmplSites_DeptsNew.PK_tblEmplSites_DeptsNew',
                'PK_tblEmplSites_Depts', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblEmplSites_DeptsOld') IS NULL
         AND OBJECT_ID('tblEmplSites_Depts') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplSites_Depts ...';
            EXEC dbo.sp_rename 'tblEmplSites_Depts', 'tblEmplSites_DeptsOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblEmplSites_Depts') IS NULL
         AND OBJECT_ID('tblEmplSites_DeptsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplSites_DeptsNew ...';
            EXEC dbo.sp_rename 'tblEmplSites_DeptsNew', 'tblEmplSites_Depts',
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