Create PROCEDURE [dbo].[usp_APP_FLPI_GetUploadRecs]
(
	@Client       char(4),
	@GroupCode    int,
	@PPED         datetime
)

AS

SET NOCOUNT ON

  EXEC usp_APP_PRECHECK_Upload @Client, @GroupCode, @PPED, 'Y'
  if @@error <> 0 
    return


Declare @tmpUpload as table
(
  Client varchar(4),
  GroupCode int,
  SSN int,
  FIleNo varchar(20),
  SiteNo int,
  DeptNo int,
  AdjustmentCode varchar(20),
  AllocHrs numeric(9,2),
  Hours numeric(9,2)
)

Insert into @tmpUpload
SELECT 	main.Client, 
				main.GroupCode, 
				main.ssn, 
				empl.FileNo, 
				main.SiteNo, 
				main.DeptNo, 
				CASE WHEN AdjustmentCode = 'REG' THEN 'REGULAR' ELSE AdjustmentCode END AdjustmentCode, 
				AllocHrs, 
				Hours
FROM 
(
	SELECT sub.client, 
         sub.groupcode, 
         sub.ssn, 
         CAST(alloc2.uploadcode as INT) siteno,   --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 03Aug2016 >--
         CAST(alloc2.jobcode as INT) deptno,   --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 03Aug2016 >--
         sub.adjustmentcode, 
         CAST(sub.hours * alloc2.percentage / 100 as decimal(7,2)) allocHrs, 
         sub.hours
	FROM 
	(
		--hours for allocated sites/depts
		SELECT thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno, adj.adjustmentcode, SUM(thd.Reghours) hours
		FROM tbltimehistdetail thd
		INNER JOIN timecurrent..tblEmplallocation alloc
		ON alloc.client = thd.client
		AND alloc.groupcode = thd.groupcode
		AND alloc.ssn = thd.ssn
		AND alloc.UploadCode = thd.siteno
		AND alloc.jobcode = thd.deptno
		INNER JOIN timecurrent..tbladjcodes adj
		ON adj.client = thd.client
		AND adj.groupcode = thd.groupcode
		AND adj.clockadjustmentno = CASE WHEN thd.clockadjustmentno IN ('', '1', '8', 'T') THEN '1' ELSE thd.clockadjustmentno END
		WHERE thd.payrollperiodenddate IN (@PPED, DATEADD(d, -7, @PPED)) 
		AND thd.client = @Client
		AND thd.groupcode = @GroupCode
		AND alloc.recordStatus = '1'
		GROUP BY thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno, adj.adjustmentcode
	
		UNION ALL
		
		--OT hours for allocated sites/depts
		SELECT thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno, 'OT' adjustmentcode, SUM(thd.OT_hours) hours
		FROM tbltimehistdetail thd
		INNER JOIN timecurrent..tblEmplallocation alloc
		ON alloc.client = thd.client
		AND alloc.groupcode = thd.groupcode
		AND alloc.ssn = thd.ssn
		AND alloc.UploadCode = thd.siteno
		AND alloc.jobcode = thd.deptno
		WHERE thd.payrollperiodenddate IN (@PPED, DATEADD(d, -7, @PPED)) 
		AND thd.client = @Client
		AND thd.groupcode = @GroupCode
		AND thd.OT_Hours <> 0
		AND alloc.recordStatus = '1'
		GROUP BY thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno
		HAVING SUM(thd.OT_Hours) <> 0
	) sub
	INNER JOIN timecurrent..tblEmplallocation alloc2
		ON alloc2.client = sub.client
		AND alloc2.groupcode = sub.groupcode
		AND alloc2.ssn = sub.ssn
		AND alloc2.RecordStatus = '1'

	UNION ALL
	
	--hours for non-allocated sites/depts	
	SELECT thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno, adj.adjustmentcode, SUM(thd.Reghours) allochrs, 0 hours
	FROM tbltimehistdetail thd
	LEFT JOIN timecurrent..tblEmplallocation alloc
	ON alloc.client = thd.client
	AND alloc.groupcode = thd.groupcode
	AND alloc.ssn = thd.ssn
	AND alloc.UploadCode = thd.siteno
	AND alloc.jobcode = thd.deptno
	AND alloc.recordStatus = '1'
	INNER JOIN timecurrent..tbladjcodes adj
	ON adj.client = thd.client
	AND adj.groupcode = thd.groupcode
	AND adj.clockadjustmentno = CASE WHEN thd.clockadjustmentno IN ('', '1', '8', 'T') THEN '1' ELSE thd.clockadjustmentno END
	WHERE thd.payrollperiodenddate IN (@PPED, DATEADD(d, -7, @PPED)) 
	AND thd.client = @Client
	AND thd.groupcode = @GroupCode
	AND alloc.uploadcode IS NULL
	GROUP BY thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno, adj.adjustmentcode
	
	UNION ALL
	
	--OT hours for non-allocated sites/depts
	SELECT thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno, 'OT' adjustmentcode, SUM(thd.OT_hours)  allochrs, 0 hours
	FROM tbltimehistdetail thd
	LEFT JOIN timecurrent..tblEmplallocation alloc
	ON alloc.client = thd.client
	AND alloc.groupcode = thd.groupcode
	AND alloc.ssn = thd.ssn
	AND alloc.UploadCode = thd.siteno
	AND alloc.jobcode = thd.deptno
	AND alloc.recordStatus = '1'
	WHERE thd.payrollperiodenddate IN (@PPED, DATEADD(d, -7, @PPED))
	AND thd.client = @Client
	AND thd.groupcode = @GroupCode
	AND thd.OT_Hours <> 0
	AND alloc.uploadcode IS NULL
	GROUP BY thd.client, thd.groupcode, thd.ssn, thd.siteno, thd.deptno
	HAVING SUM(thd.OT_Hours) <> 0
) main
INNER JOIN timeCurrent..tblEmplNames empl
ON empl.client = main.client
AND empl.groupcode = main.groupcode
AND empl.ssn = main.ssn
ORDER BY main.ssn	

Insert into @tmpUpload
select Client, Groupcode, SSN, FileNo, SiteNo, DeptNo, 
case when AdjustmentCode = '3' then '23' else '24' end, AllocHrs * -1, Hours * -1 
from @tmpUpload 
where AdjustmentCode in('3','4')

select * from @tmpUpload 
order by SSN, AdjustmentCode, AllocHrs desc, hours desc






