--ON PRIMARY SERVER!!!

use master
go

create database LogShipping
go

use LogShipping
go

create table cars
(carid int identity (1,1)primary key,
carname varchar (25))


insert into cars
values ('Porche'),('BMW')

select * from cars


--LOG SHIPPING

--TO EXECUTE LOG SHIPPING , THE RECOVERY MODE MUST BE ST TO FULL

SELECT name AS [Database Name],
recovery_model_desc AS [Recovery Model] 
FROM sys.databases
GO


-- IF ITS SIMPLE, THEN CHANGE TO FULL

USE [master]
GO

ALTER DATABASE logshipping 
SET RECOVERY FULL 
GO

BACKUP DATABASE [LogShipping] 
TO  DISK = N'\\DESKTOP-QMOOH4U\backuplogshipping\logshipping.bak' 
WITH NOFORMAT, 
NOINIT,  
NAME = N'LogShipping-Full Database Backup', 
SKIP, 
NOREWIND, 
NOUNLOAD,  
STATS = 10
GO


BACKUP LOG [LogShipping] 
TO  DISK = N'\\DESKTOP-QMOOH4U\backuplogshipping\logshipping.trn' 
WITH NOFORMAT, 
NOINIT,  
NAME = N'LogShipping-Log Database Backup', 
SKIP, 
NOREWIND, 
NOUNLOAD,  
STATS = 10
GO




---ON SECONDARY SERVER RESTORE DATABASE  (CHANGE CONNECTION TO SECONDARY QUERY PANE)

USE [master]
RESTORE DATABASE [LogShipping] 
FROM  DISK = N'C:\backuplogshipping\logshipping.bak' 
WITH  FILE = 1,  
MOVE N'LogShipping' 
TO N'C:\Program Files\Microsoft SQL Server\MSSQL12.DEV\MSSQL\DATA\LogShipping.mdf',  
MOVE N'LogShipping_log' 
TO N'C:\Program Files\Microsoft SQL Server\MSSQL12.DEV\MSSQL\DATA\LogShipping_log.ldf',  
NORECOVERY,  
NOUNLOAD,  
REPLACE,  
STATS = 5

RESTORE LOG [LogShipping] 
FROM  DISK = N'C:\backuplogshipping\logshipping.trn' 
WITH  FILE = 1,  
STANDBY = N'C:\Program Files\Microsoft SQL Server\MSSQL12.DEV\MSSQL\Backup\LogShipping_RollbackUndo_2016-03-13_18-25-18.bak',  
NOUNLOAD,  
STATS = 5

GO


--SELECT COMMAND SHOWS 2 RECORDS BECAUSE THE JOBS ARE SET FOR 15 MINS (MANUAL RUN WILL CAUSE THE THIRD WO TO BE ADDED)

USE LogShipping
GO

select * from cars

insert into cars
values ('BENZ')



