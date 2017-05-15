Create PROCEDURE [dbo].[usp_Web1_TaskPanel_SaveValidationErrors_SiteDept] 
	-- Add the parameters for the stored procedure here
    @THDRecordID BIGINT = 0 ,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
    @ESDRecordID INT = 0 ,
    @UserID INT
AS 
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON ;

        DECLARE @oldSiteNo INT
        DECLARE @oldDeptNo INT
        DECLARE @newSiteNo INT
        DECLARE @newDeptNo INT
        DECLARE @userName VARCHAR(100)
		
        SELECT  @oldSiteNo = thd.SiteNo ,
                @oldDeptNo = thd.DeptNo
        FROM    TimeHistory..tblTimeHistDetail AS thd WITH ( NOLOCK )
        WHERE   thd.RecordID = @THDRecordID
         
         
        SELECT  @newSiteNo = esd.SiteNo ,
                @newDeptNo = esd.DeptNo
        FROM    TimeCurrent..tblEmplSites_Depts AS esd WITH ( NOLOCK )
        WHERE   esd.RecordID = @ESDRecordID       
                
                
        SELECT  @userName = UPPER(TU.LastName + ', ' + TU.FirstName)
        FROM    TimeCurrent..tblUser AS TU WITH ( NOLOCK )
        WHERE   TU.UserID = @UserID
		
		PRINT 'Site/Dept changed from ' + CAST(@oldSiteNo AS VARCHAR) + '/' + CAST(@oldDeptNo AS VARCHAR)
                        + ' to ' + CAST(@newSiteNo AS VARCHAR) + '/' + CAST(@newDeptNo AS VARCHAR) + ' from TaskPanel'
		
        UPDATE  TimeHistory..tblTimeHistDetail
        SET     SiteNo = esd.SiteNo ,
                DeptNo = esd.DeptNo
        FROM    TimeCurrent..tblEmplSites_Depts AS esd
        WHERE   esd.RecordID = @ESDRecordID
                AND dbo.tblTimeHistDetail.RecordID = @THDRecordID
    
        INSERT  INTO TimeCurrent..tblFixedPunch
                ( OrigRecordID ,
                  Client ,
                  GroupCode ,
                  SSN ,
                  PayrollPeriodEndDate ,
                  MasterPayrollDate ,
                  OldSiteNo ,
                  OldDeptNo ,
                  OldJobID ,
                  OldTransDate ,
                  OldEmpStatus ,
                  OldBillRate ,
                  OldBillOTRate ,
                  OldBillOTRateOverride ,
                  OldPayRate ,
                  OldShiftNo ,
                  OldInDay ,
                  OldInTime ,
                  OldInSrc ,
                  OldOutDay ,
                  OldOutTime ,
                  OldOutSrc ,
                  OldHours ,
                  OldDollars ,
                  OldClockAdjustmentNo ,
                  OldAdjustmentCode ,
                  OldAdjustmentName ,
                  OldTransType ,
                  OldAgencyNo ,
                  OldDaylightSavTime ,
                  OldHoliday ,
                  NewSiteNo ,
                  NewDeptNo ,
                  NewJobID ,
                  NewTransDate ,
                  NewEmpStatus ,
                  NewBillRate ,
                  NewBillOTRate ,
                  NewBillOTRateOverride ,
                  NewPayRate ,
                  NewShiftNo ,
                  NewInDay ,
                  NewInTime ,
                  NewInSrc ,
                  NewOutDay ,
                  NewOutTime ,
                  NewOutSrc ,
                  NewHours ,
                  NewDollars ,
                  NewClockAdjustmentNo ,
                  NewAdjustmentCode ,
                  NewAdjustmentName ,
                  NewTransType ,
                  NewAgencyNo ,
                  NewDaylightSavTime ,
                  NewHoliday ,
                  UserName ,
                  UserID ,
                  TransDateTime ,
                  SweptDateTime ,
                  IPAddr ,
                  OldCostID ,
                  NewCostID ,
                  Comment
		        )
                SELECT  thd.RecordID ,
                        thd.Client ,
                        thd.GroupCode ,
                        thd.SSN ,
                        thd.PayrollPeriodEndDate ,
                        thd.MasterPayrollDate ,
                        @oldSiteNo ,
                        @oldDeptNo ,
                        thd.JobID ,
                        thd.TransDate ,
                        thd.EmpStatus ,
                        thd.BillRate ,
                        thd.BillOTRate ,
                        thd.BillOTRateOverride ,
                        thd.PayRate ,
                        thd.ShiftNo ,
                        thd.InDay ,
                        thd.InTime ,
                        thd.InSrc ,
                        thd.OutDay ,
                        thd.OutTime ,
                        thd.OutSrc ,
                        thd.Hours ,
                        thd.Dollars ,
                        thd.ClockAdjustmentNo ,
                        thd.AdjustmentCode ,
                        thd.AdjustmentName ,
                        thd.TransType ,
                        thd.AgencyNo ,
                        thd.DaylightSavTime ,
                        thd.Holiday ,
                        thd.SiteNo ,
                        thd.DeptNo ,
                        thd.DT_Hours ,
                        thd.TransDate ,
                        thd.EmpStatus ,
                        thd.BillRate ,
                        thd.BillOTRate ,
                        thd.BillOTRateOverride ,
                        thd.PayRate ,
                        thd.ShiftNo ,
                        thd.InDay ,
                        thd.InTime ,
                        thd.InSrc ,
                        thd.OutDay ,
                        thd.OutTime ,
                        thd.OutSrc ,
                        thd.Hours ,
                        thd.Dollars ,
                        thd.ClockAdjustmentNo ,
                        thd.AdjustmentCode ,
                        thd.AdjustmentName ,
                        thd.TransType ,
                        thd.AgencyNo ,
                        thd.DaylightSavTime ,
                        thd.Holiday ,
                        @userName ,
                        @UserID ,
                        getdate() ,
                        NULL ,
                        NULL ,
                        thd.CostID ,
                        thd.CostID ,
                        'Site/Dept changed from ' + CAST(@oldSiteNo AS VARCHAR) + '/' + CAST(@oldDeptNo AS VARCHAR)
                        + ' to ' + CAST(@newSiteNo AS VARCHAR) + '/' + CAST(@newDeptNo AS VARCHAR) + ' from TaskPanel'
                FROM    TimeHistory..tblTimeHistDetail AS thd WITH ( NOLOCK )
                WHERE   thd.RecordID = @THDRecordID
		
		
		
        INSERT  INTO TimeHistory..tblTimeHistDetail_Comments
                ( Client ,
                  GroupCode ,
                  PayrollPeriodEndDate ,
                  SSN ,
                  CreateDate ,
                  Comments ,
                  UserID ,
                  UserName ,
                  ManuallyAdded ,
                  SiteNo ,
                  DeptNo ,
                  CommentSourceID
		        )
                SELECT  thd.Client ,
                        thd.GroupCode ,
                        thd.PayrollPeriodEndDate ,
                        thd.SSN ,
                        GETDATE() ,
                        'Site/Dept changed from ' + CAST(@oldSiteNo AS VARCHAR) + '/' + CAST(@oldDeptNo AS VARCHAR)
                        + ' to ' + CAST(@newSiteNo AS VARCHAR) + '/' + CAST(@newDeptNo AS VARCHAR) + ' from TaskPanel' ,
                        @userID ,
                        @userName ,
                        0 ,
                        thd.SiteNo ,
                        thd.DeptNo ,
                        NULL
                FROM    TimeHistory..tblTimeHistDetail AS thd
                WHERE   thd.RecordID = @THDRecordID
    
    
        SELECT  SN.SiteNo ,
                SN.SiteName ,
                GD.DeptNo ,
                GD.DeptName_Long ,
                GD.Client ,
                GD.GroupCode ,
                thd.SSN ,
                thd.PayrollPeriodEndDate
        FROM    TimeHistory..tblTimeHistDetail AS thd WITH ( NOLOCK )
        INNER JOIN TimeCurrent..tblSiteNames AS SN WITH ( NOLOCK )
        ON      thd.Client = SN.Client
                AND thd.GroupCode = SN.GroupCode
                AND thd.SiteNo = SN.SiteNo
        INNER JOIN TimeCurrent..tblGroupDepts AS GD WITH ( NOLOCK )
        ON      thd.Client = GD.Client
                AND thd.GroupCode = GD.GroupCode
                AND thd.DeptNo = GD.DeptNo
        WHERE   thd.RecordID = @THDRecordID
    
    
  
    END

