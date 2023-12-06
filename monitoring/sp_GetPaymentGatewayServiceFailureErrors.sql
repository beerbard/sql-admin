CREATE PROCEDURE [dbo].[sp_GetPaymentGatewayServiceFailureErrors]
(     
	@TimeElapsedWindow int = 2,
	@AllowDebug bit = 0
)
	
AS

/*

This sproc is called by Nagios alerting system. It basically checks if an exception has occured in the Gateway service failure exception.

*/

BEGIN
	declare @DateFrom DateTime2 = CURRENT_TIMESTAMP;    
	declare @DateTo DateTime2; 
	declare @ToFlag bit; 
	declare @ErrNo int
	declare @intUnknown int, @intPaymentGatewayServiceUnavailable int, @intPaymentGatewayServiceException int, @intMerchantAccountConfigurationDbException int

	SET @DateTo = CURRENT_TIMESTAMP; 	
	SET @DateFrom = DATEADD(minute,-@TimeElapsedWindow,@DateTo); 
	
	set @intUnknown = 0
	set @intPaymentGatewayServiceUnavailable = 0
	set @intPaymentGatewayServiceException = 0
	set @intMerchantAccountConfigurationDbException = 0


	-- get DeviceDataInvalid - count
	select @intUnknown = count(1)
	from PaymentGatewayErrorAlert
	where [type] = 'Unknown'
	and AddedDate >= @DateFrom and AddedDate < @DateTo

	-- get DeviceDataUnavailable - count
	select @intPaymentGatewayServiceUnavailable = count(1)
	from PaymentGatewayErrorAlert
	where [type] = 'PaymentGatewayServiceUnavailable' 
	and AddedDate >= @DateFrom and AddedDate < @DateTo

	-- get @intPaymentGatewayServiceException - count
	select @intPaymentGatewayServiceException = count(1)
	from PaymentGatewayErrorAlert
	where [type] = 'PaymentGatewayServiceException' 
	and AddedDate >= @DateFrom and AddedDate < @DateTo


	-- get @intMerchantAccountConfigurationDbException - count
	select @intMerchantAccountConfigurationDbException = count(1)
	from PaymentGatewayErrorAlert
	where [type] = 'MerchantAccountConfigurationDbException' 
	and AddedDate >= @DateFrom and AddedDate < @DateTo

	--Print status of health
	if (isnull(@intUnknown,0) = 0 and isnull(@intPaymentGatewayServiceUnavailable,0) = 0  and isnull(@intPaymentGatewayServiceException,0) = 0 and isnull(@intMerchantAccountConfigurationDbException,0) = 0)    --and @intDeviceDataInvalid = 0
	begin    
		print 'OK: No Errors for - Unknown, PaymentGatewayServiceUnavailable, PaymentGatewayServiceException and MerchantAccountConfigurationDbException.'    
	end    
	else    
	begin    
		print 'CRITICAL: Error - Unknown - ' + convert(varchar(4), @intUnknown) + 
		' and PaymentGatewayServiceUnavailable - ' + + convert(varchar(4), @intPaymentGatewayServiceUnavailable) + 
		' and PaymentGatewayServiceException - ' + convert(varchar(4), @intPaymentGatewayServiceException) + 
		' and MerchantAccountConfigurationDbException - ' + convert(varchar(4), @intMerchantAccountConfigurationDbException)
	end    
	
	select @ErrNo = @@ERROR    
      
	if @ErrNo <> 0 begin    
		--rollback transaction    
		raiserror('IN [sp_GetPaymentGatewayServiceFailureErrors] Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
    
	return 0    
END

