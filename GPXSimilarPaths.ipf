#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

// The aim is to analyse performance over a given course.
// Igor finds similar tracks and clusters them and plots speed or pace over time
// This is a similar feature as on Strava
// Start by read a single gpx file containing multiple tracks into R,
// organise timepoints in a data frame and export.
// Use the correct menu item to read in the csv file from R.

// Notes:
//	The cluster cut-off is manual and may need altering for different courses
// 	This version does not (yet) use the hierarchical clustering and dendrogram functions
// which are coming in IGOR Pro 9

Menu "Macros"
	"GPX Clusters (Run)", FindSimilarPathsRun()
	"GPX Clusters (Cycle)", FindSimilarPathsCycle()
End


Function FindSimilarPathsRun()
	if(LoadCSVFromR() < 0)
		return -1
	else
		ConstructIgorTimeWave()
	endif
	ParseTracks()
	MakeUniTracks(64)
	CompareTracks()
	DendrogramGenerator()
	IdentifyClusters(0.02,5)
	PlotOutAllClusters(0)
	StandardPace()
	MakeTheLayouts("clust",6,2, rev = 1, saveIt = 0, sorted = 1)
End

Function FindSimilarPathsCycle()
	if(LoadCSVFromR() < 0)
		return -1
	else
		ConstructIgorTimeWave()
	endif
	ParseTracks()
	MakeUniTracks(64)
	CompareTracks()
	DendrogramGenerator()
	IdentifyClusters(5,5)
	PlotOutAllClusters(1)
	MakeTheLayouts("clust",6,2, rev = 1, saveIt = 0, sorted = 1)
End

STATIC Function LoadCSVFromR()
	Variable refNum
	String fileName
	String filters = "csv File (*.csv):.csv;"
	filters += "All Files:.*;"
	Open/D/R/F=filters/M="Select csv file from R" refNum
	fileName = S_fileName			// S_fileName is set by Open/D
	if (strlen(fileName) == 0)		// User cancelled?
		return -1
	endif
	LoadWave/A/W/J/D/O/K=0/L={0,1,0,0,0}/Q fileName
	return 0
End

Function ConstructIgorTimeWave()
	WAVE/Z/T timeW
	Make/N=(numpnts(timeW))/D numericTS
	numericTS = str2IgorTime(timeW[p])
End

// Converts a text string 2014-01-01 08:10:01 to IgorTime
STATIC Function Str2IgorTime(instring)
	String instring
 
	Variable year, month, day, hour, minute, second
	sscanf instring, "%4d%*[-]%2d%*[-]%2d%*[ ] %2d%*[:] %2d%*[:]%5f", year, month, day, hour, minute, second
 
	return  date2secs(year, month, day ) + hour * 3600 + minute * 60 + second
end

// This function will make individual tracks from the long list of data
Function ParseTracks()
	WAVE/Z numericTS
	WAVE/Z time_point, longitude, latitude, dist_point
	// make two waves containing the start and end of each track
	Make/O/N=(numpnts(time_point)) endRow
	// big time interval at the *beginning* of a track so we do p - 1
	endRow[] = (abs(time_point[p]) > 14400) ? p - 1 : NaN
	WaveTransform zapnans endRow
	Variable nTracks = numpnts(endRow)
	Make/O/I/N=(nTracks) startRow = 0
	startRow[1,*] = endRow[p - 1] + 1 // +1, it's the integer after the endRow
	
	String trackName
	Make/O/N=(nTracks)/D tkTotalDistance, tkTotalTime, tkDate
	
	Variable i
	// slice up the tracks
	for(i = 0; i < nTracks; i += 1)
		sprintf trackName, "track%04d", i
		Duplicate/O/RMD=(startRow[i],endRow[i])/FREE latitude, w0
		Duplicate/O/RMD=(startRow[i],endRow[i])/FREE longitude, w1
		Project w1,w0
		WAVE/Z W_XProjection, W_YProjection
		Concatenate/O/NP=1/KILL {W_XProjection,W_YProjection}, $trackName
		// get the cumulative distance
		trackName = ReplaceString("track",trackName,"dist")
		Duplicate/O/RMD=(startRow[i],endRow[i]) dist_point, $trackName
		Integrate/METH=0 $trackName
		// summary data
		tkDate[i] = numericTS[startRow[i] + 1] // taking next row since not certain that this row lines up with start
		SetScale d 0,0,"dat", tkDate
		tkTotalTime[i] = sum(time_point, startRow[i] + 1, endRow[i])
		tkTotalDistance[i] = sum(dist_point, startRow[i] + 1, endRow[i])
	endfor
	// calculate pace
	MatrixOp/O tkPace = tkTotalTime / tkTotalDistance
	tkPace *= 1000 // to s per km
	SetScale d 0,0,"dat", tkPace
	// calculate speed
	MatrixOp/O tkSpeed = tkTotalDistance / tkTotalTime
	tkSpeed *= 3600 / 1000 // to km per h
	
	// now clean up
	String cleanList = WaveList("*",";","") // all waves
	cleanList = RemoveFromList(WaveList("track*",";",""),cleanList)
	cleanList = RemoveFromList(WaveList("dist*",";",""),cleanList)
	cleanList = RemoveFromList(WaveList("tk*",";",""),cleanList)
	
	for(i = 0; i < ItemsInList(cleanList); i += 1)
		KillWaves/Z $(StringFromList(i,cleanList))
	endfor
	
	return 0
End

// this function will make uniformly sampled 2d coords
Function MakeUniTracks(nPoints)
	Variable nPoints
	String wList = WaveList("track*",";","")
	Variable nWaves = ItemsInList(wList)
	String xyName, distName
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		xyName = StringFromList(i, wList)
		Wave xyW = $xyName
		Duplicate/O/RMD=[][0]/FREE xyW, xW
		Duplicate/O/RMD=[][1]/FREE xyW, yW
		distName = ReplaceString("track",xyName,"dist")
		Wave distW = $distName
		if(DimSize(xyW,0) > 2)
			Interpolate2/T=1/N=(nPoints)/Y=xuW distW, xW
			Interpolate2/T=1/N=(nPoints)/Y=yuW distW, yW
			Concatenate/O/NP=1/KILL {xuW,yuW}, $("u_" + xyName)
		else
			Make/O/N=(nPoints,2) $("u_" + xyName)
			Wave fakeW = $("u_" + xyName)
			fakeW[][0] = xW[0]
			fakeW[][1] = yW[0]
		endif
	endfor
	
	return 0
End

// This is a wrapper to compare each uniTrack to every other track
// to generate a dissimilarity matrix
Function CompareTracks()
	String wList = WaveList("u_track*",";","")
	Variable nWaves = ItemsInList(wList)
	Make/O/D/N=(nWaves,nWaves) dissMatrix = NaN
	String wName0, wName1
	
	Variable i, j
	
	for(i = 0; i < nWaves; i += 1)
		wName0  = StringFromList(i, wList)
		Wave w0 = $wName0
		
		for(j = 0; j < nWaves; j += 1)
			if(i == j)
				continue
			endif
			wName1  = StringFromList(j, wList)
			Wave w1 = $wName1
			dissMatrix[i][j] = GetDissimilarity(w0,w1)
		endfor
	endfor
	
	return 0
End

STATIC Function GetDissimilarity(w0,w1)
	Wave w0,w1
	MatrixOp/O/FREE tempW = w0 - w1
	MatrixOp/O/FREE dissW = sqrt(sumRows(tempW * tempW))
	return mean(dissW)
End

Function DendrogramGenerator()
	WAVE/Z dissMatrix
	if(!WaveExists(dissMatrix))
		DoAlert 0, "No dissimilarity Matrix"
		return -1
	endif
	BuildDendrogram(dissMatrix)
	
	WAVE/Z DendPosX, DendPosY, ClusX
	WAVE/T/Z ClusXTxT
	KillWindow/Z dendro
	Display/N=dendro DendPosY vs DendPosX
	ModifyGraph/W=dendro userticks(bottom)={ClusX,ClusXTxT}
	ModifyGraph/W=dendro log(left)=1
	ModifyGraph/W=dendro rgb=(34952,34952,34952)
End

Function LookAt(number)
	Variable number	
	String trackName
	sprintf trackName, "u_track%04d", number
	Wave/Z w = $trackName
	if(!WaveExists(w))
		DoAlert 0, "No track of that name"
		return -1
	endif
	KillWindow/Z lookTrack
	Display/N=lookTrack w[][1] vs w[][0]
	ModifyGraph/W=lookTrack width={Aspect,1}
	ModifyGraph/W=lookTrack noLabel=2,axThick=0
	ModifyGraph/W=lookTrack margin=14
End

// calculates spherical distance between two points on earth given coords in decimal degrees
// uses haversine formula
// radius of earth is taken to be 6371 km (IUGG/WGS-84 mean)
Function SphericalDistanceBetweenTwoPoints(lat1, long1, lat2, long2)
	Variable lat1, long1, lat2, long2
	
	// convert inputs in degrees to radians
	lat1 *= pi/180
	long1 *= pi/180
	lat2 *= pi/180
	long2 *= pi/180
	
	Variable dlon = long1 - long2
	Variable dlat = lat1 - lat2
	Variable aa = ((sin(dlat / 2) ^ 2) + cos(lat1) * cos(lat2) * (sin(dlon / 2) ^ 2))
	Variable cc = 2 * atan2(sqrt(aa), sqrt(1 - aa))
	Variable dd = 6371 * cc
	
	// return distance in metres
	return dd * 1000
end

// Taken from https://www.wavemetrics.com/code-snippet/hierarchical-clustering-2-dendrogram
// Code snippet by AlonPolegPolsky
Function BuildDendrogram(wave DisSimilarityMatrix)
	Duplicate/O DisSimilarityMatrix, TempDisSimilarityMatrix	 // matrix that is reduced in size for each step
	Make/O/N=(dimsize(DisSimilarityMatrix,0))/T DendTxT = num2str(p), OrigDendTxT = num2str(p)   // original positions
	Make/O/N=(1,3)/T DendClusTxT = ""								 // saves the number of the original (unsorted) values
	Make/O/N=(1,3) DendClus = nan, DendClusX = nan					   // the magnitude of the clusters (y axis on a dendrogram)
	Make/O/N=(0)/T ClusXTxT
	Make/O/N=0 DendPosX, DendPosY										// waves that draw the dendrogram
	Variable run, clus
	// iterate over the dissimilarity matrix to find the smallest distance and remove that cell from the matrix
	for(run = 0; run < dimsize(DisSimilarityMatrix,0) - 1; run++)	   // over all cells in the dissimilarity matrix
		// for each iteration find the cell with the smallest distance (value)
		ImageStats/M=1 TempDisSimilarityMatrix
		Variable minloc = min(V_minColLoc,V_minRowLoc)				// removed row
		Variable maxloc = max(V_minColLoc,V_minRowLoc)				// removed col
		// set the columns and the rows on the smallest value cell to the max value of the corresponding row and column
		TempDisSimilarityMatrix[minloc][] = max(TempDisSimilarityMatrix[minloc][q],TempDisSimilarityMatrix[maxloc][q])		// find the max distance
		TempDisSimilarityMatrix[][minloc] = TempDisSimilarityMatrix[minloc][p]
		// save position information and start building the dendrogram
		InsertPoints 0, 1, DendClusTxT, DendClus, DendClusX
		DendClusTxT[0][0] = DendTxT[minloc]							   // info about child 1 (all the cells #)
		DendClusTxT[0][1] = DendTxT[maxloc]							   // info about child 2
		DendClusTxT[0][2] = DendClusTxT[0][0]+";"+DendClusTxT[0][1]   // parent - a list of all the cells in child1 and child 2
		// modify the positions for the dendrogram
		for(clus = 0; clus < numpnts(OrigDendTxT); clus++)
			if(stringmatch(OrigDendTxT[clus],DendClusTxT[0][0]))	// child 1 is a terminal branch
				InsertPoints numpnts(ClusXTxT), 1, ClusXTxT
				ClusXTxT[ numpnts(ClusXTxT) - 1 ] = OrigDendTxT[clus]   // save the original position
				DendClus[0][0] = 0
			endif
			if(stringmatch(OrigDendTxT[clus],DendClusTxT[0][1]))	// child 2 is a terminal branch
				InsertPoints numpnts(ClusXTxT), 1, ClusXTxT
				ClusXTxT[ numpnts(ClusXTxT) - 1 ] = OrigDendTxT[clus]   // save the original position
				DendClus[0][1] = 0
			endif		   
		endfor
		for(clus = 0; clus < dimsize(DendClusTxT,0); clus++)
			if(stringmatch(DendClusTxT[0][0],DendClusTxT[clus][2]))
				DendClus[0][0] = DendClus[clus][2]
			endif
			if(stringmatch(DendClusTxT[0][1],DendClusTxT[clus][2]))
				DendClus[0][1] = DendClus[clus][2]
			endif
		endfor	  
		// ready to remove the cell
		DendClus[0][2] = v_min
		DendTxT[minloc] = DendClusTxT[0][2]
		DendClusX[0][0] = DendMeanLoc(ClusXTxT,DendClusTxT[0][0])	 // X position info (for display only)
		DeletePoints/M=0 maxloc, 1, TempDisSimilarityMatrix, DendTxT
		DeletePoints/M=1 maxloc, 1, TempDisSimilarityMatrix
	endfor
	KillWaves/z TempDisSimilarityMatrix
	// normalize the dendrogram
	Variable PeakVal = wavemax(DendClus)
	DendClus = DendClus / PeakVal * 100
	Variable i
	// sort the dendrogram
	Make/O/N=(ItemsInList(DendClusTxT[0][2]))/T ClusXTxT
	String/g ClusSortedLocation=""
	for(i = 0; i < ItemsInList(DendClusTxT[0][2]); i++)
		ClusXTxT[i] = StringFromList(i,DendClusTxT[0][2])			 // new position
		ClusSortedLocation += ClusXTxT[i] + ";"
	endfor
	// drawing utilities
	for(clus = 0; clus < DimSize(DendClus,0); clus++)
		InsertPoints 0, 5, DendPosX, DendPosY							  // position of the branches
		DendPosX[0,1] = DendMeanLoc(ClusXTxT,DendClusTxT[clus][0])
		DendPosX[2,3] = DendMeanLoc(ClusXTxT,DendClusTxT[clus][1])
		DendPosX[4] = NaN
		DendPosY[0] = DendClus[clus][0]
		DendPosY[1,2] = DendClus[clus][2]
		DendPosY[3] = DendClus[clus][1]
		DendPosY[4] = NaN
	endfor	  
	// sorting
	Make/O/N=(numpnts(ClusXTxT)) ClusX = p								// just the position (p)
	Duplicate/O DisSimilarityMatrix, SortedDisSimilarityMatrix
	SortedDisSimilarityMatrix[][] = DisSimilarityMatrix[str2num(ClusXTxT[p])][str2num(ClusXTxT[q])]
End

// helper function
STATIC Function DendMeanLoc(DendTxT,matchSt)
	Wave/T DendTxT
	String matchSt
	Variable i, pos = 0, numpnt = 0
	for(i = 0; i < numpnts(DendTxT); i++)
		if(WhichListItem(DendTxT[i],matchSt) > -1)
			pos += i
			numpnt ++
		endif
	endfor
	
	return pos / numpnt
End

/// @param threshold	variable for detection of cluster (%)
///	@param	cSize		cluster size, number of tracks we call a cluster
Function IdentifyClusters(threshold, cSize)
	Variable threshold, cSize
	WAVE/Z DendClus
	WAVE/Z/T DendClusTxT
	Variable nRows = DimSize(DendClus,0)
	String clusterString
	
	Make/O/N=(nRows,2)/T/FREE tW = ""
	
	Variable i
	
	for(i = 0; i < nRows; i += 1)
		// skip if the child branch is above threshold of parent is below
		if(DendClus[i][0] > 0.02 && DendClus[i][1] > 0.02)
			continue
		elseif(DendClus[i][2] <= 0.02)
			continue
		endif
		// find child that is below threshold with parent above
		if(DendClus[i][2] > 0.02 && DendClus[i][0] <= 0.02)
			clusterString = DendClusTxT[i][0]
			if(ItemsInList(clusterString) >= cSize)
				tW[i][0] = clusterString
			endif
		endif
		// find child that is below threshold with parent above
		if(DendClus[i][2] > 0.02 && DendClus[i][1] <= 0.02)
			clusterString = DendClusTxT[i][1]
			if(ItemsInList(clusterString) >= cSize)
				tW[i][1] = clusterString
			endif
		endif
	endfor
	Redimension/N=(nRows * 2) tW
	Make/O/N=(nRows) clusterMembership = 0 // original track numbers are rows numbered by cluster number
	Variable clusterNumber = 0
	String str
	Variable j
	
	for(i = 0; i < (nRows * 2); i += 1)
		str = tW[i]
		if(strlen(str) == 0)
			continue
		else
			Wave/T tempW = ListToTextWave(str,";")
			clusterNumber += 1
			for(j = 0; j < numpnts(tempW); j += 1)
				clusterMembership[str2num(tempW[j])] = clusterNumber
			endfor
		endif
	endfor
	// visualise the clusters on the dendrogram by colouring the clusY wave
	Make/O/N=(nRows) spotsW=0.0005, spotsZ
	WAVE/Z/T ClusXTxT
	for(i = 0; i < nRows; i += 1)
		// find position on dendrogram
		FindValue/TEXT=num2str(i)/TXOP=2 ClusXTxT
		spotsZ[V_Value] = clusterMembership[i]
	endfor
	
	AppendToGraph/W=dendro spotsW
	ModifyGraph/W=dendro mode(spotsW)=3,marker(spotsW)=19,mrkThick(spotsW)=0,zColor(spotsW)={spotsZ,1,*,PastelsMap20,0},zColorMin(spotsW)=NaN
End

Function PlotOutAllClusters(runOrCycle)
	Variable runOrCycle
	
	WAVE/Z clusterMembership, tkDate, tkPace, tkSpeed, tkTotalDistance
	Variable nTracks = numpnts(clusterMembership)
	String plotName, trackName, wName
	
	Variable i
	// make the windows
	for(i = 1; i < WaveMax(clusterMembership) + 1; i += 1)
		plotName = "clust_" + num2str(i) + "_map"
		KillWindow/Z $plotname
		Display/N=$plotName/HIDE=1
	endfor
	
	WAVE/Z colorW
	if(!WaveExists(colorW))
		MakeTheColorWave()
		WAVE/Z colorW
	endif
	Variable xAxMin, xAxMax, xAxMean, yAxMin, yAxMax, yAxMean, halfRange
	
	for(i = 0; i < nTracks; i += 1)
		if(clusterMembership[i] == 0)
			continue
		endif
		// add track to appropriate cluster window
		sprintf trackName, "u_track%04d", i
		Wave/Z w = $trackName
		plotName = "clust_" + num2str(clusterMembership[i]) + "_map"
		AppendToGraph/W=$plotName w[][1] vs w[][0]
		ModifyGraph/W=$plotName zColor($trackName)={colorW,*,*,directRGB,0}
	endfor
	
	Variable j
	String wList, distString
	// format the plots
	for(i = 1; i < WaveMax(clusterMembership) + 1; i += 1)
		plotName = "clust_" + num2str(i) + "_map"
		wList = TraceNameList(plotName,";",1)
		for(j = 0; j < ItemsInList(wList); j += 1)
			wName = StringFromList(j,wList)
			WaveStats/Q/RMD=[][0] $wName
			if(j == 0)
				xAxMax = V_max
				xAxMin = V_min
			else
				xAxMax = max(V_max,xAxMax)
				xAxMin = min(V_min,xAxMin)
			endif
			WaveStats/Q/RMD=[][1] $wName
			if(j == 0)
				yAxMax = V_max
				yAxMin = V_min
			else
				yAxMax = max(V_max,yAxMax)
				yAxMin = max(V_min,yAxMin)
			endif
		endfor
			
		if((yAxMax - yAxMin) > (xAxMax - xAxMin))
			halfRange = (yAxMax - yAxMin) / 2
		else
			halfRange = (xAxMax - xAxMin) / 2
		endif
		xAxMean = (xAxMax + xAxMin) / 2
		yAxMean = (yAxMax + yAxMin) / 2
		SetAxis/W=$plotName bottom xAxMean - halfRange, xAxMean + halfRange
		SetAxis/W=$plotName left yAxMean - halfRange, yAxMean + halfRange
		ModifyGraph/W=$plotname width={Aspect,1}
		ModifyGraph/W=$plotname noLabel=2,axThick=0
		ModifyGraph/W=$plotname margin=14
		ModifyGraph/W=$plotname rgb=(0,0,0,32768)
		// use the last wName to find the distance, this is a horrible expression
		distString = num2str(round(tkTotalDistance[str2num(ReplaceString("u_track",wName,""))] / 100) / 10) + " km"
		TextBox/W=$plotname/C/N=text0/F=0/A=LB/X=0.00/Y=0.00 distString
	endfor
	// find the min and max for the plot
	Variable axMin = WaveMin(tkDate)
	Variable axMax = WaveMax(tkDate)
	if(runOrCycle == 0)
		Make/O/N=(5) paceAxTick = 240 + p * 30
		Make/O/N=(5)/T paceAxLabel = {"04:00","04:30","05:00","05:30","06:00"}
	endif
	// make the windows for pace, make the waves and plot
	for(i = 1; i < WaveMax(clusterMembership) + 1; i += 1)
		// make time wave for cluster
		if(runOrCycle == 0)
			plotName = "clust_" + num2str(i) + "_pace"
			wName = "pacecomp" + num2str(i) + "_t"
		else
			plotName = "clust_" + num2str(i) + "_speed"
			wName = "speedcomp" + num2str(i) + "_t"
		endif
		Duplicate/O tkDate, $wName
		Wave w0 = $wName
		w0[] = (clusterMembership[p] == i) ? tkDate[p] : NaN
		WaveTransform zapnans w0
		// make pace or speed wave for cluster
		if(runOrCycle == 0)
			wName = "pacecomp" + num2str(i)
			Duplicate/O tkPace, $wName
		else
			wName = "speedcomp" + num2str(i)
			Duplicate/O tkSpeed, $wName
		endif
		Wave w1 = $wName
		w1[] = (clusterMembership[p] == i) ? w1[p] : NaN
		WaveTransform zapnans w1
		
		KillWindow/Z $plotname
		Display/N=$plotName/HIDE=1 w1 vs w0
		// format the plot
		ModifyGraph/W=$plotName mode=3,marker=19,rgb=(0,0,0)
		ModifyGraph/W=$plotName dateInfo(bottom)={0,1,0}
		Label/W=$plotName bottom " "
		SetAxis/W=$plotName bottom axMin,axMax
		
		if(runOrCycle == 0)
			ModifyGraph/W=$plotName dateInfo(left)={0,2,0}
			Label/W=$plotName left "Pace (min/km)"
			SetAxis/W=$plotName left 240,360 // 4 min to 6 min per km
		else
			Label/W=$plotName left "Speed (km/h)"
			ModifyGraph/W=$plotName nticks(bottom)=10 // sample covered almost 10 years
			SetAxis/W=$plotName left 22,38 // 22 to 38 km per h
		endif
		
		ModifyGraph/W=$plotName userticks(left)={paceAxTick,paceAxLabel}
		ModifyGraph/W=$plotName grid=1,gridRGB=(43690,43690,43690)
		ModifyGraph/W=$plotName mrkThick=0,rgb=(0,0,0,32768)
	endfor
End

Function PlotOutAllTracks()
	String plotName = "allTracks"
	KillWindow/Z $plotname
	Display/N=$plotName
	
	String wList = WaveList("u_track*",";","")
	Variable nWaves = ItemsInList(wList)
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		Wave w = $(StringFromList(i,wList))
		AppendToGraph/W=$plotName w[][1] vs w[][0]
	endfor
End

STATIC Function MakeTheColorWave()
	// 64 point colorWave with 50% opacity
	Make/O/N=(64,4) colorW
	colorW[][0] = p / 63
	colorW[][1] = (63 - p) / 63
	colorW[][2] = 0.75
	colorW[][3] = 0.5
	colorW *=65535
End

Function StandardPace()
	String wList = WaveList("pacecomp*",";","")
	String tList = WaveList("pacecomp*_t",";","")
	wList = RemoveFromList(tList,wList)
	Variable nWaves = ItemsInList(wList)
	String wName, newName, zList = ""
	tList = ""
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,wList)
		Wave w0 = $wName
		newName = "z_" + wName
		Make/O/D/N=(numpnts(w0)) $newName
		Wave w1 = $newName
		w1[] = (w0[p] - mean(w0)) / sqrt(variance(w0))
		zList += newName + ";"
		tList += wName + "_t;"
	endfor
	Concatenate/O/KILL zList, standardPaceW
	Concatenate/O tList, standardPaceT
	
	// Smoothing
	Sort standardPaceT,standardPaceT,standardPaceW
	Duplicate/O standardPaceW,standardPaceW_smth
	Loess/V=2/SMTH=0.1/ORD=0 factors={standardPaceT}, srcWave= standardPaceW_smth
	// make the graph
	String plotname = "standardPlot"
	Display/N=$plotName standardPaceW vs standardPaceT
	ModifyGraph/W=$plotName mode=3,marker=19,rgb=(0,0,0,19661)
	ModifyGraph/W=$plotName dateInfo(bottom)={0,1,0}
	ModifyGraph/W=$plotName zero(left)=4
	Label/W=$plotName bottom " "
	SetAxis/A/N=1/E=2/W=$plotName left
	Label/W=$plotName left "Standard Pace (z)"
	AppendToGraph/W=$plotName standardPaceW_smth vs standardPaceT
	ModifyGraph/W=$plotName lsize(standardPaceW_smth)=4
	ModifyGraph/W=$plotName rgb(standardPaceW_smth)=(65535,0,0,32768)
End

Function MakeTheLayouts(prefix,nRow,nCol,[iter, filtVar, orient, rev, saveIt, sorted])
	String prefix
	Variable nRow, nCol
	Variable filtVar // this is the object we want to filter for
	Variable iter	// this is if we are doing multiple iterations of the same layout
	Variable orient //optional 1 = landscape, 0 or default is portrait
	Variable rev // optional - reverse plot order
	Variable saveIt
	Variable sorted // sort the list
	if(ParamIsDefault(filtVar) == 0)
		String filtStr = prefix + "_*_" + num2str(filtVar) + "_*"	// this is if we want to filter for this string from the prefix
	endif
	
	String layoutName = "all"+prefix+"Layout"
	DoWindow/K $layoutName
	NewLayout/N=$layoutName
	String allList = WinList(prefix+"*",";","WIN:1") // edited this line from previous version
	String modList = allList
	Variable nWindows = ItemsInList(allList)
	String plotName
	
	Variable i
	
	if(ParamIsDefault(filtVar) == 0)
		modList = "" // reinitialise
		for(i = 0; i < nWindows; i += 1)
			plotName = StringFromList(i,allList)
			if(stringmatch(plotName,filtStr) == 1)
				modList += plotName + ";"
			endif
		endfor
	endif
	nWindows = ItemsInList(modList)
	Variable PlotsPerPage = nRow * nCol
	String exString = "Tile/A=(" + num2str(ceil(PlotsPerPage/nCol)) + ","+num2str(nCol)+")"
	
	Variable pgNum=1
	
	if(ParamIsDefault(sorted) == 0)
		if(sorted == 1)
			modList = SortList(modList)
		endif
	endif	
	
	for(i = 0; i < nWindows; i += 1)
		if(ParamIsDefault(rev) == 0)
			if(rev == 1)
				plotName = StringFromList(nWindows - 1 - i,modList)
			else
				plotName = StringFromList(i,modList)
			endif
		else
			plotName = StringFromList(i,modList)
		endif
		AppendLayoutObject/W=$layoutName/PAGE=(pgnum) graph $plotName
		if(mod((i + 1),PlotsPerPage) == 0 || i == (nWindows -1)) // if page is full or it's the last plot
			if(ParamIsDefault(orient) == 0)
				if(orient == 1)
					LayoutPageAction size(-1)=(842,595), margins(-1)=(18, 18, 18, 18)
				endif
			else
				// default is for portrait
				LayoutPageAction/W=$layoutName size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
			endif
			ModifyLayout/W=$layoutName units=0
			ModifyLayout/W=$layoutName frame=0,trans=1
			Execute /Q exString
			if (i != nWindows -1)
				LayoutPageAction/W=$layoutName appendpage
				pgNum += 1
				LayoutPageAction/W=$layoutName page=(pgNum)
			endif
		endif
	endfor
	
	String fileName
	// if anthing is passed here we save an iteration, otherwise usual name
	if(!ParamIsDefault(iter))
		fileName = layoutName + num2str(iter) + ".pdf"
	else
		fileName = layoutName + ".pdf"
	endif
	// if anthing is passed here we save the filtered version
	if(ParamIsDefault(filtVar) == 0)
		fileName = ReplaceString(".pdf",fileName, "_" + num2str(filtVar) + ".pdf")
	endif
	if(ParamIsDefault(saveIt) == 0)
		if(saveIt == 1)
			SavePICT/O/WIN=$layoutName/PGR=(1,-1)/E=-2/W=(0,0,0,0) as fileName
		endif
	else
		// default is to save
		SavePICT/O/WIN=$layoutName/PGR=(1,-1)/E=-2/W=(0,0,0,0) as fileName
	endif
End