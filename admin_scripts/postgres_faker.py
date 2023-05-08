from faker import Faker
import psycopg2
import datetime
import random

fake = Faker()
conn = psycopg2.connect(
    host="host",
    database="tplake",
    user="postgres",
    password="postgres"
)

cursor = conn.cursor()

start_date = datetime.date(2015, 1, 1)
end_date = datetime.date(2023, 1, 1)
delta = end_date - start_date

# Populate customers table
for _ in range(100):
    registration_datetime = start_date + datetime.timedelta(days=random.randint(0, delta.days))
    cursor.execute(
        "INSERT INTO customers (name, address, phone, email, registration_datetime) VALUES (%s, %s, %s, %s, %s)",
        (fake.name(), fake.address(), fake.phone_number(), fake.email(), registration_datetime)
    )
conn.commit()

# Populate bank_accounts table
cursor.execute("SELECT id FROM customers")
customers = cursor.fetchall()
for customer in customers:
    cursor.execute(
        "INSERT INTO bank_accounts (account_number, customer_id) VALUES (%s, %s)",
        (fake.uuid4(), customer[0])
    )
conn.commit()

# Populate transactions table
cursor.execute("SELECT account_number FROM bank_accounts")
bank_accounts = cursor.fetchall()
for account in bank_accounts:
    cursor.execute(
        "INSERT INTO transactions (account_number, type, amount, description) VALUES (%s, %s, %s, %s)",
        (account[0], fake.random_element(["deposit", "withdrawal"]), fake.random_number(10, 1000), fake.sentence())
    )
conn.commit()

# Populate account_activity_log table
activity_types = ["login", "view_balance", "transfer_funds", "update_profile"]
cursor.execute("SELECT account_number, customer_id FROM bank_accounts")
account_customer_pairs = cursor.fetchall()
for account_number, customer_id in account_customer_pairs:
    activity_timestamp = start_date + datetime.timedelta(days=random.randint(0, delta.days))
    cursor.execute(
        "INSERT INTO account_activity_log (account_number, customer_id, activity_type, activity_timestamp, description) VALUES (%s, %s, %s, %s, %s)",
        (account_number, customer_id, fake.random_element(activity_types), activity_timestamp, fake.sentence())
    )
conn.commit()

cursor.close()
conn.close()
