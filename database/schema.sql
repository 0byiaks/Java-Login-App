-- ============================================
-- Java Login App Database Schema
-- Database: UserDB
-- ============================================

-- Create Database (if not exists)
CREATE DATABASE IF NOT EXISTS UserDB;

-- Use the database
USE UserDB;

-- Create Employee Table
CREATE TABLE IF NOT EXISTS Employee (
  id int unsigned auto_increment not null,
  first_name varchar(250),
  last_name varchar(250),
  email varchar(250),
  username varchar(250),
  password varchar(250),
  regdate timestamp,
  primary key (id)
);

-- Verify table creation
SHOW TABLES;

-- Display table structure
DESCRIBE Employee;

