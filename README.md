# GPXanalysis
Analysis of GPX tracks using IgorPro

Requires XMLUtiles XOP for Igor, available [here](http://www.igorexchange.com/project/XMLutils).

These functions will load and parse a directory of gpx files. Igor will plot out all the tracks and also allow you to pick an interval to make a movie of tracks in that period. It will export a movie (`*.mov` with jpeg compression) and a sequence of TIFFs at 4X screen resolution (this is so you can assemble a `*.gif` version).

Now there are versions for looking at Running and Cycling. The running analysis is tested only on GPX tracks exported from rubitrack and recorded using a Garmin watch. Export was automated using `Rubitrack Export.scpt`. This is an applescript which runs from the Users Scripts folder and works with card view in rubiTrack 4 Pro. The cycling analysis is quite bespoke (sorry) and requires an external procedure to run properly.