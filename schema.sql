-- =============================================================================
-- E-Commerce Order Management System — Schema DDL
-- Author: Aimal Khan
-- Description: Normalized relational database schema (3NF) for managing
--              customers, products, orders, inventory, payments, and shipments
--              in a multi-vendor e-commerce platform.
-- Database: PostgreSQL
-- =============================================================================

-- Drop tables in reverse dependency order (safe re-run)
DROP TABLE IF EXISTS shipments CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- =============================================================================
-- Core Entities
-- =============================================================================

CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    first_name    VARCHAR(100)        NOT NULL,
    last_name     VARCHAR(100)        NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    phone         VARCHAR(20),
    address_line1 VARCHAR(255),
    city          VARCHAR(100),
    country       VARCHAR(100)        DEFAULT 'Pakistan',
    created_at    TIMESTAMP           DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
    category_id   SERIAL PRIMARY KEY,
    name          VARCHAR(100) UNIQUE NOT NULL,
    parent_id     INT REFERENCES categories(category_id) ON DELETE SET NULL
);

CREATE TABLE warehouses (
    warehouse_id   SERIAL PRIMARY KEY,
    warehouse_name VARCHAR(150)  NOT NULL,
    location       VARCHAR(255),
    capacity       INT           CHECK (capacity > 0)
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    category_id   INT            REFERENCES categories(category_id) ON DELETE SET NULL,
    name          VARCHAR(255)   NOT NULL,
    description   TEXT,
    unit_price    NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    is_active     BOOLEAN        DEFAULT TRUE,
    created_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Orders & Line Items
-- =============================================================================

CREATE TABLE orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INT            NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    order_date    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    total_amount  NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    status        VARCHAR(20)    DEFAULT 'pending',
    CONSTRAINT chk_order_status CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id      INT            NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id    INT            NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity      INT            NOT NULL CHECK (quantity > 0),
    -- Price snapshot: captures price at time of purchase (independent of current product price)
    unit_price    NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    line_total    NUMERIC(12, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

-- =============================================================================
-- Inventory
-- =============================================================================

CREATE TABLE inventory (
    inventory_id  SERIAL PRIMARY KEY,
    product_id    INT  NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id  INT  NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    quantity      INT  NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    last_updated  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, warehouse_id)   -- one record per product per warehouse
);

-- =============================================================================
-- Payments & Shipments
-- =============================================================================

CREATE TABLE payments (
    payment_id     SERIAL PRIMARY KEY,
    order_id       INT            NOT NULL UNIQUE REFERENCES orders(order_id) ON DELETE CASCADE,
    payment_method VARCHAR(50)    NOT NULL,
    amount         NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    status         VARCHAR(20)    DEFAULT 'pending',
    paid_at        TIMESTAMP,
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('credit_card', 'debit_card', 'bank_transfer', 'cash_on_delivery', 'wallet')),
    CONSTRAINT chk_payment_status CHECK (status IN ('pending', 'completed', 'failed', 'refunded'))
);

CREATE TABLE shipments (
    shipment_id     SERIAL PRIMARY KEY,
    order_id        INT          NOT NULL UNIQUE REFERENCES orders(order_id) ON DELETE CASCADE,
    tracking_number VARCHAR(100),
    carrier         VARCHAR(100),
    shipped_at      TIMESTAMP,
    estimated_delivery TIMESTAMP,
    delivered_at    TIMESTAMP,
    status          VARCHAR(20)  DEFAULT 'preparing',
    CONSTRAINT chk_shipment_status CHECK (status IN ('preparing', 'dispatched', 'in_transit', 'delivered', 'returned'))
);

-- =============================================================================
-- Performance Indexes (Foreign Keys + High-Frequency Query Columns)
-- =============================================================================

CREATE INDEX idx_orders_customer_id   ON orders(customer_id);
CREATE INDEX idx_orders_status        ON orders(status);
CREATE INDEX idx_orders_order_date    ON orders(order_date);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product  ON order_items(product_id);
CREATE INDEX idx_inventory_product    ON inventory(product_id);
CREATE INDEX idx_inventory_warehouse  ON inventory(warehouse_id);
CREATE INDEX idx_products_category    ON products(category_id);

-- =============================================================================
-- Sample Analytical Queries
-- =============================================================================

-- Q1: Order summary with customer details (last 30 days)
-- SELECT o.order_id, c.first_name || ' ' || c.last_name AS customer_name,
--        o.order_date, o.total_amount, o.status
-- FROM orders o
-- JOIN customers c ON o.customer_id = c.customer_id
-- WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
-- ORDER BY o.order_date DESC;

-- Q2: Low stock alert (quantity below threshold)
-- SELECT p.name AS product_name, w.warehouse_name, i.quantity
-- FROM inventory i
-- JOIN products p ON i.product_id = p.product_id
-- JOIN warehouses w ON i.warehouse_id = w.warehouse_id
-- WHERE i.quantity < 10
-- ORDER BY i.quantity ASC;

-- Q3: Revenue by product category
-- SELECT c.name AS category, SUM(oi.line_total) AS total_revenue
-- FROM order_items oi
-- JOIN products p ON oi.product_id = p.product_id
-- JOIN categories c ON p.category_id = c.category_id
-- JOIN orders o ON oi.order_id = o.order_id
-- WHERE o.status = 'delivered'
-- GROUP BY c.name
-- ORDER BY total_revenue DESC;
