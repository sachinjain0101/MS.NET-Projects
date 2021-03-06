USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_PLite_FixPunchPostGetInfo]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_PLite_FixPunchPostGetInfo]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_PLite_FixPunchPostGetInfo] AS' 
END
GO




/*
***********************************************************************************
 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

 SP to post a fix punch to the database and update the appropriate tables,

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
02-27-02  DEH   Creation.
               

***********************************************************************************
*/
ALTER  Procedure [dbo].[usp_PLite_FixPunchPostGetInfo]
  (
     @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
  )
AS

Select en.ShiftClass, en.Status, sn.WeekClosedDateTime, sn.CloseHour from
TimeHistory..tblTimeHistDetail as thd
Left Join TimeCurrent..tblEmplNames as en
on en.Client = thd.Client
and en.GroupCode = thd.GroupCode
and en.SSN = thd.SSN
Left Join TimeHistory..tblSiteNames as sn
on sn.CLient = thd.Client
and sn.GroupCode = thd.GroupCode
and sn.SiteNo = thd.SiteNo
and sn.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
where thd.RecordID = @RecordID





GO
