CREATE PROCEDURE [dbo].[usp_Web1_getEmpFixPunchInfo] ( @THDRecordID BIGINT )  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
AS
    
BEGIN
        SET NOCOUNT ON

        SELECT  CASE WHEN fbe.OutDateTime IS NULL THEN 'I'
                     ELSE 'O'
                END AS MissingPunchType ,
				-- if thd time matches EE time, emp time is accepted
                CASE WHEN ( ( fbe.InDateTime IS NULL
                              AND CAST(fbe.OutDateTime AS TIME) = CAST(THD.OutTime AS TIME)
                            )
                            OR ( fbe.OutDateTime IS NULL
                                 AND CAST(fbe.InDateTime AS TIME) = CAST(THD.InTime AS TIME)
                               )
                          ) THEN 1
                     ELSE 0
                END AS IsEmployeeSuggestedTimeAccepted ,
                TimeCurrent.dbo.fn_GetDateTime(ISNULL(fbe.OutDateTime, fbe.InDateTime), 32) AS EmployeeSuggestedTime ,
                TimeCurrent.dbo.fn_GetDateTime(CASE WHEN FP.RecordID IS NULL THEN NULL
                                                    WHEN fbe.OutDateTime IS NULL THEN THD.InTime
                                                    ELSE THD.OutTime
                                               END, 32) AS AdminAcceptedTime ,
				-- fixed punch table only has record if it is resolved, either by employee or admin
                CASE WHEN FP.RecordID IS NULL THEN 0
                     ELSE 1
                END AS IsMissingPunchResolved ,
                FP.UserID AS AcceptorUserID , -- 1 means auto-accepted
                U.LastName + ', ' + U.FirstName AS AcceptorUserName ,
                TimeCurrent.dbo.fn_GetDateTime(FP.TransDateTime, 34) AS AcceptedDateTime
        FROM    TimeHistory..tblTimeHistDetail AS THD WITH ( NOLOCK )
        INNER JOIN TimeHistory..tblFixedPunchByEE AS fbe WITH ( NOLOCK )
        ON      fbe.RecordID = THD.RecordID
        LEFT  JOIN TimeCurrent..tblFixedPunch AS FP WITH ( NOLOCK )
        ON      FP.RecordID = fbe.FixedPunchRecordID
        LEFT JOIN TimeCurrent..tblUser AS U WITH ( NOLOCK )
        ON      U.UserID = FP.UserID
        WHERE   THD.RecordID = @THDRecordID

        
    END

	
