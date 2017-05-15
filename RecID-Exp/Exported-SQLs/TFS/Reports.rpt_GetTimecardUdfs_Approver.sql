Create PROCEDURE [Reports].[rpt_GetTimecardUdfs_Approver]

  @SiteName varchar(255),		-- ='19744-SAKS FIFTH AVENUE PORTLAND',
  @DepartmentName varchar(255) ,--='19744-SAKS FIFTH AVENUE PORTLAND',
  @TransDate datetime ,			--= '5/15/2014'
  @DetailRecordId int ,
  @PPED datetime,
  @FrequencyId int = 2

AS

declare @TimesheetId int

select @TimesheetId = t.recordid
FROM TimeHistory..tblTimeHistDetail thd inner join TimeHistory..tblWTE_Spreadsheet_Assignments sa
		ON thd.Client = sa.client and thd.groupcode = sa.groupcode and thd.ssn = sa.ssn and thd.siteno = sa.siteno and thd.deptno = sa.deptno
		inner join TimeHistory..tblWTE_Timesheets t 
		on t.recordid = sa.timesheetid 
WHERE thd.RecordId = @DetailRecordId and t.TimesheetEndDate = @PPED and t.FrequencyId = @FrequencyId


SELECT 
    id = IDENTITY(INT,1,1)
	, def.FieldDescription
	, ISNULL(opt.OptionDesc, du.FieldValue) AS FieldValue
    , 0 as RowId
    , def.DisplayOrder as DisplaySeq  
INTO #tmp

FROM
	TimeHistory..tblWTE_Timesheets t

	JOIN TimeHistory..tblWTE_Spreadsheet_Assignments sa
		ON t.RecordId = sa.TimesheetId
		
	JOIN TimeHistory..tblTimeHistDetail_UDF du
		ON du.SpreadsheetAssignmentId = sa.RecordId

	JOIN TimeHistory..vwWTE_Spreadsheet_UdfDefinitions def
	   ON def.SpreadsheetAssignmentId = du.SpreadsheetAssignmentID
	   AND def.FieldID = du.FieldID

	LEFT JOIN TimeHistory..vwWTE_Spreadsheet_UdfOptions opt
	   ON def.FieldID = opt.FieldId
	   AND def.TemplateMappingId = opt.TemplateMappingId
	   AND du.FieldValue = opt.OptionValue

	--Join [TimeCurrent].[dbo].[tblUDF_FieldDefs] fd
	--	ON du.FieldID = fd.fieldid

	--left join [TimeCurrent].[dbo].[tblUDF_FieldOptions] fo
	--	on du.FieldId = fo.FieldId and du.fieldValue = fo.optionvalue

WHERE 
	   t.recordid = @TimesheetId 
    AND transdate = @TransDate 
    AND sitename = @SiteName 
    AND DepartmentName = @DepartmentName

	
	
DECLARE  @imax INT, @i int, @colCnt int=0, @rowcnt int = 0, @firstName varchar(255), @idxName varchar(255)
			 
SELECT @i = 2,  @imax = max(id) from #tmp 
SELECT @firstName =FieldDescription from #tmp where id = 1
	  
WHILE (@i <= @imax) 
    BEGIN 
    SELECT @idxName =FieldDescription  FROM   #tmp  WHERE  id = @i 

    if @firstName = @idxName
	   begin
	   if @colCnt = 0
		  set @colCnt =@i-1
	   set @rowcnt = @rowcnt + 1
	   update #tmp set rowid = @rowcnt where id between @i and (@i + @colCnt-1)
	   SET @i = @i + @colCnt-1	
	   end
     
    SET @i = @i + 1 
END -- WHILE

SELECT FieldDescription, FieldValue, RowId, DisplaySeq from #tmp ORDER BY DisplaySeq

GO


