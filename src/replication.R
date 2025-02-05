suppressMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(CVXR)
  library(purrr)
  library(ggplot2)
  library(rstudioapi)
})

###################### FUNCTIONS ######################

# Optimization function
optimize_futures <- function(returns_df, n = 60) {

  print("Optimizing...")

  # Get the last n days of data
  recent_data <- returns_df %>%
    filter(Date >= max(Date) - n) %>%
    pivot_wider(
      id_cols = Date,
      names_from = .data$Ticker,
      values_from = .data$Return
    )

  # Separate dependent (ACWI) and independent (futures) variables
  y <- recent_data$ACWI
  x <- recent_data %>%
    select(-Date, -.data$ACWI)

  # Convert to matrix for optimization
  y <- as.matrix(y)
  x <- as.matrix(x)

  # Define optimization variables
  w <- Variable(ncol(x))

  # Define OLS loss function (sum of squared errors)
  loss <- sum_squares(y - x %*% w)

  # Define problem: Minimise OLS error
  problem <- Problem(Minimize(loss))

  # Solve the problem
  result <- solve(problem)

  # Extract optimised weights
  weights <- as.data.frame(result$getValue(w))
  weights$Futures <- colnames(x)
  colnames(weights) <- c("Weight", "Ticker")

  return(weights)
}

# Optimization function (runs for a specific date)
run_optimization <- function(data, target_date, n = 60) {
  # Filter for the last n days up to the target_date
  window_data <- data %>%
    filter(Date <= target_date) %>%
    filter(Date > target_date - n)

  # Run optimization only if we have enough data
  if (nrow(window_data) < n) return(NULL)

  # Run optimization and store results
  weights <- optimize_futures(window_data, n)
  weights$Date <- target_date  # Store the date of optimization
  return(weights)
}

######################### MAIN #########################

# Get current dir using $ofile
current_dir <- dirname(getActiveDocumentContext()$path)
plot_dir <- file.path(current_dir, "../plots")

# Load ETF and futures data
etf_df <- read_csv("~/Documents/Financial Data/daily_etf_index_returns.csv")
futures_df <- read_csv("~/Documents/Financial Data/daily_futures_returns.csv")

# Transform data to long-form
etf_df <- etf_df %>%
  pivot_longer(cols = -Date, names_to = "Ticker", values_to = "Return")
futures_df <- futures_df %>%
  pivot_longer(cols = -Date, names_to = "Ticker", values_to = "Return")

# Convert Date to Date class
etf_df$Date <- as.Date(etf_df$Date)
futures_df$Date <- as.Date(futures_df$Date)

# Select only MSCI ACWI ETF
etf_df <- etf_df %>%
  filter(Ticker == "ACWI")

# Select futures (independent variables):
# ES - S&P 500 E-mini
# NQ - Nasdaq 100 E-mini
# VG - Euro Stoxx 50
# NK - Nikkei 225 (Japan)
# MFS - MSCI EAFE Index (Developed markets ex-US)
# MES - MSCI Emerging Markets Index (BRICS + others)
# XU - FTSE China A50
futures_df <- futures_df %>%
  filter(Ticker %in% c("ES", "NQ", "VG", "NK", "MFS", "MES", "XU"))

# Combine ETF and futures data
combined_df <- bind_rows(etf_df, futures_df)

# Remove initial zero returns
combined_df <- combined_df %>%
  group_by(Ticker) %>%
  filter(cumsum(Return != 0) > 0) %>%
  ungroup()

# Find the maximum of all minimum dates
max_min_date <- combined_df %>%
  group_by(Ticker) %>%
  summarise(min_date = min(Date)) %>%
  summarise(max_min_date = max(min_date)) %>%
  pull(max_min_date)

# Find the minimum of all maximum dates
min_max_date <- combined_df %>%
  group_by(Ticker) %>%
  summarise(max_date = max(Date)) %>%
  summarise(min_max_date = min(max_date)) %>%
  pull(min_max_date)

# Filter data to the common date range
combined_df <- combined_df %>%
  filter(Date >= max_min_date) %>%
  filter(Date <= min_max_date)

# Turn NA returns to 0
combined_df$Return[is.na(combined_df$Return)] <- 0

################### RUN OPTIMIZATION ###################

# Define the dates we want to run optimization for
target_dates <- unique(combined_df$Date)

# Run optimization for each date using map_dfr
weights_df <- map_dfr(target_dates, ~ run_optimization(combined_df, .x, n = 60))

# Separate ACWI from futures data
futures_df_only <- combined_df %>%
  filter(Ticker != "ACWI")

acwi_returns <- combined_df %>%
  filter(Ticker == "ACWI") %>%
  select(Date, ACWI_Return = Return)

# Join weights with futures returns data
portfolio_df <- futures_df_only %>%
  inner_join(weights_df, by = c("Date", "Ticker")) %>%
  mutate(Weighted_Return = Return * Weight) %>%
  group_by(Date) %>%
  summarise(
    Portfolio_Return = sum(Weighted_Return, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  left_join(acwi_returns, by = "Date")

# Calculate cumulative returns
portfolio_df <- portfolio_df %>%
  mutate(
    Portfolio_Cumulative = cumsum(Portfolio_Return),
    ACWI_Cumulative = cumsum(ACWI_Return)
  )

# Plot cumulative returns
ggplot(portfolio_df, aes(x = Date)) +
  geom_line(aes(y = Portfolio_Cumulative, color = "Portfolio")) +
  geom_line(aes(y = ACWI_Cumulative, color = "ACWI")) +
  labs(
    title = "Portfolio vs. ACWI Cumulative Returns",
    y = "Cumulative Return",
    x = "Date"
  ) +
  scale_color_manual(values = c("Portfolio" = "blue", "ACWI" = "red"))
ggsave(file.path(plot_dir, "cumulative_returns.png"))

# Scatter plot of Portfolio vs. ACWI returns
ggplot(portfolio_df, aes(x = ACWI_Return, y = Portfolio_Return)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  labs(
    title = "Portfolio vs. ACWI Returns",
    x = "ACWI Return",
    y = "Portfolio Return"
  )
ggsave(file.path(plot_dir, "scatter_plot.png"))

# Do linear regression
lm_model <- lm(Portfolio_Return ~ ACWI_Return, data = portfolio_df)
print(summary(lm_model))