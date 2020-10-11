library(trackeR)
library(ggplot2)
library(zoo)
library(hms)

# select a gpx file
filepath <- file.choose()
runDF <- readGPX(file = filepath, timezone = "GMT")

# calculate point-to-point distance from the cumulative distance
runDF$dist_point <- c(0,diff(runDF$distance, lag=1))
# time calculations
runDF$time_temp <- strptime(runDF$time, format = "%Y-%m-%d %H:%M:%S")
runDF$time_point <- c(0,diff(as.vector(runDF$time_temp), lag=1))
#runDF$time_temp <- NULL
#runDF$time_cumulative <- cumsum(runDF$time_point)
#runDF$time_hms <- as_hms(runDF$time_cumulative)
# speed in m/s
runDF$speed <- runDF$dist_point / runDF$time_point
# replace NaNs with 0
runDF[is.na(runDF)] <- 0
write.csv(runDF,'Output/Data/runDF.csv')
