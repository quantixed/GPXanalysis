#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Needs XMLutils XOP installed

// Menu item for easy execution
Menu "Macros"
	"Running...",  RunGPXAnalysis()
	"Cycling...",  CyclingGPXAnalysis()
End

Function RunGPXAnalysis()
	LoadGPXFiles()
	MakeMasterWave()
	MakeMasterMatrix()
	PlotAllTracks()
	PlotOutTracks()
	FormatPlot("allTracks")
End

Function CyclingGPXAnalysis()
	LoadGPXFiles()
	PlotAllTracks()
	FormatPlot("allTracks")
	// ElevationChecker()
	CategorizeTracks()
	PlotCatTracks()
End

Function LoadGPXFiles()
	NewDataFolder/O/S root:data
	
	String expDiskFolderName, expDataFolderName
	String FileList, ThisFile, GPXFilePath
	Variable FileLoop, nWaves, i
	
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList=IndexedFile(expDiskFolder,-1,".gpx")
	Variable nFiles=ItemsInList(FileList)
	
	Make/O/T/N=(nFiles) root:FileName
	Make/O/T/N=(nFiles) root:DateWave
	Make/O/D/N=(nFiles) root:SecondWave
	Wave/T/Z FileName = root:FileName
	Wave/T/Z DateWave = root:DateWave
	Wave/Z SecondWave = root:SecondWave
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFolderName = ReplaceString(".gpx",ThisFile,"")
		NewDataFolder/O/S $expDataFolderName
		GPXReader(ExpDiskFolderName,ThisFile)
		FileName[FileLoop] = expDataFolderName
		WAVE/T/Z UTCWave
		DateWave[FileLoop] = 	UTCWave[0]
		WAVE/Z SecWave
		SecondWave[FileLoop] = SecWave[0]
		SetDataFolder root:data:
	endfor
	SetDataFolder root:
	// Now sort them into order of occurrence
	Sort SecondWave, SecondWave,DateWave,FileName
End

/// @param	ThisFile		string reference to gpx file
Function GPXReader(ExpDiskFolderName,ThisFile)
	String ExpDiskFolderName,ThisFile
	
	Variable fileID
	fileID = XMLopenfile(ExpDiskFolderName + ThisFile)
	xmlelemlist(fileID)
	WAVE/Z/T W_ElementList
	Variable nNodes
	
	nNodes = DimSize(W_ElementList,0)
	Make/O/N=(nNodes) latWave,lonWave
	String regExp = "lat:(.+);lon:(.+)"
	String latNum, lonNum, wName
 
	Variable i,j=0
	
	// parse W_elementlist
	for(i = 0; i < nNodes; i += 1)
		if(cmpstr(W_ElementList[i][3], "trkpt") == 0)
			SplitString/E=regExp W_ElementList[i][2], latNum, lonNum
			latWave[j] = str2num(latNum)
			lonWave[j] = str2num(lonNum)
			j += 1
		endif
	endfor
	// j is now last row so
	DeletePoints j, nNodes-j, latWave,lonWave
	// centre start at origin
	wName = ReplaceString(".gpx",ThisFile,"") + "_lat"
	Duplicate/O latWave, $wName
	Wave w0 = $wName
	w0 -= latWave[0]
	wName = ReplaceString("_lat",wName,"_lon")
	Duplicate/O lonWave, $wName
	Wave w0 = $wName
	w0 -= lonWave[0]
	
	// find elevation data, if it's there
	Duplicate/O/FREE/RMD=[][3,3] W_ElementList, elementcol
	FindValue/TEXT="ele"/Z elementCol
	if(V_Value >= 0)
		String xpathstr0 = W_ElementList[V_Value][0]
		// this will give something like /*/*[1]/*[2]/*[1]/*[1]
		// we need /*/*[1]/*[2]/*/*[1]
		// so trim 8 characters and add back last 5 characters
		// we could run it again and then compare the two strings for safety
		FindValue/TEXT="ele"/S=(V_Value+1)/Z elementCol
		String xpathstr1 = W_ElementList[V_Value][0]
		MakeXPathStr(xpathstr0,xpathstr1)
		// Now get string from MakeXPathStr
		SVAR xpathstr = root:gXpath
	endif
	XMLwaveFmXpath(fileID,xpathstr,"","")
	// transpose M_xmlcontent
	WAVE/Z/T M_XMLcontent
	nNodes = DimSize(M_XMLcontent,1)
	Make/O/N=(nNodes) elewave
	// convert
	for(i = 0; i < nNodes; i += 1)
		elewave[i] = str2num(M_XMLcontent[0][i])
	endfor
	
	// find elevation data, if it's there
	FindValue/TEXT="time"/Z elementCol
	if(V_Value >= 0)
		xpathstr0 = W_ElementList[V_Value][0]
		// this will give something like /*/*[1]/*[2]/*[1]/*[1]
		// we need /*/*[1]/*[2]/*/*[1]
		// so trim 8 characters and add back last 5 characters
		// we could run it again and then compare the two strings for safety
		FindValue/TEXT="time"/S=(V_Value+1)/Z elementCol
		xpathstr1 = W_ElementList[V_Value][0]
		MakeXPathStr(xpathstr0,xpathstr1)
	endif
	XMLwaveFmXpath(fileID,xpathstr,"","")
	// transpose M_xmlcontent
	WAVE/Z/T M_XMLcontent
	nNodes = DimSize(M_XMLcontent,1)
	Make/O/T/N=(nNodes) UTCwave
	
	for(i = 0; i < nNodes; i += 1)
		UTCwave[i] = M_XMLcontent[0][i]
	endfor
	ConvertUTC2Time(UTCWave)
	xmlclosefile(fileID,0)
End

// DateRead() is from IgorTunes
// 1 day is 86400 s
///	@param	UTCWave	Textwave containing UTC times
Function ConvertUTC2Time(UTCWave)
	Wave/T UTCWave
	
	Variable npts=numpnts(UTCWave)
//	if (npts == 0)
//		Print "No points detected for", UTCWave
//	endif
	Make/O/D/N=(npts) SecWave
	String expr="([[:digit:]]+)\-([[:digit:]]+)\-([[:digit:]]+)T([[:digit:]]+)\:([[:digit:]]+)\:([[:digit:]]+)Z"
	String yr,mh,dy,hh,mm,ss
	Variable i

	For(i = 0; i < npts; i += 1)
		SplitString /E=(expr) UTCWave[i], yr,mh,dy,hh,mm,ss
		SecWave[i]=date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
	EndFor
	// SetScale d 0, 0, "dat", SecWave
End

Function MakeMasterWave()
	// s = Start, e = End
	// dd = day, mm = month, yy = year
	// res = frequency per day, e.g. 2 = twice per day
	SetDataFolder root:
	Variable sdd = 01
	Variable smm = 01
	Variable syy = 2016
	Variable edd = 01
	Variable emm = 11
	Variable eyy = 2016
	Variable res = 2
	
	Prompt sdd, "Start day"
	Prompt smm, "Start month"
	Prompt syy, "Start year"
	Prompt edd, "End day"
	Prompt emm, "End month"
	Prompt eyy, "End year"
	Prompt res, "Frequency per day"
	DoPrompt "Specify", sdd,smm,syy,edd,emm,eyy,res
	
	Variable startsec = date2secs(syy, smm, sdd)
	Variable endsec = date2secs(eyy, emm, edd)
	
	Variable totalPts = ceil((endsec - startsec) / (86400 / res))
	Make/O/D/N=(totalPts) MasterWave = startsec + (p * (86400 / res))
End

Function MakeMasterMatrix()
	SetDataFolder root:
	WAVE/T/Z FileName
	WAVE/Z MasterWave, SecondWave
	Variable nSteps = numpnts(MasterWave)
	Variable nTracks = numpnts(FileName)
	Make/O/N=(nSteps,nTracks) MasterMatrix=0
	
	Variable i
	
	for (i = 0; i < nTracks; i += 1)
		FindLevel/Q/P MasterWave, SecondWave[i]
		if(V_flag == 0)
			MasterMatrix[V_LevelX][i] = round(65535)
			MasterMatrix[V_LevelX+1][i] = round((7/8)*65535)
			MasterMatrix[V_LevelX+2][i] = round((6/8)*65535)
			MasterMatrix[V_LevelX+3][i] = round((5/8)*65535)
			MasterMatrix[V_LevelX+4][i] = round((4/8)*65535)
			MasterMatrix[V_LevelX+5][i] = round((3/8)*65535)
			MasterMatrix[V_LevelX+6][i] = round((2/8)*65535)
			MasterMatrix[V_LevelX+7][i] = round((1/8)*65535)
			MasterMatrix[V_LevelX+8][i] = 10
		endif
	endfor
End

Function PlotAllTracks()	
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName, trkName, wList=""
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	
	DoWindow/K allTracks
	Display/N=allTracks
	
	Variable i
	// lat = y, lon = x
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		trkName = "root:data:" + folderName + ":" + folderName + "_lat"
		wList += trkName + ";"
		Wave latW = $trkName
		trkName = "root:data:" + folderName + ":" + folderName + "_lon"
		Wave lonW = $trkName
		AppendToGraph/W=allTracks latW vs lonW
	endfor
	wList = wList + ReplaceString("_lat",wList,"_lon")
	Concatenate/O wList, tempWave
	// Print wavemin(tempWave), wavemax(tempWave)
	Variable/G root:maxVar = max(abs(wavemin(tempWave)),abs(wavemax(tempWave)))
	KillWaves tempWave
End

Function PlotOutTracks()
	SetDataFolder root:
	Make/O/N=(2,2) dummyWave = {{0,0},{0,0}}
	DoWindow/K trkbytrk
	Display/N=trkbytrk/W=(0,0,500,500) dummyWave[][1] vs dummyWave[][0]
	ModifyGraph/W=trkbytrk rgb(dummyWave)=(65535,65535,65535)
	FormatPlot("trkbytrk")
	WAVE/T/Z DateWave,FileName
	WAVE/Z MasterWave,SecondWave,MasterMatrix
	Variable nSteps = DimSize(MasterMatrix,0)
	Variable nTracks = DimSize(MasterMatrix,1)
	String latName, lonName, wName, folderName, iString, tiffName
	NewPath/O/Q/M="Please find disk folder" OutputFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	
	Variable i,j
	
	for (i = 0; i < nSteps; i += 1)
		MatrixOP/O/FREE activeTrks = row(MasterMatrix,i)
		TextBox/C/N=datBox/F=0/B=1/G=(1,52428,26586)/X=0.00/Y=0.00 Secs2Date(MasterWave[i],0)
		if (sum(activeTrks) > 0)
			for (j = 0; j < nTracks; j += 1)
				if(MasterMatrix[i][j] > 0)
					folderName = ReplaceString(".gpx",FileName[j],"")
					wName = folderName + "_lat"
					if(MasterMatrix[i][j] == 65535)
						latName = "root:data:" + folderName + ":" + folderName + "_lat"
						lonName = "root:data:" + folderName + ":" + folderName + "_lon"
						AppendToGraph/W=trkbytrk $latName vs $lonName
						ModifyGraph/W=trkbytrk rgb($wName)=(65535,0,65535,65535)
					elseif(MasterMatrix[i][j] < 65535 && MasterMatrix[i][j] > 10)
						ModifyGraph/W=trkbytrk rgb($wName)=(65535,0,65535,MasterMatrix[i][j])
					elseif(MasterMatrix[i][j] == 10)
						RemoveFromGraph/W=trkbytrk $wName
					endif
				endif
			endfor
		endif
		// take snap
		DoUpdate
		DoWindow/F trkbytrk
		if(i == 0)
			NewMovie/O/P=OutputFolder/CTYP="jpeg"/F=15 as "trax"
		endif
		AddMovieFrame
		//save out pics for gif assembly in ImageJ
		if( i >= 0 && i < 10)
			iString = "000" + num2str(i)
		elseif( i >=10 && i < 100)
			iString = "00" + num2str(i)
		elseif(i >= 100 && i < 1000)
			iString = "0" + num2str(i)
		elseif(i >= 1000 && i < 10000)
			iString = num2str(i)
		endif
		tiffName = "trkbytrk" + iString + ".tif"
		SavePICT/P=OutputFolder/E=-7/B=288 as tiffName
	endfor
	CloseMovie
End

///	@param	gName		graph name
Function FormatPlot(gName)
	String gName
	NVAR/Z maxVar
	Variable limvar = maxVar
	
	SetAxis/W=$gName left -limVar,limVar
	SetAxis/W=$gName bottom -limVar,limVar
	ModifyGraph/W=$gName width={Plan,1,bottom,left}
	ModifyGraph/W=$gName gbRGB=(62258,62258,62258) // 5% grey
	ModifyGraph/W=$gName margin=5
	ModifyGraph/W=$gName noLabel=2
	ModifyGraph/W=$gName grid=1
	ModifyGraph/W=$gName gridStyle=1,gridHair=0
	ModifyGraph/W=$gName zero=1,zeroThick=2
	ModifyGraph/W=$gName manTick={0,0.02,0,2},manMinor={0,50}
	ModifyGraph/W=$gName axRGB=(65535,65535,65535),tlblRGB=(65535,65535,65535),alblRGB=(65535,65535,65535),gridRGB=(65535,65535,65535)
End

///	@param	xpathstr0		first xpath for comparison
///	@param	xpathstr1		second xpath for comparison
Function MakeXPathStr(xpathstr0,xpathstr1)
	String xpathstr0
	String xpathstr1
	
	String ss0,ss1
	
	String/G root:gXpath
	SVAR xpathstr = root:gXpath
	Variable nChar0 = strlen(xpathstr0)
	Variable nChar1 = strlen(xpathstr1)
	
	if (nChar0 != nChar1)
		Print "XPath lengths unequal"
	endif
	
	Variable i,j
	
	for (i = 0; i < nChar0; i += 1)
		ss0 = xpathstr0[i,i]
		ss1 = xpathstr1[i,i]
		if(cmpstr(ss0,ss1) != 0)
			j = i
			break
		endif
	endfor
	xpathstr = xpathstr0[0,j-2] + xpathstr0[j+2,nChar0-1]
End

Function ElevationChecker()
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName, trkName="", wList=""
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	
	Variable i
	// lat = y, lon = x, ele = z
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		trkName = "root:data:" + folderName + ":latWave"
		Wave w = $trkName
		if(WaveExists(w) == 1)
			wList += trkName + ";"
		endif
	endfor
	Concatenate/O/NP wList, root:xW
	Print ItemsInList(wList)
	wList=""	
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		trkName = "root:data:" + folderName + ":lonWave"
		Wave w = $trkName
		if(WaveExists(w) == 1)
			wList += trkName + ";"
		endif
	endfor
	Concatenate/O/NP wList, root:yW
	Print ItemsInList(wList)
	wList=""	
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		trkName = "root:data:" + folderName + ":eleWave"
		Wave w = $trkName
		if(WaveExists(w) == 1)
			wList += trkName + ";"
		else
			Print "failed on", foldername
		endif
	endfor
	Concatenate/O/NP wList, root:zW
	Print ItemsInList(wList)
End

// Tracks can be A to C via B = ABC or C to A via D
// Everything else to be discarded
Function CategorizeTracks()
	MakeABCCDA()	//external function
	WAVE/Z modelWave = root:modelWave
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName, trkName="", wList=""
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	Make/O/N=(numDataFolders) root:catWave=0
	Wave catWave = root:catWave
	// 1 = ABC, 2 = CDA
	Make/O/T/N=(numDataFolders) root:catTrackWave
	Wave/T catTrackWave = root:catTrackWave
	Variable npts,aTest,bTest,cTest,dTest
		
	Variable i
	// lat = y, lon = x, ele = z
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		catTrackWave[i] = folderName
		trkName = "root:data:" + folderName + ":latWave"
		Wave latW = $trkName
		trkName = "root:data:" + folderName + ":lonWave"
		Wave lonW = $trkName
		npts = numpnts(latW)
		aTest = sqrt((latW[0] - modelWave[0][0])^2 + (lonW[0] - modelWave[0][1])^2)
		cTest = sqrt((latW[npts-1] - modelWave[2][0])^2 + (lonW[npts-1] - modelWave[2][1])^2)
		if((aTest + cTest) < 0.002)
			bTest = sqrt((latW[ceil(npts/2)] - modelWave[1][0])^2 + (lonW[ceil(npts/2)] - modelWave[1][1])^2)
			if(bTest < 0.004)
				catWave[i] = 1
			endif
		else
			cTest = sqrt((latW[0] - modelWave[2][0])^2 + (lonW[0] - modelWave[2][1])^2)
			aTest = sqrt((latW[npts-1] - modelWave[0][0])^2 + (lonW[npts-1] - modelWave[0][1])^2)
			if((cTest + aTest) < 0.002)
				dTest = sqrt((latW[ceil(npts/2)] - modelWave[3][0])^2 + (lonW[ceil(npts/2)] - modelWave[3][1])^2)
				if(dTest < 0.004)
					catWave[i] = 2
				endif
			endif
		endif
	endfor
End

Function PlotCatTracks()
	SetDataFolder root:
	DoWindow/K tracksABC
	DoWindow/K tracksCDA
	DoWindow/K tracksOther
	Display/N=tracksABC
	Display/N=tracksCDA
	Display/N=tracksOther
	WAVE/T/Z catTrackWave
	WAVE/Z catWave
	Variable nTracks = numpnts(catTrackWave)
	String trackName, latName, lonName
	
	Variable i
	
	for(i = 0; i < nTracks; i += 1)
		trackName = catTrackWave[i]
		latName = "root:data:" + trackName + ":latWave"
		lonName = "root:data:" + trackName + ":lonWave"
		if(catWave[i] == 0)
			AppendToGraph/W=tracksOther $latName vs $lonName
		elseif(catWave[i] == 1)
			AppendToGraph/W=tracksABC $latName vs $lonName
		elseif(catWave[i] == 2)
			AppendToGraph/W=tracksCDA $latName vs $lonName
		endif
	endfor
	FormatPlot("tracksABC")
	FormatPlot("tracksCDA")
	FormatPlot("tracksOther")
	// maxvar is no good
	SetAxis/W=tracksABC left 52.35,52.4
	SetAxis/W=tracksABC bottom -1.605,-1.535
	SetAxis/W=tracksCDA left 52.35,52.4
	SetAxis/W=tracksCDA bottom -1.605,-1.535
	SetAxis/W=tracksOther left 52.35,52.4
	SetAxis/W=tracksOther bottom -1.605,-1.535
End

Function PlotCatEle()
	SetDataFolder root:
	DoWindow/K eleABC
	DoWindow/K eleCDA
	Display/N=eleABC
	Display/N=eleCDA
	WAVE/T/Z catTrackWave
	WAVE/Z catWave
	Variable nTracks = numpnts(catTrackWave)
	String trackName, eleName
	
	Variable i
	
	for(i = 0; i < nTracks; i += 1)
		trackName = catTrackWave[i]
		eleName = "root:data:" + trackName + ":eleWave"
		if(catWave[i] == 1)
			AppendToGraph/W=eleABC $eleName
		elseif(catWave[i] == 2)
			AppendToGraph/W=eleCDA $eleName
		endif
	endfor
	// requires previous load
	WAVE/Z canonABC
	WAVE/Z canonCDA
	AppendToGraph/W=eleABC canonABC[][2]
	AppendToGraph/W=eleCDA canonCDA[][2]
	ModifyGraph/W=eleABC rgb(canonABC)=(0,0,0)
	ModifyGraph/W=eleCDA rgb(canonCDA)=(0,0,0)
End

Function MakeTopo()
	SetDataFolder root:
	WAVE/T/Z catTrackWave
	WAVE/Z catWave
	Variable nTracks = numpnts(catTrackWave)
	String trackName, latName
	String latListABC=""
	String latListCDA=""
	
	Variable i
	
	for(i = 0; i < nTracks; i += 1)
		trackName = catTrackWave[i]
		latName = "root:data:" + trackName + ":latWave"
		if(catWave[i] == 1)
			latListABC += latName + ";"
		elseif(catWave[i] == 2)
			latListCDA += latName + ";"
		endif
	endfor
	Concatenate/O/NP latListABC, topoABCy
	Concatenate/O/NP ReplaceString("latW",latListABC,"lonW"), topoABCx
	Concatenate/O/NP ReplaceString("latW",latListABC,"eleW"), topoABCz
	Concatenate/O/KILL {topoABCx,topoABCy,topoABCz},topoABC
	//
	Concatenate/O/NP latListCDA, topoCDAy
	Concatenate/O/NP ReplaceString("latW",latListCDA,"lonW"), topoCDAx
	Concatenate/O/NP ReplaceString("latW",latListCDA,"eleW"), topoCDAz
	Concatenate/O/KILL {topoCDAx,topoCDAy,topoCDAz},topoCDA
End