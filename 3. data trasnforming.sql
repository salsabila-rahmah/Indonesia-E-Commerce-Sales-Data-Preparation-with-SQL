--- sqlite3


--- create table FACT orders untuk final data yang di-ekspor
CREATE TABLE IF NOT EXISTS fact_INA_sales AS
SELECT
    order_id,
    order_date_clean AS order_date,
    order_timestamp,
    strftime('%Y', order_date_clean) AS year_order_date,
    strftime('%Y-%m', order_date_clean) AS month_order_date,
    TIME(strftime('%H:%M', order_timestamp)) AS time_order_date,
    category_count,
    qty,
    returned_qty,
    weight_gr,
    order_status,
    cancel_by,
    sub_reason,
    discount,
    payment,
    pay_method,
    payment_segment,
    ship_method,
    ship_fee,
    ship_disc,
    ship_est,
    shipping_category,
    shipping_carrier,
    CAST((ship_fee - ship_disc) AS INTEGER) AS net_shipping,
    city,
    province,
    weight_flag AS flag_weight,
    payment_flag AS flag_payment,
    shipping_flag AS flag_shipping
FROM INA_sales;


--- create table DIM order and product category untuk final data yang di-ekspor
--- only included the order_id where exists in fact_INA_sales
CREATE TABLE IF NOT EXISTS dim_order_category AS
SELECT order_id, product_category
FROM ref_orderid_category
WHERE order_id IN (
    SELECT order_id FROM fact_INA_sales);


--- create table DIM payments untuk final data yang di-ekspor
CREATE TABLE IF NOT EXISTS dim_payments AS
SELECT
    pay_method_new AS pay_method,
    payment_category
FROM ref_payment_category;



--- run in terminal
--- export fact_INA_sales table into fact_INA_orders.csv files
.mode csv
.headers on
.output fact_INA_orders_2.csv 
SELECT * FROM fact_INA_sales;
.output stdout


--- export dim_order_category table into order_category.csv files
.mode csv
.headers on
.output order_category.csv
SELECT * FROM dim_order_category;
.output stdout


--- export dim_payments table into order_category.csv files
.mode csv
.headers on
.output payments.csv
SELECT * FROM dim_payments;
.output stdout