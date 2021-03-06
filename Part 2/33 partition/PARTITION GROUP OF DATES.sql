
BACKUP DATABASE

BACKUP DATABASE [AdventureWorks2012] 
TO  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\ADVENTUREWORKS2012.BAK' 
WITH  COPY_ONLY, 
NOFORMAT, 
NOINIT,  
NAME = N'AdventureWorks2012-Full Database Backup', 
SKIP, 
NOREWIND, 
NOUNLOAD,  
STATS = 10
GO


--USE SQL2
--GO

--SELECT * FROM [dbo].[People2]--1000

--SELECT * FROM [dbo].[People3] -- 10,000,000  --2 MIN 10 SECS

--SELECT * FROM [dbo].[People] -- 100,000,000  --LONGER THAN 10,000,000


--DROP DATABASE
use master
go

DROP DATABASE AdventureWorks2012
GO

--RESTORE DATABASE

USE [master]
RESTORE DATABASE [AdventureWorks2012] 
FROM  DISK = N'C:\backup122215\Database backups\ADVENTUREWORKS2012.BAK' 
WITH  FILE = 1,  
MOVE N'AdventureWorks2012_Data' 
TO N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\AdventureWorks2012_Data.mdf',  
MOVE N'AdventureWorks2012_Log' 
TO N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\AdventureWorks2012_log.ldf',  
NOUNLOAD,  
STATS = 5
GO

---- row count

SELECT COUNT(*) AS Total_Rows
FROM AdventureWorks2012.Production.TransactionHistoryArchive

----89253

----Find distinct datetime per year so as to partition

SELECT DISTINCT YEAR(TransactionDate) AS Year, COUNT(*) AS Total_Rows
FROM  AdventureWorks2012.Production.TransactionHistoryArchive
GROUP BY YEAR(TransactionDate)
ORDER BY 1

--1: Before creating the file groups, create 4 seperate folders
--on drive C: to represent 'physical drives' (drive d, drive e, drive f, drive g)

----Create 4 file groups for each year - 2005, 2006, 2007 and all data not in first three partitions
--1 ADD FILEGROUPS FOR EACH YEAR PARTITION

USE [master]
GO

ALTER DATABASE [AdventureWorks2012] 
ADD FILEGROUP [DRIVE D]
GO

ALTER DATABASE [AdventureWorks2012] 
ADD FILEGROUP [DRIVE D]
GO

ALTER DATABASE [AdventureWorks2012] 
ADD FILEGROUP [DRIVE F]
GO

ALTER DATABASE [AdventureWorks2012] 
ADD FILEGROUP [DRIVE G]
GO


----With in those four folders (drives d, drive e, drive f, drive g), create 4 seperate data files (.ndf) 
----for each year in the table


---- Create a partition function for each year range (note no table has been assigned to any partition as of yet)
----thus, you can associate any table to the partition at this point


USE AdventureWorks2012
GO

SELECT o.name objectname,i.name indexname, partition_id, partition_number, [rows]
FROM sys.partitions p
INNER JOIN sys.objects o ON o.object_id=p.object_id
INNER JOIN sys.indexes i ON i.object_id=p.object_id and p.index_id=i.index_id
WHERE o.name LIKE '%TransactionHistoryArchive%'

SELECT DISTINCT YEAR(TransactionDate) AS Year, COUNT(*) AS Total_Rows
FROM  AdventureWorks2012.Production.TransactionHistoryArchive
GROUP BY YEAR(TransactionDate)
ORDER BY 1


USE [AdventureWorks2012]
GO

--2: CREATE 4 DATA (NDF)FILES IN FILEGROUP FOR EACH PARTITION

USE [master]
GO
ALTER DATABASE [AdventureWorks2012] 
ADD FILE ( NAME = N'TRANS2005', 
FILENAME = N'C:\drive d\TRANS2005.ndf' , 
SIZE = 4096KB , 
FILEGROWTH = 1024KB ) 
TO FILEGROUP [DRIVE D]
GO

ALTER DATABASE [AdventureWorks2012] 
ADD FILE ( NAME = N'TRANS2006', 
FILENAME = N'C:\drive e\TRANS2006.ndf' , 
SIZE = 4096KB , 
FILEGROWTH = 1024KB ) 
TO FILEGROUP [DRIVE E]
GO

ALTER DATABASE [AdventureWorks2012] 
ADD FILE ( NAME = N'TRANS2007', 
FILENAME = N'C:\drive f\TRANS2007.ndf' , 
SIZE = 4096KB , 
FILEGROWTH = 1024KB ) 
TO FILEGROUP [DRIVE F]
GO

ALTER DATABASE [AdventureWorks2012] 
ADD FILE ( NAME = N'TRANS2015', 
FILENAME = N'C:\drive g\TRANS2015.ndf' , 
SIZE = 4096KB , 
FILEGROWTH = 1024KB ) 
TO FILEGROUP [DRIVE G]
GO

--AT THIS POINT WE HAVE CREATED THE 'CONTAINERS' AND FILES FOR THE TABLE TO BE PARTITIONED TOO!!

-- CREATE PARTITION ON TABLE [TransactionHistoryArchive]

USE [AdventureWorks2012]
GO

BEGIN TRANSACTION

CREATE PARTITION FUNCTION [FUNCTION_TRANSHISTORY](datetime) 
AS RANGE LEFT 
FOR VALUES (N'2005-12-31T23:59:59.997', N'2006-12-31T23:59:59.997', N'2007-12-31T23:59:59.997')


CREATE PARTITION SCHEME [SCHEMA_TRANSHISTORY] 
AS PARTITION [FUNCTION_TRANSHISTORY] 
TO ([DRIVE D], [DRIVE E], [DRIVE F], [drive g])


ALTER TABLE [Production].[TransactionHistoryArchive] DROP CONSTRAINT [PK_TransactionHistoryArchive_TransactionID]

ALTER TABLE [Production].[TransactionHistoryArchive] ADD  CONSTRAINT [PK_TransactionHistoryArchive_TransactionID] PRIMARY KEY NONCLUSTERED 
([TransactionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)


CREATE CLUSTERED INDEX [ClusteredIndex_on_SCHEMA_TRANSHISTORY_635922165997540276] ON [Production].[TransactionHistoryArchive]
([TransactionDate]
)WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [SCHEMA_TRANSHISTORY]([TransactionDate])

DROP INDEX [ClusteredIndex_on_SCHEMA_TRANSHISTORY_635922165997540276] ON [Production].[TransactionHistoryArchive]

COMMIT TRANSACTION

--VERIFY

USE AdventureWorks2012
GO

SELECT o.name objectname,i.name indexname, partition_id, partition_number, [rows]
FROM sys.partitions p
INNER JOIN sys.objects o ON o.object_id=p.object_id
INNER JOIN sys.indexes i ON i.object_id=p.object_id and p.index_id=i.index_id
WHERE o.name LIKE '%TransactionHistoryArchive%'


-- INSERT DATA TO VERIFY DIRECTION OF DATA TO PARTITION

USE [AdventureWorks2012]
GO

INSERT INTO [Production].[TransactionHistoryArchive]
           ([TransactionID]
           ,[ProductID]
           ,[ReferenceOrderID]
           ,[ReferenceOrderLineID]
           ,[TransactionDate]
           ,[TransactionType]
           ,[Quantity]
           ,[ActualCost]
           ,[ModifiedDate])
VALUES
(89265,	1,1,1,'2016-03-04 00:00:00.000','P',999,50.2600,'2016-03-04  00:00:00.000')
GO


--VIEW ACTULA DATA IN THE PARTITION

SELECT * FROM [Production].[TransactionHistoryArchive]
WHERE $PARTITION.[FUNCTION_TRANSHISTORY](TransactionDate) = 4 ;--<< PARTITION 4 CONTAIN ONLY DATA THAT IS NOT IN RANGE OF PARTITION 1,2,3


