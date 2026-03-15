# Supermart Grocery EDA 🔍

**Complete 8-Phase SQL Exploratory Data Analysis** of Tamil Nadu grocery delivery app orders (2015-2018). Reveals ₹14.96Cr revenue patterns, 25% profit margins, and actionable business strategies.

## 🎯 Key Findings

| Metric | Value |
|--------|-------|
| **Total Revenue** | ₹14.96 Crores |
| **Total Profit** | ₹37.47 Lakhs |
| **Profit Margin** | 25.0% |
| **Orders** | 9,994 |
| **Avg Order Value** | ₹1,497 |

**All 7 categories = "Star performers"** (25%+ margins). Top cities: Vellore, Bodi, Kanyakumari.

## 📁 Project Structure

supermart-grocery-eda/
├── data/
│ ├── supermart_dataset_cleaned.csv # Cleaned dataset (9,994 orders)
│ └── phase-7-outputs/ # CSV exports (Executive Summary, Category Strategy, etc.)
├── sql/
│ └── supermart_orders_eda.sql # Complete 8-phase SQL pipeline
├── reports/
│ └── Supermart_Sales_Analytics_Report.md # Stakeholder presentation
├── README.md
└── LICENSE


## 🚀 8-Phase EDA Pipeline

1. **Database Setup** → MySQL `supermart_db.orders`
2. **Data Understanding** → 50 customers, 20 cities, 17 categories
3. **Feature Engineering** → Profit margin, recency, year/month
4. **Univariate Analysis** → Sales ₹50-2500, 25% margin distribution
5. **Bivariate Analysis** → Category/Region correlations
6. **Top Performers** → Customer/City/Category leaders
7. **Business Insights** → Growth trends, discount optimization
8. **Export Pipeline** → BI-ready CSVs

## 📊 Business Insights

### Category Performance
Snacks: ₹22.4L sales | ₹5.68L profit | 25.3% margin ⭐
Eggs/Meat: ₹22.7L sales | ₹5.67L profit | 24.9% margin ⭐

**All categories profitable** → Balanced portfolio strategy.

### Location wise Opportunities
Vellore: ₹6.77L sales | 25.6% margin
Bodi: ₹6.67L sales | 26.0% margin
Kanyakumari: ₹7.07L sales | 24.3% margin

**Top 3 cities = 50% profit potential**.

### Discount Strategy
10% discount → 24.9% margin
20% discount → 25.3% margin
30% discount → 24.8% margin

**Safe up to 30%** → Test 35% tier.

## 🎯 Strategic Recommendations

1. **Push All Categories** → Cross-promote bundles (Snacks+Meat)
2. **Geo Focus** → Vellore/Bodi/Kanyakumari marketing
3. **Win-back Campaign** → Top 20 churned customers (₹3L+ each)
4. **Festive Stock-up** → 2x Q4 inventory (historical peaks)
5. **Discount Pilot** → Test 35% tier in low-risk categories

## 🛠️ Tech Stack

```sql
MySQL Workbench → 8-Phase EDA → CSV Export → Power BI/Tableau
Key functions: STR_TO_DATE(), NTILE(), LAG(), window functions

📊 Sample Output
-- Top Customer Lifetime Value
Customer Name | Orders | Total Profit
Mathew        | 224    | ₹3,34,361
Alan          | 227    | ₹3,33,351

