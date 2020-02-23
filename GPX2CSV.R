library(XML)
library(lubridate)
library(raster)
shift.vec <- function (vec, shift) {
  if(length(vec) <= abs(shift)) {
    rep(NA ,length(vec))
  }else{
    if (shift >= 0) {
      c(rep(NA, shift), vec[1:(length(vec)-shift)]) }
    else {
      c(vec[(abs(shift)+1):length(vec)], rep(NA, abs(shift))) } } }
# Parse the GPX file
gpxfile <- file.choose()
pfile <- htmlTreeParse(gpxfile,error = function (...) {}, useInternalNodes = T)
elevations <- as.numeric(xpathSApply(pfile, path = "//trkpt/ele", xmlValue))
times <- xpathSApply(pfile, path = "//trkpt/time", xmlValue)
coords <- xpathSApply(pfile, path = "//trkpt", xmlAttrs)
lats <- as.numeric(coords["lat",])
lons <- as.numeric(coords["lon",])
geodf <- data.frame(lat = lats, lon = lons,time = times)
rm(list=c("elevations", "lats", "lons", "pfile", "times", "coords"))
geodf$lat.p1 <- shift.vec(geodf$lat, -1)
geodf$lon.p1 <- shift.vec(geodf$lon, -1)
geodf$dist.to.prev <- apply(geodf, 1, FUN = function (row) {
    pointDistance(c(as.numeric(row["lon.p1"]),
                    as.numeric(row["lat.p1"])),
                  c(as.numeric(row["lon"]), as.numeric(row["lat"])),
                  lonlat = T)
})
geodf$time <- strptime(geodf$time, format = "%Y-%m-%dT%H:%M:%OS")
geodf$time.p1 <- shift.vec(geodf$time, -1)
geodf$time.diff.to.prev <- as.numeric(difftime(geodf$time.p1, geodf$time))
head(geodf)
write.csv(geodf,'geodf.csv')