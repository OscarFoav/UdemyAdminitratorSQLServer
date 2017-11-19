--truncate table numbers
--select * from numbers

--verify backup and recovery mode to full then set AG


create database rep7
go


use rep7
go

create table numbers
(num int)

insert into numbers  
values (1000)
go 1000


--on secondary replica. Run this command or create a job

BACKUP DATABASE [rep7] 
TO  DISK = N'C:\backup 777\fullbackup777.bak' 
WITH  COPY_ONLY,    --<< backups on secondary replicas occurs only if you set this option (must be copy_only)
NOFORMAT, 
NOINIT,  
NAME = N'rep7-Full Database Backup'
GO


