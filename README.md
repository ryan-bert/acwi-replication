# ACWI Futures Replication

This project aims to replicate the returns of the **MSCI ACWI ETF (ACWI)** using a selection of futures contracts. The approach involves **Ordinary Least Squares (OLS) regression** optimization to determine the optimal futures weights for tracking the ACWI index.

## **How It Works**
The `replication.R` script performs the following steps:

1. **Load ETF and Futures Data**  
   - Reads daily returns data from CSV files.  
   - Filters relevant futures contracts:  
     - `ES` (S&P 500 E-mini)  
     - `NQ` (Nasdaq 100 E-mini)  
     - `VG` (Euro Stoxx 50)  
     - `NK` (Nikkei 225)  
     - `MFS` (MSCI EAFE)  
     - `MES` (MSCI Emerging Markets)  
     - `XU` (FTSE China A50)  

2. **Preprocess Data**  
   - Filters data to the common available date range.  
   - Handles missing values by replacing `NA` returns with `0`.  

3. **Optimize Futures Weights**  
   - Uses a **rolling 60-day window** to estimate the best futures weights that minimize tracking error.  
   - Implements **Convex Optimization (CVXR)** to determine the optimal portfolio allocation.  

4. **Construct and Evaluate the Portfolio**  
   - Combines ETF and futures return data.  
   - Computes **cumulative returns** for both the ACWI ETF and the optimized portfolio.  
   - Plots **cumulative return comparison** (`cumulative_returns.png`).  
   - Generates a **scatter plot** comparing Portfolio vs. ACWI returns (`scatter_plot.png`).  
   - Runs a **linear regression** to measure tracking effectiveness.  

## Output & Results
- The optimized futures portfolio aims to track the ACWI ETF’s returns.
- The cumulative return plot shows how well the portfolio replicates ACWI.
- The scatter plot and regression model analyze tracking accuracy.

## Future Improvements
- Add transaction cost modeling.
- Optimize with a constraint on maximum weight per future.
- Explore alternative weighting methods (e.g., ridge regression, Lasso).