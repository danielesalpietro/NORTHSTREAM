-- NORTHSTREAM sample operational schema
-- Two tables designed to produce meaningful, "chattable" stream events:
--   orders           -> business events (sales)
--   sensor_readings   -> IoT/operational events (with anomaly flag)

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    region TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sensor_readings (
    id SERIAL PRIMARY KEY,
    site TEXT NOT NULL,
    temperature_c NUMERIC(6,2) NOT NULL,
    vibration_g NUMERIC(6,3) NOT NULL,
    is_anomaly BOOLEAN NOT NULL DEFAULT false,
    recorded_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Debezium/logical replication requires full row images for UPDATE/DELETE
ALTER TABLE orders REPLICA IDENTITY FULL;
ALTER TABLE sensor_readings REPLICA IDENTITY FULL;

-- Seed a few rows so the demo has something to query even before the
-- data-generator produces new events
INSERT INTO orders (customer_name, product_name, quantity, unit_price, total_amount, region)
VALUES
 ('Acme Corp', 'Industrial Pump X200', 3, 4200.00, 12600.00, 'EMEA'),
 ('Globex', 'Smart Sensor Kit', 10, 890.00, 8900.00, 'NA');

INSERT INTO sensor_readings (site, temperature_c, vibration_g, is_anomaly)
VALUES
 ('Plant-A', 64.5, 0.42, false),
 ('Plant-B', 88.9, 0.95, true);
