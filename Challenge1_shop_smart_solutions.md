# Business Scenario: ShopSmart Online Retail

Context:
ShopSmart is an online retail company that sells various products across different categories. The business team wants insights from sales data to understand customer behavior, category performance, and the effectiveness of promotions.

## Tables Overview

### PART A
5 Tables: 
Identify the PK and FK(s) for the tables. Sketch a ER diagram to help you. 
Recreate the tables in your own schema and add PKs to each table and FKs where necessary.

`Customers` (root parent table)
1. customer_id ← pk
2. first_name
3. last_name
4. region
5. signup_date

`Products`
1. product_id ← pk
2. category
3. product_name
4. unit_price

`Orders`
1. order_id ← pk
2. customer_id ← FK to customers
3. order_date
4. total_amount

`Order_items`
1. order_item_id  ← pk
2. order_id  ← fk to orders
3. product_id ← fk to products
4. quantity
5. unit_price
6. discount

`Promotions`
1. promotion_id ← pk
2. product_id  ← fk to products
3. start_date
4. end_date
5. discount_percent

![alt text](image.png)

### PART B

1. `Customer segmentation:` How many customers are from each region? 

|Region   |Total Number |
|:---     |:----        |
|South	  | 57          |
|West	  | 44          |
|North	  | 56          |
|East	  | 43          |

2. `Regional performance:` What’s the average order total per region?

|Region   |Avg Value |
|:---   |:----       |
|West	| 2566.67    | 
|North	| 2264.02    |
|South	| 2147.26    |
|East	| 1661.94    |

3. `Product mix analysis:` Which product categories have the highest average price?

--- Highest avg. price overall  

|Category   |Price   |
|:---       |:----   |
|Electronics| 279.95 |
|Beauty     | 251.14 |
|Sports     | 232.02 |
|Home       | 227.14 |
|Clothing   | 177.36 |

--- Highest avg. price per region

|Region |Category       |Price |
|:---   |:----          |:---- |
|East	|Electronics	|304.65|
|East	|Sports	        |239.27|
|East	|Beauty	        |220.11|
|East	|Home	        |178.47|
|East	|Clothing    	|175.08|
|North	|Electronics  	|303.93|
|North	|Beauty	        |286.47|
|North	|Home	        |217.07|
|North	|Sports	        |204.85|
|North	|Clothing	    |173.53|
|South	|Electronics	|294.98|
|South	|Sports	        |264.05|
|South	|Beauty	        |260.44|
|South	|Home	        |210.36|
|South	|Clothing	    |170.20|
|West	|Home	        |291.78|
|West	|Electronics	|283.99|
|West	|Beauty	        |241.82|
|West	|Sports	        |205.08|
|West	|Clothing	    |190.96|

4. `Trend analysis:` Find the total revenue generated per month.

 year |month_name|total_revenue|
 :--- |:----     |:----        |
2024|Oct       |     31629.45|
2024|Nov       |     61606.05|
2024|Dec       |     44485.72|
2025|Jan       |     63783.16|
2025|Feb       |     57011.91|
2025|Mar       |     34361.88|
2025|Apr       |     37851.54|
2025|May       |     64143.13|
2025|Jun       |     40653.51|
2025|Jul       |     55853.60|
2025|Aug       |     59518.43|
2025|Sep       |     69746.13|
2025|Oct       |     27664.54|

5. `Product performance:` List the top 10 products by total sales quantity.

- Total sales quantity → how many units sold
- Total revenue → money generated
- Average order value or price → optional metric
- Avg. revenue per order (unit_price*quantity)

category   |product_name|tot_sales_quant|total_revenue|
:---       |:----       |:----         |:----        |
Sports     |How         |             83|     38613.26|
Clothing   |Dream       |             81|     11306.79|
Sports     |Sometimes   |             80|      5930.40|
Sports     |Identify    |             74|      1077.44|
Electronics|Growth      |             73|     32555.08|
Electronics|According   |             71|     34938.39|
Electronics|Society     |             71|     24627.77|
Electronics|For         |             71|      9446.55|
Clothing   |Reality     |             71|      2477.19|
Beauty     |Term        |             69|      31395.0|

6. `Customer loyalty / retention:` Which customer(s) placed more than 2 orders in the past 6 months? (assume current date)

customer_id 50 placed 3 orders

7. `Pricing analysis:` Find product categories whose average order item discount is greater than 10%.

category   |avg_order_disc|
:---       |:----         |
Sports     |          0.13|
Electronics|          0.11|
Clothing   |          0.10|

8. `Regional target checking:` Which regions have generated more than $1,500 in total sales? (number of large orders > 1,500)

region  |n_large_orders|
:---    |:----         |
North	|56            |
South	|54            |
West	|47            |
East	|30            |

9. `RFM-style segmentation:` Identify customers whose average order value is above the overall average. (TOP 5)

Customer_ID|avg_value   |
:---       |:----       |
79	       |6029.56 	|
13	       |4970.19 	|
175	       |4689.14 	|
122	       |4590.30 	|
40	       |4585.28 	|

10. `Catalog management:` Which products have never been sold?  
none.

11. `Regional sales by segment:` Find the total revenue per category and region for the last 6 months, showing only categories with total revenue above $10,000.

Category|Region   |Revenue    |
:---    |:----    |:---       |
Electronics	|South	|23193.20
Electronics	|North	|14162.02
Sports	|North	|13295.63
Sports	|South	|12845.50
Beauty	|North	|11737.99
Electronics	|West	|11221.70
Clothing	|North	|11150.49
Clothing	|West	|9357.06
Beauty	|East	|8240.88
Electronics	|East	|7519.98
Beauty	|West	|7455.81
Sports	|East	|6284.37
Clothing	|South	|6030.95
Sports	|West	|5975.30
Clothing	|East	|5945.52
Home	|South	|5067.63
Beauty	|South	|3967.40
Home	|North	|3894.20
Home	|West	|1346.14

12. `Cross-category affinity:` Which customers bought products from more than 3 categories?

13. `Promotion performance:` Calculate the average discount applied per product category, but only include categories with at least 50 items sold.

14. `Campaign analysis:` Identify the top 5 customers who spent the most during an active promotion period.

15. `Promo ROI :` For each promotion, calculate the total incremental revenue (total sales of that product during the promotion period).

16. `Post-campaign diagnostic:` Find products that had a promotion but still generated less than the average sales of their category.

17. `Trend evaluation:` List regions where the average order value increased month over month.

18.  `Cross-sell / market basket:` Find customers who bought both Electronics and Sports products.

19. `Market penetration:` Compute the total number of unique customers per category and identify categories that have at least 40 unique buyers.

20. `Pricing / margin impact:` Find the most discounted products (by total discount amount applied) in each category.