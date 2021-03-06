USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_GetPunchDetails]    Script Date: 3/31/2015 11:53:39 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_Web1_GetPunchDetails]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_GetPunchDetails] AS' 
END
GO






/*******************************************************************************************
	-- Purpose: Multipurpose stored proc used fetch grid data for the employee search
	-- Written by: Sajjan Sarkar
	-- Module: OrderEntry-->Employee Search
	-- Tested on: SQL Server 2000
	-- Date created: 2010-01-27 17:00
	===================================================================================
	Version History:
	Date			Modifier		Change Desc
	===================================================================================
	2010-01-27		Sajjan Sarkar		Initial  version		

********************************************************************************************/
-- =============================================
-- example to execute the store procedure
-- =============================================
--EXEC TimeHistory..usp_Web1_GetPunchDetails 594805373

ALTER  PROCEDURE [dbo].[usp_Web1_GetPunchDetails] ( @recordID BIGINT )  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
AS 
    SELECT  RecordID ,
            PayrollPeriodEndDate ,
            ISNULL(Hours, 0) AS Hours ,
            ActualInTime ,
            ActualOutTime ,
            InTime ,
            InDay ,
            OutTime ,
            OutDay ,
            SiteNo ,
            DeptNo ,
            TimeHistory.dbo.PunchDateTime2(TransDate, InDay, InTime) AS PunchStart ,
            TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, OutTime) AS PunchEnd
    FROM    TimeHistory..tblTimeHistDetail AS TTHD
    WHERE   RecordID = @recordID











GO
