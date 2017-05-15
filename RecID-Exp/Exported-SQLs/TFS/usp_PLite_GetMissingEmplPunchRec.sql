Create PROCEDURE [dbo].[usp_PLite_GetMissingEmplPunchRec] 

 @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--

AS


/*
***********************************************************************************
 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

Parses tblTimeHistDetail and finds missing punches for the Client/Group/Site passed.
This is the main working screen for fixing punches on the Lite Terminal.

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
02-27-02  KRB   Initial Creation
               

***********************************************************************************
*/

SET NOCOUNT ON

SELECT *,
tblDayDef.DayAbrev as InDayAbrv,
tblDayDef_1.DayAbrev as OutDayAbrv,
tblDayDef.DayAbrev + ' ' + convert(varchar(5),InTime,8) as InPunch,
tblDayDef_1.DayAbrev + ' ' + convert(varchar(5),OutTime,8) as OutPunch 
FROM tblTimeHistDetail 
LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo
LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo
WHERE RecordID = @RecordID 





