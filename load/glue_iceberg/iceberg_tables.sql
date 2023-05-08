-- Create customers input table
CREATE EXTERNAL TABLE iceberg_demo.customers_input(
  op string, 
  id int,
  name string,
  address string,
  phone string,
  email string,
  registration_datetime timestamp,
  cdc_timestamp timestamp, 
  cdc_operation string) 
STORED AS PARQUET
LOCATION 's3://tp-lake-dev-bronze/dms-data/public/customers/'
TBLPROPERTIES (
  'has_encrypted_data'='false'
);

-- create customers output table
create table iceberg_demo.customers_output (
  id int,
  name string,
  address string,
  phone string,
  email string,
  registration_datetime timestamp) 
partitioned by (bucket(16, id)) 
location 's3://tp-lake-dev-silver/iceberg/customers/'
tblproperties (
  'table_type'='iceberg',
  'format'='parquet',
  'write_target_data_file_size_bytes'='536870912'
);

-- Create bank_accounts input table
CREATE EXTERNAL TABLE iceberg_demo.bank_accounts_input(
  op string,
  id int,
  account_number string,
  balance double,
  customer_id int,
  cdc_timestamp timestamp,
  cdc_operation string)
STORED AS PARQUET
LOCATION 's3://tp-lake-dev-bronze/dms-data/public/bank_accounts/'
TBLPROPERTIES (
  'has_encrypted_data'='false'
);

-- Create bank_accounts output table
CREATE TABLE iceberg_demo.bank_accounts_output (
  id int,
  account_number string,
  balance double,
  customer_id int)
PARTITIONED BY (bucket(16, customer_id)) 
LOCATION 's3://tp-lake-dev-silver/iceberg/bank_accounts/'
TBLPROPERTIES (
  'table_type'='ICEBERG',
  'format'='parquet',
  'write_target_data_file_size_bytes'='536870912'
);

-- Create transactions input table
CREATE EXTERNAL TABLE iceberg_demo.transactions_input(
  op string,
  id int,
  account_number string,
  date timestamp,
  type string,
  amount double,
  description string,
  cdc_timestamp timestamp,
  cdc_operation string)
STORED AS PARQUET
LOCATION 's3://tp-lake-dev-bronze/dms-data/public/transactions/'
TBLPROPERTIES (
  'has_encrypted_data'='false'
);

-- Create transactions output table
CREATE TABLE iceberg_demo.transactions_output (
  id int,
  account_number string,
  date timestamp,
  type string,
  amount double,
  description string)
PARTITIONED BY (bucket(16, id)) 
LOCATION 's3://tp-lake-dev-silver/iceberg/transactions/'
TBLPROPERTIES (
  'table_type'='ICEBERG',
  'format'='parquet',
  'write_target_data_file_size_bytes'='536870912'
);

