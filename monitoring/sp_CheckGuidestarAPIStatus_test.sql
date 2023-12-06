CREATE PROCEDURE [dbo].[sp_CheckGuidestarAPIStatus]    
AS
DECLARE @ErrorCount int
DECLARE @TotalCount int    
BEGIN
 SET NOCOUNT ON    
 SET @ErrorCount = NULL;  
 SET @TotalCount = NULL;

 BEGIN  
  SELECT @ErrorCount = COUNT(1) FROM TBL_GUIDESTAR_SEARCH_HISTORY 
   WHERE B_WEB_SERVICE_CALL_SUCCESSFUL = 0
  AND D_ADDED > DATEADD(minute,-10, SYSDATETIME());

  SELECT @TotalCount = COUNT(1) FROM TBL_GUIDESTAR_SEARCH_HISTORY 
   WHERE D_ADDED > DATEADD(minute,-10, SYSDATETIME());
 END
 
 --IF (@ErrorCount < 5)  
 IF (@TotalCount = 0 OR @TotalCount <> @ErrorCount)
 BEGIN    
  PRINT 'OK: Successful Guidestar API Calls are '+ convert(varchar(10), @TotalCount) + ' in last 10 min.';
 END
 ELSE
 BEGIN
  PRINT 'WARNING: Number of API Calls failed is '+ convert(varchar(10), @ErrorCount)+ ' and Number of Successful API Calls is ' + convert(varchar(10), (@TotalCount - @ErrorCount)) + ' in last 10 min.';
 END
 RETURN 0
END



