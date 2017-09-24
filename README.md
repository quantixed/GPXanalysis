# GPXanalysis
Analysis of GPX tracks using IgorPro

Requires XMLUtiles XOP for Igor, available [here](http://www.igorexchange.com/project/XMLutils).

These functions will load and parse a directory of gpx files. Igor will plot out all the tracks and also allow you to pick an interval to make a movie of tracks in that period. It will export a movie (`*.mov` with jpeg compression) and a sequence of TIFFs at 4X screen resolution (this is so you can assemble a `*.gif` version).

Now there are versions for looking at Running and Cycling. The running analysis is tested only on GPX tracks exported from rubitrack and recorded using a Garmin watch. Export was automated using `Rubitrack Export.scpt`. This is an applescript which runs from the Users Scripts folder and works with card view in rubiTrack 4 Pro. The cycling analysis is quite bespoke (sorry) and requires an external procedure to run properly.

--

## CumulativeTime
Rubitrack can output a single GPX file with multiple tracks. This can be read into R and then the cumulative time per year calculated using IGOR. This is an attempt to do this.

For R:

```R
library(XML)
library(lubridate)
shift.vec <- function (vec, shift) {
	if(length(vec) <= abs(shift)) {
	rep(NA ,length(vec))
	}else{
	if (shift >= 0) {
	c(rep(NA, shift), vec[1:(length(vec)-shift)]) }
	else {
	c(vec[(abs(shift)+1):length(vec)], rep(NA, abs(shift))) } } }
# Parse the GPX file
pfile <- htmlTreeParse("~/Desktop/allactivities.gpx",error = function (...) {}, useInternalNodes = T)
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
geodf$time <- strptime(geodf$time, format = "%Y-%m-%dT%H:%M:%OS")
geodf$time.p1 <- shift.vec(geodf$time, -1)
geodf$time.diff.to.prev <- as.numeric(difftime(geodf$time.p1, geodf$time))
head(geodf)
write.csv(geodf,'geodf.csv')
```