
--SQL SCRIPTS FOR MONITORING AND INVESTIGATING  DATABASE MIRRORING:

--INFORMATION ABOUT DATABASE MIRRORING

select DB_NAME(database_id) dbname,mirroring_state_desc,mirroring_role_desc,
mirroring_safety_level_desc,mirroring_safety_sequence
mirroring_partner_name,mirroring_partner_instance,
mirroring_witness_state,mirroring_witness_state_desc,
mirroring_failover_lsn,mirroring_connection_timeout,mirroring_redo_queue,
mirroring_end_of_log_lsn,mirroring_replication_lsn,*
from master.sys.database_mirroring
where mirroring_state is not null


--INFORMATION ABOUT DATABASE MIRRORING CONNECTIONS

select state_desc,connect_time,login_time,authentication_method,principal_name,
remote_user_name,last_activity_time,is_accept,login_state_desc,
receives_posted,sends_posted,total_bytes_sent,total_bytes_received,
total_sends,total_receives,*
from sys.dm_db_mirroring_connections

--INFORMATION ABOUT DATABASE MIRRORING ENDPOINTS

select name,endpoint_id,protocol_desc,type_desc,state_desc,role_desc,
connection_auth_desc,*
from sys.database_mirroring_endpoints

--SCRIPT TO INDICATE WHICH DATABASE HAS BEEN MIRRORED:

SELECT DB_NAME(database_id) AS mirrored
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
ORDER BY DB_NAME(database_id);


--SCRIPT TO INDICATE WHICH DATABASE IS IN SYNC MODE

SELECT DB_NAME(database_id) AS synchronous_mode
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
--AND mirroring_role_desc = 'PRINCIPAL'
--AND mirroring_role_desc = 'MIRROR'
AND mirroring_safety_level_desc = 'FULL'
ORDER BY DB_NAME(database_id);

--SCRIPT TO INDICATE WHICH DATABASE IS IN ASYNC MODE

SELECT DB_NAME(database_id) AS asynchronous_mode
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
--AND mirroring_role_desc = 'PRINCIPAL'
--AND mirroring_role_desc = 'MIRROR'
AND mirroring_safety_level_desc = 'OFF'
ORDER BY DB_NAME(database_id);

--SCRIPT TO INDICATE WHICH DATABASE HAS FULLT SYNCHRONIZED OR NOT

SELECT 
 DB_NAME(database_id) AS fully_synchronized
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
--AND mirroring_role_desc = 'PRINCIPAL'
--AND mirroring_role_desc = 'MIRROR'
AND mirroring_state_desc = 'SYNCHRONIZED' 
ORDER BY DB_NAME(database_id);


--SETTING THE ASYNCHRONOUS MODE OFF AND ON
 

SELECT 
  'ALTER DATABASE [' + DB_NAME(database_id) + '] SET PARTNER SAFETY OFF;'
+ ' PRINT ''[' +  DB_NAME(database_id) + '] has been set to asynchronous mirroring mode.'';'
  AS command_to_set_mirrored_database_to_use_synchronous_mirroring_mode
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
AND mirroring_role_desc = 'PRINCIPAL'
AND mirroring_safety_level_desc = 'FULL'
ORDER BY DB_NAME(database_id);


 SELECT 
  'ALTER DATABASE [' + DB_NAME(database_id) + '] SET PARTNER SAFETY FULL;'
+ ' PRINT ''[' +  DB_NAME(database_id) + '] has been set to synchronous mirroring mode.'';'
  AS command_to_set_mirrored_database_to_use_synchronous_mirroring_mode
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
AND mirroring_role_desc = 'PRINCIPAL'
AND mirroring_safety_level_desc = 'OFF'
ORDER BY DB_NAME(database_id);

 --TO SUSPEND THE DATABASE MIRRORING

 SELECT 
 'ALTER DATABASE [' + DB_NAME( database_id ) + '] SET PARTNER SUSPEND;'
+ ' PRINT ''[' +  DB_NAME(database_id) + '] has had mirroring paused.'';' 
  AS command_to_pause_mirroring_for_the_mirrored_database 
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
AND mirroring_role_desc = 'PRINCIPAL'
AND mirroring_state_desc <> 'SUSPENDED'
ORDER BY DB_NAME(database_id);

 --TO RESUME THE DATABASE MIRRORING 

SELECT 
 'ALTER DATABASE [' + DB_NAME( database_id ) + '] SET PARTNER RESUME;'
+ ' PRINT ''[' +  DB_NAME(database_id) + '] has had mirroring resumed.'';' 
  AS command_to_resume_mirroring_for_the_mirrored_database 
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
AND mirroring_role_desc = 'PRINCIPAL'
AND mirroring_state_desc = 'SUSPENDED'
ORDER BY DB_NAME(database_id);


--SETTING TO FAILOVER DATABASE MIRRORING
 

SELECT 
 'ALTER DATABASE [' + DB_NAME(database_id) + '] SET PARTNER FAILOVER;'
+ ' PRINT ''[' +  DB_NAME(database_id) + '] has been been manually failed over.'';' 
  AS command_to_manually_failover_the_mirrored_database
FROM master.sys.database_mirroring 
WHERE 1=1
AND mirroring_guid IS NOT NULL
AND mirroring_role_desc = 'PRINCIPAL'
AND mirroring_safety_level_desc = 'FULL'
AND mirroring_state_desc = 'SYNCHRONIZED'
ORDER BY DB_NAME(database_id);


-- HISTORY OF RESULTS

Exec msdb..sp_dbmmonitorresults 'prod',1,0


--use on mirror db to stop miroring and drop db

alter database mirror set partner off
restore database mirror
drop database MIRROR

USE [master]
GO

DROP ENDPOINT [endpoint_mirror]
GO
