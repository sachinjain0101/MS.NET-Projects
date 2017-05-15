USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_PLite_GetTimeHistPunchRecord]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_PLite_GetTimeHistPunchRecord]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_PLite_GetTimeHistPunchRecord] AS' 
END
GO




/*
***********************************************************************************
 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

 Gets Specific Punch detail
***********************************************************************************
 Copyright (c) Cignify Corporation, as an unpublished work first licensed in
 2002.  This program is a confidential, unpublished work of authorship created
 in 2002.  It is a trade secret which is the property of Cignify Corporation.

 All use, disclosure, and/or reproduction not specifically authorized by
 Cignify Corporation, is prohibited.  This program is protected by
 domestic and international copyright and/or trade secret laws.
 All rights reserved.

***********************************************************************************
REVISION HISTORY

DATE      INIT  Description
--------  ----  --------------------------------------------------------------------------------
03-7-02  KRB   Creation.
               

***********************************************************************************
*/
--/*
ALTER   Procedure [dbo].[usp_PLite_GetTimeHistPunchRecord] (
     @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
)

AS

SELECT *
FROM tblTimeHistDetail
WHERE RecordID = @RecordID





GO
