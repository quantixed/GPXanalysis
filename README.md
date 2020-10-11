# GPXanalysis

Analysis of GPX tracks using IgorPro

## GPXSimilarPaths

A workflow to find and compare similar running routes from a large database.

The inspiration is the Strava feature that allows runners to compare performance over the same course over time.

Starting point is a long gpx/xml output containing multiple tracks (tested on ~700 tracks).
The file is processed using `GPX2CSVwithTrackeR.R` to give a csv called `runDF.csv`.
This file is read by `GPXSimilarPaths.ipf`.

Igor parses all the tracks and compares them to find clusters of similar tracks.
For each cluster, a comparison of pace is done.

## GPX2Igor

Requires XMLUtiles XOP for Igor, available [here](http://www.igorexchange.com/project/XMLutils).

These functions will load and parse a directory of gpx files. Igor will plot out all the tracks and also allow you to pick an interval to make a movie of tracks in that period. It will export a movie (`*.mov` with jpeg compression) and a sequence of TIFFs at 4X screen resolution (this is so you can assemble a `*.gif` version).

Now there are versions for looking at Running and Cycling. The running analysis is tested only on GPX tracks exported from rubitrack and recorded using a Garmin watch. Export was automated using `Rubitrack Export.scpt`. This is an applescript which runs from the Users Scripts folder and works with card view in rubiTrack 4 Pro. The cycling analysis is quite bespoke (sorry) and requires an external procedure to run properly.

## CumulativeTime

Rubitrack can output a single GPX file with multiple tracks. This can be read into R and then the cumulative time per year calculated using IGOR. To read in the GPX file use `GPX2CSV.R`