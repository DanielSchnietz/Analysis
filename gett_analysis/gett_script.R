library(dplyr)
library(ggplot2)
library(plotly)
library(lubridate)
library(DataExplorer)
library(tidyverse)
library(hrbrthemes)
library(ggthemes)
options(dplyr.summarise.inform = FALSE)

data_orders <- read.csv("C:/Users/dschn/IdeaProjects/analystpreperation/gett_analysis/data_orders.csv")

#-------------------------preprocessing----------------------------------------------------------
#orders
summary(data_orders)
glimpse(data_orders)

plot_missing(data_orders)
theme_normal <- theme_set(theme_economist())
theme_tilted <- theme_set(theme_economist())
#create subset
subset_frame <- data_orders %>%
  rename(order_eta = m_order_eta, 
         driver_assigned = is_driver_assigned_key,
         order_canceled_by = order_status_key,
         order_id = order_gk) %>%
  mutate(order_canceled_by = ifelse(order_canceled_by == 4, "client", "system")) %>%
  mutate(driver_assigned = ifelse(driver_assigned == 0, FALSE, TRUE)) %>%
  mutate(order_canceled_by = as.factor(order_canceled_by))

#No driver assigned at this point. Therefore no eta
missing_etas <- subset_frame %>%
  filter(is.na(order_eta)) %>%
  group_by(order_canceled_by, 
           driver_assigned) %>%
  summarise(count = n()) %>%
  ungroup()

#order never approved and canceled beforehand by the system. Therefore no cancellations_time
missing_cancellations_time <- subset_frame %>%
  filter(is.na(cancellations_time_in_seconds)) %>%
  group_by(order_canceled_by, 
           driver_assigned) %>%
  summarise(count = n()) %>%
  ungroup()

subset_frame <- subset_frame %>%
  mutate(order_eta = replace_na(order_eta, 0)) %>%
  mutate(cancellations_time_in_seconds = replace_na(cancellations_time_in_seconds, 0)) %>%
  mutate(eta_missingness = ifelse(order_eta == 0, TRUE, FALSE), 
            cancellations_time_missingness = ifelse(cancellations_time_in_seconds == 0, TRUE, FALSE))

duplicates_orders <- subset_frame %>%
  filter(duplicated(.))

#--------------------------------end of preprocessing-----------------------------------------------------------------------------

# Build up distribution of orders according to reasons for failure: 
# cancellations before and after driver assignment, and reasons for order rejection. 
# Analyse the resulting plot. Which category has the highest number of orders?


# order by order_status and driver_assigned_status and create distribution

cancel_reason_before_assignment <- subset_frame %>%
  group_by(driver_assigned, order_canceled_by) %>%
  summarise(count = n()) %>%
  ungroup() %>% 
  ggplot(aes(x=order_canceled_by, y=count, fill = driver_assigned)) + 
  geom_bar(position = 'dodge', stat='identity') + 
  geom_text(aes(label=count), position=position_dodge(width=0.9), vjust=-0.25)+
  labs(y = "count(n)", x = "canceled order by", fill = "driver assigned") +
  ggtitle("Orders canceled by cient / system") +
  theme_set(theme_normal)

cancel_reason_before_assignment  

#Plot the distribution of failed orders by hours. 
# Is there a trend that certain hours have an abnormally high proportion of one category or another? 
# What hours are the biggest fails? How can this be explained?
orders_by_daytime <- subset_frame %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H:%M"), canceled_by = order_canceled_by) %>%
  summarise(canceled_orders = n()) %>%
  ungroup() 

theme_set(theme_tilted)
theme_update(axis.text.x = element_text(angle = 60, size = 8, vjust = 1))

orders_by_daytime %>%
  ggplot(aes(x = time, y = canceled_orders, group = canceled_by, colour=canceled_by, fill = canceled_by)) +
  geom_bar(stat='identity') +
  ggtitle("canceled orders by hour") 
        


# Plot the average time to cancellation with and without driver, by the hour. 
# If there are any outliers in the data, it would be better to remove them. 
# Can we draw any conclusions from this plot?

#get values considered as outlier
filtered <- subset_frame %>%
  filter(!cancellations_time_missingness)

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


#verify data is without outliers

outlier_filtered %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H:%M")) %>%
  ggplot(aes(time, cancellations_time_in_seconds)) +
  geom_boxplot(fill = "#0c4c8a")

#plot mean by hour
avg_time_data <- outlier_filtered %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H"), driver_assigned = driver_assigned) %>%
  summarise(mean_time = mean(cancellations_time_in_seconds)) %>%
  ungroup() 

avg_time_plot <- avg_time_data %>%
  ggplot(aes(x = time, y = mean_time, group = driver_assigned, colour = driver_assigned)) +
  geom_line(linewidth = 2) +
  ggtitle("time until cancellation mean by hour") +
  labs(x="time(h)", y="mean_time(s)")
avg_time_plot

#verify insights on correlations
class(avg_time_data$time)
avg_time_data["time"] <- sapply(avg_time_data["time"],as.numeric)

cor_data <- avg_time_data %>%
  mutate(canceled_orders = orders_by_daytime$canceled_orders)

plot_correlation(na.omit(cor_data))


#Plot the distribution of average ETA by hours?
#NOTICE: This data only represents the data for the "driver_assigned" == TRUE key
filtered_eta <- subset_frame %>%
  filter(!eta_missingness)

avg_eta_data <- filtered_eta %>%
  group_by(time = format(floor_date(as.POSIXct(order_datetime, format="%H:%M"), "hour"),format="%H:%M")) %>%
  summarise(mean_eta = mean(order_eta)) %>%
  ungroup() 

avg_eta_plot <- avg_eta_data %>%
  ggplot(aes(x = time, y = mean_eta, group = 1)) +
  geom_bar(stat="identity", fill = "blue") +
  ggtitle("eta mean by hour")

avg_eta_plot


