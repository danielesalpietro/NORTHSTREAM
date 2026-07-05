"""
NORTHSTREAM data generator
--------------------------
Continuously writes realistic, structured business and IoT events into
Postgres so that Debezium/Kafka/the stream-agent always have fresh,
"quality" stream data to work with.

Two event families:
  - orders            : business/sales events
  - sensor_readings    : operational/IoT events, with occasional anomalies
"""

import os
import random
import time
from datetime import datetime

import psycopg2

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "sales")
DB_USER = os.getenv("DB_USER", "demo")
DB_PASSWORD = os.getenv("DB_PASSWORD", "demo")
INTERVAL_SECONDS = float(os.getenv("INTERVAL_SECONDS", "3"))

CUSTOMERS = ["Acme Corp", "Globex", "Umbrella Inc", "Initech", "Soylent", "Stark Industries"]
PRODUCTS = [
    ("Industrial Pump X200", 4200.00),
    ("Smart Sensor Kit", 890.00),
    ("Cloud Storage Bundle 5TB", 150.00),
    ("Predictive Maintenance License", 2300.00),
    ("Edge Gateway Device", 610.00),
]
REGIONS = ["EMEA", "NA", "APAC", "LATAM"]
SITES = ["Plant-A", "Plant-B", "Warehouse-1", "Warehouse-2", "Line-3"]


def get_conn():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )


def insert_order(cur):
    customer = random.choice(CUSTOMERS)
    product, unit_price = random.choice(PRODUCTS)
    qty = random.randint(1, 20)
    region = random.choice(REGIONS)
    total = round(unit_price * qty, 2)
    cur.execute(
        """
        INSERT INTO orders (customer_name, product_name, quantity, unit_price, total_amount, region, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (customer, product, qty, unit_price, total, region, datetime.utcnow()),
    )
    print(f"[order] {customer} bought {qty}x {product} ({region}) = {total}")


def insert_sensor_reading(cur):
    site = random.choice(SITES)
    temperature = round(random.gauss(65, 8), 2)
    vibration = round(random.gauss(0.5, 0.15), 3)
    # occasionally force a clear anomaly so the demo has something concrete to catch
    if random.random() < 0.08:
        temperature += random.uniform(20, 35)
        vibration += random.uniform(0.4, 0.8)
    is_anomaly = temperature > 85 or vibration > 0.9
    cur.execute(
        """
        INSERT INTO sensor_readings (site, temperature_c, vibration_g, is_anomaly, recorded_at)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (site, temperature, vibration, is_anomaly, datetime.utcnow()),
    )
    tag = "ANOMALY" if is_anomaly else "normal"
    print(f"[sensor] {site} temp={temperature}C vib={vibration}g ({tag})")


def main():
    conn = None
    while conn is None:
        try:
            conn = get_conn()
        except Exception as e:
            print("waiting for postgres...", e)
            time.sleep(3)

    conn.autocommit = True
    cur = conn.cursor()
    print("NORTHSTREAM data generator started")

    while True:
        try:
            if random.random() < 0.5:
                insert_order(cur)
            else:
                insert_sensor_reading(cur)
        except Exception as e:
            print("insert failed, reconnecting:", e)
            try:
                conn = get_conn()
                conn.autocommit = True
                cur = conn.cursor()
            except Exception as e2:
                print("reconnect failed:", e2)
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
