CREATE PROCEDURE [dbo].[sp_GetAPIServiceStatus](  
	@ServiceName VARCHAR(100)= NULL,    
	@PartnerName VARCHAR(100)= NULL,    
	@TimeElapsedWindow int = 30,    
    @APIMethodType VARCHAR(255) = NULL,    
    @ExludeMethods varchar(max) =NULL)    
AS
DECLARE @ErrNo int    
BEGIN
	SET NOCOUNT ON    

	DECLARE @TotalCount int;    
	DECLARE @DateFrom DateTime;    
	DECLARE @DateTo DateTime;
	DECLARE @APIMethodTypeid int;  

	SET @TotalCount = 0;    
	SET @DateTo = CURRENT_TIMESTAMP;    
	SET @APIMethodTypeId = NULL;  
   
	IF (@ExludeMethods IS NOT NULL AND (@ExludeMethods='' OR @ExludeMethods='None'))  
	BEGIN  
		SET @ExludeMethods = NULL;  
	END  
	
	IF (@APIMethodType IS NOT NULL or @APIMethodType != '')  
	BEGIN  
		SELECT @APIMethodTypeId = I_API_METHOD_TYPE_ID FROM dbo.TBL_API_METHOD_TYPE where VC_API_METHOD_TYPE = @APIMethodType;  
	END  
	
	IF (@APIMethodTypeId IS null or @APIMethodTypeId = 0)  
	BEGIN  
		SELECT @APIMethodTypeId = I_API_METHOD_TYPE_ID FROM dbo.TBL_API_METHOD_TYPE where VC_API_METHOD_TYPE = 'RealTimeDonationProcessing';  
	END  
    SET @DateFrom = DATEADD (minute,-@TimeElapsedWindow,@DateTo);    
    
	IF (@PartnerName IS NULL or @PartnerName ='' or @PartnerName ='All')     
	BEGIN     
		SET @PartnerName = 'General'    
	END

	IF @ServiceName = 'API-DonationServices' AND @APIMethodTypeId = 9 -- 9 is RealTimeDonationProcessing
	BEGIN
		SELECT @TotalCount = count(1)    
		FROM TBL_API_ACCESS_LOG    
		WHERE      
			VC_SERVICE_NAME IN('API-DonationServices','OrganizationDonationService')
			AND I_API_METHOD_TYPE_ID IN (9,12) -- to consider both 'RealTimeDonationProcessing' and 'OrganizationDonation'
			AND (@ExludeMethods IS NULL or VC_METHOD_NAME not in (select [String] from dbo.fn_CSVToTable(@ExludeMethods)))  
			AND D_ADDED BETWEEN @DateFrom and @DateTo    
	END
	ELSE
	BEGIN
		SELECT @TotalCount = count(1)    
		FROM TBL_API_ACCESS_LOG    
		WHERE      
			VC_SERVICE_NAME = @ServiceName    
			AND I_API_METHOD_TYPE_ID = @APIMethodTypeId   
			AND (@ExludeMethods IS NULL or VC_METHOD_NAME not in (select [String] from dbo.fn_CSVToTable(@ExludeMethods)))  
			AND D_ADDED BETWEEN @DateFrom and @DateTo    
	END

	
	SELECT @ErrNo = @@ERROR    
      
	IF @ErrNo <> 0 
	BEGIN    
		RAISERROR('IN sp_GetAPIServiceStatus Some Error-- Errno: %d', 11,1, @ErrNo)    
		RETURN -1    
	END    
    
	IF (@TotalCount = 0)    
	BEGIN    
		PRINT 'CRITICAL: There are  0 donations in last ' + convert(varchar(10), @TimeElapsedWindow) + ' minutes'
	END    
	ELSE
	BEGIN    
		PRINT 'OK: There are ' + convert(varchar(10), @TotalCount) + ' donations in last ' + convert(varchar(10), @TimeElapsedWindow) + ' minutes'
	END    
	RETURN 0
END


