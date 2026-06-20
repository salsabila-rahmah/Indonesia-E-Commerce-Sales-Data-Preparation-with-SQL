<h2 align="center">ERD Schema</h2>

This file contains the SQL schema used to build the Entity Relationship Diagram (ERD) in [**dbdiagram.io**](https://dbdiagram.io/)., making it easier to visualize relationships between tables in this project.


### ERD INA_sales + 5 ref tables

```sql
Table INA_sales {
  order_id text [pk, not null]
  qty integer [not null]
  weight_gr integer [not null]
  returned_qty integer [not null]
  discount integer [not null]
  product_categories text [not null]
  category_count integer [not null]
  order_status text [not null]
  cancel_reason text [not null]
  cancel_by text
  ship_method text [not null]
  shipping_carrier text
  shipping_category text
  shipping_flag text
  pay_method text [not null]
  payment integer [not null]
  payment_flag text
  payment_segment text
  province text [not null]
  city text [not null]
  ship_fee integer [not null]
  ship_disc integer [not null]
  ship_est integer [not null]
  order_timestamp datetime
  order_date_clean date
  sub_reason text
  weight_flag text}

Table ref_cancel_status {
  cancel_id text
  cancel_by text
  reason text
  cancel_reason text}

Table ref_orderid_category {
  order_id text
  product_category text}

Table ref_payment_category {
  pay_method text
  pay_method_new text
  payment_category text}

Table ref_prov_city {
  province text
  province_new text
  city text
  city_new text}

Table ref_ship_method_category {
  ship_method text
  ship_method_new text
  shipping_carrier text
  shipping_category text}

Ref: INA_sales.order_id > ref_orderid_category.order_id
Ref: INA_sales.pay_method > ref_payment_category.pay_method
Ref: INA_sales.ship_method > ref_ship_method_category.ship_method
Ref: INA_sales.cancel_reason > ref_cancel_status.cancel_reason
Ref: INA_sales.province > ref_prov_city.province
Ref: INA_sales.city > ref_prov_city.city
```


### ERD Fact + 2 dim tables

```sql
TABLE fact_INA_sales {
    order_id TEXT
    order_date NUM
    order_timestamp NUM
    year_order_date date
    month_order_date date
    time_order_date datetime
    category_count INT
    qty INT
    returned_qty INT
    weight_gr INT
    order_status TEXT
    cancel_by TEXT
    sub_reason TEXT
    discount INT
    payment INT
    pay_method TEXT
    payment_segment TEXT
    ship_method TEXT
    ship_fee INT
    ship_disc INT
    ship_est INT
    shipping_category TEXT
    shipping_carrier TEXT
    net_shipping INT
    city TEXT
    province TEXT}

TABLE dim_payment {
    pay_method TEXT [pk]
    payment_category TEXT}

TABLE dim_order_category {
    order_id TEXT [pk]
    product_category TEXT}

Ref: fact_INA_sales.pay_method > dim_payment.pay_method
Ref: fact_INA_sales.order_id > dim_order_category.order_id
```
