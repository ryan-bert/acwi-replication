library(dplyr)
library(readr)
library(tidyr)

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