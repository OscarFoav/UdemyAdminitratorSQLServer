--- Queries curso DBA SQL Server 2012

--- Part 1

http://www.vmware.com/products/workstation/workstation-evaluation 
https://msdn.microsoft.com/enus/windowsserver2012r2.aspx 
https://www.microsoft.com/en-us/download/details.aspx?id=29066



dbcc LogInfo;

dbcc sqlperf(logspace);


CREATE DATABASE AdventureWorks2012
ON (FILENAME = 'I:\DataFiles\AdventureWorks2012_Data.mdf')
FOR ATTACH_REBUILD_LOG ;

--RESULTS:

--As the insert is being recored in the transaction log that was 1mb in size, the initial size (1mb) of the tlog recording can't keep up with the
--activity, and as such, needs to expand by 10% each time there is modifications to record.

-- query to find auto growth setting for all or specified database (or use the SQL reports)

USE [master]
GO
 
BEGIN TRY
    IF (SELECT CONVERT(INT,value_in_use) FROM sys.configurations WHERE NAME = 'default trace enabled') = 1
    BEGIN
        DECLARE @curr_tracefilename VARCHAR(500);
        DECLARE @base_tracefilename VARCHAR(500);
        DECLARE @indx INT;
 
        SELECT @curr_tracefilename = path FROM sys.traces WHERE is_default = 1;
        SET @curr_tracefilename = REVERSE(@curr_tracefilename);
        SELECT @indx  = PATINDEX('%\%', @curr_tracefilename) ;
        SET @curr_tracefilename = REVERSE(@curr_tracefilename) ;
        SET @base_tracefilename = LEFT( @curr_tracefilename,LEN(@curr_tracefilename) - @indx) + '\log.trc'; 
        SELECT
            --(DENSE_RANK() OVER (ORDER BY StartTime DESC))%2 AS l1,
            ServerName AS [SQL_Instance],
            --CONVERT(INT, EventClass) AS EventClass,
            DatabaseName AS [Database_Name],
            Filename AS [Logical_File_Name],
            (Duration/1000) AS [Duration_MS],
            CONVERT(VARCHAR(50),StartTime, 100) AS [Start_Time],
            --EndTime,
            CAST((IntegerData*8.0/1024) AS DECIMAL(19,2)) AS [Change_In_Size_MB]
        FROM ::fn_trace_gettable(@base_tracefilename, default)
        WHERE
            EventClass >=  92
            AND EventClass <=  95
            --AND ServerName = @@SERVERNAME
            --AND DatabaseName = 'myDBName'  
			AND DatabaseName IN ('auto','auto2')
        ORDER BY DatabaseName, StartTime DESC;  
    END    
    ELSE   
        SELECT -1 AS l1,
        0 AS EventClass,
        0 DatabaseName,
        0 AS Filename,
        0 AS Duration,
        0 AS StartTime,
        0 AS EndTime,
        0 AS ChangeInSize 
END TRY 
BEGIN CATCH 
    SELECT -100 AS l1,
    ERROR_NUMBER() AS EventClass,
    ERROR_SEVERITY() DatabaseName,
    ERROR_STATE() AS Filename,
    ERROR_MESSAGE() AS Duration,
    1 AS StartTime, 
    1 AS EndTime,
    1 AS ChangeInSize 
END CATCH


----------------------------------------------------------------------------

SQL Server System Databases
     Each time you install any SQL Server Edition on a server; there are four primary system databases, each of which must be present for the server to operate effectively. 
Master
•	file locations of the user databases
•	login accounts
•	server configuration settings
•	linked servers information
•	startup stored procedures  
Model
•	A template database that is copied into a new database 
•	Options set in model will be applied to new databases
•	Used to create tempdb every time the server starts  
Msdb
•	Support SQL Server Agent
•	SQL Server Management Studio
•	Database Mail
•	Service Broker
•	History and metadata information is available in msdb
•	Backup and restore history for the databases
•	History for SQL agent jobs
Tempdb
•	The tempdb is a shared resource used by SQL Server all users 
•	Tempdb is used for temporary objects, worktables, online index operations, cursors, table variables, and the snapshot isolation version store, among other things
•	It is recreated every time that the server is restarted
•	As tempdb is non-permanent storage, backups and restores are not allowed for this database.  
Reporting Services Databases
•	ReportServer - available if you have installed Reporting Services 
•	ReportServerTempDB - available if you have installed Reporting Services
Replication System Database
•	Distribution - available when you configure Replication
Resource Database
•	Read-only hidden database that contains all the system information
•	Cant  back up the Resource database
•	Must copy paste the file
•	C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Binn

----------------------------------------------------------------------------


What is a database file?
     When you create a database, two primary files are created by default: the data file and the transaction log file.  The primary purpose of the data file is to hold all the data, such tables, indexes, store procedures and other relevant data.  While the data file is simple to understand and requires some management, the transaction log file requires a greater attention and understanding.

What are a transaction log file and its purpose?
The primary function of the transaction log file is to:
Record all changes to the database
Record changes sequentially
All data is written to the transaction log file first before committing the changes to the data file
A triggering mechanism, called a checkpoint,  is triggered each few minutes to the transaction log to indicate that a particular transaction has been completely written from the buffer to the data file;  this process keeps flushes out the committed transaction, and maintains the size of the physical transaction log file (only in simple recovery mode) 
 Key object needed to restore databases
Controls the size of the transaction log file and prevents the log consuming the disk space
 Used in log shipping, database mirroring, and replication
Allows recover to a point in time

Reason the transaction log file is out of control in size

Transaction log backups are not occurring while in Simple recovery mode
 Very long transactions are occurring, like indexes of table or many updates
Demo to control the size of transaction log by doing log backups

Stop
What are the recovery models and their roles?
The recovery models in SQL Server, Simple, Full, Bulk-Logged, determine whether a transaction log backup is available or not
With Simple recovery model
Transaction log backups are not supported
Truncation of the transaction log is done automatically, thereby releasing space to the system
You can lose data, as there are no transaction log backups
When in recovery mode, data in the T-Log will not grow
With Bulk-logged recovery model
Supports transaction log backups 
As in Full mode, there is no automated process of transaction log truncation
Used primarily for bulk operations, such as bulk insert, thereby minimal 
Full recovery model
Supports transaction log backups 
Little chance of data loss under the normal circumstances
No automated process to truncate the log thus must have T-log backups
The transaction log backups must be made regularly to mark unused space available for overwriting
When using Full recovery mode, the T-log can get large in size 

During most backup processes, the changes contained in the logfile are sent to the backup file
Scripts for Recovery Models:
select [name], DATABASEPROPERTYEX([name],'recovery')
from sysdatabases
where name not in ('master','model','tempdb','msdb')

--Change the recovery mode:
USE master;
GO
-- Set recovery model to SIMPLE
ALTER DATABASE Admin SET RECOVERY SIMPLE;
GO
 -- Set recovery model to FULL
ALTER DATABASE Admin SET RECOVERY FULL;
GO




SCRIPTS TO CHECK THE TRANSACTION LOG
--Demo that taking a full backup does not truncate the log file, but taking a transaction log file does truncate the log file

--drop the current database

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'ADMIN'
GO

USE [master]
GO

ALTER DATABASE [ADMIN] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO

USE [master]
DROP DATABASE [ADMIN]
GO

--Create a database for testing

  USE MASTER
  GO
  
  CREATE DATABASE ADMIN
  GO


-- Create a table and insert data from AdventureWorks2012.HumanResources.Employee

USE ADMIN
GO

SELECT *
INTO dbo.AAA
FROM AdventureWorks2012.HumanResources.Employee

SELECT * FROM AAA

--Change the recovery mode to full so as to take transactional log backups

USE MASTER;
ALTER DATABASE ADMIN
SET RECOVERY FULL;

USE ADMIN 
GO

-- View the space used and allocated to transaction log

DBCC SQLPERF (LOGSPACE);

--Database Name	Log Size (MB)	Log Space Used (%)	Status
--ADMIN	          0.5078125	       74.71154	           0

--Take a full backup of database

BACKUP DATABASE admin
TO DISK = 'C:\FullBackups\admin.bak';

-- Modify the database by updates, and deletes

USE Admin
GO


UPDATE AAA
SET MaritalStatus = 'S'
WHERE JobTitle = 'Design Engineer';

DELETE AAA
WHERE BusinessEntityID > 5;

--take a full database backup to set it in full mode

BACKUP DATABASE admin
TO DISK = 'C:\FullBackups\admin.bak';


--check the space used by log file after full database backup, notice the log space used had not reduced in size!

DBCC SQLPERF (LOGSPACE);

--Database Name	Log Size (MB)	Log Space Used (%)	Status
--ADMIN	         0.8046875	       74.45388	          0	          

--take a transaction log backup.  Note that the size of the log file space used is reduced, but not the actual size of the file
--this is because, when you take a log backup, the inactive transactions are removed from the log file to the backup file!

BACKUP log  admin
TO DISK = 'C:\FullBackups\admin.bak'

DBCC SQLPERF (LOGSPACE);

--Database Name	Log Size (MB)	Log Space Used (%)	Status
--ADMIN	          0.8046875	       48.36165	           0


Viewing inside the SQL Server Database Transaction Log to prevent internal fragmentation
(Auto growth and sizing of auto growth log)
     There is a function called (fn_dblog) which requires a beginning LSN and an ending LSN (Log Sequence Number) for a transaction, but for our purpose we will use NULL as starting and ending values. The following example will show how the transaction log records multiple rows of data for any activity against the database and how a transaction log backup truncates the transaction file, once it’s written to the backup log.  (fn_dblog)  A ways to view the contents of the log.  DONOT RUN THIS COMMAND IN PRODUCTION AS IT IS UNDOCUMENTED.
USE [master];
GO
CREATE DATABASE VIEWLOG;
GO
-- Create tables.
USE VIEWLOG;
GO
CREATE TABLE Cities
(City varchar (20));
USE VIEWLOG;
GO
Backup database fnlog to disk = 'C:\FullBackups\VIEWLOG.back'
Insert into Cities values ('NewYork')
Go 1000
Select COUNT (*) from fn_dblog (null, null)
Backup database fnlog to disk = 'C:\FullBackups\VIEWLOG.back'
Select COUNT (*) from fn_dblog (null, null)


Backup log fnlog to disk = 'C:\FullBackups\VIEWLOG.back'
Select COUNT (*) from fn_dblog (null, null)
Select * from fn_dblog (null, null)
Options to truncate the log file:
1.	Backup the database.
2.	Detach the database, 
3.	Delete the transaction log file. (or rename the file, just in case)
4.	Re-attach the database 
5.	Shrink the database
6.	None of the above





----------------------------------------------------------------------------

--Drop database auto
--Drop database auto2


--Create database with default setting based on the Model database configuration

Use master
go

CREATE DATABASE [auto]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'auto', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\auto.mdf' , 
SIZE = 3072KB ,      --<< initial size of data file 3mb      
FILEGROWTH = 1024KB )  --<< growth by 1mg

 LOG ON 
( NAME = N'auto_log', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\auto_log.ldf' , 
SIZE = 1024KB ,    --<< initial size of log file 1mb 
FILEGROWTH = 10%)  --<< growth by 10%
GO

DBCC LogInfo;


--Create database with set LOG FILE setting

CREATE DATABASE [auto2]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'auto2', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\auto2.mdf' , 
SIZE = 1024000KB ,       --<< initial size of data file 1000mb 
FILEGROWTH = 102400KB )  

 LOG ON 
( NAME = N'auto2_log', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\auto2_log.ldf' , 
SIZE = 102400KB , 
FILEGROWTH = 102400KB ) --<< growth by 100mb (PRE SIZED SO THAT THE AUTO GROWTH DOES NOT ACTIVATE)
GO

DBCC LogInfo

-- examine the database files

sp_helpdb auto
sp_helpdb auto2

dbcc sqlperf (logspace)

--move data from adventureworks2012 to auto and auto2 dtabase via import/export wizard OR 

Select * Into LogGrowthTable from adventureworks2012.sales.SalesOrderDetai3l


------------------------------------------------------------------------
--RESULTS:

--As the insert is being recored in the transaction log that was 1mb in size, the initial size (1mb) of the tlog recording can't keep up with the
--activity, and as such, needs to expand by 10% each time there is modifications to record.

-- query to find auto growth setting for all or specified database (or use the SQL reports)

USE [master]
GO
 
BEGIN TRY
    IF (SELECT CONVERT(INT,value_in_use) FROM sys.configurations WHERE NAME = 'default trace enabled') = 1
    BEGIN
        DECLARE @curr_tracefilename VARCHAR(500);
        DECLARE @base_tracefilename VARCHAR(500);
        DECLARE @indx INT;
 
        SELECT @curr_tracefilename = path FROM sys.traces WHERE is_default = 1;
        SET @curr_tracefilename = REVERSE(@curr_tracefilename);
        SELECT @indx  = PATINDEX('%\%', @curr_tracefilename) ;
        SET @curr_tracefilename = REVERSE(@curr_tracefilename) ;
        SET @base_tracefilename = LEFT( @curr_tracefilename,LEN(@curr_tracefilename) - @indx) + '\log.trc'; 
        SELECT
            --(DENSE_RANK() OVER (ORDER BY StartTime DESC))%2 AS l1,
            ServerName AS [SQL_Instance],
            --CONVERT(INT, EventClass) AS EventClass,
            DatabaseName AS [Database_Name],
            Filename AS [Logical_File_Name],
            (Duration/1000) AS [Duration_MS],
            CONVERT(VARCHAR(50),StartTime, 100) AS [Start_Time],
            --EndTime,
            CAST((IntegerData*8.0/1024) AS DECIMAL(19,2)) AS [Change_In_Size_MB]
        FROM ::fn_trace_gettable(@base_tracefilename, default)
        WHERE
            EventClass >=  92
            AND EventClass <=  95
            --AND ServerName = @@SERVERNAME
            --AND DatabaseName = 'myDBName'  
			AND DatabaseName IN ('auto','auto2')
        ORDER BY DatabaseName, StartTime DESC;  
    END    
    ELSE   
        SELECT -1 AS l1,
        0 AS EventClass,
        0 DatabaseName,
        0 AS Filename,
        0 AS Duration,
        0 AS StartTime,
        0 AS EndTime,
        0 AS ChangeInSize 
END TRY 
BEGIN CATCH 
    SELECT -100 AS l1,
    ERROR_NUMBER() AS EventClass,
    ERROR_SEVERITY() DatabaseName,
    ERROR_STATE() AS Filename,
    ERROR_MESSAGE() AS Duration,
    1 AS StartTime, 
    1 AS EndTime,
    1 AS ChangeInSize 
END CATCH

--DBCC LogInfo;




----------------------------------------------------------------------------

--Virtual Log File and the transaction log file
--Virtual Log Files (VLF)
--Anatomy of a transaction log file --VLF blocks

--the size and number of VLF added at the time of expanding the transaction log is based on this following criteria:

--transaction log size less than 64MB and up to 64MB = 4 VLFs
--transaction log size larger than 64MB and up to 1GB = 8 VLFs
--transaction size log larger than 1GB = 16 VLFs

--1. CREATE A DATABASE WITH LOG FILE LESS THAN 64 MB THAT WILL CREATE 4 VLFS

/*
the following will show that improper sizing of the transaction log file and setting and relying on the default auto growth contributes to internal log fragmentation, 
and causes the VLFS to increase.
*/

--Note that the transaction log is 1 megabyte in size, and the autogrowth is set to grow in increments of 10% (bad practice)

CREATE DATABASE [Log Growth]
ON PRIMARY
( NAME = N'LogGrowth', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\LogGrowth.mdf' ,
SIZE = 4096KB ,
FILEGROWTH = 1024KB )

LOG ON
( NAME = N'LogGrowth_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\LogGrowth_log.ldf' ,
SIZE = 1024KB , --1 megabyte
FILEGROWTH = 10%)
GO

USE [Log Growth]
GO
--Each row indicates a VLF

DBCC LOGINFO
GO

--4 VLFS
--look at the size of the database and note transaction log is 1 MB and data file is 4MB

sp_helpdb [Log Growth]

--Insert data into table from another database and view the transaction log size, data file size, and the percentage of transaction log used

Use [Log Growth]
go

Select * Into LogGrowthTable from adventureworks2012.sales.SalesOrderDetail

select count(*) from LogGrowthTable

--log space used 28.7 %

DBCC sqlPerf (LogSpace)

--look at the size of the database and note transaction log is 14 MB and data file is 15MB

sp_helpdb [Log Growth]

--Each row indicates a VLF

DBCC LOGINFO
GO

--47 VLFs created as a result of improper pre sizing of the transaction log, and relying upon the auto growth property to accommodate the expansion of file
--Drop the database

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'LogGrowth'
GO
USE [master]
GO
DROP DATABASE [Log Growth]
GO
--===============================================================================================================================================================================================================
--The following demonstration will illustrate the number of VLF created depending upon the sizing of the transaction log
--Inserting the same amount of data into the table, 
--but this time sizing the transaction log before inserting data by managing the autogrowth size so as to avoid VLFS from being created

--transaction log size larger than 64MB and up to 1GB = 8 VLFs

CREATE DATABASE [Log Growth]
ON PRIMARY
( NAME = N'LogGrowth', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\LogGrowth.mdf' ,
SIZE = 1000 MB ,
FILEGROWTH = 100 MB )

LOG ON
( NAME = N'LogGrowth_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\LogGrowth_log.ldf' ,
SIZE = 500 MB , --500 MEGA BYTES - PRE SIZING THE LOG FILE SO AS TO AVOID AUTO GROWTH FROM KICKING IN. AUTOGROWTH SET TO 100 GROWTH RATE AS A FAILSAFE
FILEGROWTH = 100 MB) --file auto growth NOT set to 10%, but allocated 100 in MEGA BYTES
GO

USE [Log Growth]
GO
--Each row indicates a VLF

DBCC LOGINFO
GO

--8 VLFS

--look at the size of the database and note transaction log is 500 MB and data file is 1000

sp_helpdb [Log Growth]

--Insert data into table from another database and view the transaction log size, data file size, and the percentage of transaction log used

Use [Log Growth]
go

Select * Into LogGrowthTable from adventureworks2012.sales.SalesOrderDetail

select count(*) from LogGrowthTable

--121317

--log space used 2.504434 %

DBCC sqlPerf (LogSpace)

--Each row indicates a VLF

DBCC LOGINFO
GO
--VLFs have not increased in number as a result of pre sizing the transaction log to 500 MB and therefore having the need to rely on auto growth from kicking in
--Drop the database

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'LogGrowth'
GO
USE [master]
GO
DROP DATABASE [Log Growth]
GO




----------------------------------------------------------------------------

--create database either by GUI or script it out

--Create a database with proper configuration taking in the following consideration:

--pre size the data file and auto growth property of the data file
--pre size the log file and auto growth property of the log file
--have each data and transaction log file on its own physical drive
--sizing based on the activity that your environment uses
--base your size roughly on two or three years of growth patterns

--NOTE: CHANGED THE DEFAULT KB TO MG!

USE master
GO

CREATE DATABASE [Production2]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'Production2', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\Production2.mdf' , --<< this must be in its own physical drive
SIZE = 5MB , --<< pre size the data file 5000 mb
FILEGROWTH = 1MB )  --<< pre size the log file 100 mb

 LOG ON 
( NAME = N'Production2_log', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\Production2_log.ldf' , --<< this must be in its own physical drive
SIZE = 1MB , --<< pre size size of transaction log file 100 mb
FILEGROWTH = 1MB ) --<< pre size size auto growth to increase in increments of 5 mb
GO


sp_helpdb [Production]

-- 1 minute and 10 seconds to create a database for database file size 5 gigs!

--size the physical DRIVE size of both the data and the transaction log file based on activity and workload
--as both the data and log files are on seperate physical hard drives, if possible, allocated the data file and log file to the amount of physical drive!
--we have set the auto growth to increase by 50 mg for the transaction log, but what if a transaction needs more than 50 mg of space, won't that cause
--the auto growth to kick in?
--and if another transaction needs more than 50mg oF space, won't the transaction log get full and stop working?
--YES
--but you must take transaction log backups to truncate the transaction log file so that it does not consume the physical drive!!!



----------------------------------------------------------------------------

What is detaching and attaching a database
The process of moving the data and the log files to another drive or server for performance reasons 
How to use detach and attach a database
At times there may be a need to move a database to another physical drive or another physical server; if so, you can use the sprocs detach and attach or use a GUI
Step by step moving a database
--The following scripts will detach and then reattach the sales database

--Find the path of the database

sp_helpdb sales

--Set the database to a single user mode

USE [master]
GO

ALTER DATABASE [Sales] 
SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO

--Detach the database using the sprocs

USE [master]
GO

EXEC master.dbo.sp_detach_db @dbname = N'Sales', @skipchecks = 'false'
GO

--Reattach the database using the FOR ATTACH command

USE [master]
GO
CREATE DATABASE [Sales] ON 
( FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\Sales.mdf' ),
( FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\Sales_log.ldf' )
 FOR ATTACH --<<use for attach to attach the sales database
GO
Note: when moving a database using detach and attach, you will lose the users in the original database after the completion of the move to a new server.  To resolve this, use the following sproc to link the user to the login in the new server.

EXEC sp_change_users_login 'Update_One', 'Bob', 'Bob'




----------------------------------------------------------------------------

Database Backup Strategies

One of the most important responsibilities of a DBA is the planning, testing and deployment of the backup plan.  The planning of the backup strategy, ironically, starts with the restore strategy that has been determined by the organization.   Two leading questions direct the restore strategy: What is the maximum amount of data loss that can be tolerated, and what is the accepted time frame for the database to be restored in case of a disaster.  The first question involves taking multiple transaction logs backups and the second question involves the use of high availability solutions.  To answer these question, you must ask the why, what, when, where and who for the strategy.
Why back-up?

Backups are taken in order to be able to restore the database to its original state just before the disaster and protect against the following reasons:
·         hardware failure
·         malicious damage
·         user-error
·         database corruption
What is a backup?

Simply put, it is an image of the database at the time of the full backup.
There are several different kinds of backups:
·         Full backup - a complete, page-by-page copy of an entire database including all the data, all the structures and all other objects stored within the database.
·         Differential backups -  a backup of a database that have been modified in any way since the last full backup.
·         Transaction Log - a backup of all the committed transactions currently stored in the transaction log
·         Copy-only backup -  a special-use backup that is independent of the regular sequence of SQL Server backups.
·         File backup - a backup of one or more database files or filegroups
·         Partial backup - contains data from only some of the filegroups in a database
When to do backups?

Again, this is a company decision that must be determined by asking the following questions: What is the maximum amount of data loss that can be tolerated, and what is the accepted time frame for the database to be restored in case of a disaster.  The first question will address the use of transaction logs and their frequency, and the second question will involve some type of high availability solution.
Where should backups be placed?

Ideally, the backups should be placed on their own drives onto separate servers from the production server, and then using a third party application, copies made to a remote server on a separate site. What should not be tolerated is having backups on the same drive and server as the data and log files.  If the server crashes, we lose all hopes or restoring critical data!
What needs backing up?

All user defined databases and system database should be backed up.
Who should perform backups?

The person in charge of the backup planning and executing will most likely be the Database Administrator (DBA).  He will coordinate with the upper management, direct and provide valuable advice on the best practices for restoring the database; however, note that on a production server, most of the backups will be automated by using the SQL Agent and jobs.
Backup Retention Period
The amount of backups retained is a question determined by the business needs. Most likely, it may involve a month of backups onsite and three months of backups offsite.  But again, this depends upon the organization needs.
Performing Backups

The following method illustrates the use of  T-SQL to backup database because it provides a greater and granular control of the process.  However, you can use the SSMS console.
Full Database backup
Backup the whole database, which includes parts of transaction log which is needed to recover the database using full backup.
 
Create a test database
 
 
Use master
go
 
 
Create database Sales
go
 
use sales
go
 
 
Create table Products
(ProductID int IDENTITY (1,1) Primary Key,
ProductName varchar (100),
Brand varchar (100))
go
 
insert into Products values ('Bike','Genesis')
insert into Products values ('Hat','Nike')
insert into Products values ('Shoe','Payless')
insert into Products values ('Phone','Apple')
insert into Products values ('Book','Green')
insert into Products values ('Cup','Large')
 
select * from Products
BACKUP DATABASE [sales]
TO  DISK = N'c:\fullbackups\sales.bak'
WITH NOINIT,
NAME = N'sales-Full Database Backup',
COMPRESSION,
STATS = 10
GO
 
declare @backupSetId as int
select @backupSetId = position
from msdb..backupset
where database_name=N'sales'
and backup_set_id=(select max(backup_set_id)
from msdb..backupset where database_name=N'sales' )
if @backupSetId is null
begin
raiserror(N'Verify failed. Backup information for database ''sales'' not found.', 16, 1)
end
RESTORE VERIFYONLY
FROM
DISK = N'c:\fullbackups\sales.bak'
WITH  FILE = @backupSetId
GO
 
Differential backup
The database must have a full back up in order to take a differential backup; it only backups the changes since last full backup.
BACKUP DATABASE [sales]
TO  DISK = N'c:\fullbackups\sales.bak'
WITH  DIFFERENTIAL ,
NOINIT,
NAME = N'sales-Differential Database Backup',
COMPRESSION,
STATS = 10
GO
 
declare @backupSetId as int
select @backupSetId = position
from msdb..backupset
where database_name=N'sales'
and backup_set_id=(select max(backup_set_id)
from msdb..backupset where database_name=N'sales' )
if @backupSetId is null
begin
raiserror(N'Verify failed. Backup information for database ''sales'' not found.', 16, 1)
end
 
RESTORE VERIFYONLY
FROM  DISK = N'c:\fullbackups\sales.bak'
WITH  FILE = @backupSetId
GO
 
Transaction Log backup
You must backup the transaction log, if SQL Server database uses either FULL or BULK-LOGGED recovery model otherwise transaction log is going to full. Backing up the transaction log truncates the log and user should be able to restore the database to a specific point in time.
BACKUP LOG [sales]
TO  DISK = N'c:\fullbackups\sales.bak'
WITH
NAME = N'sales-Transaction Log  Backup',
COMPRESSION,
STATS = 10
GO
 
declare @backupSetId as int
select @backupSetId = position
from msdb..backupset
where database_name=N'sales' and backup_set_id=(select max(backup_set_id)
from msdb..backupset where database_name=N'sales' )
if @backupSetId is null
begin
raiserror(N'Verify failed. Backup information for database ''sales'' not found.', 16, 1)
end
RESTORE VERIFYONLY
FROM  DISK = N'c:\fullbackups\sales.bak'
WITH  FILE = @backupSetId
GO
 
Recovery models

There are three recovery models that can be set on each user database which determines the types of backups you’ll use. You set the recovery model via the GUI or use the ALTER DATABASE command:
·         SELECT name, recovery_model_desc FROM sys.databases --ß find the recovery model
·         ALTER DATABASE SALES SET RECOVERY FULL
·         ALTER DATABASE SALES SET RECOVERY SIMPLE
·         ALTER DATABASE SALES SET RECOVERY BULK_LOGGED
Simple
When in this mode, the transaction are removed automatically at each checkpoint within the database and no log backups are possible. Recovery to a point in time is not possible and you could lose substantial amounts of data under simple recovery.  Not advised for production databases that are critical.
Bulk-logged
This recovery model reduces the size of the transaction log by minimally logging some operations such as bulk inserts. The problem is, recovery to a point in time is not possible with this recovery model because any minimally logged operations cannot be restored. This means that bulk-logged has all the overhead of Full Recovery, but effectively works like Simple Recovery. Unless you have specific needs or are willing to perform lots of extra backup operations, it’s not recommended to use bulk-logged recovery.
Full
In full recovery you must run a log backup on a regular basis in order to reclaim log space. Recovery to a point in time is fully supported. For any production system that has data that is vital to the business, full recovery should be used.
Backup History
The following commands provides information as to the history of the backups in the MSDB database.
 
Use msdb
go
SELECT * FROM dbo.backupfile  -- Contains one row for each data or log file that is backed up
SELECT * FROM dbo.backupmediafamily  -- Contains one row for each media family
SELECT * FROM dbo.backupmediaset -- Contains one row for each backup media set
SELECT * FROM dbo.backupset  -- Contains a row for each backup set
SELECT * FROM dbo.backupfilegroup -- Contains one row for each filegroup in a database at the time of backup
Backup File Information
It is possible to look at a backup file itself to get information about the backup. The header of the backup stores data like when the backup was created, what type of backup it is, the user who took the backup and all other sorts of information. The basic commands available are:
RESTORE LABELONLY FROM DISK = N'c:\fullbackups\sales.bak'
RESTORE HEADERONLY FROM DISK = N'c:\fullbackups\sales.bak'
RESTORE FILELISTONLY FROM DISK = N'c:\fullbackups\sales.bak'
Basic Backup Process
The following  backup schedule is one that I have used on a production server for critical data bases.
·         Sunday Night: Full Backup with database consistency check (DBCC CHECKDB)
Monday-Saturday: Differential Backup each day
Midnight-11:45PM: Log Backup every 30 minutes
What is important to understand is that you frequently test your backups with restores, at least once a month, to ensure that your backups are valid and restorable.  Having backups is useless unless they have been tested well.  When backing up database, starting with SQL version 2008 and up, you have the ability to compress the databases backup, which saves time to backup and restore.  Note that the CPU resource will consume about 20% additional resource, thus, the backup must be done in the off hours.
 
 
Example of backup plan using different types of backups
12:00 am - Create an empty database (20 gigs)
12:15 am - Full backup
12:30 am - Insert 100,000 rows (1 gig)
12:45 am - Differential backup (size1 gig after diff)
1:00 am - Insert 100,000 rows (1 gig)
1:15 am - Differential backup (size 2 gigs after diff)
1:30 am - Insert 100,000 rows (1 gig)
1:15 am - Differential backup (size 3 gigs after diff)
1:30 am - Insert 100,000 rows (1 gig)
1:45 am - Transactional log (size 4 gigs after t-log)
2:00 am - Insert 100,000 rows (1 gig)
2:15 am - Transactional log (size 5 gigs after t-log)
 
Restore the database process
12:15 am - Full backup
1:15 am - Differential backup (size 3 gigs after diff)
1:45 am - Transactional log (size 4 gigs after t-log)
2:15 am - Transactional log (size 5 gigs after t-log)


----------------------------------------------------------------------------


Restoring a database

The principal reason we take backups of system and user defined databases is that it allows us to restore the databases in case of a disaster. There are a few restore commands that we should be familiar with and they are as follows:

Restore Commands:

• RESTORE DATABASE - allows us to restore a full, differential, file or filegroup backup
• RESTORE LOG - allows us to restore a transaction log backup

Informational Restore Commands:

• RESTORE HEADERONLY - gives you a list of all the backups in a file
• RESTORE FILELISTONLY - gives you a list of all of the files that were backed up for a give backup
• RESTORE VERIFYONLY - verifies that the backup is readable by the RESTORE process
• RESTORE LABELONLY - gives you the backup media information
RESTORE HEADERONLY
The RESTORE HEADERONLY option allows you to see the backup header information for all backups for a particular backup device.

Example:

RESTORE HEADERONLY FROM DISK = 'C:\FullBackups\test.bak'
GO
RESTORE FILELISTONLY
The RESTORE FILELISTONLY option allows you to see a list of the files that were backed up such as the .mdf and .ldf.

Example:

RESTORE FILELISTONLY FROM DISK = 'C:\FullBackups\test.bak'
GO
RESTORE VERIFYONLY
Verifies that the backup is readable by the RESTORE process
Example:

RESTORE VERIFYONLY from disk = 'C:\FullBackups\test.bak'
RESTORE LABELONLY
The RESTORE LABELONLY option allows you to see the backup media information for the backup device

----------------------------------------------------------------------------


--Drop database BackupDatabase

--Create a test database

Use master
go

Create database BackupDatabase
go


use BackupDatabase 
go

--Create table

Create table Products
(ProductID int IDENTITY (1,1) Primary Key,
ProductName varchar (100),
Brand varchar (100))
go

--Insert data into table

insert into Products values ('motor','chevy')
insert into Products values ('Hat','Nike')
insert into Products values ('Shoe','Payless')
insert into Products values ('Phone','Apple')
insert into Products values ('Book','Green')
insert into Products values ('Cup','Large')

--View data

select * from Products

--Take full database backup of six rows

BACKUP DATABASE [BackupDatabase] 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH NOINIT,  --<< No override
NAME = N'BackupDatabase-Full Database Backup', 
STATS = 10
GO


--Insert data into table AFTER a full database backup, but before a transactional log backup

Insert into Products values ('Doll','Toy_R_us')

BACKUP LOG BackupDatabase 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH 
NAME = N'BackupDatabase-Transaction Log  Backup', 
STATS = 10
GO



Insert into Products values ('House','Remax')

--another transaction log backup

BACKUP LOG BackupDatabase 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH 
NAME = N'BackupDatabase-Transaction Log  Backup', 
STATS = 10
GO



Insert into Products values ('Car','Porche')

--Taking differential backups

BACKUP DATABASE [BackupDatabase] 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH  DIFFERENTIAL , 
NOINIT,  
NAME = N'BackupDatabase-Differential Database Backup',   
STATS = 10
GO

Insert into Products values ('Chair','Walmart')

BACKUP LOG BackupDatabase 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH 
NAME = N'BackupDatabase-Transaction Log  Backup', 
STATS = 10
GO


Insert into Products values ('Mouse','Apple')

BACKUP LOG BackupDatabase 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH 
NAME = N'BackupDatabase-Transaction Log  Backup', 
STATS = 10
GO

Insert into Products values ('TV','Sony')

BACKUP DATABASE [BackupDatabase] 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH  DIFFERENTIAL , 
NOINIT,  
NAME = N'BackupDatabase-Differential Database Backup',   
STATS = 10
GO


Insert into Products values ('Phone','Apple')

BACKUP LOG BackupDatabase 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH 
NAME = N'BackupDatabase-Transaction Log  Backup', 
STATS = 10
GO

--Look insde the .bak file
RESTORE HEADERONLY FROM DISK = N'c:\fullbackups\BackupDatabase.bak'


--Restore database using T SQL

--before restoring a database, if you can, take a very last transactional log backup to save data:
--tail log
USE master
GO
BACKUP LOG BackupDatabase 
TO  DISK = N'c:\fullbackups\BackupDatabase.bak' 
WITH NORECOVERY,
NAME = N'BackupDatabase-Transaction Log  Backup', 
STATS = 10
GO


USE [master]
Go


RESTORE DATABASE [BackupDatabase] 
FROM  DISK = N'C:\FullBackups\BackupDatabase.bak' 
WITH  FILE = 1,  
NORECOVERY,  
NOUNLOAD,  
STATS = 5

RESTORE DATABASE [BackupDatabase] 
FROM  DISK = N'C:\FullBackups\BackupDatabase.bak' 
WITH  FILE = 7,  
NORECOVERY,  
NOUNLOAD,  
STATS = 5

RESTORE LOG [BackupDatabase] 
FROM  DISK = N'C:\FullBackups\BackupDatabase.bak' 
WITH  FILE = 8,  
NORECOVERY,
NOUNLOAD,  
STATS = 5

RESTORE LOG [BackupDatabase] 
FROM  DISK = N'C:\FullBackups\BackupDatabase.bak' 
WITH  FILE = 9,  
RECOVERY,
NOUNLOAD,  
STATS = 5
GO

RESTORE LOG [BackupDatabase] 
FROM  DISK = N'C:\FullBackups\BackupDatabase.bak' 
WITH  FILE = 10,  
NORECOVERY,
NOUNLOAD,  
STATS = 5
GO

RESTORE LOG [BackupDatabase] 
FROM  DISK = N'C:\FullBackups\BackupDatabase.bak' 
WITH  FILE = 11,  
RECOVERY,
NOUNLOAD,  
STATS = 5
GO

----------------------------------------------------------------------------


USE Admin
GO

CREATE TABLE dbo.WHILE_TABLE 
(
FIRSTNAME VARCHAR (800)
)
GO
  

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

WAITFOR DELAY '00:00:05' --<<USING THE WAITFOR DELAY TO 'PAUSE' THE EXECUTIONOF THE NEXT COMMAND

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

WAITFOR DELAY '00:00:10'

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

WAITFOR DELAY '00:00:15'

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

WAITFOR DELAY '00:00:10'

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

WAITFOR DELAY '00:00:05' --<<USING THE WAITFOR DELAY TO 'PAUSE' THE EXECUTIONOF THE NEXT COMMAND

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

WAITFOR DELAY '00:00:10'

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

WAITFOR DELAY '00:00:15'

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

--USING A WHILE LOOP COMMAND TO POPULATE DATA INTO A TABLE

WAITFOR DELAY '00:00:10'

declare @i int;
SET @i = 0;
while @i < 100
begin
	INSERT INTO DBO.WHILE_TABLE (FIRSTNAME)
	VALUES(cast(replicate('DBA',203) AS VARCHAR (20)));
	SET @i = @i + 1;
end;
GO

SELECT * FROM DBO.WHILE_TABLE

--1000 ROWS


----------------------------------------------------------------------------

Maintenance Plan Tasks
Check Database Integrity Purpose:
•	The DBCC CHECKDB performs an internal consistency check 
•	very resource intensive
•	perform it on a regular basis
Shrink Database
•	Shrinking a database is a very poor practice in the SQL world.  Don’t do it
Rebuild Index
•	The Rebuild Index task physically rebuilding indexes from scratch
•	This removes index fragmentation and updates statistics at the same time
Reorganize Index
•	The Reorganize Index task helps to remove index fragmentation, but does not update index and column statistics
•	If you use this option to remove index fragmentation, then you will also need to run the Update Statistics task as part of the same Maintenance Plan
Update Statistics
•	The Update Statistics task runs the sp_updatestats system stored procedure against the tables 
•	Dont run it after running the Rebuild Index task, as the Rebuild Index task performs this same task automatically
Execute SQL Server Agent Job
•	The Execute SQL Server Agent Job task allows you to select SQL Server Agent jobs (ones you have previously created), and to execute them as part of a Maintenance Plan
History Cleanup
•	The History Cleanup task deletes historical data from the msdb database
•	backup and restore
•	SQL Server Agent and Maintenance Plans

Back Up Database (Full)
•	The Back Up Database (Full) task executes the BACKUP DATABASE statement and creates a full backup of the database
Back Up Database (Differential)
•	The Back Up Database (Differential) task executes the BACKUP DATABASE statement using the DIFFERENTIAL option
Backup Database (Transaction Log)
•	The Backup Database (Transaction Log) task executes the BACKUP LOG statement, and, in most cases, should be part of any Maintenance Plan that uses the Back Up Database (Full) task
Maintenance Cleanup Task
•	Use a batch file to clean up files



----------------------------------------------------------------------------

Shrinking a Database
     The primary purpose of shrinking a database (or individual files) is to reclaim the SPACE by removing unused pages when a file no longer needs to be as large as it once was; shrinking the file may then become necessary, but as we will demonstrate, this process is highly discouraged and is an extremely poor practice in the production database environment.



Things to note
•	Both data and transaction log files can be shrunk individually or collectively
•	When using the DBCC SHRINKDATABASE statement, you cannot shrink a whole database to be smaller than its original size. However, you can shrink the individual database files to a smaller size than their initial size by using the DBCC SHRINKFILE statement.
•	The size of the virtual log files within the log determines the possible reductions in size. 
•	Shrinking causes massive fragmentation and will just result in the data file growing again next time data gets added.  When that happens, the entire system will slow down as the file is expanded. 
Automatic Database Shrinking
     When the AUTO_SHRINK database option has been set to ON, the Database Engine automatically shrinks databases that have free space. By default, it is set to OFF. Leave it as is.
Database Shrinking Commands
•	DBCC SHRINKDATABASE (ShrinkDB, 10)
•	DBCC SHRINKFILE (ShrinkDB, 10)
Best Practices
•	Size the database accordingly so as to prevent shrinking and expanding the database
•	When unused space is created due to dropping of tables, shrinking of the database may be needed - but rarely
•	Dont constantly shrink the database as it will grow again
•	When you shrink a database, the indexes on tables are not preserved and as such will causes massive fragmentation and will have to be rebuilt
•	Shrinking the log file may be necessary if your log has grown out of control however, shrinking the log should be rare also
•	Regular maintenance plans should never have shrink database job
•	Other issues that shrinking causes are lot of I/O, of CPU usage, and transaction log gets larger – as everything it does is fully logged.

/*the following example will illustrate that shrinking a database will

1. Causes pages being moved from the front of file to the end
2. It will cause massive fragmentation
3. It will not reduce the size of the data file, but actually increase it
4. That shrinking a database will cause unnecessary I/O hits
5. That shrinking a database was a futile endeavor because of poor planning regarding sizing of database
6. And that shrinking a database should be very rarely done
*/

USE [master];
GO
 
CREATE DATABASE ShrinkDB;
GO

USE [ShrinkDB];
GO
 

-- Create an initial table at the 'front' of the data file
CREATE TABLE Initial (
    [col1] INT IDENTITY,
    [col2] CHAR (8000) DEFAULT 'Front');
GO


-- Insert data into Initial table
INSERT INTO Initial DEFAULT VALUES;
GO 1500

select * from Initial

--check the size of the database
sp_helpdb [ShrinkDB]
--14.83 MB
 
-- Create the second table, which will be created 'after' the initial table in the data file
CREATE TABLE second (
    [col1] INT IDENTITY,
    [col2] CHAR (8000) DEFAULT 'after');

--create a clusterd index on the second table
CREATE CLUSTERED INDEX [coll] ON second ([col1]);
GO
 

-- Insert data into second table
INSERT INTO second DEFAULT VALUES;
GO 1500


select * from second

--check db size 
sp_helpdb [ShrinkDB]

--database expanded due to insert of data in the second table (26.83 MB)
 
-- Check the fragmentation of the second table
SELECT
    [avg_fragmentation_in_percent]
FROM sys.dm_db_index_physical_stats (
    DB_ID (N'ShrinkDB'), OBJECT_ID (N'second'), 1, NULL, 'LIMITED');
GO

--notice that the fragmentation of the clustered index for the second table is almost zero before the shrink

--We will now drop the initial table we created and execute the shrink command to reclaim the SPACE at the front of the data file
-- then see what happens to the fragmentaion.

DROP TABLE Initial;
GO


sp_helpdb [ShrinkDB]
-- 26.83 MB the data file has not shrunk due to the deletion of the initial table
 
-- Shrink the database
DBCC SHRINKDATABASE ([ShrinkDB]);
GO

--notice that the SPACE after the shrink went down from 26.83 to 15.02 mb
sp_helpdb [ShrinkDB]
--15.02 MB
 
-- But notice what happened to the fragmentation of the data file because of the shrinking of the database???
--when Checking the index fragmentation again, we notice that the fragmentation has drastically increased to almost 100%!!!
--this is because we have shuffled all the data pages and the index is not in a sorted position

SELECT
    [avg_fragmentation_in_percent]
FROM sys.dm_db_index_physical_stats (
    DB_ID (N'ShrinkDB'), OBJECT_ID (N'second'), 1, NULL, 'LIMITED');
GO

--99.6

--while the database has shrunk, and we have reclaimed space from the data file, we MUST now the fix the fragmented index of the table by rebuilding the index!!!

-- Rebuild the Clustered Index

ALTER INDEX [coll] ON second REBUILD
GO


-- Checking the index fragmentation again indicates that the fragmentaion of the index has been restored, but notice the size of the data
--file when we run the sp_helpdb [ShrinkDB] - it has actually GROWN even more than it started from!!!

SELECT
    [avg_fragmentation_in_percent]
FROM sys.dm_db_index_physical_stats (
    DB_ID (N'ShrinkDB'), OBJECT_ID (N'second'), 1, NULL, 'LIMITED');
GO

--0.2%

sp_helpdb [ShrinkDB]
--41.81 MB

--the database file has grown because of the rebuilding of the index and the logging of the index

--use master
--go
--select * from sys.databases

--sp_helpdb ShrinkDB
--transaction log = 13888 KB

--individual file shrink
USE ShrinkDB
GO
DBCC SHRINKFILE (N'ShrinkDB_Log' , 0, TRUNCATEONLY)
GO

sp_helpdb ShrinkDB

--784 KB



--USE ShrinkDB
--GO
--DBCC SHRINKFILE (N'ShrinkDB_Data' , 0, TRUNCATEONLY)
--GO


--USE ShrinkDB
--GO
--DBCC SHRINKDATABASE(N'ShrinkDB' )
--GO





----------------------------------------------------------------------------

What is the SQL Server Agent?
•	SQL Server Agent uses SQL Server to store job information
•	A job is a specified series of actions that can run on a local server or on multiple remote servers
•	Jobs can contain one or more other job steps
•	SQL Server Agent can run on a job on a schedule
•	To a response or a specific event or manually
•	You can avoid repetitive tasks by automating those tasks
•	SQL Server Agent can record the event and notify you via email or pager
•	You can set up a job using the SQL Agent for SSIS packages or for Analysis Services 
•	More than one job can run on the same schedule, and more than one schedule can apply to the same job
Alerts
•	An alert is an automatic response to a specific event. Which you can you define the conditions under which an alert occurs fires
Operators
•	An operator is the contact person for alerts via the following: 
•	E-mail
•	Pager (through e-mail)
•	net send

Security for SQL Server Agent Administration
•	SQL Agent uses the following msdb database roles to manage security:
•	SQLAgentUserRole
•	SQLAgentReaderRole
•	SQLAgentOperatorRole 
SQL Agent Multi Server Administration

Using Master/Target servers to manage many jobs at once

Error Logs and job activity monitor


----------------------------------------------------------------------------

DBCC CHECKDB
WHAT IS THE PURPOSE OF DBCC CHECKDB
The primary purpose is to check both the logical and the physical integrity of all objects in the specified database. In a busy and large production database, it may become necessary to run a few selected options that the DBCC CHECKDB provides.
COMPLETE SYNTAX OF DBCC CHECKDB
DBCC CHECKDB 
    ( 'database_name' 
            [ , NOINDEX 
                | { REPAIR_ALLOW_DATA_LOSS 
                    | REPAIR_FAST 
                    | REPAIR_REBUILD 
                    } ] 
    )    [ WITH { [ ALL_ERRORMSGS ] 
                    [ , [ NO_INFOMSGS ] ] 
                    [ , [ TABLOCK ] ] 
                    [ , [ ESTIMATEONLY ] ] 
                    [ , [ PHYSICAL_ONLY ] ] 
                    } 
        ] 

DBCC CHECKDB SYNTAX OPTIONS


--Checks all data in database --8 seconds

DBCC CHECKDB ('adventureworks2012')

DBCC CHECKDB ('adventureworks2012', NOINDEX) --5 seconds

--Specifies that non clustered indexes for non system tables should not be checked

USE [master]
GO

DBCC CHECKDB WITH NO_INFOMSGS

--Suppresses all informational messages (use in a large database)

DBCC CHECKDB ('TEMPDB') WITH ESTIMATEONLY

--Displays the estimated amount of tempdb space needed to run DBCC CHECKDB (if you want to unload the integrity check to the tempdb)


DBCC CHECKDB ('adventureworks2012') WITH PHYSICAL_ONLY

--This checks physical on-disk structures, but omits the internal logical checks



----------------------------------------------------------------------------


Configuring and setting up SQL database mail

Database Mail is an enterprise solution for sending e-mail messages from the SQL Server Database Engine. Using Database Mail, your database applications can send e-mail messages to users. Database Mail is not active by default. To use Database Mail, you must explicitly enable Database Mail by using either the Database Mail Configuration Wizard or sp_configure stored procedure. Once it has been enabled, you can configure SQL mail using either GUI (Wizard) or by script.

After the Account and the Profile are created successfully, we need to configure the Database Mail. To configure it, we need to enable the Database Mail XPs parameter through the sp_configure stored procedure, as shown here:
sp_CONFIGURE -- shows the options for server properties (about 17)
GO
sp_CONFIGURE 'Show Advanced', 1 -- shows the options for server properties (about 69)
GO
RECONFIGURE
GO
sp_CONFIGURE 'Database Mail XPs',1 -- configure the database mail
GO
RECONFIGURE
GO
--------------------------------------------------
sp_CONFIGURE 'Show Advanced', 0 -- set the options off for server properties
GO
RECONFIGURE
GO

Setting up SQL database mail via wizard:

Database Mail Configuration through scripts
When you need to setup Database Mail on dozens of SQL Server instances, rather than perform this tedious task using the SSMS GUI, use the following script that saves me a lot of time. Below is the template. The sysmail_add_account_sp @username and @password parameters might be required depending on your SMTP server authentication and you will of course need to customize the mail server name and addresses for your environment.
-- 1. Enable Database Mail for this instance
EXECUTE sp_configure 'show advanced', 1;
RECONFIGURE;
EXECUTE sp_configure 'Database Mail XPs',1;
RECONFIGURE;
GO
-- 2. Create a Database Mail account
EXECUTE msdb.dbo.sysmail_add_account_sp
@account_name = 'Primary Account',
@description = 'Account used by all mail profiles.',
@email_address = 'myaddress@mydomain.com', -- enter your email address here
@replyto_address = 'myaddress@mydomain.com', -- enter your email address here
@display_name = 'Database Mail',
@mailserver_name = 'mail.mydomain.com'; -- enter your server name here
--3. Create a Database Mail profile
EXECUTE msdb.dbo.sysmail_add_profile_sp
@profile_name = 'Default Public Profile',
@description = 'Default public profile for all users';
-- 4.Add the account to the profile
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
@profile_name = 'Default Public Profile',
@account_name = 'Primary Account',
@sequence_number = 1;
-- 5.Grant access to the profile to all msdb database users
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
@profile_name = 'Default Public Profile',
@principal_name = 'public',
@is_default = 1;
GO
--6.send a test email
EXECUTE msdb.dbo.sp_send_dbmail
@subject = 'Test Database Mail Message',
@recipients = 'testaddress@mydomain.com', -- enter your email address here
@query = 'SELECT @@SERVERNAME';
GO
Database Mail keeps copies of outgoing e-mail messages and other information about mail and displays them in msdb database using the following scripts:
use msdb
go
SELECT * FROM sysmail_server
SELECT * FROM sysmail_allitems
SELECT * FROM sysmail_sentitems
SELECT * FROM sysmail_unsentitems
SELECT * FROM sysmail_faileditems
SELECT * FROM sysmail_mailitems
SELECT * FROM sysmail_log

----------------------------------------------------------------------------

Alerts: Severity Levels

•	What are alerts?
•	Setting up 17 thought 25 alerts via script
•	Mapping alerts to DBA ADMIN operator
•	Example of creating an alert for T-LOG Full
     Events are generated by SQL Server and entered into the Microsoft Windows application log. SQL Server Agent reads the application log and compares events written there to the alerts that you have defined. When SQL Server Agent finds a match, it fires an alert

Types of problem:
 Severity level 10 messages are informational
 Severity levels from 11 through 16 are generated by the user
Severity levels from 17 through 25 indicate software or hardware errors
When a level 17, 18, or 19 errors occurs, you can continue working but check the error log 
If the problem affects an entire database, you can use DBCC CHECKDB (database) to determine the extent of the damage
Severity Level 17: Insufficient Resources
These messages indicate that the statement caused SQL Server to run out of resources (such as locks or disk space for the database) 
Severity Level 18: Nonfatal Internal Error Detected
These messages indicate that there is some type of internal software problem, but the statement finishes, and the connection to SQL Server is maintained. For example, a severity level 18 message occurs when the SQL Server query processor detects an internal error during query optimization. 
Severity Level 19: SQL Server Error in Resource
These messages indicate that some no configurable internal limit has been exceeded and the current batch process is terminated. Severity level 19 errors occur rarely
Severity Level 20: SQL Server Fatal Error in Current Process
These messages indicate that a statement has encountered a problem. Because the problem has affected only the current process, it is unlikely that the database itself has been damaged.
Severity Level 21: SQL Server Fatal Error in Database (dbid) Processes
These messages indicate that you have encountered a problem that affects all processes in the current database; however, it is unlikely that the database itself has been damaged.
Severity Level 22: SQL Server Fatal Error Table Integrity Suspect
These messages indicate that the table or index specified in the message has been damaged by a software or hardware problem.
Severity Level 23: SQL Server Fatal Error: Database Integrity Suspect
These messages indicate that the integrity of the entire database is in question because of a hardware or software problem.
Severity level 23 errors occur rarely; DBCC CHECKDB to determine the extent of the damage may be necessary to restore the database.
Severity Level 24: Hardware Error
These messages indicate some type of media failure. The system administrator might have to reload the database. It might also be necessary to call your hardware vendor.
Setting Up SQL Server Agent Alerts
USE [msdb]
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 17 Alert', 
  @message_id=0, 
  @severity=17, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 18 Alert', 
  @message_id=0, 
  @severity=18, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 19 Alert', 
  @message_id=0, 
  @severity=19, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 20 Alert', 
  @message_id=0, 
  @severity=20, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 21 Alert', 
  @message_id=0, 
  @severity=21, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 22 Alert', 
  @message_id=0, 
  @severity=22, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 23 Alert', 
  @message_id=0, 
  @severity=23, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 24 Alert', 
  @message_id=0, 
  @severity=24, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO

EXEC msdb.dbo.sp_add_alert @name=N'Error 25 Alert', 
  @message_id=0, 
  @severity=25, 
  @enabled=1, 
  @delay_between_responses=0, 
  @include_event_description_in=1;
GO


Configuring the SQL Server Operator
USE msdb;
GO
EXEC msdb.dbo.sp_add_operator
  @name = 'DBAs',
  @enabled = 1,
  @email_address = 'DBAs@mycompany.com';
GO 

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 17 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 18 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 19 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 20 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 21 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 22 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 23 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 24 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO

EXEC msdb.dbo.sp_add_notification 
  @alert_name = N'Error 25 Alert',
  @operator_name = 'DBAs',
  @notification_method = 1;
GO



----------------------------------------------------------------------------


--Create a SQL Login not using Windows User

USE [master]
GO

CREATE LOGIN [Mary] 
WITH PASSWORD=N'password123' --<< password does not meet complexity (use upper 'P')
MUST_CHANGE, DEFAULT_DATABASE=[master], 
CHECK_EXPIRATION=ON, 
CHECK_POLICY=ON
GO

USE [AdventureWorks2012]
GO

CREATE USER [Mary] FOR LOGIN [Mary] --<< Create a SQL Login
GO

USE [AdventureWorks2012]
GO

ALTER ROLE [db_datareader] --<< Add SQL Login to database Role (db_datareader)
ADD MEMBER [Mary]
GO

----------------------------------------------------------------------------

Creating SQL Roles
What are SQL Roles – Predefined collection of objects and permissions?
Roles allow the dba to manage permissions more efficiently
We first create roles and then assign permissions to roles, and then add logins to the roles
SQL Server supports four types of roles
•	Fixed database roles - These roles already have pre – defined set of permissions
•	User-defined database roles - These roles have their set of permissions defined by the sa
•	Fixed server roles – These roles already have pre – defined set of permissions
•	User-defined server roles – These roles have their set of permissions defined by the sa
The following shows the fixed database-level roles and their capabilities. These roles exist in all databases.
Database-level role 
db_owner	
Members of the db_owner fixed database role can perform all configuration and maintenance activities on the database, and can also drop the database.
db_securityadmin	
Members of the db_securityadmin fixed database role can modify role membership and manage permissions (be careful)
db_accessadmin	
Members of the db_accessadmin fixed database role can add or remove access to the database for Windows logins, Windows groups, and SQL Server logins.
db_backupoperator	
Members of the db_backupoperator fixed database role can back up the database.
db_ddladmin	
Members of the db_ddladmin fixed database role can run any Data Definition Language (DDL) command in a database.
db_datawriter	
Members of the db_datawriter fixed database role can add, delete, or change data in all user tables.
db_datareader	
Members of the db_datareader fixed database role can read all data from all user tables.
db_denydatawriter	
Members of the db_denydatawriter fixed database role cannot add, modify, or delete any data in the user tables within a database.
db_denydatareader	
Members of the db_denydatareader fixed database role cannot read any data in the user tables within a database.

--Demo
Create a Role that access only two HR tables.
Create database role: HR Tables
Add Securable: Department table, Employee table 
Grant Select on both tables
Add both Peter and Robert logins to the database role HR Table










SQL Server Roles
The Server Roles page lists all possible roles that can be assigned to the new login. 
bulkadmin
Members of the bulkadmin fixed server role can run the BULK INSERT statement.
dbcreator
Members of the dbcreator fixed server role can create, alter, drop, and restore any database.
diskadmin
Members of the diskadmin fixed server role can manage disk files.
processadmin
Members of the processadmin fixed server role can terminate processes running in an instance of the Database Engine.
public
All SQL Server users, groups, and roles belong to the public fixed server role by default.
securityadmin
Members of the securityadmin fixed server role manage logins and their properties. They can GRANT, DENY, and REVOKE server-level permissions. They can also GRANT, DENY, and REVOKE database-level permissions. Additionally, they can reset passwords for SQL Server logins.
serveradmin
Members of the serveradmin fixed server role can change server-wide configuration options and shut down the server.
setupadmin
Members of the setupadmin fixed server role can add and remove linked servers, and they can execute some system stored procedures.

Sysadmin  (‘God’ like powers – can do anything and everything)
Members of the sysadmin fixed server role can perform any activity in the Database Engine.

----------------------------------------------------------------------------

What are GRANT, DENY, and REVOKE Permissions
GRANT – this allows the principal to perform an action
DENY – this Denies permission to a login (principal)
REVOKE – These remove the grant or deny permission to the securable
      Notes:
A deny will override a grant. This means that if a user is denied permission they cannot inherit a grant from another source




Viewing the Permissions Script
SELECT  
    [UserName] = CASE princ.[type] 
                    WHEN 'S' THEN princ.[name]
                    WHEN 'U' THEN ulogin.[name] COLLATE Latin1_General_CI_AI
                 END,
    [UserType] = CASE princ.[type]
                    WHEN 'S' THEN 'SQL User'
                    WHEN 'U' THEN 'Windows User'
                 END,  
    [DatabaseUserName] = princ.[name],       
    [Role] = null,      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],       
    [ObjectType] = obj.type_desc,--perm.[class_desc],       
    [ObjectName] = OBJECT_NAME(perm.major_id),
    [ColumnName] = col.[name]
FROM    
    --database user
    sys.database_principals princ  
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on princ.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = princ.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col ON col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]
WHERE 
    princ.[type] in ('S','U')
UNION
--List all access provisioned to a sql user or windows user/group through a database or application role
SELECT  
    [UserName] = CASE memberprinc.[type] 
                    WHEN 'S' THEN memberprinc.[name]
                    WHEN 'U' THEN ulogin.[name] COLLATE Latin1_General_CI_AI
                 END,
    [UserType] = CASE memberprinc.[type]
                    WHEN 'S' THEN 'SQL User'
                    WHEN 'U' THEN 'Windows User'
                 END, 
    [DatabaseUserName] = memberprinc.[name],   
    [Role] = roleprinc.[name],      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],       
    [ObjectType] = obj.type_desc,--perm.[class_desc],   
    [ObjectName] = OBJECT_NAME(perm.major_id),
    [ColumnName] = col.[name]
FROM    
    --Role/member associations
    sys.database_role_members members
JOIN
    --Roles
    sys.database_principals roleprinc ON roleprinc.[principal_id] = members.[role_principal_id]
JOIN
    --Role members (database users)
    sys.database_principals memberprinc ON memberprinc.[principal_id] = members.[member_principal_id]
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on memberprinc.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]
UNION
--List all access provisioned to the public role, which everyone gets by default
SELECT  
    [UserName] = '{All Users}',
    [UserType] = '{All Users}', 
    [DatabaseUserName] = '{All Users}',       
    [Role] = roleprinc.[name],      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],       
    [ObjectType] = obj.type_desc,--perm.[class_desc],  
    [ObjectName] = OBJECT_NAME(perm.major_id),
    [ColumnName] = col.[name]
FROM    
    --Roles
    sys.database_principals roleprinc
LEFT JOIN        
    --Role permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]                   
JOIN 
    --All objects   
    sys.objects obj ON obj.[object_id] = perm.[major_id]
WHERE
    --Only roles
    roleprinc.[type] = 'R' AND
    --Only public role
    roleprinc.[name] = 'public' AND
    --Only objects of ours, not the MS objects
    obj.is_ms_shipped = 0
ORDER BY
    princ.[Name],
    OBJECT_NAME(perm.major_id),
    col.[name],
    perm.[permission_name],
    perm.[state_desc],
    obj.type_desc--perm.[class_desc] 

----------------------------------------------------------------------------

Best Practice to Secure the SQL Server(s)
Start with the physical server room where the Servers are kept
Insure that only selected IT staff has access (Network Admins, System Admins, and SQL DBAs)
Keep the backups not only on site, but keep a copy of backups off site
Install all service packs and critical fixes for Windows Operating System and SQL Server Service Packs
(Test on test server first before applying to production)
Disable the default admin the BUILTIN\Administrators group from the SQL Server (demo)
Use Windows Authentication mode as opposed to mixed Mode (demo)
Use service accounts for applications and create a different service account for each SQL Service
Create service accounts with the least privileges
Document all user permission with the script and keep track of which user has what permissions (demo)
Disable all features via the SQL Server Configuration Manager that are not in use (demo)
Install only required components when installing SQL Server (don’t install ssrs, ssis, ssas)
Disable the SA account and rename it (demo)
Remove the BUILTIN\Administrators Windows Group from a SQL (demo)
Use SQL Server Roles to limit logins accessing database (as shown in previous videos)
Use permission to give only that is needed to the SQL Login or User
Hide all databases from logins (demo)
Be proactive in securing the SQL Server and databases


--Drop the BUILTIN\administrators

EXEC master..xp_logininfo 
@acctname = 'Builtin\Administrators',
@option = 'members' 

USE MASTER
IF EXISTS (SELECT * FROM sys.server_principals
WHERE name = N'BUILTIN\Administrators')
DROP LOGIN [BUILTIN\Administrators]
GO

--Verfiy the Builtin\Administrators group has been dropped

EXEC master..xp_logininfo 
  @acctname = 'Builtin\Administrators',
  @option = 'members'     


--AddBuiltin\Administrators 

EXEC sp_grantlogin 'BUILTIN\Administrators'
EXEC sp_addsrvrolemember 'BUILTIN\Administrators','sysadmin'


EXEC master..xp_logininfo 
  @acctname = 'Builtin\Administrators',
  @option = 'members' 


  --Enable Windows Authentication (requires a restart of services)

USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', 
N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', 
REG_DWORD, 1
GO

--Enable Mixed Mode Authentication (requires a restart of services)

USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', 
N'Software\Microsoft\MSSQLServer\MSSQLServer', 
N'LoginMode', REG_DWORD, 2
GO


--Get infor on all SQL Logins and Windows users

SELECT name AS Login_Name,TYPE, type_desc AS Account_Type
FROM sys.server_principals 
WHERE TYPE IN ('U', 'S', 'G')
ORDER BY name, type_desc


--make sure you have a login that is part of the sysadmin role before doing this!!!!

USE [master]
GO
ALTER LOGIN [sa] WITH PASSWORD=N'Password#12345'
GO
ALTER LOGIN [sa] DISABLE
GO


USE [master]
GO
ALTER LOGIN [sa] WITH PASSWORD=N'Password#12345'
GO
ALTER LOGIN [sa] ENABLE
GO

--Hide all databases

    
USE MASTER
GO
DENY VIEW ANY DATABASE TO PUBLIC
GO

--unhide all databases

USE MASTER
GO
GRANT VIEW ANY DATABASE TO PUBLIC;
GO



----------------------------------------------------------------------------

--- Part 2

For more Information and new courses visit us at:
Rafacademy.com


Sites to download

SQL Server 2014
http://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2014

Red Gate Software:
https://www.red-gate.com/products/




----------------------------------------------------------------------------


Use SQL2
Go



Create Table People
(
PeopleID int Identity (1,1),
Fname varchar (20),
Lname varchar (20),
Address1 varchar (100),
City varchar (50),
State varchar (50),
Zip varchar (10),
Country varchar (50),
Phone varchar (20))



--Verify data inserts

select COUNT (*) from People

--View database size

sp_helpdb  [SQL2]


select top 100 * from People


BACKUP DATABASE [SQL2] 
TO  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL12.SQL2014\MSSQL\Backup\SQL2.bak' 
WITH NOFORMAT, 
NOINIT, 
NAME = N'SQL2-Full Database Backup', 
SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO


----------------------------------------------------------------------------


What Is an Index?
•	An index can be best described as a pointer to data in a table. An index in a database is very similar to an index in the back of a book or the phone book.  Indexes are created on the table or the view
Purpose of index
•	The purpose of an index is to retrieve data from a table efficiently and fast
Types of indexes
•	Clustered Indexes
Clustered indexes sort the data rows in the table or view based on their key values, as such there can be only one clustered index per table. When a table does not have an index, it is referred to as a heap.  When you create a clustered index, it does not require any additional disk space
•	Non-clustered Indexes
A Nonclustered index have a structure separate from the data rows, much like the index in back of a book; and as such does require disk space, as it’s a separate object. A nonclustered index contains a pointer to the data row that contains the key value. For a heap, a row locator is a pointer to the row. For a clustered table, the row locator is the clustered index key. 
•	Composite Indexes


	A composite index is an index on two or more columns of a table. A composite index can be created both on a clustered and non clustered index. Note, when creating a composite index the order of columns in the index is important for performance. Columns that will always mentioned in a query should be placed first. 


 Other less used indexes (depends)

•	Covering Indexes
•	Full-text
•	Filtered Indexes
•	Column-based Indexes
•	Spatial
•	XML


Creating indexes using TSQL and GUI


CREATE INDEX index_name
ON table_name (column_name)

CREATE UNIQUE INDEX index_name
ON table_name (column_name)

CREATE NONCLUSTERED INDEX [indexname] 
ON table_or_view_name ([columnname] ASC|DESC) 


DROP INDEX index_name ON table_name


--CREATE CLUSTERED INDEX index_name
--ON table_name (column_name)



EXAMPLE OF INDEXES AND CLUSTERED INDEX

--Insert 1000 records from  RedGate app
  
USE [SQL2]
GO

CREATE TABLE [dbo].[PhoneBook](
	[PhoneBookID] [int] NULL,
	[lname] [varchar](50) NULL,
	[fname] [varchar](50) NULL,
	[phone] [varchar](50) NULL
) ON [PRIMARY]

GO

--Insert 1000 records from RedGate app

--View the 1000 records. Notice that the last name is not in any particular order
 
SELECT * FROM PHONEBOOK

--Insert record into phonebook table and notice the row is inserted after 1000 rows, as there is no index and the Lname is in no particular order

Insert into PHONEBOOK
values (1001,'Abba','Sara','555-1212')

SELECT * FROM PHONEBOOK

--repeat with another record

Insert into PHONEBOOK
values (1002,'Turner','Mike','805-555-1212')

SELECT * FROM PHONEBOOK


--Create a clustered index on table phonebook and column Lname so that the last name is alphabetized (its sorted by the clustered index created)

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_Lname] --<< Index name with prefix, table name and column name (convention for clarity)
ON PhoneBook(Lname ASC)                      --<< Table and column name
GO


--View the 1000 records. This time notice that the last name IS in order by the last!
 
SELECT * FROM PHONEBOOK

--Now with the clusttered index in place, if we insert a record, it will automatically be inserted in the sorted order.

Insert into PHONEBOOK
values (1003,'Briggham','Johm','777-555-1212')

SELECT * FROM PHONEBOOK

USE [SQL2]
GO
Drop table PHONEBOOK


NON CLUSTERED INDEX SCRIPT



--View data with clustered index (lname column is still sorted)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

-- Create another clustered index causes an issue (on fname) because you can only have one clustered index

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_phonebookid]
ON PhoneBook(phonebookid ASC)


Drop index [PhoneBook].[Idx_PhoneBook_lname]

--Can create an single clustered index that has multiple columns

CREATE CLUSTERED INDEX [Idx_PhoneBook_Fname_Lname]
ON [dbo].[PhoneBook](lname ASC,fname ASC) --<< multiple columns


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Example of non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_ fname]  --<< notice that after creation of a non clustered index, the data is not sorted
ON PhoneBook(fname ASC)


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Can create multiple non clustered index (On lname)

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_phone] --<< second creation of an index and phone
ON PhoneBook(phone ASC)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]




----------------------------------------------------------------------------



--View data with clustered index (lname column is still sorted)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

-- Create another clustered index causes an issue (on fname) because you can only have one clustered index

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_phonebookid]
ON PhoneBook(phonebookid ASC)


Drop index [PhoneBook].[Idx_PhoneBook_lname]

--Can create an single clustered index that has multiple columns

CREATE CLUSTERED INDEX [Idx_PhoneBook_Fname_Lname]
ON [dbo].[PhoneBook](lname ASC,fname ASC) --<< multiple columns


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Example of non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_ fname]  --<< notice that after creation of a non clustered index, the data is not sorted
ON PhoneBook(fname ASC)


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Can create multiple non clustered index (On lname)

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_phone] --<< second creation of an index and phone
ON PhoneBook(phone ASC)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

----------------------------------------------------------------------------

--Find all created indexes

Use AdventureWorks2014
go

sp_helpindex '[HumanResources].[Department]'  --<< sproc followed by table name


--Create a composite index (two or more columns are specified) on a non clustered index

USE [SQL2]
Go


CREATE NONCLUSTERED INDEX [NC_Ind_People_Lname_Fname] 
ON [dbo].[People]
(Lname ASC,Fname ASC) --<< Note the order of the columns specified is important.  place the column in order of the query's where clause order


sp_helpindex people  --<< sproc followed by table name



***********************



--Find all created indexes (two ways: GUI or sproc)

Use AdventureWorks2014
go

sp_helpindex '[HumanResources].[Department]'  --<< sproc followed by table name


--Create a composite index (two or more columns are specified) on a non clustered index

USE [SQL2]
Go


CREATE NONCLUSTERED INDEX [NC_Ind_People_Lname_Fname] --<< the more columns you chose to index, the longer it will take to create the index!!
ON [dbo].[People]
(Lname ASC,Fname ASC) --<< Note the order of the columns specified is important.  place the column in order of the query's where clause order


--4 mins


USE [SQL2]
Go

sp_helpindex people  --<< sproc followed by table name


USE [SQL2]
Go

DROP INDEX [NC_Ind_People_Lname_Fname] ON [dbo].[People]
GO



--Example: Running a query with out an index looking for the last name 'Franklin600'
--as there is no index on the lname, the query will have to start from the first row and sequentially go through 
--all the 50 million rows until it finds the lname Franklin600!!!  (this is called a table scan and very poor for performance)


USE [SQL2]
GO

SELECT * 
  FROM [dbo].[People]
  where Lname = 'Franklin600'
GO
--that took 35 seconds!!! 12 rows (before  creating of an index on lname)


--Create an index on lname (to create an index on lname column, the data has to be sorted and has pointers to the actual data in a table)
--the creatinon of an index can take along time because it is 'copying' the the column lname seperately with pointers to data!!
--any time you update the table people with and insert, update or delete, the index on that column has to be updated ALSO. 

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_People_Lname] 
ON [dbo].[People]([Lname] ASC)
--2:45 mins


--Run select statment after the index creating


USE [SQL2]
GO

SELECT * 
  FROM [dbo].[People]
 --where Lname = 'Franklin600'
 where Lname = 'Everett652'
GO
--that less than a second!!! 12 rows (after the creating of an index on lname)





----------------------------------------------------------------------------

USE [SQL2]
GO

--create a table and use the SQL Data Generator to insert 1 million rows

--CREATE TABLE [dbo].[People2](
--	[Fname] [varchar](20) NULL,
--	[Lname] [varchar](20) NULL,
--	[Phone] [varchar](20) NULL
--) ON [PRIMARY]

--GO

--Use SQL Data Generator to poulate 10 million rows
--select count (*) from people2
--15,000,000 rows

--When to create/use and not to use an index.  Find the phone number for lname Lambert   --<< don't use

SELECT TOP 10 [Fname]
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]


--When to create/use and not to use an index.  Find the phone number for lname Conrad --<< don't use

  SELECT TOP 100 [Fname]
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]

 --When to create/use and not to use an index.  Find the phone number for lname Sanders  --<< don't use


SELECT TOP 1000 [Fname]
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]

   --When to create/use and not to use an index.  Find the phone number for lname Robertson  --<<  use

  SELECT  [Fname] 
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]
  Where lname = 'Robertson'


  -- So when should we create an index?  The first answer to this is when there is large amount of data (but other considrations)

  --If we create an indexm how does the clustered index help us retrieve last name data faster?  bu sorting the lname column
  --you alphabatize the lname and as such, if you encounter two SAME lname, they will be next to each other.


  --Create a clustered index on lname to sort the data.  This wil improve retrival of lname data

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Ind_People2_Lname] 
ON [People2]([Lname] ASC)



  SELECT   [Fname] 
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]
  Where lname = 'Robertson'

  
----------------------------------------------------------------------------


What Is an Index?
•	An index can be best described as a pointer to data in a table. An index in a database is very similar to an index in the back of a book or the phone book.  Indexes are created on the table or the view
Purpose of index
•	The purpose of an index is to retrieve data from a table efficiently and fast
Types of indexes
•	Clustered Indexes
Clustered indexes sort the data rows in the table or view based on their key values, as such there can be only one clustered index per table. When a table does not have an index, it is referred to as a heap.  When you create a clustered index, it does not require any additional disk space
•	Non-clustered Indexes
A Nonclustered index have a structure separate from the data rows, much like the index in back of a book; and as such does require disk space, as it’s a separate object. A nonclustered index contains a pointer to the data row that contains the key value. For a heap, a row locator is a pointer to the row. For a clustered table, the row locator is the clustered index key. 
•	Composite Indexes


	A composite index is an index on two or more columns of a table. You should consider performance when creating a composite index because the order of columns in the index has a measurable effect on data retrieval speed. Generally, the most restrictive value should be placed first for optimum performance. However, the columns that will always be specified should be placed first. 


 Other less used indexes (depends)

•	Covering Indexes
•	Full-text
•	Filtered Indexes
•	Column-based Indexes
•	Spatial
•	XML


Creating indexes using TSQL and GUI


CREATE INDEX index_name
ON table_name (column_name)

CREATE UNIQUE INDEX index_name
ON table_name (column_name)

CREATE NONCLUSTERED INDEX [indexname] 
ON table_or_view_name ([columnname] ASC|DESC) 


DROP INDEX index_name ON table_name


--CREATE CLUSTERED INDEX index_name
--ON table_name (column_name)



EXAMPLE OF INDEXES AND CLUSTERED INDEX

--Insert 1000 records from  RedGate app
  
USE [SQL2]
GO

CREATE TABLE [dbo].[PhoneBook](
	[PhoneBookID] [int] NULL,
	[lname] [varchar](50) NULL,
	[fname] [varchar](50) NULL,
	[phone] [varchar](50) NULL
) ON [PRIMARY]

GO

--Insert 1000 records from RedGate app

--View the 1000 records. Notice that the last name is not in any particular order
 
SELECT * FROM PHONEBOOK

--Insert record into phonebook table and notice the row is inserted after 1000 rows, as there is no index and the Lname is in no particular order

Insert into PHONEBOOK
values (1001,'Abba','Sara','555-1212')

SELECT * FROM PHONEBOOK

--repeat with another record

Insert into PHONEBOOK
values (1002,'Turner','Mike','805-555-1212')

SELECT * FROM PHONEBOOK


--Create a clustered index on table phonebook and column Lname so that the last name is alphabetized (its sorted by the clustered index created)

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_Lname] --<< Index name with prefix, table name and column name (convention for clarity)
ON PhoneBook(Lname ASC)                      --<< Table and column name
GO


--View the 1000 records. This time notice that the last name IS in order by the last!
 
SELECT * FROM PHONEBOOK

--Now with the clusttered index in place, if we insert a record, it will automatically be inserted in the sorted order.

Insert into PHONEBOOK
values (1003,'Briggham','Johm','777-555-1212')

SELECT * FROM PHONEBOOK

USE [SQL2]
GO
Drop table PHONEBOOK


NON CLUSTERED INDEX SCRIPT



--View data with clustered index (lname column is still sorted)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

-- Create another clustered index causes an issue (on fname) because you can only have one clustered index

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_phonebookid]
ON PhoneBook(phonebookid ASC)


Drop index [PhoneBook].[Idx_PhoneBook_lname]

--Can create an single clustered index that has multiple columns

CREATE CLUSTERED INDEX [Idx_PhoneBook_Fname_Lname]
ON [dbo].[PhoneBook](lname ASC,fname ASC) --<< multiple columns


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Example of non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_ fname]  --<< notice that after creation of a non clustered index, the data is not sorted
ON PhoneBook(fname ASC)


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Can create multiple non clustered index (On lname)

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_phone] --<< second creation of an index and phone
ON PhoneBook(phone ASC)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]













When should indexes be considered and 
What factors influence creation of indexes?

When the table is large in size (row count)
•	Contains millions if not 100’s of millions rows
When the table is used frequently
•	The table is used more than just infrequently
When the columns are frequently used in the WHERE clause 
•	The query against the database has where clause
Columns that are frequently referenced in the ORDER BY and GROUP BY clauses
•	If you’re sorting data, then its beneficial
Indexes should be created on columns with a high number of unique values
•	Create indexes on columns that are all virtually unique such as integer
Create a single column index on single where clause query
•	If the where clause has a single column then create a single index
Create a multiple column index on multiple where clause query
•	If the where clause has multiple columns then create multiple index
Build index on columns of integer type
•	Integers take less space to store, which means the query will be faster

The order of the composite index matters, so place the column in the index as with the where clause
•	Use the column with the lowest cardinality first, and the column with the highest cardinality last, which means keep the unique column first and less unique column last (select distinct col1 from table)
Testing is the key in determining what will work for your environment. Play with different combinations of indexes, no indexes, single-column indexes, and composite indexes. 
When Should Indexes Be Avoided?

Indexes should not be used on small tables
•	Smaller tables do better with a table scan
Indexes should not be used on columns that contain a high number of NULL values.
•	Maintenance on the index can become excessive
Don’t use an index that will return a high percentage of data 
•	few distinct values such as gender
Creating indexes come with a cost
•	Indexes take up disk space 
•	INSERT, UPDATE, and DELETE operations become slower, since the database system need to update the values in the table, and it also needs to update the indexes


************************


/*

Note: table people in db SQL2 has beeen updated to contain 100,000,000 million rows using SQL Data Generator

Select count (*) from people  --100000000 rows

Use the where clause for lname (single column index would be beneficial
if the table is used frequently, otherwise do not create an index

*/

--Using the WHERE clause without an index (1 min 10 sesc)
--click on icon to display estimated execution plan (shows that a table scan will be executed and missing non clustered index is suggested on lname and others columns)
--the display estimated execution plan dose not execute the query, but shows the plan if executed!!

USE [SQL2]
GO

SELECT [PeopleID]  --<< note while i am using all the columns, in a production server, use only columns that are needed
      ,[Fname]
      ,[Lname]
      ,[Address1]
      ,[City]
      ,[State]
      ,[Zip]
      ,[Country]
      ,[Phone]
  FROM [dbo].[People]
  WHERE Lname = 'Spence'

GO

--Using the WHERE clause without a non clustered index on lname  (1 min 10 sesc)

--Before runnng the script, create the 'suggeted' non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[People] ([Lname])
--INCLUDE ([PeopleID],[Fname],[Address1],[City],[State],[Zip],[Country],[Phone])--<< INCLUDE MEANS INCLUDE NON KEY COLUMNS. THIS COVERS MORE QUERIES
GO

--5 MIN 30 SEC


--RERUN THE SCRIPT FOR FINDING ALL DATA FOR LNAME SPENCE.  REMEMBER, IN A PRODUCTION SERVER, DONT USE ALL THE FIELDS, ONLY THE ONES THAT ARE NEEDED.

USE [SQL2]
GO

SELECT  [PeopleID]
      ,[Fname]
      ,[Lname]
      ,[Address1]
      ,[City]
      ,[State]
      ,[Zip]
      ,[Country]
      ,[Phone]
  FROM [dbo].[People]
  --WHERE Lname = 'Spence'
  WHERE Lname =  'Zuniga'
GO


--1st run = 2 min 15 sec
--2nd run = 10 sec  (becasue it is cached)


--without all columns

USE [SQL2]
GO

SELECT  [PeopleID]
      ,[Fname]
      ,[Lname]
  FROM [dbo].[People]
  --HERE Lname = 'Spence'
  WHERE Lname =  'Zuniga'
GO

--2 sec



----------------------------------------------------------------------------


What Is an Index?
•	An index can be best described as a pointer to data in a table. An index in a database is very similar to an index in the back of a book or the phone book.  Indexes are created on the table or the view
Purpose of index
•	The purpose of an index is to retrieve data from a table efficiently and fast
Types of indexes
•	Clustered Indexes
Clustered indexes sort the data rows in the table or view based on their key values, as such there can be only one clustered index per table. When a table does not have an index, it is referred to as a heap.  When you create a clustered index, it does not require any additional disk space
•	Non-clustered Indexes
A Nonclustered index have a structure separate from the data rows, much like the index in back of a book; and as such does require disk space, as it’s a separate object. A nonclustered index contains a pointer to the data row that contains the key value. For a heap, a row locator is a pointer to the row. For a clustered table, the row locator is the clustered index key. 
•	Composite Indexes


	A composite index is an index on two or more columns of a table. A composite index can be created both on a clustered and non clustered index. Note, when creating a composite index the order of columns in the index is important for performance. Columns that will always mentioned in a query should be placed first. 


 Other less used indexes (depends)

•	Covering Indexes
•	Full-text
•	Filtered Indexes
•	Column-based Indexes
•	Spatial
•	XML


Creating indexes using TSQL and GUI


CREATE INDEX index_name
ON table_name (column_name)

CREATE UNIQUE INDEX index_name
ON table_name (column_name)

CREATE NONCLUSTERED INDEX [indexname] 
ON table_or_view_name ([columnname] ASC|DESC) 


DROP INDEX index_name ON table_name


--CREATE CLUSTERED INDEX index_name
--ON table_name (column_name)



EXAMPLE OF INDEXES AND CLUSTERED INDEX

--Insert 1000 records from  RedGate app
  
USE [SQL2]
GO

CREATE TABLE [dbo].[PhoneBook](
	[PhoneBookID] [int] NULL,
	[lname] [varchar](50) NULL,
	[fname] [varchar](50) NULL,
	[phone] [varchar](50) NULL
) ON [PRIMARY]

GO

--Insert 1000 records from RedGate app

--View the 1000 records. Notice that the last name is not in any particular order
 
SELECT * FROM PHONEBOOK

--Insert record into phonebook table and notice the row is inserted after 1000 rows, as there is no index and the Lname is in no particular order

Insert into PHONEBOOK
values (1001,'Abba','Sara','555-1212')

SELECT * FROM PHONEBOOK

--repeat with another record

Insert into PHONEBOOK
values (1002,'Turner','Mike','805-555-1212')

SELECT * FROM PHONEBOOK


--Create a clustered index on table phonebook and column Lname so that the last name is alphabetized (its sorted by the clustered index created)

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_Lname] --<< Index name with prefix, table name and column name (convention for clarity)
ON PhoneBook(Lname ASC)                      --<< Table and column name
GO


--View the 1000 records. This time notice that the last name IS in order by the last!
 
SELECT * FROM PHONEBOOK

--Now with the clusttered index in place, if we insert a record, it will automatically be inserted in the sorted order.

Insert into PHONEBOOK
values (1003,'Briggham','Johm','777-555-1212')

SELECT * FROM PHONEBOOK

USE [SQL2]
GO
Drop table PHONEBOOK


NON CLUSTERED INDEX SCRIPT



--View data with clustered index (lname column is still sorted)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

-- Create another clustered index causes an issue (on fname) because you can only have one clustered index

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_phonebookid]
ON PhoneBook(phonebookid ASC)


Drop index [PhoneBook].[Idx_PhoneBook_lname]

--Can create an single clustered index that has multiple columns

CREATE CLUSTERED INDEX [Idx_PhoneBook_Fname_Lname]
ON [dbo].[PhoneBook](lname ASC,fname ASC) --<< multiple columns


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Example of non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_ fname]  --<< notice that after creation of a non clustered index, the data is not sorted
ON PhoneBook(fname ASC)


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Can create multiple non clustered index (On lname)

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_phone] --<< second creation of an index and phone
ON PhoneBook(phone ASC)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]



**********************************************

--Example of creating a clustered index using TSQL 

--CREATE CLUSTERED INDEX index_name
--ON table_name (column_name)


--Insert 1000 records from  RedGate app
  
USE [SQL2]
GO

CREATE TABLE [dbo].[PhoneBook](
	[PhoneBookID] [int] NULL,
	[lname] [varchar](50) NULL,
	[fname] [varchar](50) NULL,
	[phone] [varchar](50) NULL
) ON [PRIMARY]

GO

--Insert 1000 records from RedGate app

--View the 1000 records. Notice that the last name is not in any particular order
 
SELECT * FROM PHONEBOOK

--Insert record into phonebook table and notice the row is inserted after 1000 rows, as there is no index and the Lname is in no particular order

Insert into PHONEBOOK
values (1001,'Abba','Sara','555-1212')

SELECT * FROM PHONEBOOK

--repeat with another record

Insert into PHONEBOOK
values (1002,'Turner','Mike','805-555-1212')

SELECT * FROM PHONEBOOK


--Create a clustered index on table phonebook and column Lname so that the last name is alphabetized (its sorted by the clustered index created)

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_Lname] --<< Index name with prefix, table name and column name (convention for clarity)
ON PhoneBook(Lname ASC)                      --<< Table and column name
GO


--View the 1000 records. This time notice that the last name IS in order by the last!
 
SELECT * FROM PHONEBOOK

--Now with the clusttered index in place, if we insert a record, it will automatically be inserted in the sorted order.

Insert into PHONEBOOK
values (1003,'Briggham','Johm','777-555-1212')

SELECT * FROM PHONEBOOK

--Exmaple of creating a clusetered index using the GUI

USE [SQL2]
GO
Drop table PHONEBOOK



----------------------------------------------------------------------------



--View data with clustered index (lname column is still sorted)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

-- Create another clustered index causes an issue (on fname) because you can only have one clustered index

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_phonebookid]
ON PhoneBook(phonebookid ASC)


Drop index [PhoneBook].[Idx_PhoneBook_lname]

--Can create an single clustered index that has multiple columns

CREATE CLUSTERED INDEX [Idx_PhoneBook_Fname_Lname]
ON [dbo].[PhoneBook](lname ASC,fname ASC) --<< multiple columns


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Example of non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_ fname]  --<< notice that after creation of a non clustered index, the data is not sorted
ON PhoneBook(fname ASC)


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Can create multiple non clustered index (On lname)

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_phone] --<< second creation of an index and phone
ON PhoneBook(phone ASC)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

----------------------------------------------------------------------------

--Find all created indexes

Use AdventureWorks2014
go

sp_helpindex '[HumanResources].[Department]'  --<< sproc followed by table name


--Create a composite index (two or more columns are specified) on a non clustered index

USE [SQL2]
Go


CREATE NONCLUSTERED INDEX [NC_Ind_People_Lname_Fname] 
ON [dbo].[People]
(Lname ASC,Fname ASC) --<< Note the order of the columns specified is important.  place the column in order of the query's where clause order


sp_helpindex people  --<< sproc followed by table name



--Find all created indexes (two ways: GUI or sproc)

Use AdventureWorks2014
go

sp_helpindex '[HumanResources].[Department]'  --<< sproc followed by table name


--Create a composite index (two or more columns are specified) on a non clustered index

USE [SQL2]
Go


CREATE NONCLUSTERED INDEX [NC_Ind_People_Lname_Fname] --<< the more columns you chose to index, the longer it will take to create the index!!
ON [dbo].[People]
(Lname ASC,Fname ASC) --<< Note the order of the columns specified is important.  place the column in order of the query's where clause order


--4 mins


USE [SQL2]
Go

sp_helpindex people  --<< sproc followed by table name


USE [SQL2]
Go

DROP INDEX [NC_Ind_People_Lname_Fname] ON [dbo].[People]
GO



--Example: Running a query with out an index looking for the last name 'Franklin600'
--as there is no index on the lname, the query will have to start from the first row and sequentially go through 
--all the 50 million rows until it finds the lname Franklin600!!!  (this is called a table scan and very poor for performance)


USE [SQL2]
GO

SELECT * 
  FROM [dbo].[People]
  where Lname = 'Franklin600'
GO
--that took 35 seconds!!! 12 rows (before  creating of an index on lname)


--Create an index on lname (to create an index on lname column, the data has to be sorted and has pointers to the actual data in a table)
--the creatinon of an index can take along time because it is 'copying' the the column lname seperately with pointers to data!!
--any time you update the table people with and insert, update or delete, the index on that column has to be updated ALSO. 

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_People_Lname] 
ON [dbo].[People]([Lname] ASC)
--2:45 mins


--Run select statment after the index creating


USE [SQL2]
GO

SELECT * 
  FROM [dbo].[People]
 --where Lname = 'Franklin600'
 where Lname = 'Everett652'
GO
--that less than a second!!! 12 rows (after the creating of an index on lname)



----------------------------------------------------------------------------

USE [SQL2]
GO

--create a table and use the SQL Data Generator to insert 1 million rows

--CREATE TABLE [dbo].[People2](
--	[Fname] [varchar](20) NULL,
--	[Lname] [varchar](20) NULL,
--	[Phone] [varchar](20) NULL
--) ON [PRIMARY]

--GO

--Use SQL Data Generator to poulate 10 million rows
--select count (*) from people2
--15,000,000 rows

--When to create/use and not to use an index.  Find the phone number for lname Lambert   --<< don't use

SELECT TOP 10 [Fname]
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]


--When to create/use and not to use an index.  Find the phone number for lname Conrad --<< don't use

  SELECT TOP 100 [Fname]
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]

 --When to create/use and not to use an index.  Find the phone number for lname Sanders  --<< don't use


SELECT TOP 1000 [Fname]
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]

   --When to create/use and not to use an index.  Find the phone number for lname Robertson  --<<  use

  SELECT  [Fname] 
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]
  Where lname = 'Robertson'


  -- So when should we create an index?  The first answer to this is when there is large amount of data (but other considrations)

  --If we create an indexm how does the clustered index help us retrieve last name data faster?  bu sorting the lname column
  --you alphabatize the lname and as such, if you encounter two SAME lname, they will be next to each other.


  --Create a clustered index on lname to sort the data.  This wil improve retrival of lname data

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Ind_People2_Lname] 
ON [People2]([Lname] ASC)



  SELECT   [Fname] 
      ,[Lname]
      ,[Phone]
  FROM [SQL2].[dbo].[People2]
  Where lname = 'Robertson'


  
----------------------------------------------------------------------------


What Is an Index?
•	An index can be best described as a pointer to data in a table. An index in a database is very similar to an index in the back of a book or the phone book.  Indexes are created on the table or the view
Purpose of index
•	The purpose of an index is to retrieve data from a table efficiently and fast
Types of indexes
•	Clustered Indexes
Clustered indexes sort the data rows in the table or view based on their key values, as such there can be only one clustered index per table. When a table does not have an index, it is referred to as a heap.  When you create a clustered index, it does not require any additional disk space
•	Non-clustered Indexes
A Nonclustered index have a structure separate from the data rows, much like the index in back of a book; and as such does require disk space, as it’s a separate object. A nonclustered index contains a pointer to the data row that contains the key value. For a heap, a row locator is a pointer to the row. For a clustered table, the row locator is the clustered index key. 
•	Composite Indexes


	A composite index is an index on two or more columns of a table. You should consider performance when creating a composite index because the order of columns in the index has a measurable effect on data retrieval speed. Generally, the most restrictive value should be placed first for optimum performance. However, the columns that will always be specified should be placed first. 


 Other less used indexes (depends)

•	Covering Indexes
•	Full-text
•	Filtered Indexes
•	Column-based Indexes
•	Spatial
•	XML


Creating indexes using TSQL and GUI


CREATE INDEX index_name
ON table_name (column_name)

CREATE UNIQUE INDEX index_name
ON table_name (column_name)

CREATE NONCLUSTERED INDEX [indexname] 
ON table_or_view_name ([columnname] ASC|DESC) 


DROP INDEX index_name ON table_name


--CREATE CLUSTERED INDEX index_name
--ON table_name (column_name)



EXAMPLE OF INDEXES AND CLUSTERED INDEX

--Insert 1000 records from  RedGate app
  
USE [SQL2]
GO

CREATE TABLE [dbo].[PhoneBook](
	[PhoneBookID] [int] NULL,
	[lname] [varchar](50) NULL,
	[fname] [varchar](50) NULL,
	[phone] [varchar](50) NULL
) ON [PRIMARY]

GO

--Insert 1000 records from RedGate app

--View the 1000 records. Notice that the last name is not in any particular order
 
SELECT * FROM PHONEBOOK

--Insert record into phonebook table and notice the row is inserted after 1000 rows, as there is no index and the Lname is in no particular order

Insert into PHONEBOOK
values (1001,'Abba','Sara','555-1212')

SELECT * FROM PHONEBOOK

--repeat with another record

Insert into PHONEBOOK
values (1002,'Turner','Mike','805-555-1212')

SELECT * FROM PHONEBOOK


--Create a clustered index on table phonebook and column Lname so that the last name is alphabetized (its sorted by the clustered index created)

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_Lname] --<< Index name with prefix, table name and column name (convention for clarity)
ON PhoneBook(Lname ASC)                      --<< Table and column name
GO


--View the 1000 records. This time notice that the last name IS in order by the last!
 
SELECT * FROM PHONEBOOK

--Now with the clusttered index in place, if we insert a record, it will automatically be inserted in the sorted order.

Insert into PHONEBOOK
values (1003,'Briggham','Johm','777-555-1212')

SELECT * FROM PHONEBOOK

USE [SQL2]
GO
Drop table PHONEBOOK


NON CLUSTERED INDEX SCRIPT



--View data with clustered index (lname column is still sorted)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]

-- Create another clustered index causes an issue (on fname) because you can only have one clustered index

USE [SQL2]
GO

CREATE CLUSTERED INDEX [Idx_PhoneBook_phonebookid]
ON PhoneBook(phonebookid ASC)


Drop index [PhoneBook].[Idx_PhoneBook_lname]

--Can create an single clustered index that has multiple columns

CREATE CLUSTERED INDEX [Idx_PhoneBook_Fname_Lname]
ON [dbo].[PhoneBook](lname ASC,fname ASC) --<< multiple columns


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Example of non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_ fname]  --<< notice that after creation of a non clustered index, the data is not sorted
ON PhoneBook(fname ASC)


SELECT*
FROM [SQL2].[dbo].[PhoneBook]


--Can create multiple non clustered index (On lname)

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NC_Ind_PhoneBook_phone] --<< second creation of an index and phone
ON PhoneBook(phone ASC)

SELECT*
FROM [SQL2].[dbo].[PhoneBook]













When should indexes be considered and 
What factors influence creation of indexes?

When the table is large in size (row count)
•	Contains millions if not 100’s of millions rows
When the table is used frequently
•	The table is used more than just infrequently
When the columns are frequently used in the WHERE clause 
•	The query against the database has where clause
Columns that are frequently referenced in the ORDER BY and GROUP BY clauses
•	If you’re sorting data, then its beneficial
Indexes should be created on columns with a high number of unique values
•	Create indexes on columns that are all virtually unique such as integer
Create a single column index on single where clause query
•	If the where clause has a single column then create a single index
Create a multiple column index on multiple where clause query
•	If the where clause has multiple columns then create multiple index
Build index on columns of integer type
•	Integers take less space to store, which means the query will be faster

The order of the composite index matters, so place the column in the index as with the where clause
•	Use the column with the lowest cardinality first, and the column with the highest cardinality last, which means keep the unique column first and less unique column last (select distinct col1 from table)
Testing is the key in determining what will work for your environment. Play with different combinations of indexes, no indexes, single-column indexes, and composite indexes. 
When Should Indexes Be Avoided?

Indexes should not be used on small tables
•	Smaller tables do better with a table scan
Indexes should not be used on columns that contain a high number of NULL values.
•	Maintenance on the index can become excessive
Don’t use an index that will return a high percentage of data 
•	few distinct values such as gender
Creating indexes come with a cost
•	Indexes take up disk space 
•	INSERT, UPDATE, and DELETE operations become slower, since the database system need to update the values in the table, and it also needs to update the indexes



/*

Note: table people in db SQL2 has beeen updated to contain 100,000,000 million rows using SQL Data Generator

Select count (*) from people  --100000000 rows

Use the where clause for lname (single column index would be beneficial
if the table is used frequently, otherwise do not create an index

*/

--Using the WHERE clause without an index (1 min 10 sesc)
--click on icon to display estimated execution plan (shows that a table scan will be executed and missing non clustered index is suggested on lname and others columns)
--the display estimated execution plan dose not execute the query, but shows the plan if executed!!

USE [SQL2]
GO

SELECT [PeopleID]  --<< note while i am using all the columns, in a production server, use only columns that are needed
      ,[Fname]
      ,[Lname]
      ,[Address1]
      ,[City]
      ,[State]
      ,[Zip]
      ,[Country]
      ,[Phone]
  FROM [dbo].[People]
  WHERE Lname = 'Spence'

GO

--Using the WHERE clause without a non clustered index on lname  (1 min 10 sesc)

--Before runnng the script, create the 'suggeted' non clustered index

USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[People] ([Lname])
--INCLUDE ([PeopleID],[Fname],[Address1],[City],[State],[Zip],[Country],[Phone])--<< INCLUDE MEANS INCLUDE NON KEY COLUMNS. THIS COVERS MORE QUERIES
GO

--5 MIN 30 SEC


--RERUN THE SCRIPT FOR FINDING ALL DATA FOR LNAME SPENCE.  REMEMBER, IN A PRODUCTION SERVER, DONT USE ALL THE FIELDS, ONLY THE ONES THAT ARE NEEDED.

USE [SQL2]
GO

SELECT  [PeopleID]
      ,[Fname]
      ,[Lname]
      ,[Address1]
      ,[City]
      ,[State]
      ,[Zip]
      ,[Country]
      ,[Phone]
  FROM [dbo].[People]
  --WHERE Lname = 'Spence'
  WHERE Lname =  'Zuniga'
GO


--1st run = 2 min 15 sec
--2nd run = 10 sec  (becasue it is cached)


--without all columns

USE [SQL2]
GO

SELECT  [PeopleID]
      ,[Fname]
      ,[Lname]
  FROM [dbo].[People]
  --HERE Lname = 'Spence'
  WHERE Lname =  'Zuniga'
GO

--2 sec


----------------------------------------------------------------------------


/*

The system function sys.dm_db_index_physical_stats provides you inforamation about fragmetation

*/

--BACKUP TABLE PEOPLE3

--SELECT * INTO PEOPLE3BACKUP FROM People3

--SCRIPT TO INDICATE PERCENT OF FRAGMENTATION BEFORE INDEX CREATIONS

SELECT a.index_id, name, avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats (DB_ID(N'SQL2'), 
OBJECT_ID(N'SQL2'), NULL, NULL, NULL) AS a
JOIN sys.indexes AS b ON a.object_id = b.object_id AND a.index_id = b.index_id; 
GO



--CREATE IN INDEX


USE [SQL2]
GO

CREATE NONCLUSTERED INDEX [NonClusteredIndex-lname] 
ON [dbo].[PEOPLE3]
([Lname] ASC)


SELECT a.index_id, name, avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats (DB_ID(N'SQL2'), 
OBJECT_ID(N'PEOPLE3'), NULL, NULL, NULL) AS a
JOIN sys.indexes AS b ON a.object_id = b.object_id AND a.index_id = b.index_id; 
GO


--index_id	name	                  avg_fragmentation_in_percent
--3	        NonClusteredIndex-lname	  0.0101153145862836


--FIND LNAME WITH HANSON WITHOUT INDEX

USE [SQL2]
GO

SELECT [PeopleID]
      ,[Fname]
      ,[Lname]
      ,[Address1]
      ,[City]
      ,[State]
      ,[Zip]
      ,[Country]
      ,[Phone]
  FROM [dbo].[People3]
  WHERE Lname = 'HANSON'
GO


--FIND LNAME AND FNAME WITHOUT COMPOSITE INDEX

USE [SQL2]
GO

SELECT [PeopleID]
      ,[Fname]
      ,[Lname]
      ,[Address1]
      ,[City]
      ,[State]
      ,[Zip]
      ,[Country]
      ,[Phone]
  FROM [dbo].[People3]
  WHERE Lname = 'HANSON' OR Fname = 'EVA'
GO


--INSERT INTO PEOPLE A ROW

INSERT INTO [dbo].[People3]
VALUES (10000001,'Peggy','Villarreal', '777 Fabien Freeway','Lubbock','Alaska','59320','Morocco','959-485-3114')
GO 50000
--20 SEC


SELECT * FROM PEOPLE3 WHERE PeopleID LIKE  '%10000001'

--UPDATE LNAME WHERE LNAME IS BAXTER TO SUPERMAN


UPDATE People3
SET Lname = 'SUPERMAN'
WHERE Lname = 'BAXTER'

UPDATE People3
SET Lname = 'BATMAN'
WHERE Lname = 'Dickson'

UPDATE People3
SET Lname = 'HULK'
WHERE Lname = 'King'

UPDATE People3
SET Lname = 'JOKER'
WHERE  PeopleID BETWEEN '29740284' AND '31630639'
--5002044


DELETE FROM PEOPLE3 WHERE PeopleID BETWEEN '34546957' AND '39549000'
--5002044







----------------------------------------------------------------------------

Index Fragmentation (Rebuild or Reorganize an Index)

•	When index fragmentation occurs should you reorganize or rebuild a fragmented index (it depends)
•	Whenever an insert, update, or delete operations occur against the underlying data, SQL automatically maintains indexes
•	These operation cause index fragmentation and can cause performance issues
•	Fragmentation exists when indexes have pages in which the logical ordering, based on the key value, does not match the physical ordering inside the data file
•	When you Rebuild an index SQL drops and re-creates the index and removes fragmentation, reclaims disk space by compacting and reorders the index rows in contiguous pages
•	When you Reorganize an index it defragments the leaf level of clustered and nonclustered indexes on tables and views by physically reordering the leaf-level 
•	The system function sys.dm_db_index_physical_stats, allows you to detect fragmentation 
•	If avg_fragmentation_in_percent value
•	> 5% and < = 30%    REORGANIZE
•	> 30%                        REBUILD 
•	Rebuilding an index can be executed online or offline. 
•	Reorganizing an index is always executed online. 


***********************************************


USE [master];
GO
 
CREATE DATABASE ShrinkDB;
GO

USE [ShrinkDB];
GO
 

-- Create an initial table at the 'front' of the data file
CREATE TABLE Initial (
    [col1] INT IDENTITY,
    [col2] CHAR (8000) DEFAULT 'Front');
GO


-- Insert data into Initial table
INSERT INTO Initial DEFAULT VALUES;
GO 1500

select * from Initial

--check the size of the database
sp_helpdb [ShrinkDB]
--14.83 MB
 
-- Create the second table, which will be created 'after' the initial table in the data file
CREATE TABLE second (
    [col1] INT IDENTITY,
    [col2] CHAR (8000) DEFAULT 'after');

--create a clusterd index on the second table
CREATE CLUSTERED INDEX [coll] ON second ([col1]);
GO
 

-- Insert data into second table
INSERT INTO second DEFAULT VALUES;
GO 1500


select * from second

--check db size 
sp_helpdb [ShrinkDB]

--database expanded due to insert of data in the second table (26.83 MB)
 
-- Check the fragmentation of the second table
SELECT
    [avg_fragmentation_in_percent]
FROM sys.dm_db_index_physical_stats (
    DB_ID (N'ShrinkDB'), OBJECT_ID (N'second'), 1, NULL, 'LIMITED');
GO

--notice that the fragmentation of the clustered index for the second table is almost zero before the shrink
--0.333333333333333

--We will now drop the initial table we created and execute the shrink command to reclaim the SPACE at the front of the data file
-- then see what happens to the fragmentaion.

DROP TABLE Initial;
GO


sp_helpdb [ShrinkDB]
-- 26.83 MB the data file has not shrunk due to the deletion of the initial table
 
-- Shrink the database
DBCC SHRINKDATABASE ([ShrinkDB]);
GO

--notice that the SPACE after the shrink went down from 26.83 to 15.02 mb
sp_helpdb [ShrinkDB]
--15.02 MB
 
-- But notice what happened to the fragmentation of the data file because of the shrinking of the database???
--when Checking the index fragmentation again, we notice that the fragmentation has drastically increased to almost 100%!!!
--this is because we have shuffled all the data pages and the index is not in a sorted position

SELECT
    [avg_fragmentation_in_percent]
FROM sys.dm_db_index_physical_stats (
    DB_ID (N'ShrinkDB'), OBJECT_ID (N'second'), 1, NULL, 'LIMITED');
GO

--99.6

--while the database has shrunk, and we have reclaimed space from the data file, we MUST now the fix the fragmented index of the table by rebuilding the index!!!

-- Rebuild or Reorganize the Clustered Index?

--If avg_fragmentation_in_percent value
--> 5% and < = 30%    REORGANIZE
--> 30%               REBUILD 


ALTER INDEX [coll] ON second REBUILD
GO

ALTER INDEX [coll] ON second REORGANIZE
GO

-- Checking the index fragmentation again indicates that the fragmentaion of the index has been restored, but notice the size of the data
--file when we run the sp_helpdb [ShrinkDB] - it has actually GROWN even more than it started from!!!

SELECT
    [avg_fragmentation_in_percent]
FROM sys.dm_db_index_physical_stats (
    DB_ID (N'ShrinkDB'), OBJECT_ID (N'second'), 1, NULL, 'LIMITED');
GO

--0.2%

sp_helpdb [ShrinkDB]
--41.81 MB

--the database file has grown because of the rebuilding of the index and the logging of the index



----------------------------------------------------------------------------


What is the SQL Profiler?
     SQL Profiler is a graphical tool that allows the DBAs to monitor events in an instance of Microsoft SQL Server. Once those events and data are captured, you can save the results to a file or a table for later analysis

The next few videos I will demonstrate the following capabilities of the Profiler:
•	How to monitor the performance of an instance of SQL Server via trace
•	Review and debug T-SQL statements and stored procedures
•	Identify what is causing slow-executing queries
•	Audit activity against the SQL Server by tracing logins and users (security)
•	Use the tuning template to analyze Indexes
•	Add a user profiler template
•	Best practice in using the SQL Profiler
Does and don’ts of SQL Profiler
•	Since the Profiler adds a lot of overhead to production server, filter trace
•	Save the trace to a file rather than a table first
•	Use only when needed for short period of time, as it consumes CPU
•	Configured the trace only relevant events and columns
Terminology
Event – An event is an action within an instance of SQL Server Database Engine
Trace – A trace captures data based on the columns and events
Template – A template defines the default configuration or one that you set for the trace



----------------------------------------------------------------------------

USE [SQL2]
GO

SELECT TOP 100000 *
FROM [dbo].[People]
GO


-- 1 SEC

SELECT TOP 200000 *
FROM [dbo].[People]
GO


--2 SEC

SELECT TOP 300000 *
FROM [dbo].[People]
GO

--4 SEC

SELECT TOP 700000 *
FROM [dbo].[People]
GO

--9 SEC

SELECT TOP 800000 *
FROM [dbo].[People]
GO

--10

SELECT TOP 900000 *
FROM [dbo].[People]
GO

--12

SELECT TOP 1000000 *
FROM [dbo].[People]
GO
--14 SECS

USE [SQL2]
GO

SELECT TOP 2000000 *
FROM [dbo].[People]
GO
--26 SECS

SELECT TOP 3000000 *
FROM [dbo].[People]
GO

--40 SEC


  --the duration column i shown in millionth of a second, even though the filter was in 1000!!!

  select Duration/1000000 as DurationsInSeconds,* --<< divide by 1 million to get seconds
  from Duration
  where Textdata like '%select%'



  
----------------------------------------------------------------------------


---- Audit login Tom to see what he is doing??

----Before creating a SQL Login, make user the that authentication is set to mixed mode.  will need to restart services

----Create a SQL Login for Tom

--USE [master]
--GO

--CREATE LOGIN [Tom] WITH PASSWORD=N'password123', 
--DEFAULT_DATABASE=[master], 
--CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
--GO

--USE [SQL2]
--GO

--CREATE USER [Tom] FOR LOGIN [Tom]
--GO

--USE [SQL2]
--GO

--ALTER ROLE [db_owner] ADD MEMBER [Tom] --<< Tom is a the databasse owner as such has
--GO


SELECT TOP 1000 [RowNumber]
,[EventClass]
,[Duration]
,[TextData]
,[SPID]
,[BinaryData]
FROM [SQL2].[dbo].[duration]-- 10 rows

--Create a backup of duration table

select * into duration013016 from duration

 

--Audit deleted rows from login Tom using the profiler (find the sql statements against the database)

delete from duration where RowNumber = 6



/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [RowNumber]
      ,[EventClass]
      ,[TextData]
      ,[ApplicationName]
      ,[NTUserName]
      ,[LoginName]
      ,[SPID]
      ,[BinaryData]
  FROM [SQL2].[dbo].[audit]
  where loginname = 'tom' and textdata like '%delete%'


----------------------------------------------------------------------------


use SQL2
go

--select statements against SQL2 database gor SQL Tuning template

--Create a user profiler template

SELECT TOP 1000 [PeopleID]
,[Fname]
,[Lname]
,[Address1]
,[City]
,[State]
,[Zip]
,[Country]
,[Phone]
FROM [SQL2].[dbo].[People]
WHERE LNAME = 'Garcia'     --<< note that SQL will recommend INCLUDED columns to index when included in the select clause


SELECT TOP 10000 
[Lname]
FROM [SQL2].[dbo].[People]
WHERE LNAME = 'Houston'    --<< note that SQL will NOT recommend INCLUDED columns to index when not included in the select statement

SELECT TOP 10000 *
FROM [SQL2].[dbo].[People]
WHERE Fname = 'gloria'     --<<the query optimizer detects that the where clause refers to the fname

SELECT TOP 1000000 *
FROM [SQL2].[dbo].[People]
WHERE state = 'Utah'       --<<the query optimizer detects that the where clause refers to the state


--Create a SQL Profiler Template

Create database Testdb

Use Testdb
go

Create Table test (col int)

Drop Table test

----------------------------------------------------------------------------


use SQL2
go

--select statements against SQL2 database gor SQL Tuning template

--Create a user profiler template

SELECT TOP 1000 [PeopleID]
,[Fname]
,[Lname]
,[Address1]
,[City]
,[State]
,[Zip]
,[Country]
,[Phone]
FROM [SQL2].[dbo].[People]
WHERE LNAME = 'Garcia'     --<< note that SQL will recommend INCLUDED columns to index when included in the select clause


SELECT TOP 10000 
[Lname]
FROM [SQL2].[dbo].[People]
WHERE LNAME = 'Houston'    --<< note that SQL will NOT recommend INCLUDED columns to index when not included in the select statement

SELECT TOP 10000 *
FROM [SQL2].[dbo].[People]
WHERE Fname = 'gloria'     --<<the query optimizer detects that the where clause refers to the fname

SELECT TOP 1000000 *
FROM [SQL2].[dbo].[People]
WHERE state = 'Utah'       --<<the query optimizer detects that the where clause refers to the state

----------------------------------------------------------------------------

SQL Server statistics and the role it plays

•	What is the SQL query optimizer?
•	What is the function of the query optimizer?
•	What are SQL Server Statistics?
•	How does it help up in performance?
•	How do you create statistics?
•	How do you view them?
•	Best practice for statistics
      A query is a request for information from a database; this can be either a simple request or a complex request such as using joins
      Since database structures are complex and the need to access the data can be achieved in different ways, (such as a table scan or use of index) the processing time to get that data may vary and SQL may need ‘help’ to retrieve that data. Statistics in SQL Server refers specifically to information that the server collects about the distribution of data in columns and indexes
     This is where the query optimizer comes in.  Note, the query optimizer cannot be accessed directly by users, but the query optimizer attempts to determine the most efficient way to execute a given query by considering the possible query plans, such as using a table scan or the index, uses statistics to “find the best path” in its query optimization and factors such as number of records, density of pages, histogram, or available indexes all help the SQL Server optimizer in “guessing” the most efficient way to retrieve data
     Thus query optimization typically tries to approximate the optimum processing time it will take to retrieve the data request

So how are statistics created?
      Statistics can be automatically created when you create an index. If the database setting auto create stats is on, then SQL Server will automatically create statistics for non-indexed columns that are used in queries

See images
•	Or they can be manually created by TSQL or GUI
See image
USE [AdventureWorks2014]
GO

CREATE NONCLUSTERED INDEX [NonClusteredIndex-20160203-192425] 
ON [dbo].[People2]
([Fname] ASC,[Lname] ASC)


DBCC SHOW_STATISTICS ('people2','NonClusteredIndex-20160203-192425')
WITH HISTOGRAM

How are statistics updated?
The default settings in SQL Server are to auto create and auto update statistics.

Auto Update Statistics basically means, if there is an incoming query but statistics are stale, SQL Server will update statistics first before it generates an execution plan.

Auto Update Statistics Asynchronously on the other hand means, if there is an incoming query but statistics are stale, SQL Server uses the stale statistics to generate the execution plan, then updates the statistics afterwards.
What configuration settings should we set?
Automatic Statistics
By default, SQL Server databases automatically create and update statistics. The information that gets stored includes:
•	The number of rows and pages occupied by a table's data '
•	The time that statistics were last updated
•	The average length of keys in a column
•	Histograms showing the distribution of data in a column


****************************************


-- Create an index.  When creating an index, the statistics are created automatically

USE [AdventureWorks2014]
GO

CREATE NONCLUSTERED INDEX [NonClusteredIndex-20160203-192425] 
ON [dbo].[People2]
([Fname] ASC,[Lname] ASC)

--view statistics via GUI

--alternative way to view statistcs with DBCC command - distribution of data

DBCC SHOW_STATISTICS ('people2','NonClusteredIndex-20160203-192425')
WITH HISTOGRAM

--list all of the statistics being maintained on a table

use AdventureWorks2014
go
EXEC sp_helpstats 
@objname = '[dbo].[People2]',
@results = 'ALL';


----------------------------------------------------------------------------



The next several videos will be devoted to SQL Server Monitoring and the tools that come with the SQL Server

We will be discussing the following tools

•	Windows Task Manager
•	SQL Activity monitor
•	SQL Performance Monitor
•	SQL Database Management Views (DMV)
•	Stored Procedures
•	SQL Profiler


Activity Monitor in SQL Server
	
    The primary function of the Activity Monitor is to allow the DBA to quickly view any potential performance issues in the server, network or the database.  If any contentions are occurring between SPIDs, this is where the DBA can kill the process

     Viewing the Activity Monitor Dashboard you will notice four graphs which can help identity any abnormal activity in the Database.  Note that the refresh rate for each graph is 10 seconds; however it can be changed by right clicking on the graph

Here is what he Activity monitor looks like:



 




This dashboard also contain four panes where you can view more detailed information about each process inside the server



Processor Time:

The Processes pane gives information on what processes are running and what resources are being utilized etc.  You can right click this and view the Kill, Profiler, and Detail options 
 
Waiting Tasks:

The number of tasks that are waiting for processor, I/O, or memory resources.  The Resource Waits pane details the processes waiting for other resources on the server

Database I/O: (Input/Output)

Information on data and log files for both system and user defined databases. Provides information on such things as the transfer rate in MB/Sec, data from memory to disk, disk to memory, or disk to disk. This allow the DBA to quickly view what is causing I/O contention
 
Batch Requests/sec:

This pane show the number of batches being received, 
Expensive queries running, and Find the Most Time Consuming Code in your SQL Server Database. If you right click this pane, you can view the execution plan option

The various panes info
The Processes pane shows the information about the currently running processes on the SQL databases, who runs them, and from which application.  Hover over each header to show tool tip

Session ID – or SPID is a unique value assigned by Database Engine to every user connection. 
User Process – 1 for user processes, 0 for system processes. 
Task State – the task state, blank for tasks in the runnable and sleeping state
PENDING: Waiting for a worker thread.
RUNNABLE: Runnable, but waiting to receive a quantum.
RUNNING: Currently running on the scheduler.
SUSPENDED: Has a worker, but is waiting for an event.
DONE: Completed.
SPINLOOP: Stuck in a spinlock.
•	Wait Time (ms) – how long in milliseconds the task is waiting for a resource. 
•	Wait Type – the last/current wait type
•	Wait Resource – the resource the connection is waiting for
•	Blocked By – the ID of the session that is blocking the task. 
•	Head Blocker – the session that causes the first blocking condition in a blocking chain
•	Memory Use (KB) – the memory used by the task. 
•	MB/sec Read – shows recent read activity for the database file
•	MB/sec Written – shows recent write activity for the database file
•	Response Time (ms) – average response time for recent read-and-write activity
The Recent Expensive Queries pane
Expensive queries are the queries that use much resources – memory, disk, and network
•	Executions/min – the number of executions per minute, since the last recompilation. 
•	CPU (ms/sec) – the CPU rate used, since the last recompilation. 
•	Physical Reads/sec, Logical Writes/sec, and Logical Reads/ Average 
•	Duration (ms) – average time that the query runs




----------------------------------------------------------------------------

What is the (SQL) Performance Monitor?

Windows Performance Monitor or PerfMon is a great tool to capture metrics for your entire Windows server and including your SQL Server environment.  It has easy to view graphs and counters that you can select to find a specific issue at hand.  
There are counters for .NET, Disks, Memory, Processors, Network, and many for SQL Server related to each instance of SQL Server that you may have on the box. 
The purpose of the perfmon is to identify the metrics you like to use to measure SQL Server performance and collecting them over time giving you a quick and easy way to identify SQL Server problems, as well as capture your performance trend over time.

What are counters, what counters should we use?
Depends!
Counters are a method to measure current performance, as well as performance over time.  As there are many counters and there is no strict guideline as to use a specific counter, I suggest we look at some common ones for our demonstration and then allow the DBA to experience with others.  The best approach is to capture some common values when your system is running fine, so you can create a baseline.  Then once you have information about these counters and the baseline you can compare performance issues against the baseline.

Measuring Windows counters example:
•	Memory – Available MBytes 
•	Paging File – % Usage 
•	Physical Disk – Avg. Disk sec/Read 
•	Physical Disk – Avg. Disk sec/Write 
•	Physical Disk – Disk Reads/sec 
•	Physical Disk – Disk Writes/sec 
•	Processor – % Processor Time
•	Network

Measuring SQL Server counters:
SQLServer: Buffer Manager: Buffer cache hit ratio
The buffer cache hit ratio counter represents how often SQL Server is able to find data pages (smallest unit of data 8k) in its buffer cache when a query needs a data page. We want this number to be as close to a 100 as possible, which means that the SQL Server was able to get data for queries out of memory instead of reading from disk. A low number indicates memory issue.
SQLServer: Buffer Manager: Page life expectancy
The page life expectancy counter measures how long pages stay in the buffer cache in seconds. The longer a page stays in memory, the better as this indicates that the SQL Serve did not need to read from the disk.  A lower number indicates that the it’s reading form disk.  Update memory??
SQLServer: SQL Statistics: Batch Requests/Sec
Batch Requests/Sec measures the number of batches SQL Server is receiving per second. This information provides how much activity is being processed by your SQL Server box. The higher the number, the more queries are being executed on your box. Higher number indicates that the server is busy.  But, again create a baseline for you system.

SQLServer: SQL Statistics: SQL Compilations/Sec
The SQL Compilations/Sec measure the number of times SQL Server compiles an execution plan per second. Compiling an execution plan is a resource-intensive operation. One compile per every 10 batch requests.
SQLServer: Locks: Lock Waits / Sec: _Total
In order for SQL Server to manage concurrent users on the system, SQL Server needs to lock resources from time to time. The lock waits per second counter tracks the number of times per second that SQL Server is not able to retain a lock right away for a resource. Ideally you dont want any request to wait for a lock. Therefore you want to keep this counter at zero, or close to zero at all times.
SQLServer: Access Methods: Page Splits / Sec
This counter measures the number of times SQL Server had to split a page when updating or inserting data per second. Page splits are expensive, and cause your table to perform more poorly due to fragmentation. Therefore, the fewer page splits you have the better your system will perform. Ideally this counter should be less than 20% of the batch requests per second.

SQLServer: General Statistics: User Connections
The user connections counter identifies the number of different users that are connected to SQL Server at the time the sample was taken.  This does not refer to the end users, but rather connections that a user has to the server.  Thus a user can have many connections

SQLServer: General Statistic: Processes Block
The processes blocked counter identifies the number of blocked processes. When one process is blocking another process, the blocked process cannot move forward with its execution plan until the resource that is causing it to wait is freed up. Ideally you dont want to see any blocked processes. When processes are being blocked you should investigate.
SQLServer: Buffer Manager: Checkpoint Pages / Sec
The checkpoint pages per second counter measures the number of pages written to disk by a checkpoint operation. If this counter is climbing, it might mean you are running into memory pressures that are causing dirty pages to be flushed to disk more frequently than normal.



----------------------------------------------------------------------------

Simple Demo to illustrate resource utilization
Server Hardware:
Central Processing Unit (CPU)
Memory
Disk
Network
The CPU is the brain of the computer.  As it gets more requests, it must work harder and faster at answering the queries
The memory is the ‘space’ that is needed for the application for to ‘OPEN’.  Analogy:  a small physical desk can hold two or three pages of Time magazine.  As you get into opening larger newspaper, you will need more ‘space on that desk’
The disk is the warehouse and placing the boxes next to each other for retrieval is easier than scatters around the large warehouse.  That is the I/O of the system.  The less I/Os the better for performance
Network is the ‘highway’ for sending and getting data bits.  The NIC card and the channels for communication between resources gets bottle necked if there are large amounts of data to be sent or retrieved.  A faster highway lane with many booths can handle the traffic better than a single booth

 
     One of the prime purpose of the Perfmon is to discover bottlenecks.  Thus, we must first understand what is a bottleneck? 
     A bottleneck occurs when simultaneous access BY APPLICATION OR USERS to shared resources such as (CPU, memory, disk, network or other resources) causes an overload for the resources. This demand on shared resources can cause poor response time and must be identified and tuned by the DBA.  The tuning can be either hardware upgrade, application tuning or both.  Monitoring SQL Server performance is a complex task, as performance depends on many parameters, both hardware and software
What causes bottleneck:
•	Insufficient hardware resources which may require upgrade or replacement
•	Resources are not distributed evenly; an example being one disk is being monopolized
•	Incorrectly configured resources such as application or ill designed databases
Some of the key areas to monitor to identify bottlenecks are as follows:
•	CPU utilization	
•	Memory usage	
•	Disk input/output (I/O)	
•	User connections	
•	Blocking locks	
So now that we know what resources to monitor, how should we begin?
Before going out and buying a faster server or upgrading the existing server with faster CPUS, more memory and faster disks, obtain a baseline of metrics.  And always rule out software issues first such as poorly designed databases and insufficient indexes
Start with obtaining a performance baseline. 
You monitor the server over time so that you can determine Server average performance, identify peak usage, determine the time required for backup and restore activities, and so on.  This gives you a baseline from which you can judge the server against to determine if you have a performance bottleneck. This may be a weekly or monthly set of metrics that you obtain.  Each depends upon you environment.





 ***************************************
 
 
 
     One of the prime purpose of the Perfmon is to discover bottlenecks.  Thus, we must first understand what is a bottleneck? 
     A bottleneck occurs when simultaneous access BY APPLICATION OR USERS to shared resources such as (CPU, memory, disk, network or other resources) causes an overload for the resources. This demand on shared resources can cause poor response time and must be identified and tuned by the DBA.  The tuning can be either hardware upgrade, application tuning or both.  Monitoring SQL Server performance is a complex task, as performance depends on many parameters, both hardware and software
What causes bottleneck:
•	Insufficient hardware resources which may require upgrade or replacement
•	Resources are not distributed evenly; an example being one disk is being monopolized
•	Incorrectly configured resources such as application or ill designed databases
Some of the key areas to monitor to identify bottlenecks are as follows:
•	CPU utilization	
•	Memory usage	
•	Disk input/output (I/O)	
•	User connections	
•	Blocking locks	
So now that we know what resources to monitor, how should we begin?
Before going out and buying a faster server or upgrading the existing server with faster CPUS, more memory and faster disks, obtain a baseline of metrics.  And always rule out software issues first such as poorly designed databases and insufficient indexes
Start with obtaining a performance baseline. 
You monitor the server over time so that you can determine Server average performance, identify peak usage, determine the time required for backup and restore activities, and so on.  This gives you a baseline from which you can judge the server against to determine if you have a performance bottleneck. This may be a weekly or monthly set of metrics that you obtain.  Each depends upon you environment.


Hardware bottlenecks
Most hardware bottlenecks can be attributed to disk throughput, memory usage, processor usage, or network bandwidth. 
One problem can often mask another. You might suspect hard disk performance as the cause of degraded query performance. 
You can sometimes relieve bottlenecks by rescheduling resource-intensive SQL Server activities so that there’s less of a load on the server. 
One area you should check is the performance of queries.
If you have queries that use excessive server resources, overall performance suffers. 
SQL Profiler and the Database Engine Tuning Advisor can both help you gather information about queries. 

CPU utilization	
•	A chronically high CPU utilization rate may indicate that Transact-SQL queries need to be tuned or that a CPU upgrade is needed.  CPU usage greater than 80% consistently (plateauing)
Memory usage	
•	Insufficient memory allocated or available to Microsoft SQL Server degrades performance. SQL Server is a hog for memory and the more memory the better. If in sufficient memory is not allocated to the SQL Server, then Data must be read from the disk rather than directly from the data cache. This can cause performance issues.  
Disk input/output (I/O)	
•	Transact-SQL queries can be tuned to reduce unnecessary I/O; for example, by employing indexes.
User connections	
•	Too many users may be accessing the server simultaneously causing performance degradation.
Blocking locks	
•	Incorrectly designed applications can cause locks and hamper concurrency, thus causing longer response times and lower transaction throughput rates.

Monitoring processor use
High processor utilization can be an indication that: 
1.	You need a processor upgrade (faster, better processor). 
2.	You need an additional processor. 
3.	You have a poorly designed application. 
By monitoring processor activity over time, you can determine if you have a processor bottleneck and often identify the activities placing an excessive load on the processor.
 Counters that you should monitor include those in the following table. 
Object	Counter	Description
Processor	% Processor Time 	Value should be consistently less than 90%. A consistent value of 90% or more indicates a processor bottleneck. Monitor this for each processor in a multiprocessor system and for total processor time (all processors). 
System	Processor Queue Length 	The number of threads waiting for processor time. A consistent value of 2 or more can indicate a processor bottleneck. 
In most cases, a processor bottleneck indicates you need to either upgrade to a faster processor or to multiple processors. In some cases, you can reduce the processor load by fine-tuning your application


Monitor SQL Server memory usage 
•	Memory: Available MBytes 
•	Memory: Pages/sec 
•	Memory: Page Faults/sec
Available MBytes is the amount of physical memory, in Megabytes, immediately available for allocation to a process or for system use. The higher the value the better
The Pages/sec counter indicates the number of pages that were retrieved from disk. A high value can indicate lack of memory.  
Monitor the Memory: Page Faults/sec counter to make sure that the disk activity is not caused by paging.
By default, SQL Server changes its memory requirements dynamically so there is no need to alter the memory parameters; but if you need to alter the memory, you can change that via GUI or TSQL
To monitor the amount of memory that SQL Server specifically uses monitor

•	SQL Server: Buffer Manager: Buffer Cache Hit Ratio 
•	SQL Server: Memory Manager: Total Server Memory (KB) 
•	SQL Server: Buffer Manager: Page Life Expectancy
The Buffer Cache Hit Ratio counter is specific to SQL Server; Percentage of pages that were found in the buffer pool without having to incur a read from disk.  a rate of 90 percent or higher is desirable. A value greater than 90 percent indicates that more than 90 percent of all requests for data were satisfied from the data cache rather than the disk
If the Total Server Memory (KB) counter is consistently high compared to the amount of physical memory in the computer, it may indicate that more memory is required.
Page Life Expectancy is the number of seconds a page will stay in the buffer pool without references. The recommended value of the Page Life Expectancy counter is approximately 300 seconds. Simply put, the longer the page stays in the buffer pool the better performance you will get rather than getting the data from the disk


Some common counters used for analyzing disk performance are:
•	 Avg. Disk sec/Read - the average time, in seconds, of a read of data from the disk. 
•	 Avg. Disk sec/Write - is the average time, in seconds, of a write of data to the disk.
These metrics help how long the disks took to service an I/O request no matter what kind of hardware you using, weather its physical or virtual hardware.  If your system had many disks, then it’s important to measure each disk for discovering bottlenecks
The average should be under 15ms with maximums up to 30ms. The less time it takes to read or write data the faster your system will be










•	Disk Transfers/sec - is the rate of read and write operations on the disk. 
•	Disk Reads/sec - is the rate of read operations on the disk. 
•	Disk Writes/sec - is the rate of write operations on the disk. 
•	Avg. Disk Queue Length - is the average number of both read and write requests that were queued for the selected disk during the sample interval. 
•	Current Disk Queue Length - is the number of requests outstanding on the disk at the time the performance data is collected.


 
 
----------------------------------------------------------------------------

What are Dynamic Management Views (DMVs)

Another tool at your disposal to measure performance and view details about the SQL Server is the DMVs.  Dynamic management views and functions return server state information that can be used to monitor the health of a server instance, diagnose problems, and tune performance

There are two different kinds of DMVs and DMFs:
•	Server-scoped: These look at the state of an entire SQL Server instance.
•	Database-scoped: These look at the state of a specific database
•	While the DMV can be used like the select statement, the DMF requires a parameter
•	Some apply to entire server and are stored in the master database while others to each database
•	Over 200 DMVs at this time


The DMVs are broken down into the following categories:
•	Change Data Capture Related Dynamic Management Views 
•	Change Tracking Related Dynamic Management Views 
•	Common Language Runtime Related Dynamic Management Views 
•	Database Mirroring Related Dynamic Management Views 
•	Database Related Dynamic Management Views 
•	Execution Related Dynamic Management Views and Functions 
•	Extended Events Dynamic Management Views 
•	Full-Text Search Related Dynamic Management Views 
•	Filestream-Related Dynamic Management Views (Transact-SQL) 
•	I/O Related Dynamic Management Views and Functions 
•	Index Related Dynamic Management Views and Functions 
•	Object Related Dynamic Management Views and Functions 
•	Query Notifications Related Dynamic Management Views 
•	Replication Related Dynamic Management Views 
•	Resource Governor Dynamic Management Views 
•	Service Broker Related Dynamic Management Views 
•	SQL Server Operating System Related Dynamic Management Views 
•	Transaction Related Dynamic Management Views and Functions 
•	Security Related Dynamic Management Views 

--website to DMV
https://msdn.microsoft.com/en-us/library/ms188754.aspx
A few common examples of DMVs:

--view all DMVs

SELECT name, type, type_desc
FROM sys.system_objects
WHERE name LIKE 'dm_%'
ORDER BY 2 desc


SELECT * FROM SYS.dm_os_memory_allocations               --<< Notice that all DMVs starts with SYS.DM
SELECT * FROM SYS.dm_db_xtp_nonclustered_index_stats   
SELECT * FROM SYS.dm_db_mirroring_past_actions
SELECT * FROM SYS.dm_xe_session_object_columns
SELECT * FROM SYS.dm_os_loaded_modules
SELECT * FROM SYS.dm_db_task_space_usage
SELECT * FROM SYS.dm_os_memory_objects
SELECT * FROM SYS.dm_audit_class_type_map
SELECT * FROM SYS.dm_os_schedulers
SELECT * FROM SYS.dm_os_server_diagnostics_log_configurations
SELECT * FROM SYS.dm_hadr_instance_node_map
SELECT * FROM SYS.dm_io_cluster_valid_path_names
SELECT * FROM SYS.dm_os_dispatcher_pools
SELECT * FROM SYS.dm_xtp_transaction_stats
SELECT * FROM SYS.dm_exec_query_profiles
SELECT * FROM SYS.dm_os_threads
SELECT * FROM SYS.dm_repl_tranhash
SELECT * FROM SYS.dm_hadr_cluster
SELECT * FROM SYS.dm_qn_subscriptions
SELECT * FROM SYS.dm_db_session_space_usage
SELECT * FROM SYS.dm_xtp_gc_stats
SELECT * FROM SYS.dm_exec_query_optimizer_info
SELECT * FROM SYS.dm_xe_map_values
SELECT * FROM SYS.dm_db_xtp_index_stats
SELECT * FROM SYS.dm_tran_top_version_generators
SELECT * FROM SYS.dm_fts_fdhosts
SELECT * FROM SYS.dm_xe_sessions
SELECT * FROM SYS.dm_db_log_space_usage
SELECT * FROM SYS.dm_hadr_name_id_map
SELECT * FROM SYS.dm_os_waiting_tasks
SELECT * FROM SYS.dm_exec_background_job_queue
SELECT * FROM SYS.dm_resource_governor_resource_pool_volumes
SELECT * FROM SYS.dm_os_hosts
SELECT * FROM SYS.dm_os_memory_brokers
SELECT * FROM SYS.dm_exec_requests
SELECT * FROM SYS.dm_tran_commit_table
SELECT * FROM SYS.dm_db_missing_index_details
SELECT * FROM SYS.dm_clr_properties
SELECT * FROM SYS.dm_os_sublatches
SELECT * FROM SYS.dm_os_buffer_pool_extension_configuration
SELECT * FROM SYS.dm_exec_query_memory_grants
SELECT * FROM SYS.dm_fts_outstanding_batches
SELECT * FROM SYS.dm_logpool_hashentries
SELECT * FROM SYS.dm_os_wait_stats
SELECT * FROM SYS.dm_os_memory_node_access_stats
SELECT * FROM SYS.dm_os_spinlock_stats
SELECT * FROM SYS.dm_database_encryption_keys
SELECT * FROM SYS.dm_db_xtp_checkpoint_stats
SELECT * FROM SYS.dm_hadr_availability_replica_states
SELECT * FROM SYS.dm_broker_connections
SELECT * FROM SYS.dm_db_mirroring_auto_page_repair
SELECT * FROM SYS.dm_server_registry
SELECT * FROM SYS.dm_tran_current_snapshot
SELECT * FROM SYS.dm_os_dispatchers
SELECT * FROM SYS.dm_os_stacks
SELECT * FROM SYS.dm_db_xtp_object_stats
SELECT * FROM SYS.dm_filestream_non_transacted_handles
SELECT * FROM SYS.dm_xe_session_targets
SELECT * FROM SYS.dm_fts_memory_buffers
SELECT * FROM SYS.dm_fts_index_population
SELECT * FROM SYS.dm_tran_current_transaction
SELECT * FROM SYS.dm_os_cluster_properties
SELECT * FROM SYS.dm_os_child_instances
SELECT * FROM SYS.dm_exec_connections
SELECT * FROM SYS.dm_server_memory_dumps
SELECT * FROM SYS.dm_xtp_threads
SELECT * FROM SYS.dm_exec_background_job_queue_stats
SELECT * FROM SYS.dm_os_memory_broker_clerks
SELECT * FROM SYS.dm_filestream_file_io_handles
SELECT * FROM SYS.dm_xtp_transaction_recent_rows
SELECT * FROM SYS.dm_hadr_availability_replica_cluster_nodes
SELECT * FROM SYS.dm_fts_active_catalogs
SELECT * FROM SYS.dm_tran_database_transactions
SELECT * FROM SYS.dm_filestream_file_io_requests
SELECT * FROM SYS.dm_cdc_log_scan_sessions
SELECT * FROM SYS.dm_os_memory_cache_clock_hands
SELECT * FROM SYS.dm_repl_schemas
SELECT * FROM SYS.dm_db_mirroring_connections
SELECT * FROM SYS.dm_audit_actions
SELECT * FROM SYS.dm_hadr_availability_group_states
SELECT * FROM SYS.dm_os_ring_buffers
SELECT * FROM SYS.dm_db_xtp_table_memory_stats
SELECT * FROM SYS.dm_db_missing_index_groups
SELECT * FROM SYS.dm_hadr_cluster_members
SELECT * FROM SYS.dm_db_uncontained_entities
SELECT * FROM SYS.dm_exec_cached_plans
SELECT * FROM SYS.dm_hadr_availability_replica_cluster_states
SELECT * FROM SYS.dm_exec_sessions
SELECT * FROM SYS.dm_os_memory_clerks
SELECT * FROM SYS.dm_hadr_auto_page_repair
SELECT * FROM SYS.dm_db_xtp_memory_consumers
SELECT * FROM SYS.dm_repl_articles
SELECT * FROM SYS.dm_xe_session_events
SELECT * FROM SYS.dm_broker_forwarded_messages
SELECT * FROM SYS.dm_resource_governor_resource_pools
SELECT * FROM SYS.dm_db_xtp_checkpoint_files
SELECT * FROM SYS.dm_db_partition_stats
SELECT * FROM SYS.dm_io_pending_io_requests
SELECT * FROM SYS.dm_xtp_system_memory_consumers
SELECT * FROM SYS.dm_hadr_cluster_networks
SELECT * FROM SYS.dm_os_nodes
SELECT * FROM SYS.dm_tcp_listener_states
SELECT * FROM SYS.dm_os_memory_cache_entries
SELECT * FROM SYS.dm_os_virtual_address_dump
SELECT * FROM SYS.dm_os_memory_cache_hash_tables
SELECT * FROM SYS.dm_cdc_errors
SELECT * FROM SYS.dm_resource_governor_configuration
SELECT * FROM SYS.dm_exec_query_stats
SELECT * FROM SYS.dm_fts_semantic_similarity_population
SELECT * FROM SYS.dm_clr_tasks
SELECT * FROM SYS.dm_db_xtp_hash_index_stats
SELECT * FROM SYS.dm_os_worker_local_storage
SELECT * FROM SYS.dm_db_persisted_sku_features
SELECT * FROM SYS.dm_os_sys_memory
SELECT * FROM SYS.dm_cryptographic_provider_properties
SELECT * FROM SYS.dm_tran_transactions_snapshot
SELECT * FROM SYS.dm_os_buffer_descriptors
SELECT * FROM SYS.dm_tran_active_snapshot_database_transactions
SELECT * FROM SYS.dm_server_services
SELECT * FROM SYS.dm_tran_active_transactions
SELECT * FROM SYS.dm_db_file_space_usage
SELECT * FROM SYS.dm_broker_activated_tasks
SELECT * FROM SYS.dm_broker_queue_monitors
SELECT * FROM SYS.dm_os_memory_cache_counters
SELECT * FROM SYS.dm_tran_session_transactions
SELECT * FROM SYS.dm_clr_appdomains
SELECT * FROM SYS.dm_db_xtp_gc_cycle_stats
SELECT * FROM SYS.dm_exec_trigger_stats
SELECT * FROM SYS.dm_os_memory_pools
SELECT * FROM SYS.dm_os_latch_stats
SELECT * FROM SYS.dm_io_backup_tapes
SELECT * FROM SYS.dm_db_xtp_merge_requests
SELECT * FROM SYS.dm_resource_governor_workload_groups
SELECT * FROM SYS.dm_hadr_database_replica_states
SELECT * FROM SYS.dm_fts_memory_pools
SELECT * FROM SYS.dm_resource_governor_resource_pool_affinity
SELECT * FROM SYS.dm_os_sys_info
SELECT * FROM SYS.dm_tran_locks
SELECT * FROM SYS.dm_exec_procedure_stats
SELECT * FROM SYS.dm_hadr_database_replica_cluster_states
SELECT * FROM SYS.dm_exec_query_transformation_stats
SELECT * FROM SYS.dm_exec_query_resource_semaphores
SELECT * FROM SYS.dm_repl_traninfo
SELECT * FROM SYS.dm_db_missing_index_group_stats
SELECT * FROM SYS.dm_fts_population_ranges
SELECT * FROM SYS.dm_os_performance_counters
SELECT * FROM SYS.dm_os_workers
SELECT * FROM SYS.dm_xe_session_event_actions
SELECT * FROM SYS.dm_db_script_level
SELECT * FROM SYS.dm_server_audit_status
SELECT * FROM SYS.dm_io_cluster_shared_drives
SELECT * FROM SYS.dm_os_tasks
SELECT * FROM SYS.dm_db_fts_index_physical_stats
SELECT * FROM SYS.dm_xe_packages
SELECT * FROM SYS.dm_logpool_stats
SELECT * FROM SYS.dm_os_memory_nodes
SELECT * FROM SYS.dm_tran_version_store
SELECT * FROM SYS.dm_os_windows_info
SELECT * FROM SYS.dm_os_cluster_nodes
SELECT * FROM SYS.dm_xtp_gc_queue_stats
SELECT * FROM SYS.dm_os_process_memory
SELECT * FROM SYS.dm_xe_objects
SELECT * FROM SYS.dm_xe_object_columns
SELECT * FROM SYS.dm_db_xtp_transactions
SELECT * FROM SYS.dm_clr_loaded_assemblies
SELECT * FROM SYS.dm_db_index_usage_stats


   /* DMV to list all empty tables in your database. */

   Use AdventureWorks2012

   go


   ;WITH Empty AS     
   (
    SELECT 
 OBJECT_NAME(OBJECT_ID) [Table],
 SUM(row_count) [Records]
    FROM 
 sys.dm_db_partition_stats      
    WHERE 
 index_id = 0 OR index_id = 1      
    GROUP BY 
 OBJECT_ID      
   )      

   SELECT [Table],Records 
   FROM [Empty]      
   WHERE [Records] = 0

/*
dmvs for indexes, slow running quieries, missing indexes, statistice, 
counters, cpu, memoru, I/), physical disk sessions, users, security, 
database info 
*/


Select * from sys.dm_exec_connections
Select * from sys.dm_exec_sessions
Select * from sys.dm_exec_requests
Select * from sys.dm_db_index_usage_stats
Select * from sys.dm_db_missing_index_group_stats
Select * from sys.dm_os_performance_counters
select * from sys.dm_os_sys_memory



--allow the DBA to identify where the bulk of the connections originate

SELECT dec.client_net_address ,
des.program_name ,
des.host_name ,
--des.login_name  
COUNT(dec.session_id) AS connection_count
FROM sys.dm_exec_sessions AS des
INNER JOIN sys.dm_exec_connections AS dec
ON des.session_id = dec.session_id
-- WHERE LEFT(des.host_name, 2) = 'WK'
GROUP BY dec.client_net_address ,
des.program_name ,
des.host_name
-- des.login_name
-- HAVING COUNT(dec.session_id) > 1
ORDER BY des.program_name,
dec.client_net_address ;


--who are directly connected to the SQL Server instance

SELECT dec.client_net_address ,
des.host_name ,
dest.text
FROM sys.dm_exec_sessions des
INNER JOIN sys.dm_exec_connections dec
ON des.session_id = dec.session_id
CROSS APPLY sys.dm_exec_sql_text(dec.most_recent_sql_handle) dest
WHERE des.program_name LIKE 'Microsoft SQL Server Management Studio%'
ORDER BY des.program_name ,
dec.client_net_address

--Find indexes for database

use AdventureWorks2012
go

SELECT DB_NAME(ddius.[database_id]) AS database_name ,
OBJECT_NAME(ddius.[object_id], DB_ID('AdventureWorks2012')) --<< replace db name
AS [object_name] ,
asi.[name] AS index_name ,
ddius.user_seeks + ddius.user_scans + ddius.user_lookups AS user_reads
FROM sys.dm_db_index_usage_stats ddius
INNER JOIN AdventureWorks2012.sys.indexes asi
ON ddius.[object_id] = asi.[object_id]
AND ddius.index_id = asi.index_id ;

--userful DMV for determining usage of index

SELECT OBJECT_NAME(ddius.[object_id], ddius.database_id) AS [object_name] ,
ddius.index_id ,
ddius.user_seeks ,
ddius.user_scans ,
ddius.user_lookups ,
ddius.user_seeks + ddius.user_scans + ddius.user_lookups
AS user_reads ,
ddius.user_updates AS user_writes ,
ddius.last_user_scan ,
ddius.last_user_update
FROM sys.dm_db_index_usage_stats ddius
WHERE ddius.database_id > 4 -- filter out system tables
AND OBJECTPROPERTY(ddius.object_id, 'IsUserTable') = 1
AND ddius.index_id > 0 -- filter out heaps
ORDER BY ddius.user_scans DESC

-- List unused indexes

SELECT OBJECT_NAME(i.[object_id]) AS [Table Name] ,
i.name
FROM sys.indexes AS i
INNER JOIN sys.objects AS o ON i.[object_id] = o.[object_id]
WHERE i.index_id NOT IN ( SELECT ddius.index_id
FROM sys.dm_db_index_usage_stats AS ddius
WHERE ddius.[object_id] = i.[object_id]
AND i.index_id = ddius.index_id
AND database_id = DB_ID() )
AND o.[type] = 'U'
ORDER BY OBJECT_NAME(i.[object_id]) ASC ;

--STOP

--Current Running Transaction

use master 
SELECT 
SPID,ER.percent_complete,
CAST(((DATEDIFF(s,start_time,GetDate()))/3600) as varchar) + ' hour(s), '
+ CAST((DATEDIFF(s,start_time,GetDate())%3600)/60 as varchar) + 'min, '
+ CAST((DATEDIFF(s,start_time,GetDate())%60) as varchar) + ' sec' as running_time,
CAST((estimated_completion_time/3600000) as varchar) + ' hour(s), '
+ CAST((estimated_completion_time %3600000)/60000 as varchar) + 'min, '
+ CAST((estimated_completion_time %60000)/1000 as varchar) + ' sec' as est_time_to_go,
DATEADD(second,estimated_completion_time/1000, getdate()) as est_completion_time,
ER.command,ER.blocking_session_id, SP.DBID,LASTWAITTYPE,
DB_NAME(SP.DBID) AS DBNAME,
SUBSTRING(est.text, (ER.statement_start_offset/2)+1,
((CASE ER.statement_end_offset 
WHEN -1 THEN DATALENGTH(est.text)
ELSE ER.statement_end_offset
END - ER.statement_start_offset)/2) + 1) AS QueryText,
TEXT,CPU,HOSTNAME,LOGIN_TIME,LOGINAME,
SP.status,PROGRAM_NAME,NT_DOMAIN, NT_USERNAME
FROM SYSPROCESSES SP
INNER JOIN 
sys.dm_exec_requests ER
ON sp.spid = ER.session_id
CROSS APPLY SYS.DM_EXEC_SQL_TEXT(er.sql_handle) EST



--Run following query to find longest running query using T-SQL

SELECT DISTINCT TOP 3
t.TEXT QueryName,
s.execution_count AS ExecutionCount,
s.max_elapsed_time AS MaxElapsedTime,
--ISNULL(s.total_elapsed_time / s.execution_count, 0) AS AvgElapsedTime,
s.creation_time AS LogCreatedOn--,
--ISNULL(s.execution_count / DATEDIFF(s, s.creation_time, GETDATE()), 0) AS FrequencyPerSec
FROM sys.dm_exec_query_stats s
CROSS APPLY sys.dm_exec_sql_text( s.sql_handle ) t
ORDER BY
s.max_elapsed_time DESC
GO

-- Top 5 worst performing Queries 

SELECT 
TOP 5 obj.name, max_logical_reads, max_elapsed_time 
FROM 
sys.dm_exec_query_stats a CROSS APPLY 
sys.dm_exec_sql_text(sql_handle) hnd INNER JOIN 
sys.sysobjects obj on hnd.objectid = obj.id 
ORDER BY 
max_logical_reads DESC

--TOP 5 CPU-CONSUMING STATEMENTS 

SELECT TOP 5
qs.total_worker_time/(qs.execution_count*60000000) as [Avg CPU Time in mins],
qs.execution_count,
qs.min_worker_time/60000000 as [Min CPU Time in mins],
--qs.total_worker_time/qs.execution_count,
SUBSTRING(qt.text,qs.statement_start_offset/2,
(case when qs.statement_end_offset = -1
then len(convert(nvarchar(max), qt.text)) * 2
else qs.statement_end_offset end -qs.statement_start_offset)/2)
as query_text,
dbname=db_name(qt.dbid),
object_name(qt.objectid) as [Object name]
FROM 
sys.dm_exec_query_stats qs cross apply 
sys.dm_exec_sql_text(qs.sql_handle) as qt
ORDER BY
[Avg CPU Time in mins] DESC



********************************************


--view all DMVs

SELECT name, type, type_desc
FROM sys.system_objects
WHERE name LIKE 'dm_%'
ORDER BY 2 desc


SELECT * FROM SYS.dm_os_memory_allocations               --<< Notice that all DMVs starts with SYS.DM
SELECT * FROM SYS.dm_db_xtp_nonclustered_index_stats   
SELECT * FROM SYS.dm_db_mirroring_past_actions
SELECT * FROM SYS.dm_xe_session_object_columns
SELECT * FROM SYS.dm_os_loaded_modules
SELECT * FROM SYS.dm_db_task_space_usage
SELECT * FROM SYS.dm_os_memory_objects
SELECT * FROM SYS.dm_audit_class_type_map
SELECT * FROM SYS.dm_os_schedulers
SELECT * FROM SYS.dm_os_server_diagnostics_log_configurations
SELECT * FROM SYS.dm_hadr_instance_node_map
SELECT * FROM SYS.dm_io_cluster_valid_path_names
SELECT * FROM SYS.dm_os_dispatcher_pools
SELECT * FROM SYS.dm_xtp_transaction_stats
SELECT * FROM SYS.dm_exec_query_profiles
SELECT * FROM SYS.dm_os_threads
SELECT * FROM SYS.dm_repl_tranhash
SELECT * FROM SYS.dm_hadr_cluster
SELECT * FROM SYS.dm_qn_subscriptions
SELECT * FROM SYS.dm_db_session_space_usage
SELECT * FROM SYS.dm_xtp_gc_stats
SELECT * FROM SYS.dm_exec_query_optimizer_info
SELECT * FROM SYS.dm_xe_map_values
SELECT * FROM SYS.dm_db_xtp_index_stats
SELECT * FROM SYS.dm_tran_top_version_generators
SELECT * FROM SYS.dm_fts_fdhosts
SELECT * FROM SYS.dm_xe_sessions
SELECT * FROM SYS.dm_db_log_space_usage
SELECT * FROM SYS.dm_hadr_name_id_map
SELECT * FROM SYS.dm_os_waiting_tasks
SELECT * FROM SYS.dm_exec_background_job_queue
SELECT * FROM SYS.dm_resource_governor_resource_pool_volumes
SELECT * FROM SYS.dm_os_hosts
SELECT * FROM SYS.dm_os_memory_brokers
SELECT * FROM SYS.dm_exec_requests
SELECT * FROM SYS.dm_tran_commit_table
SELECT * FROM SYS.dm_db_missing_index_details
SELECT * FROM SYS.dm_clr_properties
SELECT * FROM SYS.dm_os_sublatches
SELECT * FROM SYS.dm_os_buffer_pool_extension_configuration
SELECT * FROM SYS.dm_exec_query_memory_grants
SELECT * FROM SYS.dm_fts_outstanding_batches
SELECT * FROM SYS.dm_logpool_hashentries
SELECT * FROM SYS.dm_os_wait_stats
SELECT * FROM SYS.dm_os_memory_node_access_stats
SELECT * FROM SYS.dm_os_spinlock_stats
SELECT * FROM SYS.dm_database_encryption_keys
SELECT * FROM SYS.dm_db_xtp_checkpoint_stats
SELECT * FROM SYS.dm_hadr_availability_replica_states
SELECT * FROM SYS.dm_broker_connections
SELECT * FROM SYS.dm_db_mirroring_auto_page_repair
SELECT * FROM SYS.dm_server_registry
SELECT * FROM SYS.dm_tran_current_snapshot
SELECT * FROM SYS.dm_os_dispatchers
SELECT * FROM SYS.dm_os_stacks
SELECT * FROM SYS.dm_db_xtp_object_stats
SELECT * FROM SYS.dm_filestream_non_transacted_handles
SELECT * FROM SYS.dm_xe_session_targets
SELECT * FROM SYS.dm_fts_memory_buffers
SELECT * FROM SYS.dm_fts_index_population
SELECT * FROM SYS.dm_tran_current_transaction
SELECT * FROM SYS.dm_os_cluster_properties
SELECT * FROM SYS.dm_os_child_instances
SELECT * FROM SYS.dm_exec_connections
SELECT * FROM SYS.dm_server_memory_dumps
SELECT * FROM SYS.dm_xtp_threads
SELECT * FROM SYS.dm_exec_background_job_queue_stats
SELECT * FROM SYS.dm_os_memory_broker_clerks
SELECT * FROM SYS.dm_filestream_file_io_handles
SELECT * FROM SYS.dm_xtp_transaction_recent_rows
SELECT * FROM SYS.dm_hadr_availability_replica_cluster_nodes
SELECT * FROM SYS.dm_fts_active_catalogs
SELECT * FROM SYS.dm_tran_database_transactions
SELECT * FROM SYS.dm_filestream_file_io_requests
SELECT * FROM SYS.dm_cdc_log_scan_sessions
SELECT * FROM SYS.dm_os_memory_cache_clock_hands
SELECT * FROM SYS.dm_repl_schemas
SELECT * FROM SYS.dm_db_mirroring_connections
SELECT * FROM SYS.dm_audit_actions
SELECT * FROM SYS.dm_hadr_availability_group_states
SELECT * FROM SYS.dm_os_ring_buffers
SELECT * FROM SYS.dm_db_xtp_table_memory_stats
SELECT * FROM SYS.dm_db_missing_index_groups
SELECT * FROM SYS.dm_hadr_cluster_members
SELECT * FROM SYS.dm_db_uncontained_entities
SELECT * FROM SYS.dm_exec_cached_plans
SELECT * FROM SYS.dm_hadr_availability_replica_cluster_states
SELECT * FROM SYS.dm_exec_sessions
SELECT * FROM SYS.dm_os_memory_clerks
SELECT * FROM SYS.dm_hadr_auto_page_repair
SELECT * FROM SYS.dm_db_xtp_memory_consumers
SELECT * FROM SYS.dm_repl_articles
SELECT * FROM SYS.dm_xe_session_events
SELECT * FROM SYS.dm_broker_forwarded_messages
SELECT * FROM SYS.dm_resource_governor_resource_pools
SELECT * FROM SYS.dm_db_xtp_checkpoint_files
SELECT * FROM SYS.dm_db_partition_stats
SELECT * FROM SYS.dm_io_pending_io_requests
SELECT * FROM SYS.dm_xtp_system_memory_consumers
SELECT * FROM SYS.dm_hadr_cluster_networks
SELECT * FROM SYS.dm_os_nodes
SELECT * FROM SYS.dm_tcp_listener_states
SELECT * FROM SYS.dm_os_memory_cache_entries
SELECT * FROM SYS.dm_os_virtual_address_dump
SELECT * FROM SYS.dm_os_memory_cache_hash_tables
SELECT * FROM SYS.dm_cdc_errors
SELECT * FROM SYS.dm_resource_governor_configuration
SELECT * FROM SYS.dm_exec_query_stats
SELECT * FROM SYS.dm_fts_semantic_similarity_population
SELECT * FROM SYS.dm_clr_tasks
SELECT * FROM SYS.dm_db_xtp_hash_index_stats
SELECT * FROM SYS.dm_os_worker_local_storage
SELECT * FROM SYS.dm_db_persisted_sku_features
SELECT * FROM SYS.dm_os_sys_memory
SELECT * FROM SYS.dm_cryptographic_provider_properties
SELECT * FROM SYS.dm_tran_transactions_snapshot
SELECT * FROM SYS.dm_os_buffer_descriptors
SELECT * FROM SYS.dm_tran_active_snapshot_database_transactions
SELECT * FROM SYS.dm_server_services
SELECT * FROM SYS.dm_tran_active_transactions
SELECT * FROM SYS.dm_db_file_space_usage
SELECT * FROM SYS.dm_broker_activated_tasks
SELECT * FROM SYS.dm_broker_queue_monitors
SELECT * FROM SYS.dm_os_memory_cache_counters
SELECT * FROM SYS.dm_tran_session_transactions
SELECT * FROM SYS.dm_clr_appdomains
SELECT * FROM SYS.dm_db_xtp_gc_cycle_stats
SELECT * FROM SYS.dm_exec_trigger_stats
SELECT * FROM SYS.dm_os_memory_pools
SELECT * FROM SYS.dm_os_latch_stats
SELECT * FROM SYS.dm_io_backup_tapes
SELECT * FROM SYS.dm_db_xtp_merge_requests
SELECT * FROM SYS.dm_resource_governor_workload_groups
SELECT * FROM SYS.dm_hadr_database_replica_states
SELECT * FROM SYS.dm_fts_memory_pools
SELECT * FROM SYS.dm_resource_governor_resource_pool_affinity
SELECT * FROM SYS.dm_os_sys_info
SELECT * FROM SYS.dm_tran_locks
SELECT * FROM SYS.dm_exec_procedure_stats
SELECT * FROM SYS.dm_hadr_database_replica_cluster_states
SELECT * FROM SYS.dm_exec_query_transformation_stats
SELECT * FROM SYS.dm_exec_query_resource_semaphores
SELECT * FROM SYS.dm_repl_traninfo
SELECT * FROM SYS.dm_db_missing_index_group_stats
SELECT * FROM SYS.dm_fts_population_ranges
SELECT * FROM SYS.dm_os_performance_counters
SELECT * FROM SYS.dm_os_workers
SELECT * FROM SYS.dm_xe_session_event_actions
SELECT * FROM SYS.dm_db_script_level
SELECT * FROM SYS.dm_server_audit_status
SELECT * FROM SYS.dm_io_cluster_shared_drives
SELECT * FROM SYS.dm_os_tasks
SELECT * FROM SYS.dm_db_fts_index_physical_stats
SELECT * FROM SYS.dm_xe_packages
SELECT * FROM SYS.dm_logpool_stats
SELECT * FROM SYS.dm_os_memory_nodes
SELECT * FROM SYS.dm_tran_version_store
SELECT * FROM SYS.dm_os_windows_info
SELECT * FROM SYS.dm_os_cluster_nodes
SELECT * FROM SYS.dm_xtp_gc_queue_stats
SELECT * FROM SYS.dm_os_process_memory
SELECT * FROM SYS.dm_xe_objects
SELECT * FROM SYS.dm_xe_object_columns
SELECT * FROM SYS.dm_db_xtp_transactions
SELECT * FROM SYS.dm_clr_loaded_assemblies
SELECT * FROM SYS.dm_db_index_usage_stats


   /* DMV to list all empty tables in your database. */

   Use AdventureWorks2012

   go


   ;WITH Empty AS     
   (
    SELECT 
 OBJECT_NAME(OBJECT_ID) [Table],
 SUM(row_count) [Records]
    FROM 
 sys.dm_db_partition_stats      
    WHERE 
 index_id = 0 OR index_id = 1      
    GROUP BY 
 OBJECT_ID      
   )      

   SELECT [Table],Records 
   FROM [Empty]      
   WHERE [Records] = 0

/*
dmvs for indexes, slow running quieries, missing indexes, statistice, 
counters, cpu, memory, I/), physical disk sessions, users, security, 
database info 
*/


Select * from sys.dm_exec_connections
Select * from sys.dm_exec_sessions
Select * from sys.dm_exec_requests
Select * from sys.dm_db_index_usage_stats
Select * from sys.dm_db_missing_index_group_stats
Select * from sys.dm_os_performance_counters
select * from sys.dm_os_sys_memory



--allow the DBA to identify where the bulk of the connections originat

SELECT dec.client_net_address ,
des.program_name ,
des.host_name ,
--des.login_name  
COUNT(dec.session_id) AS connection_count
FROM sys.dm_exec_sessions AS des
INNER JOIN sys.dm_exec_connections AS dec
ON des.session_id = dec.session_id
-- WHERE LEFT(des.host_name, 2) = 'WK'
GROUP BY dec.client_net_address ,
des.program_name ,
des.host_name
-- des.login_name
-- HAVING COUNT(dec.session_id) > 1
ORDER BY des.program_name,
dec.client_net_address ;


--who are directly connected to the SQL Server instance

SELECT dec.client_net_address ,
des.host_name ,
dest.text
FROM sys.dm_exec_sessions des
INNER JOIN sys.dm_exec_connections dec
ON des.session_id = dec.session_id
CROSS APPLY sys.dm_exec_sql_text(dec.most_recent_sql_handle) dest
WHERE des.program_name LIKE 'Microsoft SQL Server Management Studio%'
ORDER BY des.program_name ,
dec.client_net_address

--Find indexes for database

use AdventureWorks2012
go

SELECT DB_NAME(ddius.[database_id]) AS database_name ,
OBJECT_NAME(ddius.[object_id], DB_ID('AdventureWorks2012')) --<< replace db name
AS [object_name] ,
asi.[name] AS index_name ,
ddius.user_seeks + ddius.user_scans + ddius.user_lookups AS user_reads
FROM sys.dm_db_index_usage_stats ddius
INNER JOIN AdventureWorks2012.sys.indexes asi
ON ddius.[object_id] = asi.[object_id]
AND ddius.index_id = asi.index_id ;

--userful DMV for determining usage of index

SELECT OBJECT_NAME(ddius.[object_id], ddius.database_id) AS [object_name] ,
ddius.index_id ,
ddius.user_seeks ,
ddius.user_scans ,
ddius.user_lookups ,
ddius.user_seeks + ddius.user_scans + ddius.user_lookups
AS user_reads ,
ddius.user_updates AS user_writes ,
ddius.last_user_scan ,
ddius.last_user_update
FROM sys.dm_db_index_usage_stats ddius
WHERE ddius.database_id > 4 -- filter out system tables
AND OBJECTPROPERTY(ddius.object_id, 'IsUserTable') = 1
AND ddius.index_id > 0 -- filter out heaps
ORDER BY ddius.user_scans DESC

-- List unused indexes

SELECT OBJECT_NAME(i.[object_id]) AS [Table Name] ,
i.name
FROM sys.indexes AS i
INNER JOIN sys.objects AS o ON i.[object_id] = o.[object_id]
WHERE i.index_id NOT IN ( SELECT ddius.index_id
FROM sys.dm_db_index_usage_stats AS ddius
WHERE ddius.[object_id] = i.[object_id]
AND i.index_id = ddius.index_id
AND database_id = DB_ID() )
AND o.[type] = 'U'
ORDER BY OBJECT_NAME(i.[object_id]) ASC ;

----------------------------------------------------------------------------


----------------------------------------------------------------------------


----------------------------------------------------------------------------


----------------------------------------------------------------------------


----------------------------------------------------------------------------


----------------------------------------------------------------------------


----------------------------------------------------------------------------


----------------------------------------------------------------------------


----------------------------------------------------------------------------


