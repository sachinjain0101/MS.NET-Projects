USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_GetTimeHistDetail_RecordID]    Script Date: 3/31/2015 11:53:39 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_Web1_GetTimeHistDetail_RecordID]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_GetTimeHistDetail_RecordID] AS' 
END
GO




/****** Object:  Stored Procedure usp_Web1_GetTimeHistDetail    Script Date: 12/12/00 ******/
ALTER PROCEDURE [dbo].[usp_Web1_GetTimeHistDetail_RecordID]  
 @RecordID  BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 09Sept2016 >--
AS

SELECT  tblTimeHistDetail.* ,
 convert(varchar(08),TransDate,1) as TransDate_mdy,
 convert(varchar(5),InTime,8) as InTime_hm,
 convert(varchar(5),OutTime,8) as OutTime_hm,  
 tblDayDef.DayAbrev as InDayAbrev, 
 tblDayDef_1.DayAbrev as OutDayAbrev, 
 TimeCurrent.dbo.tblInOutSrc.SrcAbrev as InSrcAbrev, 
 (case when (tblTimeHistDetail.ClockAdjustmentNo = 'x' and tblTimeHistDetail.Hours = '0') then tblTimeHistDetail.xAdjHours else tblTimeHistDetail.Hours END) as Hours,
 tblInOutSrc_1.SrcAbrev as OutSrcAbrev 
FROM tblTimeHistDetail 
LEFT JOIN tblDayDef ON InDay=tblDayDef.DayNo 
LEFT JOIN tblDayDef as tblDayDef_1 ON OutDay=tblDayDef_1.DayNo
LEFT JOIN TimeCurrent.dbo.tblInOutSrc ON InSrc=TimeCurrent.dbo.tblInOutSrc.Src 
LEFT JOIN TimeCurrent.dbo.tblInOutSrc as tblInOutSrc_1 ON OutSrc=tblInOutSrc_1.Src
WHERE tblTimeHistDetail.RecordID = @RecordID
ORDER BY TransDate, tblTimeHistDetail.ClockAdjustmentNo, InTime



GO
