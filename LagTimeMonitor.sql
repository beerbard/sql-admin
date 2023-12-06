--Writes lag time metrics to a temp table. 


DECLARE @LowRPOWarning INT = 30
DECLARE @MediumRPOWarning INT = 60
DECLARE @HighRPOWarning INT = 120

;WITH LastRestores AS
(
SELECT
    [d].[name] [Database],
    bmf.physical_device_name [LastFileRestored],
    bs.backup_start_date LastFileRestoredCreatedTime,
    r.restore_date [DateRestored],        
    RowNum = ROW_NUMBER() OVER (PARTITION BY d.Name ORDER BY r.[restore_date] DESC)
FROM master.sys.databases d
    INNER JOIN msdb.dbo.[restorehistory] r ON r.[destination_database_name] = d.Name
    INNER JOIN msdb..backupset bs ON [r].[backup_set_id] = [bs].[backup_set_id]
    INNER JOIN msdb..backupmediafamily bmf ON [bs].[media_set_id] = [bmf].[media_set_id] 
	--Type D = full backup, un-comment if you want to see the last full backup file restored.
	--where type='D'
)
SELECT 
     CASE WHEN DATEDIFF(MINUTE,max([LastFileRestoredCreatedTime]),GETDATE()) > @HighRPOWarning THEN 'RPO High Warning!'
        WHEN DATEDIFF(MINUTE,max([LastFileRestoredCreatedTime]),GETDATE()) > @MediumRPOWarning THEN 'RPO Medium Warning!'
        WHEN DATEDIFF(MINUTE,max([LastFileRestoredCreatedTime]),GETDATE()) > @LowRPOWarning THEN 'RPO Low Warning!'
        ELSE 'RPO Good'
     END [Status],
    [Database],
    max([LastFileRestored]) as [LastFileRestored],
    max([LastFileRestoredCreatedTime]) as [LastFileRestoredCreatedTime],
    max([DateRestored]) as [DateRestored],
	getdate() as CurrentTime,
	DATEDIFF(MINUTE,max(LastFileRestoredCreatedTime),GETDATE()) as LagTimeMin,
	count(*) as NumRestores
FROM [LastRestores]
group by [Database]
--having count(*) = 1 --Only backup restored no logs applied.
--WHERE [RowNum] = 1

--Pulls data from temp table and places it in New Relic. Implemented on NR Infrastructure Agent. 

select 
  'LogShippingLagTimeMin' as metric_name
  ,max(DATEDIFF(MINUTE,backup_start_date,GETDATE())) as LogShippingLagTimeMin
  ,'gauge' as metric_type
  ,'AllDatabases' as CustName
from 
(
select destination_database_name,max(restore_history_id) as LastRestoreID
from msdb.dbo.[restorehistory] (nolock)
group by destination_database_name
) as MostRecentRestoreIDs
    INNER JOIN msdb.dbo.[restorehistory] r on r.restore_history_id= MostRecentRestoreIDs.LastRestoreID
    INNER JOIN master.sys.databases d ON r.[destination_database_name] = d.Name
    INNER JOIN msdb..backupset bs ON [r].[backup_set_id] = [bs].[backup_set_id]
    INNER JOIN msdb..backupmediafamily bmf ON [bs].[media_set_id] = [bmf].[media_set_id] 