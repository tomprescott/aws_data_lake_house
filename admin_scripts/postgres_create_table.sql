CREATE TABLE customers (
    id serial PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    registration_datetime TIMESTAMP NOT NULL
);

CREATE TABLE bank_accounts (
    id serial PRIMARY KEY,
    account_number VARCHAR(50) UNIQUE,
    balance NUMERIC(15,2) NOT NULL DEFAULT 0,
    customer_id INTEGER REFERENCES customers(id)
);

CREATE TABLE transactions (
    id serial PRIMARY KEY,
    account_number VARCHAR(50) REFERENCES bank_accounts(account_number),
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    type VARCHAR(255) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    description VARCHAR(255)
);

CREATE TABLE account_activity_log (
    id serial PRIMARY KEY,
    account_number VARCHAR(50) REFERENCES bank_accounts(account_number),
    customer_id INTEGER REFERENCES customers(id),
    activity_type VARCHAR(100) NOT NULL,
    activity_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    description VARCHAR(255)
);

