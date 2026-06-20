<h1 align="center">Indonesia E-Commerce Sales Data Preparation with SQL</h1>

<div align="center">

[Overview](#overview) → [Project Highlight](#project-highlight) → [Featured SQL Queries](#featured-sql-queries) → [Data Preparation Summary](#data-preparation-summary) → [SQL Techniques](#sql-techniques)


<div align="justify">

This project focuses on preparing an Indonesia E-Commerce Sales dataset using SQL & SQLite. Starting from raw transactional data, SQL was used to clean, validate, standardize, & transform the dataset before exporting it as an analysis-ready CSV for Tableau dashboard development.

- **Datasets**: Indonesia E-Commerce Sales dataset ([_Kaggle_](https://www.kaggle.com/datasets/zkyfauzi/indonesia-ecommerce-sales)) containing 18,868 order-level transactions (2023–2025), supported by ISO-based province–city mapping & custom reference tables for categorical standardization.
- **Tools**: SQL (SQLite) in Visual Studio Code, dbdiagram.io, Google Sheets

<table width="100%">

  <!-- ROW 1: HEADER IMAGE (SPAN 2 COLUMNS) -->
  <tr>
    <td colspan="2" align="center">
      <b>Workflow</b><br>
      <img width="100%" 
           src="https://github.com/user-attachments/assets/772532ea-264b-4ddf-93a2-8eb22a13acff"
           alt="ERD Overview">
    </td>
  </tr>
  
  <!-- ROW 2: 2 ERD SIDE BY SIDE -->
  <tr>
    <td align="center">
      <b>Data Preparation Model</b><br>Main table + reference tables</sub><br>
      <img src="https://github.com/user-attachments/assets/37c0daf2-6184-4f08-8b37-b1902c691d85"
           alt="ERD Data Preparation"
           width="100%">
    </td>
    <td align="center">
      <b>Analysis Model</b><br>Fact & dimension tables</sub><br>
      <img src="https://github.com/user-attachments/assets/2398ccef-8e2a-47cd-9888-0f9d3c3c2a5b"
           alt="ERD Analysis"
           width="100%">
    </td>
  </tr>

</table>




<h2 align="center">Project Highlight</h2>

<div align="center">


<table width="100%">
<tr>
    <th align="center">Area</th>
    <th align="center">Summary</th>
    <th align="center">Results</th>
</tr>
<tr>
    <td align="center">Data Cleaning</td>
    <td align="center">Removed duplicate records, corrected invalid data, & standardized key fields</td>
    <td align="center">631 removed<br>580 corrected</td>
</tr>
<tr>
    <td align="center">Data Validation</td>
    <td align="center">Applied business rules to identify invalid and unusual records</td>
    <td align="center">18,868 rows validated<br>2,478 flagged</td>
</tr>
<tr>
    <td align="center">Feature Engineering</td>
    <td align="center">Created business categories & quality flags</td>
    <td align="center">8 new fields</td>
</tr>
<tr>
    <td align="center">Data Modeling</td>
    <td align="center">Restructured the cleaned data into a star schema for analysis</td>
    <td align="center">1 fact &amp; 2 dim tables</td>
</tr>
<tr>
    <td align="center">Final Output</td>
    <td align="center">Exported an analysis-ready dataset for Tableau dashboard development</td>
    <td align="center">18,237 clean transactions</td>
</tr>
</table>






<h2 align="center">Featured SQL Queries</h2>

<div align="center">

<table>

  <!-- #1 -->
  <tr>
    <td>
      <b>#1. Standardizing Categories</b><br>
      Standardized payment methods using a reference table instead of hardcoded mappings.

```sql
UPDATE raw_INA_sales
SET pay_method = 
    (SELECT pay_method_new
     FROM ref_payment_category
     WHERE raw_INA_sales.pay_method = ref_payment_category.pay_method)
WHERE pay_method IN (
    SELECT pay_method FROM ref_payment_category);
```

</td> </tr> <!-- #2 --> <tr> <td> <b>#2. Validating Business Rules</b><br> Validated zero-payment transactions by separating valid cases from invalid records.

```sql
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
```

</td> </tr> <!-- #3 --> <tr> <td> <b>#3. Analyzing Payment Distribution</b><br>Used NTILE() to explore payment distribution and identify a natural threshold for high-value transactions.

```sql
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
```

</td> </tr> </table>



<h2 align="center">Data Preparation Summary</h2>

| Category | Actions | Total Records Involved |
|:---:|---|:---:|
| Deleted | • Removed duplicate records<br>• Removed blank `qty` & `pay_method` records<br>• Removed invalid shipping records (`ship_disc > ship_est`)<br>• Removed invalid zero-payment transactions | 631 |
| Reformatted | • Corrected malformed `order_date` values<br>• Recovered missing dates from `order_timestamp`<br>• Standardized date format to `YYYY-MM-DD` | 580 |
| Renamed | • Standardized city names<br>• Standardized province names using reference mapping | 18,298 |
| Regrouped | • Standardized payment methods<br>• Standardized shipping methods<br>• Unified order status values | 18,298 |
| Flagged | • Flagged payment outliers<br>• Flagged shipping inconsistencies<br>• Flagged suspicious package weights<br>• Applied quality flags to valid edge cases | 2,478 |


<h2 align="center">SQL Techniques</h2>
<div align="justify"> 
    
- **Data Manipulation:** `UPDATE`, `DELETE`, `CAST`, `REPLACE`, `TRIM`
- **Data Querying:** `JOINs`, `CTEs`, `Subqueries`, `Views`
- **Analytical SQL:** `CASE`, `GROUP BY`, `HAVING`, Aggregate Functions, `Window Functions (NTILE)`
- **Data Validation:** `CHECK`, `GLOB`, Business Rule Validation, Data Quality Flagging
- **Date & Time Functions:** `DATE()`, `DATETIME()`
