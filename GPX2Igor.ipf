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
	Sort SecWave, SecWave,UTCWave,FileName
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
	String latNum, lonNum
 
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
	Duplicate/O latWave, latWave_n
	Duplicate/O lonWave, lonWave_n
	latWave_n -= latWave[0]
	lonWave_n -= lonWave[0]
	
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

Function PlotAllTracks()	
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName, trkName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	
	DoWindow/K allTracks
	Display/N=allTracks
	
	Variable i
	// lat = y, lon = x
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		trkName = "root:data:" + folderName + ":" + "latWave_n"
		Wave latW = $trkName
		trkName = "root:data:" + folderName + ":" + "lonWave_n"
		Wave lonW = $trkName
		AppendToGraph/W=allTracks latW vs lonW
	endfor
End