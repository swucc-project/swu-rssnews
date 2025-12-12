USE master;
GO

-- ตรวจสอบและแสดงข้อมูล Collation
PRINT '==================================================';
PRINT 'Current Server Collation: ' + CAST(SERVERPROPERTY('Collation') AS NVARCHAR(128));
PRINT '==================================================';
PRINT '';

-- สร้าง Database
IF NOT EXISTS (
   SELECT name
   FROM sys.databases
   WHERE name = N'RSSActivityWeb'
)
BEGIN
    PRINT '📦 Creating database [RSSActivityWeb]...';
    CREATE DATABASE [RSSActivityWeb] COLLATE Thai_CI_AS;
    PRINT '✅ Database [RSSActivityWeb] created successfully';
END
ELSE
BEGIN
    PRINT '✅ Database [RSSActivityWeb] already exists';
END
GO

-- รอให้ database พร้อม
WAITFOR DELAY '00:00:02';
GO

-- เปลี่ยนไปใช้ database
PRINT '';
PRINT '🔄 Switching to database [RSSActivityWeb]...';
USE [RSSActivityWeb];
GO

-- ตรวจสอบว่าเข้าถึงได้
DECLARE @CurrentDB NVARCHAR(128) = DB_NAME();
DECLARE @Collation NVARCHAR(128) = CAST(DATABASEPROPERTYEX(@CurrentDB, 'Collation') AS NVARCHAR(128));

PRINT '';
PRINT '==================================================';
PRINT 'Current Database: ' + @CurrentDB;
PRINT 'Database Collation: ' + @Collation;
PRINT '==================================================';
PRINT '';
PRINT '✅ Database setup completed successfully!';
GO