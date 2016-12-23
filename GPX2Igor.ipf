#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
// Needs XMLutils XOP installed
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
	Wave/T/Z FileName = root:FileName
	Wave/T/Z DateWave = root:DateWave
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		//NewPath/O/Q GPXFilePath, ExpDiskFolderName + ThisFile
		expDataFolderName = ReplaceString(".gpx",ThisFile,"")
		NewDataFolder/O/S $expDataFolderName
		GPXReader(ExpDiskFolderName,ThisFile)
		FileName[FileLoop] = expDataFolderName
		WAVE/T/Z w0
		DateWave[FileLoop] = 	w0[0]
		SetDataFolder root:data:
	endfor
	SetDataFolder root:
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
	
	XMLwaveFmXpath(fileID,"/*/*[1]/*[2]/*/*[1]","","")
	// transpose M_xmlcontent
	WAVE/Z/T M_XMLcontent
	nNodes = DimSize(M_XMLcontent,1)
	Make/O/T/N=(nNodes) w0
	
	for(i = 0; i < nNodes; i += 1)
		w0[i] = M_XMLcontent[0][i]
	endfor
	// convert to date/time
End