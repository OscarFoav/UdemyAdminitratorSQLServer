--ENABLE SQLCMD MODE TO SWITCH BETWEEN DIFFERENT SQL SERVERS WTIH A A QUERY PANE
--QUERY - SQLMCMD MODE 

--:CONNECT SQLSERVER1
--Or for a non-default instance 
--:CONNECT DESKTOP-QMOOH4U\DEV


--DROP DATABASE MIRROR

USE MASTER
GO

CREATE DATABASE MIRROR
GO

USE MIRROR
GO

CREATE TABLE CHOCOLATES
(NAME VARCHAR (25))

INSERT INTO CHOCOLATES
VALUES ('GODIVA'),('MARS'),('HERSHYS'),('DOVE'),('KITKAT')

SELECT * FROM CHOCOLATES


BACKUP DATABASE [MIRROR] TO  DISK = N'C:\Mirror\CHOC.BAK' WITH iNIT

BACKUP LOG [MIRROR] TO  DISK = N'C:\Mirror\CHOC.TRN' WITH iNIT

USE [master]
GO

--CHANGE CONNECTIONS TO DEV SERVER: THEN RUN

:CONNECT DESKTOP-QMOOH4U\DEV

RESTORE DATABASE [MIRROR] 
FROM  DISK = N'C:\Mirror\CHOC.BAK' 
WITH  FILE = 1,  
MOVE N'MIRROR' 
TO N'C:\Program Files\Microsoft SQL Server\MSSQL12.DEV\MSSQL\DATA\MIRROR.mdf',  
MOVE N'MIRROR_log' 
TO N'C:\Program Files\Microsoft SQL Server\MSSQL12.DEV\MSSQL\DATA\MIRROR_log.ldf',  
NORECOVERY
GO

RESTORE LOG [MIRROR] 
FROM  DISK = N'C:\Mirror\CHOC.TRN' 
WITH  FILE = 1,  
NORECOVERY
GO


--GO TO SECURITY - LOGINS - (RC) [NT AUTHORITY\SYSTEM] - PROPERTIES - SERVERROLE (SYSADMIN) - SELECT DB FOR DBM - DB OWNER

--CHANGE CONNECTIONS TO DEV SERVER: THEN RUN

:CONNECT DESKTOP-QMOOH4U\DEV

INSERT INTO CHOCOLATES
VALUES ('OH HENRY'),('ALMOND JOY')

SELECT * FROM CHOCOLATES

ALTER DATABASE MIRROR SET PARTNER OFF
DROP DATABASE MIRROR

USE MASTER
GO

CREATE DATABASE MIRROR
GO

USE MIRROR
GO

CREATE TABLE CHOCOLATES
(NAME VARCHAR (25))

INSERT INTO CHOCOLATES
VALUES ('GODIVA'),('MARS'),('HERSHYS'),('DOVE'),('KITKAT')

SELECT * FROM CHOCOLATES

--1 primary

alter database mirror
set recovery full
go


--2 primary
backup database mirror
to disk = 'c:\s\full.bak'
go




--4 primary

backup log mirror
to disk = 'c:\s\tlog.trn'
go



--6 primary

create endpoint endpoint_principal
state = started
as tcp (listener_port = 5022)
for database_mirroring (role = partner)
go




--9 primary

alter database mirror
set partner = 'tcp://server1:5022'
go




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

Exec msdb..sp_dbmmonitorresults 'db',1,0


--use on mirror db to stop miroring and drop db
alter database mirror set partner off
restore database mirror
drop database MIRROR


