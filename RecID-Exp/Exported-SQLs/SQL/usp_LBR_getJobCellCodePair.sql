USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_LBR_getJobCellCodePair]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_LBR_getJobCellCodePair]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_LBR_getJobCellCodePair] AS' 
END
GO


/*	select * from (
	usp_LBR_getJobCellCodePair 'stfm',524000,1)
*/
ALTER   PROCEDURE [dbo].[usp_LBR_getJobCellCodePair]
(
	@client varchar(4),
	@groupCode int,	
	@siteNo INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 25Aug2016 >--
)
AS

SET NOCOUNT ON

DECLARE @jobID int
DECLARE @cellCode varchar(20)
CREATE TABLE #JobCellPair(
	JobID int,
	CellCode varchar(20)
)

INSERT INTO #JobCellPair(JobID)
select distinct jobs.JobID
from timehistory..tblstdjobs jobs
inner join timehistory..tblstdjobcells cells
on jobs.jobID = cells.jobID
inner join timehistory..tblstdjobleads leads
on jobs.jobid = leads.jobid
where jobs.client = @client
and jobs.groupcode = @groupCode
and jobs.siteNo = @siteNo
and jobs.STATUS <> 'CLS'
and jobs.CompleteDateTime IS NULL


DECLARE cJobCellPair CURSOR STATIC
FOR SELECT JobID FROM #JobCellPair

OPEN cJobCellPair
FETCH NEXT FROM cJobCellPair INTO @jobID
WHILE (@@fetch_Status <> -1)
BEGIN
	IF(@@fetch_status <> -2)
	BEGIN
		DECLARE cCellCode CURSOR STATIC FOR
		SELECT CellCode FROM timehistory..tblstdjobcells
		WHERE JobID = @jobID
		
		OPEN cCellCode
		FETCH NEXT FROM cCellCode INTO @cellCode
		WHILE (@@fetch_Status <> -1)
		BEGIN
			IF(@@fetch_status <> -2)
			BEGIN
				INSERT INTO #JobCellPair(JobID,CellCode)
				VALUES(@jobID,@cellCode)
			END
			FETCH NEXT FROM cCellCode INTO @cellCode
		END
		CLOSE cCellCode
		DEALLOCATE cCellCode
	END
	FETCH NEXT FROM cJobCellPair INTO @jobID
END

CLOSE cJobCellPair
DEALLOCATE cJobCellPair

SELECT * FROM #JobCellPair
where cellcode is not null
order by jobid



GO
