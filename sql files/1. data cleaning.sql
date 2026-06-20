--- sqlite3


--- run in terminal
--- opening database in sqlite3
sqlite3 "C:\Users\.......\INA_ecommerce_sales.db"


--- import data csv to sql database
--- karena separator dalam file adalah (;)
.mode csv
.separator ; 


--- import data (raw Indonesia E-commerce Sales.csv) sebagai tabel raw_INA_sales
--- "C:/Users/......./[raw] Indonesia E-commerce Sales.csv" path file depends on folder where you saved it
.import "C:/Users/......./[raw] Indonesia E-commerce Sales.csv" raw_INA_sales
.schema raw_INA_sales



--- import other CSV files as external references to support data cleaning and validation
.import "C:/Users/......./prov_kab-kota_standardisation.csv" ref_prov_city
.import "C:/Users/......./order id_categories.csv" ref_orderid_category
.import "C:/Users/......./payment_categories.csv" ref_payment_category
.import "C:/Users/......./ship_method_categories.csv" ref_ship_method_category
.import "C:/Users/......./cancel_status.csv" ref_cancel_status


--- cek isi tabel
SELECT * FROM raw_INA_sales LIMIT 100;


--- rename penamaan beberapa attributes dalam tabel
--- total_qty -----------------------------> qty
--- total_weight_gr -----------------------> weight_gr
--- total_returned_qty --------------------> returned_qty
--- "Total Diskon" ------------------------> discount
--- num_product_categories ----------------> category_count
--- "Status Pesanan" ----------------------> order_status
--- "Alasan Pembatalan" -------------------> cancel_reason
--- "Opsi Pengiriman" ---------------------> ship_method
--- "Metode Pembayaran" -------------------> pay_method
--- "Kota/Kabupaten" ----------------------> city
--- Provinsi ------------------------------> province
--- "Ongkos Kirim Dibayar oleh Pembeli" ---> ship_fee
--- "Estimasi Potongan Biaya Pengiriman" --> ship_disc
--- "Total Pembayaran" --------------------> payment
--- "Perkiraan Ongkos Kirim" --------------> ship_est
--- "Waktu Pesanan Dibuat" ----------------> order_timestamp


--- rename penamaan beberapa attributes dalam tabel
ALTER TABLE raw_INA_sales RENAME COLUMN total_qty TO qty;
ALTER TABLE raw_INA_sales RENAME COLUMN total_weight_gr TO weight_gr;
ALTER TABLE raw_INA_sales RENAME COLUMN total_returned_qty TO returned_qty;
ALTER TABLE raw_INA_sales RENAME COLUMN "Total Diskon" TO discount;
ALTER TABLE raw_INA_sales RENAME COLUMN num_product_categories TO category_count;
ALTER TABLE raw_INA_sales RENAME COLUMN "Status Pesanan" TO order_status;
ALTER TABLE raw_INA_sales RENAME COLUMN "Alasan Pembatalan" TO cancel_reason;
ALTER TABLE raw_INA_sales RENAME COLUMN "Opsi Pengiriman" TO ship_method;
ALTER TABLE raw_INA_sales RENAME COLUMN "Metode Pembayaran" TO pay_method;
ALTER TABLE raw_INA_sales RENAME COLUMN "Kota/Kabupaten" TO city;
ALTER TABLE raw_INA_sales RENAME COLUMN Provinsi TO province;
ALTER TABLE raw_INA_sales RENAME COLUMN "Ongkos Kirim Dibayar oleh Pembeli" TO ship_fee;
ALTER TABLE raw_INA_sales RENAME COLUMN "Estimasi Potongan Biaya Pengiriman" TO ship_disc;
ALTER TABLE raw_INA_sales RENAME COLUMN "Total Pembayaran" TO payment;
ALTER TABLE raw_INA_sales RENAME COLUMN "Perkiraan Ongkos Kirim" TO ship_est;
ALTER TABLE raw_INA_sales RENAME COLUMN "Waktu Pesanan Dibuat" TO order_timestamp;



--------------------------------------------------------------------------------
------------------- CEK DUPLIKAT (BEFORE CLEANING) -----------------------------
--------------------------------------------------------------------------------


--- cek duplicate data by all columns (kecuali order_id)
--- ada data duplicate
SELECT 
    count(*) AS jumlah_data,
    r.*
FROM raw_INA_sales r
GROUP BY
       qty, weight_gr, returned_qty, discount, product_categories, 
       category_count, order_status, cancel_reason, ship_method, 
       pay_method, city, province, ship_fee, ship_disc, payment, 
       ship_est, order_timestamp, order_date
HAVING jumlah_data > 1;


--- query data yang duplicate by all columns (kecuali order_id)
--- total 14 baris data duplicate dengan order_id berbeda
WITH duplicate_group AS (
    SELECT 
        count(*) AS jumlah_data,
        r.*
    FROM raw_INA_sales r
    GROUP BY
        qty, weight_gr, returned_qty, discount, product_categories, 
        category_count, order_status, cancel_reason, ship_method, 
        pay_method, city, province, ship_fee, ship_disc, payment, 
        ship_est, order_timestamp, order_date
    HAVING jumlah_data > 1)
SELECT * FROM raw_INA_sales r
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
    r.order_date = g.order_date;

--- DELETE duplicate rows data
WITH delete_duplicate AS (
    SELECT 
        count(*) AS jumlah_data,
        r.*
    FROM raw_INA_sales r
    GROUP BY
        qty, weight_gr, returned_qty, discount, product_categories, 
        category_count, order_status, cancel_reason, ship_method, 
        pay_method, city, province, ship_fee, ship_disc, payment, 
        ship_est, order_timestamp, order_date
    HAVING jumlah_data > 1)
DELETE FROM raw_INA_sales
WHERE order_id IN (
    SELECT order_id 
    FROM delete_duplicate);



--- cek order_id duplicate atau null
SELECT order_id, count(order_id)
FROM raw_INA_sales
GROUP BY order_id
HAVING 
    count(order_id) > 1 OR 
    order_id IS NULL;

--- cek lenght untuk kolom order_id
SELECT DISTINCT length(order_id) AS LEN_order_id
FROM raw_INA_sales
WHERE LEN_order_id <> 11;

--- format order_id ORD_XXXXXXX --> "ORD" + "_" + "7 Numbers"
--- cek format by per-words / characters
SELECT DISTINCT 
    substr(order_id, 1, 3) AS first_three_ch,
    substr(order_id, 4, 1) AS underscore_ch
FROM raw_INA_sales
WHERE 
    first_three_ch <> 'ORD' AND underscore_ch <> '_';

--- cek the last 7 characters are pure real number
WITH RECURSIVE 
    full_numbers AS (
    SELECT 1 AS nomor 
    UNION ALL
    SELECT nomor + 1
    FROM full_numbers
    WHERE nomor <= 21000)
SELECT 
    order_id,
    CAST(substr(order_id, 5, 7) AS INTEGER) AS last_seven_ch
FROM raw_INA_sales
WHERE last_seven_ch NOT IN (SELECT nomor FROM full_numbers);



------------------ //////// ------------------
--- CEK qty

--- cek total qty dan jumlah data tiap data qty
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
--- ada ~283 blank rows
SELECT 
    qty,
    length(REPLACE(qty, '.0', '')) As LEN_data,
    length(CAST(qty AS INTEGER)) AS LEN_real_integer, 
    count(qty) AS jumlah_data
FROM raw_INA_sales
GROUP BY qty
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(qty AS INTEGER);

--- cek jumlah row qty yang null/blank
--- ada 283 blank rows
SELECT  
    count(qty),
    (CASE
        WHEN qty = '' THEN 'blank'  
        WHEN qty IS NULL THEN 'null'  
        ELSE 'ok'
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';

--- DELETE rows of blank qty 
DELETE FROM raw_INA_sales
WHERE qty = '';



------------------ //////// ------------------
--- CEK weight_gr

--- cek total weight dan jumlah data tiap data weight
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    weight_gr,
    length(weight_gr) As LEN_data,
    length(CAST(weight_gr AS INTEGER)) AS LEN_real_integer, 
    count(weight_gr) AS jumlah_data
FROM raw_INA_sales
GROUP BY weight_gr
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(weight_gr AS INTEGER);


--- cek jumlah row weight_gr yang null/blank
--- no blank/null
SELECT  
    count(weight_gr),
    (CASE 
        WHEN weight_gr = '' THEN 'blank'  
        WHEN weight_gr IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- returned_qty

--- cek total returned qty dan jumlah data tiap data returned qty
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    returned_qty,
    length(returned_qty) As LEN_data,
    length(CAST(returned_qty AS INTEGER)) AS LEN_real_integer, 
    count(returned_qty) AS jumlah_data
FROM raw_INA_sales
GROUP BY returned_qty
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(returned_qty AS INTEGER);


--- cek jumlah row returned_qty yang null/blank
--- no blank/null
SELECT  
    count(returned_qty),
    (CASE 
        WHEN returned_qty = '' THEN 'blank'  
        WHEN returned_qty IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- TOTAL DISKON

--- cek total diskon dan jumlah data tiap data diskon
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    discount,
    length(discount) As LEN_data,
    length(CAST(discount AS INTEGER)) AS LEN_real_integer, 
    count(discount) AS jumlah_data
FROM raw_INA_sales
GROUP BY discount
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(discount AS INTEGER);


--- cek jumlah row discount yang null/blank
--- no blank/null
SELECT  
    count(discount),
    (CASE 
        WHEN discount = '' THEN 'blank'  
        WHEN discount IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- PRODUCT_CATEGORIES

--- cek data product_categories yang null/blank
--- product_categories masih dalam bentuk multiple categories
SELECT
    product_categories,
    count(product_categories) as jumlah_data
FROM raw_INA_sales
GROUP BY product_categories
HAVING product_categories IS NULL or product_categories = '';



------------------ //////// ------------------
--- category_count

--- cek category_count dan jumlah data tiap category_count
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    category_count,
    length(category_count) As LEN_data,
    length(CAST(category_count AS INTEGER)) AS LEN_real_integer, 
    count(category_count) AS jumlah_data
FROM raw_INA_sales
GROUP BY category_count
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(category_count AS INTEGER);

--- cek jumlah row category_count yang null/blank
--- no blank/null
SELECT  
    count(category_count),
    (CASE 
        WHEN category_count = '' THEN 'blank'  
        WHEN category_count IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- STATUS PESANAN
--- cek order_status dan jumlah data tiap order_status
--- masih belum terstandarisasi kategori status pesanannya, tidak ada extra spasi
SELECT DISTINCT
    order_status,
    count(order_status),
    (CASE 
        WHEN length(order_status) = length(trim(order_status)) THEN 'OK'  
        ELSE 'Problem'
    END) AS length_data_status
FROM raw_INA_sales
GROUP BY order_status
HAVING length_data_status <> 'OK'
ORDER BY order_status;

--- cek jumlah row order_status yang null/blank
--- no blank/null
SELECT  
    count(order_status),
    (CASE 
        WHEN order_status = '' THEN 'blank'  
        WHEN order_status IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';

--- UPDATE order_status ke 5 kategori saja (Batal, Pesanan Diterima, Sedang Dikirim, Selesai, Telah Dikirim)
--- Rename data "Pesanan diterima, namun...." --> "Pesanan Diterima"
UPDATE raw_INA_sales
SET order_status = 'Pesanan Diterima'
WHERE order_status LIKE '%Pesanan diterima, namun Pembeli masih dapat%';



------------------ //////// ------------------
--- ALASAN PEMBATALAN

--- cek Alasan Pembatalan dan jumlah data tiap Alasan Pembatalan
--- masih belum terstandarisasi kategori Alasan Pembatalannya, tidak ada extra spasi
SELECT DISTINCT
    cancel_reason,
    count(cancel_reason),
    (CASE 
        WHEN length(cancel_reason) = length(trim(cancel_reason)) THEN 'OK'  
        ELSE 'Problem'
    END) AS length_data_status
FROM raw_INA_sales
GROUP BY cancel_reason
HAVING length_data_status <> 'OK'
ORDER BY cancel_reason;


--- cek jumlah row cancel_reason yang null/blank
--- no blank/null
SELECT  
    count(cancel_reason),
    (CASE 
        WHEN cancel_reason = '' THEN 'blank'  
        WHEN cancel_reason IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- OPSI PENGIRIMAN

--- cek ship_method dan jumlah data tiap ship_method
--- masih belum terstandarisasi kategori Opsi Pengirimannya, tidak ada extra spasi
SELECT DISTINCT
    ship_method,
    count(ship_method),
    (CASE 
        WHEN length(ship_method) = length(trim(ship_method)) THEN 'OK'  
        ELSE 'Problem'
    END) AS length_data_status
FROM raw_INA_sales
GROUP BY ship_method
HAVING length_data_status <> 'OK'
ORDER BY ship_method;

--- cek jumlah row ship_method yang null/blank
--- no blank/null
SELECT  
    count(ship_method),
    (CASE 
        WHEN ship_method = '' THEN 'blank'  
        WHEN ship_method IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



--- UPDATE penyeragaman data ship_method agar lebih uniform
UPDATE raw_INA_sales
SET ship_method = 
    (SELECT ship_method_new 
    FROM ref_ship_method_category
    WHERE raw_INA_sales.ship_method = ref_ship_method_category.ship_method)
WHERE ship_method IN (
    SELECT ship_method FROM ref_ship_method_category);



------------------ //////// ------------------
--- METODE PEMBAYARAN

--- cek pay_method dan jumlah data tiap pay_method
--- masih belum terstandarisasi kategori Metode Pembayarannya, tidak ada extra spasi
--- ada 283 blank rows
SELECT DISTINCT
    pay_method,
    count(pay_method),
    (CASE 
        WHEN length(pay_method) = length(trim(pay_method)) THEN 'OK'  
        ELSE 'Problem'
    END) AS length_data_status
FROM raw_INA_sales
GROUP BY pay_method
HAVING length_data_status <> 'OK'
ORDER BY pay_method;

--- cek jumlah row pay_method yang null/blank
--- ada ~280 blank rows
SELECT  
    count(pay_method),
    (CASE 
        WHEN pay_method = '' THEN 'blank'  
        WHEN pay_method IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';

--- DELETE rows of blank pay_method
DELETE FROM raw_INA_sales
WHERE pay_method = '';

--- UPDATE penyeragaman nama di data pay_method agar lebih uniform
UPDATE raw_INA_sales
SET pay_method = 
    (SELECT pay_method_new 
    FROM ref_payment_category
    WHERE raw_INA_sales.pay_method = ref_payment_category.pay_method)
WHERE pay_method IN (
    SELECT pay_method FROM ref_payment_category);



------------------ //////// ------------------
--- KOTA/KABUPATEN

--- cek city dan jumlah data tiap city
--- masih belum terstandarisasi kategori Kota/Kabupatennya, tidak ada extra spasi
SELECT DISTINCT
    city,
    count(city),
    (CASE 
        WHEN length(city) = length(trim(city)) THEN 'OK'  
        ELSE 'Problem'
    END) AS length_data_status
FROM raw_INA_sales
GROUP BY city
HAVING length_data_status <> 'OK'
ORDER BY city;

--- cek jumlah row city yang null/blank
--- no blank/null
SELECT  
    count(city),
    (CASE 
        WHEN city = '' THEN 'blank'  
        WHEN city IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';

--- UPDATE penyeragaman nama data KOTA/KABUPATEN agar lebih uniform
--- update penamaan sesuai standar tanpa awalan KAB/KOTA
--- update penulisan sesuai standar, misal KOTA BARU --> Kotabaru
UPDATE raw_INA_sales
SET city = 
    (SELECT city_new 
    FROM ref_prov_city
    WHERE raw_INA_sales.city = ref_prov_city.city)
WHERE city IN (
    SELECT city FROM ref_prov_city);



------------------ //////// ------------------
--- province

--- cek province dan jumlah data tiap province
--- masih belum terstandarisasi kategori provincenya, tidak ada extra spasi
SELECT DISTINCT
    province,
    count(province),
    (CASE 
        WHEN length(province) = length(trim(province)) THEN 'OK'  
        ELSE 'Problem'
    END) AS length_data_status
FROM raw_INA_sales
GROUP BY province
HAVING length_data_status <> 'OK'
ORDER BY province;

--- cek jumlah row province yang null/blank
--- no blank/null
SELECT  
    count(province),
    (CASE 
        WHEN province = '' THEN 'blank'  
        WHEN province IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';

--- UPDATE penyeragaman nama provinsi agar lebih uniform
--- update penulisan sesuai standar NUSA TENGGARA BARAT (NTB) --> Nusa Tenggara Barat
UPDATE raw_INA_sales
SET province = 
    (SELECT province_new 
    FROM ref_prov_city
    WHERE raw_INA_sales.province = ref_prov_city.province)
WHERE province IN (
    SELECT province FROM ref_prov_city);



------------------ //////// ------------------
--- ONGKOS KIRIM DIBAYAR OLEH PEMBELI

--- cek ship_fee dan jumlah data tiap ship_fee
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    ship_fee,
    length(ship_fee) As LEN_data,
    length(CAST(ship_fee AS INTEGER)) AS LEN_real_integer, 
    count(ship_fee) AS jumlah_data
FROM raw_INA_sales
GROUP BY ship_fee
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(ship_fee AS INTEGER);

--- cek jumlah row ship_fee yang null/blank
--- no blank/null
SELECT
    count(ship_fee),
    (CASE 
        WHEN ship_fee = '' THEN 'blank'  
        WHEN ship_fee IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- ESTIMASI POTONGAN BIAYA PENGIRIMAN

--- cek ship_disc dan jumlah data tiap ship_disc
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    ship_disc,
    length(ship_disc) As LEN_data,
    length(CAST(ship_disc AS INTEGER)) AS LEN_real_integer, 
    count(ship_disc) AS jumlah_data
FROM raw_INA_sales
GROUP BY ship_disc
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(ship_disc AS INTEGER);

--- cek jumlah row ship_disc yang null/blank
--- no blank/null
SELECT
    count(ship_disc),
    (CASE 
        WHEN ship_disc = '' THEN 'blank'  
        WHEN ship_disc IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- TOTAL PEMBAYARAN

--- cek payment dan jumlah data tiap payment
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    payment,
    length(payment) As LEN_data,
    length(CAST(payment AS INTEGER)) AS LEN_real_integer, 
    count(payment) AS jumlah_data
FROM raw_INA_sales
GROUP BY payment
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(payment AS INTEGER);

--- cek jumlah row payment yang null/blank
--- no blank/null
SELECT
    count(payment),
    (CASE 
        WHEN payment = '' THEN 'blank'  
        WHEN payment IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- PERKIRAAN ONGKOS KIRIM

--- cek ship_est dan jumlah data tiap ship_est
--- cek juga apakah sama dengan LEN data real as integer
--- masih dimuat dalam format TEXT
SELECT 
    ship_est,
    length(ship_est) As LEN_data,
    length(CAST(ship_est AS INTEGER)) AS LEN_real_integer, 
    count(ship_est) AS jumlah_data
FROM raw_INA_sales
GROUP BY ship_est
HAVING LEN_data <> LEN_real_integer
ORDER BY CAST(ship_est AS INTEGER);

--- cek jumlah row ship_est yang null/blank
--- no blank/null
SELECT
    count(ship_est),
    (CASE 
        WHEN ship_est = '' THEN 'blank'  
        WHEN ship_est IS NULL THEN 'null'  
        ELSE 'ok' 
    END) AS status
FROM raw_INA_sales
GROUP BY status
HAVING status <> 'ok';



------------------ //////// ------------------
--- WAKTU PESANAN DIBUAT

--- cek data waktu pesanan dibuat yang tidak valid beserta jumlah datanya
--- no problematic data tanggal
SELECT
    order_timestamp,
    DATETIME(order_timestamp) as order_timestamp_new,
    count(order_timestamp) as jumlah_data
FROM raw_INA_sales
GROUP BY order_timestamp
HAVING order_timestamp_new IS NULL
LIMIT 1000;



------------------ //////// ------------------
--- ORDER_DATE

--- cek data order_date yang tidak valid beserta jumlah datanya
--- ada data order_date yang tidak valid (blank rows dan berformat DD/MM/YYYY)
SELECT
    order_date,
    DATE(order_date) as new_order_date,
    count(order_date) as jumlah_data
FROM raw_INA_sales
GROUP BY order_date
HAVING new_order_date IS NULL
ORDER BY new_order_date;

--- cek data order_date yang tidak valid (selain data berformat DD/MM/YYYY dan blank)
--- ada 36 data abnormal ('2024-13-40' bulan-13 dan tanggal-40)
WITH cek_date AS (
    SELECT
        order_date,
        DATE(order_date) as new_order_date,
        count(order_date) as jumlah_data
    FROM raw_INA_sales
    GROUP BY order_date
    HAVING new_order_date IS NULL
    ORDER BY new_order_date DESC)
SELECT * FROM cek_date
WHERE order_date NOT LIKE '%/%' AND order_date <> '';

--- cek jumlah data tanggal di kolom order_date dan order_timestamp yang sama/beda
--- rearrange order_date yang DD/MM/YYYY to YYYY-MM-DD
--- result: tanggal di kolom order_date dan order_timestamp sama (selain data blank dan abnormal)
--- data blank dan abnormal akan diganti dengan data tanggal dari kolom order_timestamp
WITH cek_date AS (
    SELECT 
        order_date,
        DATE(
            CASE 
                WHEN order_date LIKE '%/%' THEN (substr(order_date, 7, 4) || '-' || substr(order_date, 4, 2) || '-' || substr(order_date, 1, 2)) --rearrange order_date
                ELSE order_date
            END) AS order_date_rearrange,
        DATE(substr(order_timestamp, 1, 10)) AS date_waktu_pesanan_dibuat
    FROM raw_INA_sales)
SELECT 
    'Jumlah Data' AS attributes,
    count(*) AS 'Total Data',
    SUM(order_date_rearrange = date_waktu_pesanan_dibuat) AS 'Sama', 
    SUM(order_date_rearrange IS NULL AND order_date = '') AS 'Beda (Blank)',
    SUM(order_date_rearrange IS NULL AND order_date <> '') AS 'Beda (Abnormal)'
FROM cek_date;


--- create new column (order_date_clean) untuk data order_date baru
ALTER TABLE raw_INA_sales
ADD COLUMN
    order_date_clean DATE
    CHECK (order_date_clean GLOB'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]');


--- UPDATE DATA kolom order_date_clean
--- untuk tanggal order_date normal ---> tetap dari order_date
--- untuk tanggal order_date DD/MM/YYY --> rearrange ke YYYY-MM-DD
--- untuk blank dan abnormal --> query tanggal dari tanggal order_timestamp
UPDATE raw_INA_sales
SET order_date_clean =
    coalesce(
        DATE(CASE 
            WHEN order_date LIKE '%/%' THEN substr(order_date, 7, 4) || '-' || substr(order_date, 4, 2) || '-' || substr(order_date, 1, 2)  
            ELSE order_date 
            END),
        DATE(substr(order_timestamp, 1, 10)) )
WHERE order_date_clean IS NULL;



------------------ //////// ------------------
--- ORDER_DATE_CLEAN

--- cek data order_date_clean yang tidak valid beserta jumlah datanya
--- ada data order_date_clean yang tidak valid (blank rows dan berformat DD/MM/YYYY)
SELECT
    order_date_clean,
    DATE(order_date_clean) as new_order_date_clean,
    count(order_date_clean) as jumlah_data
FROM raw_INA_sales
GROUP BY order_date_clean
HAVING new_order_date_clean IS NULL
ORDER BY new_order_date_clean;

--- cek data order_date_clean yang tidak valid (selain data berformat DD/MM/YYYY dan blank)
--- ada 36 data abnormal ('2024-13-40' bulan-13 dan tanggal-40)
WITH cek_date AS (
    SELECT
        order_date_clean,
        DATE(order_date_clean) as new_order_date_clean,
        count(order_date_clean) as jumlah_data
    FROM raw_INA_sales
    GROUP BY order_date_clean
    HAVING new_order_date_clean IS NULL
    ORDER BY new_order_date_clean DESC)
SELECT * FROM cek_date
WHERE order_date_clean NOT LIKE '%/%' AND order_date_clean <> '';

--- cek jumlah data tanggal di kolom order_date_clean dan order_timestamp yang sama/beda
--- rearrange order_date_clean yang DD/MM/YYYY to YYYY-MM-DD
--- result: tanggal di kolom order_date_clean dan order_timestamp sama (selain data blank dan abnormal)
--- data blank dan abnormal akan diganti dengan data tanggal dari kolom order_timestamp
WITH cek_date AS (
    SELECT 
        order_date_clean,
        DATE(
            CASE 
                WHEN order_date_clean LIKE '%/%' THEN (substr(order_date_clean, 7, 4) || '-' || substr(order_date_clean, 4, 2) || '-' || substr(order_date_clean, 1, 2)) --rearrange order_date_clean
                ELSE order_date_clean
            END) AS order_date_clean_rearrange,
        DATE(substr(order_timestamp, 1, 10)) AS date_waktu_pesanan_dibuat
    FROM raw_INA_sales)
SELECT 
    'Jumlah Data' AS attributes,
    count(*) AS 'Total Data',
    SUM(order_date_clean_rearrange = date_waktu_pesanan_dibuat) AS 'Sama', 
    SUM(order_date_clean_rearrange IS NULL AND order_date_clean = '') AS 'Beda (Blank)',
    SUM(order_date_clean_rearrange IS NULL AND order_date_clean <> '') AS 'Beda (Abnormal)'
FROM cek_date;



--- cek duplicate data by all columns (kecuali order_id)
--- ada data duplicate
SELECT 
    count(*) AS jumlah_data,
    r.*
FROM raw_INA_sales r
GROUP BY
       qty, weight_gr, returned_qty, discount, product_categories, 
       category_count, order_status, cancel_reason, ship_method, 
       pay_method, city, province, ship_fee, ship_disc, payment, 
       ship_est, order_timestamp, order_date_clean
HAVING jumlah_data > 1;





--------------------------------------------------------------------------------
-------------------- CEK DUPLIKAT (AFTER CLEANING) -----------------------------
--------------------------------------------------------------------------------


--- query data yang duplicate by all columns (kecuali order_id)
--- menggunakan order_date_clean
--- total 14 baris data duplicate dengan order_id berbeda
WITH duplicate_group AS (
    SELECT 
        count(*) AS jumlah_data,
        r.*
    FROM raw_INA_sales r
    GROUP BY
        qty, weight_gr, returned_qty, discount, product_categories, 
        category_count, order_status, cancel_reason, ship_method, 
        pay_method, city, province, ship_fee, ship_disc, payment, 
        ship_est, order_timestamp, order_date_clean
    HAVING jumlah_data > 1)
SELECT * FROM raw_INA_sales r
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

--- DELETE duplicate rows data
WITH delete_duplicate AS (
    SELECT 
        count(*) AS jumlah_data,
        r.*
    FROM raw_INA_sales r
    GROUP BY
        qty, weight_gr, returned_qty, discount, product_categories, 
        category_count, order_status, cancel_reason, ship_method, 
        pay_method, city, province, ship_fee, ship_disc, payment, 
        ship_est, order_timestamp, order_date_clean
    HAVING jumlah_data > 1)
DELETE FROM raw_INA_sales
WHERE order_id IN (
    SELECT order_id 
    FROM delete_duplicate);
