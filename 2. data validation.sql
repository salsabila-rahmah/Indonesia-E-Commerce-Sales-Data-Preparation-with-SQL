--- sqlite3


--- create new table (INA_sales) with proper data type for all columns
CREATE TABLE IF NOT EXISTS INA_sales (
    order_id 
        TEXT NOT NULL
        PRIMARY KEY
        CHECK (length(order_id) = 11),
    qty 
        INTEGER
        NOT NULL
        CHECK (qty > 0),
    weight_gr 
        INTEGER
        NOT NULL
        CHECK (weight_gr > 0),
    returned_qty 
        INTEGER
        NOT NULL
        CHECK (returned_qty >= 0),
    discount 
        INTEGER
        NOT NULL
        CHECK (discount >= 0),
    product_categories 
        TEXT
        NOT NULL,
    category_count 
        INTEGER
        NOT NULL
        CHECK (category_count > 0),
    order_status 
        TEXT
        NOT NULL,
    cancel_reason 
        TEXT
        NOT NULL,
    ship_method 
        TEXT
        NOT NULL,
    pay_method 
        TEXT
        NOT NULL,
    city 
        TEXT
        NOT NULL,
    province 
        TEXT
        NOT NULL,
    ship_fee 
        INTEGER
        NOT NULL
        CHECK (ship_fee >= 0),
    ship_disc 
        INTEGER
        NOT NULL
        CHECK (ship_disc >= 0),
    payment 
        INTEGER
        NOT NULL
        CHECK (payment >= 0),
    ship_est 
        INTEGER
        NOT NULL
        CHECK (ship_est >= 0),
    order_timestamp 
        DATETIME
        CHECK (order_timestamp GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]*' 
        AND DATETIME(order_timestamp) IS NOT NULL),
    order_date_clean 
        DATE -- cek format 
        CHECK (order_date_clean GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' 
        AND DATE(order_date_clean) IS NOT NULL) );


--- insert data into table INA_sales
INSERT INTO INA_sales
SELECT 
    TRIM(order_id),
    CAST(NULLIF(qty, '') AS INTEGER),
    CAST(NULLIF(weight_gr, '') AS INTEGER),
    CAST(NULLIF(returned_qty, '') AS INTEGER),
    CAST(NULLIF(discount, '') AS INTEGER),
    TRIM(product_categories),
    CAST(NULLIF(category_count, '') AS INTEGER),
    TRIM(order_status),
    TRIM(cancel_reason),
    TRIM(ship_method),
    TRIM(pay_method),
    TRIM(city),
    TRIM(province),
    CAST(NULLIF(ship_fee, '') AS INTEGER),
    CAST(NULLIF(ship_disc, '') AS INTEGER),
    CAST(NULLIF(payment, '') AS INTEGER),
    CAST(NULLIF(ship_est, '') AS INTEGER),
    DATETIME(TRIM(order_timestamp)),
    DATE(TRIM(order_date_clean))
FROM raw_INA_sales;



---------------------------------------------------------------------------------------
---- create dan insert to tabel BACKUP_INA_sales menggunakan query seperti di atas ----
---------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------
---------------------------------- DATA VALIDATING ------------------------------------
---------------------------------------------------------------------------------------


--- cek uniqueness of order_id 
--- (UNIQUE data --> total seluruh data = total distinct data)
--- OK
SELECT 
    count(*) AS total_data,
    count(DISTINCT order_id) AS total_order_id,
    (CASE 
        WHEN count(*) = count(DISTINCT order_id) THEN 'Unique'
        ELSE 'Not Unique'
    END) AS status_order_id
FROM INA_sales;


--- pengkategorian ship_method ke shipping_category
ALTER Table INA_sales ADD COLUMN shipping_category TEXT;
UPDATE INA_sales
SET shipping_category = (
    SELECT shipping_category
    FROM ref_ship_method_category
    WHERE INA_sales.ship_method = ref_ship_method_category.ship_method_new);


--- pengkategorian ship_method ke shipping_carrier (jasa pengiriman)
ALTER Table INA_sales ADD COLUMN shipping_carrier TEXT;
UPDATE INA_sales
SET shipping_carrier = (
    SELECT shipping_carrier
    FROM ref_ship_method_category
    WHERE INA_sales.ship_method = ref_ship_method_category.ship_method_new);


--- pengkategorian cancel_reason ke cancel_by (dan sub_reason)
ALTER Table INA_sales ADD COLUMN cancel_by TEXT;
UPDATE INA_sales
SET cancel_by = (
    SELECT cancel_by
    FROM ref_cancel_status
    WHERE INA_sales.cancel_reason = ref_cancel_status.cancel_reason);


--- pengkategorian cancel_reason ke sub_reason
ALTER Table INA_sales ADD COLUMN sub_reason TEXT;
UPDATE INA_sales
SET sub_reason = (
    SELECT reason
    FROM ref_cancel_status
    WHERE INA_sales.cancel_reason = ref_cancel_status.cancel_reason);


--- cek duplikat order berdasarkan city, order_timestamp, qty, payment sama
--- OK
SELECT 
    INA_sales.*,
    count(*) AS jumlah_data 
FROM INA_sales
GROUP BY qty, city, payment, order_timestamp
HAVING jumlah_data > 1;


--- cek returned yang lebih besar dari qty
--- (returned_qty harus lebih kecil atau sama dengan qty)
--- OK
SELECT 
    returned_qty, 
    qty
FROM INA_sales
WHERE returned_qty > qty;


--- cek potential outliers untuk berat paket per-qty 
--- (1 qty > 10 potensial outliers)
--- dengan filter qty < 10 dan berat/item > 20 kg --> potential outlier
--- NOT OK (OK)
SELECT
    product_categories,
    ((weight_gr/1000.0) / qty) AS per_item_kg,
    (weight_gr/1000.0) AS weight_kg,
    qty
FROM INA_sales
WHERE qty < 10 AND per_item_kg > 10
ORDER BY product_categories, per_item_kg;


--- weight besar tapi pakai instant --> outliers
--- (max. weight pengiriman instant/same day umumnya 50 kg )
--- NOT OK (OK)
SELECT
    ship_method,
    shipping_carrier,
    round(weight_gr/1000.0, 3) AS weight_kg
FROM INA_sales
WHERE 
    weight_kg > 50 AND 
    shipping_category IN ('Instant', 'Same Day');


--- flagging weight outliers
ALTER TABLE INA_sales ADD COLUMN weight_flag TEXT;
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
UPDATE INA_sales
SET weight_flag = (
    SELECT weight_flag FROM flagging_weight
    WHERE 
        INA_sales.order_id = flagging_weight.order_id);


--- cek pay_method = 'Free (No Payment)', tapi payment > 0
--- (payment = 0 dan pay_method = Free (No Payment) --> OK)
--- OK
SELECT DISTINCT pay_method, payment
FROM INA_sales
WHERE pay_method = 'Free (No Payment)' AND payment > 0;


--- cek payment = 0
--- (payment = 0 dan order_status = batal --> OK)
--- (payment = 0 dan pay_method = 'Free (No Payment)' --> OK)
--- (selain itu payment = 0 dianggap outliers)
--- NOT OK (OK)
WITH valid_zero_payment AS (
    SELECT * FROM INA_sales WHERE payment = 0 AND order_status = 'Batal'
    UNION
    SELECT * FROM INA_sales WHERE payment = 0 AND pay_method = 'Free (No Payment)')
SELECT
    order_id,
    order_status,
    pay_method,
    payment
FROM INA_sales
WHERE
    payment = 0 AND order_id NOT IN (
    SELECT order_id FROM valid_zero_payment);

--- DELETE invalid zero payment
WITH valid_zero_payment AS (
    SELECT * FROM INA_sales
    WHERE payment = 0 AND order_status = 'Batal'
    UNION
    SELECT * FROM INA_sales
    WHERE payment = 0 AND pay_method = 'Free (No Payment)')
DELETE FROM INA_sales
WHERE
    payment = 0 AND order_id NOT IN (
    SELECT order_id FROM valid_zero_payment);


--- cek order_status, payment, pay_method
--- COD_1 --> COD, selesai/diterima, payment = 0 (problem)
--- COD_2 --> COD, batal, payment > 0 (problem)
--- COD_3 --> COD, selesai/diterima, payment > 0 (valid)
--- COD_4 dan COD_5 --> COD, masih dikirim, payment boleh 0 atau >0 (valid)
--- COD_6 --> COD, batal, payment = 0 (valid)
--- COD_7 --> others COD (kalau ada status aneh, potensi problem)
--- Non_COD --> other payment method selain COD
--- OK
SELECT 
    order_id,
    order_status, 
    payment, 
    pay_method,
    CASE 
        WHEN pay_method = 'Cash On Delivery' AND payment = 0
            AND order_status IN ('Selesai', 'Pesanan Diterima')
            THEN 'COD_1'
        WHEN pay_method = 'Cash On Delivery' AND payment > 0
            AND order_status = 'Batal'
            THEN 'COD_2'
        WHEN pay_method = 'Cash On Delivery' AND payment > 0 --ada
            AND order_status IN ('Selesai', 'Pesanan Diterima')
            THEN 'COD_3'
        WHEN pay_method = 'Cash On Delivery' AND payment = 0
            AND order_status IN ('Sedang Dikirim', 'Telah Dikirim')
            THEN 'COD_4'
        WHEN pay_method = 'Cash On Delivery' AND payment > 0 -- ada
            AND order_status IN ('Sedang Dikirim', 'Telah Dikirim')
            THEN 'COD_5'
        WHEN pay_method = 'Cash On Delivery' AND payment = 0 -- ada
            AND order_status = 'Batal'
            THEN 'COD_6'
        WHEN pay_method = 'Cash On Delivery'
            THEN 'COD_Other'
        ELSE 'Non_COD'
    END AS cod_payment_status
FROM INA_sales
WHERE cod_payment_status IN ('COD_1', 'COD_2', 'COD_7');


--- cek payment outliers 

--- cek distribusi data payment (NTILE method)
--- NOT OK (OK)
--- result: Transaksi bernilai tinggi didefinisikan sebagai sekitar 10% teratas dari distribusi pembayaran, dengan batas alami di kisaran 100 ribu berdasarkan analisis desil.
WITH distribusi_data AS (
    SELECT
        payment,
        NTILE(10) OVER (ORDER BY payment) AS bucket
    FROM INA_sales)
SELECT
    bucket,
    ROUND(AVG(payment)) AS avg_payment,
    MIN(payment) AS min_payment,
    MAX(payment) AS max_payment,
    COUNT(*) AS total
FROM distribusi_data
GROUP BY bucket
ORDER BY bucket;


--- cek transaksi dengan payment di atas 100k
--- NOT OK (OK)
SELECT order_id, qty, payment 
FROM INA_sales
WHERE payment > 100000
ORDER BY payment DESC;


--- cek total transaksi per kategori dengan payment di atas 100k
--- NOT OK (OK)
SELECT 
    oc.product_category,
    COUNT(*) AS total
FROM INA_sales s
JOIN ref_orderid_category oc 
    ON s.order_id = oc.order_id
WHERE s.payment > 100000
GROUP BY oc.product_category
ORDER BY total DESC;


--- flagging hight value payment
ALTER TABLE INA_sales ADD COLUMN payment_flag TEXT;
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
UPDATE INA_sales
SET payment_flag = (
    SELECT payment_flag FROM flagging_payment
    WHERE 
        INA_sales.order_id = flagging_payment.order_id);


--- pengkategorian payment ke payment_segment
ALTER TABLE INA_sales ADD COLUMN payment_segment TEXT;
WITH segmenting_payment AS (
    SELECT
        order_id,
        (CASE 
            WHEN payment >= 100000 THEN 'High Value'
            WHEN payment >= 50000 THEN 'Mid Value'
            ELSE 'Low Value'
        END) AS payment_segment
    FROM INA_sales)
UPDATE INA_sales
SET payment_segment = (
    SELECT payment_segment FROM segmenting_payment
    WHERE INA_sales.order_id = segmenting_payment.order_id);


--- cek discount yang melebihi total payment (ship_fee + payment)
--- (logic discount harus lebih kecil dari total payment + ship_fee)
--- (kecuali pesanan dibatalkan --> OK)
--- OK
SELECT
    order_status,
    discount, 
    payment,
    ship_fee,
    (payment + ship_fee) AS total_payment
FROM INA_sales
WHERE 
    discount > total_payment AND 
    order_status <> 'Batal';


--- cek ship_disc yang melebihi ship_est 
--- (ship_disc tidak bisa > ship_est karena ship_disc tidak bisa multiple promo)
--- (ship_disc <= ship_est --> OK)
--- NOT OK (OK)
SELECT 
    order_id,
    ship_disc,
    ship_est
FROM INA_sales
WHERE order_id NOT IN (
    SELECT order_id FROM INA_sales
    WHERE ship_disc <= ship_est);


--- DELETE invalid ship_disc dan ship_est
DELETE FROM INA_sales
WHERE order_id NOT IN (
    SELECT order_id FROM INA_sales
    WHERE ship_disc <= ship_est);


--- cek ship_fee yang melebihi ship_est (invalid)
--- (ship_free tidak bisa > ship_est karena ongkir harus sesuai harganya/lebih kecil)
--- (ship_fee lebih kecil/sama dengan ship_est --> OK)
--- OK
SELECT 
    order_id,
    ship_disc,
    ship_est
FROM INA_sales
WHERE order_id NOT IN (
    SELECT order_id FROM INA_sales
    WHERE ship_fee <= ship_est);


--- cek gap selisih ship_fee dan ship_est
--- NOT OK (OK)
--- cek distribusi data selisih ship_fee dan ship_est (NTILE method)
--- result: Distribusi selisih ship_fee dan ship_est menunjukkan mayoritas transaksi berada di bawah 15 ribu, dengan lonjakan signifikan mulai dari 20 ribu, dan outlier ekstrem di atas 30 ribu.
WITH distribusi_data AS (
    SELECT
        ABS(ship_fee - ship_est) AS selisih,
        NTILE(10) OVER (ORDER BY ABS(ship_fee - ship_est)) AS bucket
    FROM INA_sales)
SELECT
    bucket,
    ROUND(AVG(selisih)) AS avg_selisih,
    MIN(selisih) AS min_selisih,
    MAX(selisih) AS max_selisih,
    COUNT(*) AS total
FROM distribusi_data
GROUP BY bucket
ORDER BY bucket;


--- flagging selisih ship_fee dan ship_est outliers
ALTER TABLE INA_sales ADD COLUMN shipping_flag TEXT;
WITH flagging_shipping AS (
    SELECT
        order_id,
        ship_fee,
        ship_est,
        ship_disc,
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
UPDATE INA_sales
SET shipping_flag = (
    SELECT shipping_flag FROM flagging_shipping
    WHERE 
        INA_sales.order_id = flagging_shipping.order_id);


--- validasi order_status dan cancel_reason
--- OK
SELECT order_id, cancel_reason, order_status
FROM INA_sales
WHERE --- cek order yang batal, tapi cancel_reason "tidak dibatalkan"
    cancel_reason = 'Tidak Dibatalkan' AND
    order_status ='Batal'
UNION
SELECT order_id, cancel_reason, order_status
FROM INA_sales
WHERE --- cek order yang tidak batal, tapi cancel_reason "dibatalkan"
    order_status <> 'Batal' AND
    cancel_reason LIKE 'Dibatalkan%';


--- cek untuk returned qty > 0, maka order_status harus selesai
--- (selain selesai maka invalid --> biasanya return hanya dari completed order)
--- OK
SELECT * FROM INA_sales
WHERE
    returned_qty > 0 AND
    order_status <> 'Selesai';


--- cek penamaan setelah rename untuk penyeragaman nama ship_method
--- OK
SELECT order_id, ship_method 
FROM INA_sales
WHERE ship_method NOT IN (
    SELECT ship_method_new FROM ref_ship_method_category);


--- cek penamaan setelah rename untuk penyeragaman nama pay_method
--- OK
SELECT order_id, pay_method 
FROM INA_sales
WHERE pay_method NOT IN (
    SELECT pay_method_new FROM ref_payment_category);


--- cek penamaan setelah rename untuk penyeragaman nama city
--- OK
SELECT order_id, city 
FROM INA_sales
WHERE city NOT IN (
    SELECT city_new FROM ref_prov_city);


--- cek penamaan setelah rename untuk penyeragaman nama province
--- OK
SELECT order_id, province 
FROM INA_sales
WHERE province NOT IN (
    SELECT province_new FROM ref_prov_city);


--- cek category_count (main table) dengan category_count (ref_orderid_category)
--- OK
SELECT 
    i.order_id, 
    i.category_count,
    count(r.product_category) AS category_count_ref 
FROM INA_sales i
JOIN ref_orderid_category r ON i.order_id = r.order_id
GROUP BY i.order_id
HAVING category_count <> category_count_ref;


--- validasi order_date_clean dan order_timestamp
--- OK
SELECT * FROM INA_sales
WHERE --- tanggal di order_date_clean tidak lebih dari hari ini
DATE(order_date_clean) >= DATE('now')
UNION
SELECT * FROM INA_sales
WHERE --- order_timestamp tidak lebih dari waktu sekarang (GMT +7)
DATETIME(order_timestamp) >= DATE('now', '+7 hours');


--- validasi tanggal di order_timestamp sama dengan order_date_clean
--- OK
SELECT
    DATE(order_timestamp),
    DATE(order_date_clean)
FROM INA_sales
WHERE DATE(order_timestamp) <> DATE(order_date_clean);


--- cek final data yang null or blank
--- OK
SELECT * FROM INA_sales
WHERE
    order_id IS NULL OR order_id = '' OR
    qty IS NULL OR qty = '' OR
    weight_gr IS NULL OR weight_gr = '' OR
    returned_qty IS NULL OR returned_qty = '' OR
    discount IS NULL OR discount = '' OR
    product_categories IS NULL OR product_categories = '' OR
    category_count IS NULL OR category_count = '' OR
    order_status IS NULL OR order_status = '' OR
    cancel_reason IS NULL OR cancel_reason = '' OR
    ship_method IS NULL OR ship_method = '' OR
    pay_method IS NULL OR pay_method = '' OR
    city IS NULL OR city = '' OR
    province IS NULL OR province = '' OR
    ship_fee IS NULL OR ship_fee = '' OR
    ship_disc IS NULL OR ship_disc = '' OR
    payment IS NULL OR payment = '' OR
    ship_est IS NULL OR ship_est = '' OR
    order_timestamp IS NULL OR order_timestamp = '' OR
    order_date_clean IS NULL OR order_date_clean = '' OR
    shipping_category IS NULL OR shipping_category = '' OR
    shipping_carrier IS NULL OR shipping_carrier = '' OR
    cancel_by IS NULL OR cancel_by = '' OR
    sub_reason IS NULL OR sub_reason = '';


--- cek duplikat after validation
--- OK
WITH duplicate_group AS (
    SELECT 
        count(*) AS jumlah_data,
        r.*
    FROM INA_sales r
    GROUP BY
        qty, weight_gr, returned_qty, discount, product_categories, category_count, order_status, cancel_reason, ship_method, pay_method, city, province, ship_fee, ship_disc, payment, ship_est, order_timestamp, order_date_clean
    HAVING jumlah_data > 1)
SELECT * FROM INA_sales r
JOIN duplicate_group g ON
    r.qty = g.qty AND
    r.weight_gr = g.weight_gr AND
    r.returned_qty = g.returned_qty AND
    r.discount = g.discount AND
    r.product_categories = g.product_categories AND
    r.category_count = g.category_count AND
    r.order_status = g.order_status AND
    r.cancel_reason = g.cancel_reason AND
    r.ship_method = g.ship_method AND
    r.pay_method = g.pay_method AND
    r.city = g.city AND
    r.province = g.province AND
    r.ship_fee = g.ship_fee AND
    r.ship_disc = g.ship_disc AND
    r.payment = g.payment AND
    r.ship_est = g.ship_est AND
    r.order_timestamp = g.order_timestamp AND
    r.order_date_clean = g.order_date_clean;