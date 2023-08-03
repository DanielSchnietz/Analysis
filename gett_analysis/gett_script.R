library(dplyr)
library(ggplot2)
library(plotly)
library(lubridate)
library(DataExplorer)
library(tidyverse)
library(hrbrthemes)
options(dplyr.summarise.inform = FALSE)

data_offers <- read.csv("data_offers.csv")
data_orders <- read.csv("data_orders.csv")

# Task 1:
# Build up distribution of orders according to reasons for failure: 
# cancellations before and after driver assignment, and reasons for order rejection. 
# Analyse the resulting plot. Which category has the highest number of orders?

#list summary of data
summary(data_orders)

glimpse(data_orders)

#show missing values by column
plot_missing(data_orders)


# 7902 out of 10716 rows got NA in column m_order_eta.
# 3409 out of 10716 rows got NA in cancellations_time_in_seconds.
# Therefore i will drop m_order_eta for further analysis.
# This results from eta only being available after a driver is assigned. 


#create subframe to work with
subset_frame <- subset(data_orders, select = -c(m_order_eta))

#replace cancel reason key with words
subset_frame <- subset_frame %>% 
  mutate(order_status_key = ifelse(order_status_key == 4, "client", "system")) %>%
  mutate(is_driver_assigned_key = ifelse(is_driver_assigned_key == 0, FALSE, TRUE))


# order by order_status and driver_assigned_status and create distribution

cancel_reason_before_assignment <- subset_frame %>%
  group_by(is_driver_assigned_key, order_status_key) %>%
  summarise(reason = n()) %>%
  ungroup() %>% 
  ggplot(aes(x=order_status_key, y=reason, fill = is_driver_assigned_key)) + 
  geom_bar(position = 'dodge', stat='identity') + 
  geom_text(aes(label=reason), position=position_dodge(width=0.9), vjust=-0.25)+
  labs(y = "count", x = "canceled order by:", fill = "driver assigned") +
  ggtitle("Orders canceled by cient / system before / after driver assignment")

  

#Plot the distribution of failed orders by hours. 
# Is there a trend that certain hours have an abnormally high proportion of one category or another? 
# What hours are the biggest fails? How can this be explained?
orders_by_daytime <- subset_frame %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H"), canceled_by = order_status_key) %>%
  summarise(canceled_orders = n()) %>%
  ungroup() 

orders_by_daytime %>%
  ggplot(aes(x = time, y = canceled_orders, group = canceled_by, colour=canceled_by)) +
  geom_line(linewidth = 2) +
  geom_point() +
  ggtitle("canceled orders by hour")
        

#filter na's' out of cancellations_time.
#will not create values for missing rows as there are <30% values missing.

filtered <- subset_frame %>%
  filter(!is.na(cancellations_time_in_seconds))

# Plot the average time to cancellation with and without driver, by the hour. 
# If there are any outliers in the data, it would be better to remove them. 
# Can we draw any conclusions from this plot?

filtered %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H")) %>%
  ggplot(aes(time, cancellations_time_in_seconds)) +
  geom_boxplot(fill = "#0c4c8a") +
  theme_minimal()

subset_frame %>% 
  summary(cancellations_time_in_seconds)

#get values considered as outlier
out <- boxplot.stats(filtered$cancellations_time_in_seconds)$out
out

plot_correlation(na.omit(filtered), type = "c")


#get rows of outleirs
out_ind <- which(filtered$cancellations_time_in_seconds %in% c(out))
out_ind
#verify times considered as outliers
filtered[out_ind, ]

#filter outliers
outlier_filtered <- filtered %>% 
  filter(!(rownames(filtered) %in% out_ind))


#validating data is without outliers

outlier_filtered %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H")) %>%
  ggplot(aes(time, cancellations_time_in_seconds)) +
  geom_boxplot(fill = "#0c4c8a") +
  theme_minimal()

#plot mean by hour
avg_time_data <- outlier_filtered %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H"), driver_assigned = is_driver_assigned_key) %>%
  summarise(mean_time = mean(cancellations_time_in_seconds)) %>%
  ungroup() 

avg_time_plot <- avg_time_data %>%
  ggplot(aes(x = time, y = mean_time, group = driver_assigned, colour = driver_assigned)) +
  geom_line(linewidth = 2) +
  ggtitle("time until cancellation mean by hour") +
  labs(x="time(h)", y="mean_time(s)")
avg_time_plot
#calc IQR
#iqr <- quantile(subset_frame$cancellations_time_in_seconds, 0.75, na.rm = TRUE) - quantile(subset_frame$cancellations_time_in_seconds, 0.25, na.rm = TRUE)

#validate insights on correlations
class(avg_time_data$time)
avg_time_data["time"] <- sapply(avg_time_data["time"],as.numeric)

cor_data <- avg_time_data %>%
  mutate(canceled_orders = orders_by_daytime$canceled_orders)

plot_correlation(na.omit(cor_data))


#Plot the distribution of average ETA by hours. How can this plot be explained?
#NOTICE: This data only represents the data for the "driver_assigned" == TRUE key
filtered_na <- data_orders %>%
  filter(!is.na(m_order_eta)) 

avg_eta_data <- filtered_na %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H")) %>%
  summarise(mean_eta = mean(m_order_eta)) %>%
  ungroup() 

avg_eta_plot <- avg_eta_data %>%
  ggplot(aes(x = time, y = mean_eta, group = 1)) +
  geom_line(linewidth = 2, color="red") +
  ggtitle("eta mean by hour")




