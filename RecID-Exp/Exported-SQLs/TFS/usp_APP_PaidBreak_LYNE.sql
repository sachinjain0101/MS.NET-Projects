Create PROCEDURE dbo.usp_APP_PaidBreak_LYNE
    (
      @MinHoursPerDay NUMERIC(7, 2)
    , @PaidMinutes NUMERIC(7, 2)
    , @Client VARCHAR(4)
    , @GroupCode INT
    , @PPED DATETIME
    , @SSN INT
    )
AS

--DECLARE @minhoursperday int = 0
--DECLARE @PaidMinutes INT = 15
--DECLARE @client VARCHAR(4) = 'LYNE'
--DECLARE @groupcode INT = 564600
--DECLARE @PPED DATETIME = '2015-09-26 00:00:00.000'
--DECLARE @SSN INT = 537367080
SET NOCOUNT ON;

    DECLARE @TransDate DATETIME;
    DECLARE @MPD DATETIME;
    DECLARE @SiteNo INT;
    DECLARE @DeptNo INT;
    DECLARE @TotHours NUMERIC(9, 2);
    DECLARE @RecordId BIGINT;  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
    DECLARE @hours NUMERIC(9, 2);
	-- US3709
	-- If the employee works more than 2 hours and less than 6, the employee should have 1 fifteen minute paid break added. 
	-- IF the employee works more than 6 hours, both paid breaks should be added. 

    DECLARE cPunch CURSOR READ_ONLY
    FOR
        SELECT distinct thd2.SiteNo
              , thd2.DeptNo
              , thd2.TransDate
              , thd1.Hours
        FROM    ( SELECT  distinct  TransDate,client,GroupCode,ssn
                          , SUM(Hours) Hours
                  FROM      TimeHistory..tblTimeHistDetail
                  WHERE     Client = @Client
                            AND GroupCode = @GroupCode
                            AND SSN = @SSN
							AND AdjustmentCode = ''
                            AND PayrollPeriodEndDate = @PPED
                  GROUP BY  TransDate,client,GroupCode,ssn
                ) AS thd1
        INNER JOIN TimeHistory..tblTimeHistDetail thd2 ON thd2.TransDate = thd1.TransDate AND thd2.Client = thd1.client AND thd2.GroupCode = thd1.GroupCode AND thd2.SSN = thd1.SSN
        WHERE   thd2.Client = @Client
                AND thd2.GroupCode = @GroupCode
                AND thd2.SSN = @SSN
                AND thd2.PayrollPeriodEndDate = @PPED;


    OPEN cPunch;

    FETCH NEXT FROM cPunch INTO @SiteNo, @DeptNo, @TransDate,  @hours;

    WHILE ( @@fetch_status = 0 )
	        BEGIN
				SELECT @MPD = MasterPayrollDate 
				FROM TimeHistory..tblPeriodEndDates (NOLOCK)
				WHERE client = @client  
				AND GroupCode = @GroupCode
				AND PayrollPeriodEndDate = @PPED
			 				
                SELECT  @TotHours = @PaidMinutes / 60.00;
            IF @hours > 2 
             BEGIN
                 
                    SET @RecordId = NULL;
                    SET @RecordId = ( SELECT TOP 1
                                                RecordID
                                      FROM      TimeHistory..tblTimeHistDetail
                                      WHERE     Client = @Client
                                                AND GroupCode = @GroupCode
                                                AND PayrollPeriodEndDate = @PPED
                                                AND SSN = @SSN
                                                AND TransDate = @TransDate
                                                AND ClockAdjustmentNo = '1'
                                                AND AdjustmentName = 'PAIDBREAK'
                                                AND ( Hours = @TotHours OR ( TransType = 7 AND Hours = 0.00 ) )
                                                AND ISNULL(UserCode, '') = 'SYS'
                                    );


                    IF @RecordId IS NULL 
					BEGIN	
					                            EXEC TimeHistory.dbo.usp_APP_XLSImport_Adjustment_Insert_THD @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'PAIDBREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS';
                    END
                END
			IF @hours < 2 
			Begin
			   				DELETE TimeHistory..tblTimeHistDetail WHERE AdjustmentName = 'PAIDBREAK' AND SSn = @ssn AND client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED  AND TransDate = @TransDate
            END
			IF @hours > 6
		
                    BEGIN 
                        SET @RecordId = NULL;
                        SET @RecordId = ( SELECT TOP 1
                                                    RecordID
                                          FROM      TimeHistory..tblTimeHistDetail
                                          WHERE     Client = @Client
                                                    AND GroupCode = @GroupCode
                                                    AND PayrollPeriodEndDate = @PPED
                                                    AND SSN = @SSN
                                                    AND TransDate = @TransDate
                                                    AND ClockAdjustmentNo = '1'
                                                    AND AdjustmentName = 'PAIDBREAK2'
                                                    AND ( Hours = @TotHours
                                                          OR ( TransType = 7
                                                               AND Hours = 0.00
                                                             )
                                                        )
                                                    AND ISNULL(UserCode, '') = 'SYS'
                                        );


                        IF @RecordId IS NULL 
						BEGIN
											        EXEC TimeHistory.dbo.usp_APP_XLSImport_Adjustment_Insert_THD @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'PAIDBREAK2', @TotHours, 0.00, @TransDate, @MPD, 'SYS';
						END
                    END
			IF @hours < 6 
				BEGIN	
										DELETE TimeHistory..tblTimeHistDetail WHERE AdjustmentName = 'PAIDBREAK2' AND SSn = @ssn AND client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED  AND TransDate = @TransDate
				END
			
			FETCH NEXT FROM cPunch INTO @SiteNo, @DeptNo, @TransDate,  @hours;
        END;

    CLOSE cPunch;
    DEALLOCATE cPunch;








