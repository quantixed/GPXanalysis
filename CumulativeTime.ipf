#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Read single gpx file containing multiple tracks into R. Organise timepoints in data frame and export
// Read csv into Igor, only timeW is needed
// Make/N=(numpnts(timeW))/D numericTS
// numericTS = test( timeW[p] )


// Converts a text string 2014-01-01 08:10:01 to IgorTime
Function test(instring)
	String instring
 
	Variable year, month, day,hour,minute,second
	sscanf instring, "%4d%*[-]%2d%*[-]%2d%*[ ] %2d%*[:] %2d%*[:]%5f", year, month, day,hour,minute,second
 
	return  date2secs(year, month, day ) + hour*3600+minute*60 +second
end

// Input years to look at e.g. 2007,2017
Function HowLong(firstY,lastY)
	Variable firstY,lastY
	
	String wName
	
	Variable yy,mm,dd, i
	
	for(yy = firstY; yy < lastY + 1; yy += 1)
		wName = "year_" + num2str(yy)
		Make/O/D/N=(12*31) $wName
		Wave w0 = $wName
		i = 0
		for(mm = 1; mm < 13; mm += 1)
			for(dd = 1; dd < 32; dd += 1)
				w0[i] = date2secs(yy,mm,dd)
				i += 1
			endfor
		endfor
	endfor
End

// This runs Slooooww. Could do something more sophisticated, but this was the 1st attempt
Function ParseAndAdd()
	WAVE/Z numericTS
	WAVE/Z time_diff_to_prev
	Duplicate/O time_diff_to_prev, diffsec
	diffsec = (abs(time_diff_to_prev[p]) < 14400) ? time_diff_to_prev[p] : 0
	String wList = WaveList("year_*",";","")
	Variable nWaves = ItemsInList(wList)
	String wName,newName
	Variable jMax,loVar,hiVar
	Make/O/FREE/N=(numpnts(numericTS)) sumW
	
	Variable i, j
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i, wList)
		Wave w0 = $wName
		jMax = numpnts(w0)
		newName = ReplaceString("year_",wName,"time_")
		Duplicate/O w0, $newName
		Wave w1 = $newName
		for(j = 0; j < jMax; j += 1)
			loVar = w0[j]
			if(j == jMax -1)
				hiVar = loVar + 24*3600
			else
				hiVar = w0[j+1]
			endif
			sumW = (numericTS[p] >= loVar && numericTS[p] < hiVar) ? diffsec[p] : 0
			w1[j] = sum(sumW)
		endfor
	endfor
End

// This function could be added or chained to ParseAndAdd
Function Accumulate()
	String wList = WaveList("time_2*",";","") // kludge
	Variable nWaves = ItemsInList(wList)
	String wName,newName
	KillWindow/Z timePlot
	Display/N=timePlot
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i, wList)
		Wave w0 = $wName
		newName = ReplaceString("time_",wName,"cum_")
		Duplicate/O w0, $newName
		Wave w1 = $newName
		Integrate/METH=0 w1
		AppendToGraph/W=timePlot w1
	endfor
End