CREATE PROCEDURE [dbo].[usp_Web1_GetTimeHistDetail_RecordID]  
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



