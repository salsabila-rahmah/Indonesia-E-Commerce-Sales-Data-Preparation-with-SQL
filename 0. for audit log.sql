--- sqlite3


--- create table audit_log untuk record semua anomali data 
CREATE TABLE IF NOT EXISTS audit_log (
    log_id INTEGER PRIMARY KEY,
    logged_at DATETIME DEFAULT (DATETIME(CURRENT_TIMESTAMP, '+7 hours')),
    order_id TEXT,
    attribute TEXT,
    reason TEXT,
    solution TEXT,
    source_table TEXT,
    total_rows INTEGER,
    problematic_rows INTEGER,
    UNIQUE(order_id, attribute, reason, source_table) );


--- create table BACKUP_audit_log untuk backup tabel audit_log
CREATE TABLE IF NOT EXISTS BACKUP_audit_log (
    log_id INTEGER PRIMARY KEY,
    logged_at DATETIME DEFAULT (DATETIME(CURRENT_TIMESTAMP, '+7 hours')),
    order_id TEXT,
    attribute TEXT,
    reason TEXT,
    solution TEXT,
    source_table TEXT,
    total_rows INTEGER,
    problematic_rows INTEGER,
    UNIQUE(order_id, attribute, reason, source_table) );


--- create trigger for automate input ke BACKUP_audit_log table
--- trigger activated after every INSERT on the audit_log table 
CREATE TRIGGER trigger_insert_to_BACKUP_audit_log
AFTER INSERT ON audit_log
BEGIN
    INSERT INTO BACKUP_audit_log (
        log_id,
        logged_at,
        order_id,
        attribute,
        reason,
        solution,
        source_table,
        total_rows,
        problematic_rows)
    VALUES (
        NEW.log_id,
        NEW.logged_at,
        NEW.order_id,
        NEW.attribute,
        NEW.reason,
        NEW.solution,
        NEW.source_table,
        NEW.total_rows,
        NEW.problematic_rows);
END;




-------------------- INSERT PROBLEMATIC DATA ---------------


--- INSERT LOG: deleting duplicate rows based on all columns (kecuali order_id)
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT 
    order_id,
    'ALL Column (kecuali order_id)',
    'Duplicate rows',
    'Delete',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY
    qty, weight_gr, returned_qty, discount, product_categories, 
    category_count, order_status, cancel_reason, ship_method, 
    pay_method, city, province, ship_fee, ship_disc, payment, 
    ship_est, order_timestamp, order_date
HAVING problematic_rows > 1
ORDER BY order_id;


--- INSERT LOG: deleting blank rows of qty
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT 
    order_id,
    'qty',
    'Blank qty',
    'Delete',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
HAVING qty = ''
ORDER BY order_id;



--- INSERT LOG: deleting blank rows of pay_method
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT 
    order_id,
    'pay_method',
    'Blank pay_method',
    'Delete',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
HAVING pay_method = ''
ORDER BY order_id;


--- INSERT LOG: Rearrange invalid order_date dan query data tanggal dari order_timestamp
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT
    order_id,
    'order_date',
    'Invalid data tanggal (wrong format DD/MM/YYYY, blank rows, abnormal date)',
    'Rearrange invalid order_date dan query data tanggal dari order_timestamp',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
HAVING DATE(order_date) IS NULL
ORDER BY order_id;


--- INSERT LOG: Rename data "Pesanan diterima, namun...." --> "Pesanan Diterima"
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'order_status',
    'Pengkategorian order_status belum seragam (uniform)',
    'Rename data "Pesanan diterima, namun...." --> "Pesanan Diterima"',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
HAVING order_status LIKE '%Pesanan diterima, namun Pembeli masih dapat mengajukan pengembalian%'
ORDER BY order_id;



--- INSERT LOG: Rename data ship_method dengan external resource (ref_ship_method_category)
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'ship_method',
    'Pengkategorian ship_method belum seragam (uniform)',
    'Update data ship_method menggunakan external resource cleaned (ref_ship_method_category)',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
ORDER BY order_id;



--- INSERT LOG: Rename data pay_method dengan external resource (ref_payment_category)
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'pay_method',
    'Penamaan pay_method belum seragam (uniform)',
    'Update data pay_method menggunakan external resource cleaned (ref_payment_category)',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
ORDER BY order_id;



--- INSERT LOG: Rename data province dengan external resource (ref_prov_city)
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id, 
    'province',
    'Penamaan province belum sesuai standar',
    'Rename data province sesuai standar menggunakan external resource cleaned (ref_prov_city)',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
ORDER BY order_id;



--- INSERT LOG: Rename data city dengan external resource (ref_prov_city)
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id, 
    'city',
    'Penamaan city belum sesuai standar',
    'Rename data city sesuai standar menggunakan external resource cleaned (ref_prov_city)',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY order_id
ORDER BY order_id;



--- INSERT LOG: deleting duplicate rows based on all columns (kecuali order_id)
--- menggunakan order_date_clean instead od order_date
--- tabel raw_INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT 
    order_id,
    'ALL Column (kecuali order_id)',
    'Duplicate rows',
    'Delete',
    'raw_INA_sales',
    (SELECT count(order_id) FROM raw_INA_sales),
    count(order_id) AS problematic_rows
FROM raw_INA_sales
GROUP BY
    qty, weight_gr, returned_qty, discount, product_categories, 
    category_count, order_status, cancel_reason, ship_method, 
    pay_method, city, province, ship_fee, ship_disc, payment, 
    ship_est, order_timestamp, order_date_clean
HAVING problematic_rows > 1
ORDER BY order_id;



--- INSERT LOG: deleting invalid zero payment
--- tabel INA_sales
WITH valid_zero_payment AS (
    SELECT * FROM INA_sales
    WHERE payment = 0 AND order_status = 'Batal'
    UNION
    SELECT * FROM INA_sales
    WHERE payment = 0 AND pay_method = 'Free (No Payment)')
INSERT INTO audit_log 
    (order_id,
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'payment',
    'Invalid zero payment',
    'Delete invalid zero payment',
    'INA_sales',
    (SELECT count(order_id) FROM INA_sales),
    count(order_id) AS problematic_rows
FROM INA_sales
GROUP BY order_id
HAVING 
    payment = 0 AND 
    order_id NOT IN (
        SELECT order_id FROM valid_zero_payment)
ORDER BY order_id;


--- INSERT LOG: deleting invalid ship_disc dan ship_est
--- tabel INA_sales
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'ship_disc, ship_est',
    'Invalid ship_disc dan ship_est',
    'Delete invalid ship_disc dan ship_est',
    'INA_sales',
    (SELECT count(order_id) FROM INA_sales),
    count(order_id) AS problematic_rows
FROM INA_sales
GROUP BY order_id
HAVING order_id NOT IN (
    SELECT order_id FROM INA_sales
    WHERE ship_disc <= ship_est)
ORDER BY order_id;



--- INSERT LOG: flagging weight_gr, qty, shipping_category outliers
--- tabel INA_sales
WITH flagging_weight AS (
    SELECT
        order_id,
        (CASE 
            WHEN (weight_gr * 1.0 / qty) > 20000 AND qty < 10
                THEN 'Invalid_Per_Item_Too_Heavy'
            WHEN shipping_category = 'Instant' AND weight_gr > 100000
                THEN 'Invalid_Instant_Too_Heavy'
            WHEN (weight_gr * 1.0 / qty) > 10000 AND qty < 10
                THEN 'Suspicious_Per_Item_Heavy'
            WHEN shipping_category IN ('Instant', 'Same Day') AND weight_gr > 50000
                THEN 'Suspicious_Fast_Shipping_Heavy'
            ELSE 'Normal'
        END) AS weight_flag
    FROM INA_sales)
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'weight_gr, qty, shipping_category',
    (SELECT weight_flag FROM flagging_weight 
        WHERE INA_sales.order_id = flagging_weight.order_id),
    'flagging weight',
    'INA_sales',
    (SELECT count(order_id) FROM INA_sales),
    count(order_id) AS problematic_rows
FROM INA_sales
GROUP BY order_id
HAVING order_id IN (
    SELECT order_id FROM flagging_weight
    WHERE weight_flag <> 'Normal')
ORDER BY order_id;



--- INSERT LOG: flagging high value payment
--- tabel INA_sales
WITH flagging_payment AS (
    SELECT
        order_id,
        (CASE 
            WHEN payment > 100000 AND qty <= 2 AND product_categories NOT LIKE '%Seal / Baut / Roof%'
                THEN 'Suspicious_High_Value_Low_Qty'
            WHEN payment > 100000 AND product_categories LIKE '%Seal / Baut / Roof%'
                THEN 'High_Value_Heavy_Category'
            WHEN payment > 100000 AND qty >= 10
                THEN 'High_Value_Bulk'
            WHEN payment > 100000
                THEN 'High_Value'
            ELSE 'Normal'
        END) AS payment_flag
    FROM INA_sales)
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'payment',
    (SELECT payment_flag FROM flagging_payment 
        WHERE INA_sales.order_id = flagging_payment.order_id),
    'flagging payment',
    'INA_sales',
    (SELECT count(order_id) FROM INA_sales),
    count(order_id) AS problematic_rows
FROM INA_sales
GROUP BY order_id
HAVING order_id IN (
    SELECT order_id FROM flagging_payment
    WHERE payment_flag <> 'Normal')
ORDER BY order_id;



--- INSERT LOG: flagging selisih ship_fee dan ship_est outliers
--- tabel INA_sales
WITH flagging_shipping AS (
    SELECT
        order_id,
        ABS(ship_fee - ship_est) AS selisih,
        (CASE 
            WHEN ABS(ship_fee - ship_est) > 30000
                AND ABS(ship_fee - ship_est) * 1.0 / ship_est > 0.5
                THEN 'Outlier'
            WHEN ABS((ship_est - ship_disc) - ship_fee) > 15000
                THEN 'Suspicious'
            ELSE 'Normal'
        END) AS shipping_flag
    FROM INA_sales)
INSERT INTO audit_log 
    (order_id, 
    attribute, 
    reason, 
    solution, 
    source_table, 
    total_rows,
    problematic_rows)
SELECT  
    order_id,
    'ship_fee, ship_est',
    (SELECT shipping_flag FROM flagging_shipping 
        WHERE INA_sales.order_id = flagging_shipping.order_id),
    'flagging shipping',
    'INA_sales',
    (SELECT count(order_id) FROM INA_sales),
    count(order_id) AS problematic_rows
FROM INA_sales
GROUP BY order_id
HAVING order_id IN (
    SELECT order_id FROM flagging_shipping
    WHERE shipping_flag <> 'Normal')
ORDER BY order_id;
