#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Needs XMLutils XOP installed

// Menu item for easy execution
Menu "Macros"
	"GPX Analysis...",  GPXAnalysis()
End

Function GPXAnalysis()
	LoadGPXFiles()
	MakeMasterWave()
	MakeMasterMatrix()
	PlotAllTracks()
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
	
	XMLwaveFmXpath(fileID,"/*/*[1]/*[2]/*/*[1]","","")
	// transpose M_xmlcontent
	WAVE/Z/T M_XMLcontent
	nNodes = DimSize(M_XMLcontent,1)
	Make/O/T/N=(nNodes) UTCwave
	
	for(i = 0; i < nNodes; i += 1)
		UTCwave[i] = M_XMLcontent[0][i]
	endfor
	ConvertUTC2Time(UTCWave)
End

// DateRead() is from IgorTunes
// 1 day is 86400 s
///	@param	UTCWave	Textwave containing UTC times
Function ConvertUTC2Time(UTCWave)
	Wave/T UTCWave
	
	Variable npts=numpnts(UTCWave)
	Make/O/D/N=(npts) SecWave
	String expr="([[:digit:]]+)\-([[:digit:]]+)\-([[:digit:]]+)T([[:digit:]]+)\:([[:digit:]]+)\:([[:digit:]]+)Z"
	String yr,mh,dy,hh,mm,ss
	Variable i

	For(i = 0; i < npts; i += 1)
		SplitString /E=(expr) UTCWave[i], yr,mh,dy,hh,mm,ss
		SecWave[i]=date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
	EndFor
	SetScale d 0, 0, "dat", SecWave
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
			MasterMatrix[V_LevelX+1][i] = round(0.75*65535)
			MasterMatrix[V_LevelX+2][i] = round(0.5*65535)
			MasterMatrix[V_LevelX+3][i] = round(0.25*65535)
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
	FormatPlot("allTracks")
	PlotOutTracks()
	KillWaves tempWave
End

Function PlotOutTracks()
	
	SetDataFolder root:
	DoWindow/K trkbytrk
	Display/N=trkbytrk
	FormatPlot("trkbytrk")
	WAVE/T/Z DateWave,FileName
	WAVE/Z MasterWave,SecondWave,MasterMatrix
	Variable nSteps = DimSize(MasterMatrix,0)
	Variable nTracks = DimSize(MasterMatrix,1)
	String latName, lonName, wName, folderName
	
	Variable i,j
	
	for (i = 0; i < nSteps; i += 1)
		MatrixOP/O/FREE activeTrks = row(MasterMatrix,i)
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
					elseif(MasterMatrix[i][j] == round(0.75*65535))
						ModifyGraph/W=trkbytrk rgb($wName)=(65535,0,65535,round(0.75*65535))
					elseif(MasterMatrix[i][j] == round(0.5*65535))
						ModifyGraph/W=trkbytrk rgb($wName)=(65535,0,65535,round(0.5*65535))
					elseif(MasterMatrix[i][j] == round(0.25*65535))
						ModifyGraph/W=trkbytrk rgb($wName)=(65535,0,65535,round(0.25*65535))
					endif
				endif
			endfor
		endif
		// take snap
	endfor
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