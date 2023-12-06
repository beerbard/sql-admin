CREATE PROCEDURE [dbo].[sp_GetPaymentGatewayDeviceErrors]
(     
	@TimeElapsedWindow int = 2,
	@AllowDebug bit = 0
)
	
AS

/*

This sproc is called by Nagios alerting system. It basically checks if an exception has occured in the Gateway charge exception.

*/

BEGIN
	declare @DateFrom DateTime2 = CURRENT_TIMESTAMP;    
	declare @DateTo DateTime2; 
	declare @ToFlag bit; 
	declare @ErrNo int

	SET @DateTo = CURRENT_TIMESTAMP; 	
	SET @DateFrom = DATEADD(minute,-@TimeElapsedWindow,@DateTo); 
	
	DECLARE @InvalidDeviceDataAlert AS TABLE
	(
		Id INT IDENTITY(1,1),
		PartnerSource VARCHAR(255),
		PartnerId INT,
		TxnCount INT,
		InvalidCount INT
	)

	--Get all failures (UseKount = 0)
	INSERT INTO @InvalidDeviceDataAlert
	SELECT tp.VC_PARTNER_SOURCE, tpc.I_PARTNER_ID, 0, COUNT(1)
	FROM dbo.BraintreeGatewayCharge bgc (NOLOCK)
	JOIN dbo.TBL_DONATION td (NOLOCK) ON bgc.ChargeId = td.I_CHARGE_ID
	JOIN dbo.TBL_DONATION_ITEM tdi (NOLOCK) ON td.I_DONATION_ID = tdi.I_DONATION_ID
	JOIN dbo.TBL_PARTNER_CAMPAIGN tpc (NOLOCK) ON td.I_PARTNER_CAMPAIGN_ID = tpc.I_PARTNER_CAMPAIGN_ID
	JOIN dbo.TBL_PARTNER tp (NOLOCK) ON tpc.I_PARTNER_ID = tp.I_PARTNER_ID
	WHERE bgc.DonationType IN ('OneTime','FirstRecurring')
	AND bgc.UseKount = 0
	AND tpc.I_PARTNER_ID NOT IN (100591,100459) -- Exclude ENTERPRISE (100591) and NFGTEST (100459)
	AND bgc.AddedDate >= @DateFrom AND bgc.AddedDate < @DateTo
	GROUP BY tp.VC_PARTNER_SOURCE, tpc.I_PARTNER_ID

	DECLARE @Id INT, @MaxId INT, @PartnerId INT, @TxnCount INT
	SELECT @Id = 1, @MaxId = MAX(Id) FROM @InvalidDeviceDataAlert

	--Update total txn count per partner
	WHILE (@Id <= @MaxId)
	BEGIN
		SELECT @PartnerId = PartnerId FROM @InvalidDeviceDataAlert WHERE Id = @Id

		SELECT @TxnCount = COUNT(bgc.Id)
		FROM dbo.BraintreeGatewayCharge bgc (NOLOCK)
		JOIN dbo.TBL_DONATION td (NOLOCK) ON bgc.ChargeId = td.I_CHARGE_ID
		JOIN dbo.TBL_DONATION_ITEM tdi (NOLOCK) ON td.I_DONATION_ID = tdi.I_DONATION_ID
		JOIN dbo.TBL_PARTNER_CAMPAIGN tpc (NOLOCK) ON td.I_PARTNER_CAMPAIGN_ID = tpc.I_PARTNER_CAMPAIGN_ID
		WHERE bgc.DonationType IN ('OneTime','FirstRecurring')
		AND tpc.I_PARTNER_ID = @PartnerId
		AND bgc.AddedDate >= @DateFrom AND bgc.AddedDate < @DateTo

		UPDATE @InvalidDeviceDataAlert SET TxnCount = @TxnCount WHERE Id = @Id

		SET @Id = @Id + 1
	END

	--Remove records with failed count not matching the total txn count since we only want to be alerted when all txns coming in have invalid device data
	DELETE FROM @InvalidDeviceDataAlert WHERE InvalidCount <> TxnCount

	--Print status of health
	if NOT EXISTS (SELECT 1 FROM @InvalidDeviceDataAlert)
	begin    
		print 'OK: No Errors for - DeviceDataUnavailable and DeviceDataInvalid.'    
	end    
	else    
	begin
		--DECLARE @statusMsg VARCHAR(MAX)
		--SELECT @statusMsg = STUFF((SELECT ', ' + PartnerSource + ' (' + CAST(InvalidCount AS VARCHAR) + ' of ' + CAST(TxnCount AS VARCHAR) + ')'
  --                           FROM @InvalidDeviceDataAlert
  --                           ORDER BY Id
  --                           FOR XML PATH('')), 
  --                          1, 1, '')

		--print 'CRITICAL: Error - Device Data invalid for partner(s): ' + @statusMsg
		
		DECLARE @InvalidCount INT
		SELECT @InvalidCount = ISNULL(SUM(InvalidCount),0) FROM @InvalidDeviceDataAlert
		print 'CRITICAL: Error - Device Data invalid count = ' + CAST(@InvalidCount AS VARCHAR)
	end    
	
	select @ErrNo = @@ERROR    
      
	if @ErrNo <> 0 begin    
		--rollback transaction    
		raiserror('IN [sp_GetPaymentGatewayDeviceErrors] Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
    
	return 0    
END

