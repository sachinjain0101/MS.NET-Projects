CREATE PROCEDURE [dbo].[usp_Web1_FixRecordInFixedPunchEE]
    (
      @FixPunchRecordID INT
    )
AS
    
BEGIN
        SET NOCOUNT ON

        DECLARE @NewTHDRecordID BIGINT  --< @NewTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--

		/**
			For non DAVT txns, this will perfectly line up
			and go straight to the UPDATE at the bottom
		*/

        SELECT  @NewTHDRecordID = thd.RecordID
        FROM    TimeCurrent..tblFixedPunch AS FP WITH ( NOLOCK )
        INNER JOIN TimeHistory..tblTimeHistDetail AS THD WITH ( NOLOCK )
        ON      THD.RecordID = FP.OrigRecordID
        INNER JOIN TimeHistory..tblFixedPunchByEE AS FPBE
        ON      FPBE.RecordID = THD.RecordID
        WHERE   FP.RecordID = @FixPunchRecordID


		/***
			for DAVT cases where the txn is broken up or -re-created,
			we try to get the new THD record that captures the missing punch
			
		 */
        IF ISNULL(@NewTHDRecordID, 0) = 0
            BEGIN
                SELECT  @NewTHDRecordID = THD.RecordID
                FROM    TimeHistory..tblTimeHistDetail AS THD WITH (NOLOCK)
                INNER JOIN (
                             SELECT FP2.Client ,
                                    FP2.GroupCode ,
                                    FP2.NewSiteNo AS SiteNo ,
                                    FP2.NewDeptNo AS DeptNo ,
                                    FP2.SSN ,
                                    FP2.NewTransDate AS TransDate ,
                                    FP2.NewInTime ,
                                    FP2.NewOutTime ,
                                    FP2.PayrollPeriodEndDate ,
                                    CASE WHEN FPBE.InDateTime IS NULL THEN 'O'
                                         WHEN FPBE.OutDateTime IS NULL THEN 'I'
                                         ELSE ''
                                    END AS MissingPunchType
                             FROM   TimeCurrent..tblFixedPunch AS FP2 WITH (NOLOCK)
                             INNER JOIN TimeHistory..tblFixedPunchByEE AS FPBE WITH (NOLOCK)
                             ON     FPBE.FixedPunchRecordID = FP2.RecordID
                             WHERE  FP2.RecordID = @FixPunchRecordID
                           ) AS fp
                ON      fp.Client = THD.Client
                        AND fp.GroupCode = THD.GroupCode
                        AND fp.SiteNo = THD.SiteNo
                        AND fp.DeptNo = THD.DeptNo
                        AND fp.SSN = THD.SSN
                        AND fp.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
                        AND fp.TransDate = THD.TransDate
                        AND ( fp.MissingPunchType <> ''
                              AND ( fp.MissingPunchType = 'O'
                                    AND CAST(THD.OutTime AS TIME) = CAST(fp.NewOutTime AS TIME)
                                  )
                              OR ( fp.MissingPunchType = 'I'
                                   AND CAST(THD.InTime AS TIME) = CAST(fp.NewInTime AS TIME)
                                 )
                            )

                IF ISNULL(@NewTHDRecordID, 0) <> 0
                    BEGIN
                        UPDATE  TimeHistory..tblFixedPunchByEE
                        SET     RecordID = @NewTHDRecordID
                        WHERE   FixedPunchRecordID = @FixPunchRecordID
                    END
            END
            

        IF ISNULL(@NewTHDRecordID, 0) <> 0 -- this is possibly redundant as it cannot be NULL at this point, unless the DAVT case returned no rows
            BEGIN

                IF EXISTS ( SELECT  1
                            FROM    TimeHistory..tblTimeHistDetail AS THD WITH (NOLOCK)
                            INNER JOIN TimeHistory..tblFixedPunchByEE AS FPBE WITH (NOLOCK)
                            ON      FPBE.RecordID = THD.RecordID
                                    AND ( CAST(THD.OutTime AS TIME) = CAST(FPBE.OutDateTime AS TIME)
                                          OR CAST(THD.InTime AS TIME) = CAST(FPBE.InDateTime AS TIME)
                                        )
                            WHERE   THD.RecordID = @NewTHDRecordID )
                    BEGIN

                        UPDATE  TimeHistory..tblTimeHistDetail
                        SET     OutUserCode = CASE WHEN CAST(THD.OutTime AS TIME) = CAST(FPBE.OutDateTime AS TIME) THEN 'eCorr'
                                                   ELSE OutUserCode
                                              END ,
                                UserCode = CASE WHEN CAST(THD.InTime AS TIME) = CAST(FPBE.InDateTime AS TIME) THEN 'eCorr'
                                                ELSE UserCode
                                           END
                        FROM    TimeHistory..tblTimeHistDetail AS THD
                        INNER JOIN TimeHistory..tblFixedPunchByEE AS FPBE
                        ON      FPBE.RecordID = THD.RecordID
						WHERE THD.RecordID=@NewTHDRecordID
                    
                    END
				
            END

        SELECT  @NewTHDRecordID AS NewTHDRecordID
    END

