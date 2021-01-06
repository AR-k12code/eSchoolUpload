try {
	#Run Download Definition for Student Emails
	Start-Process -FilePath 'powershell.exe' -ArgumentList 'c:\scripts\eSchoolUpload\eSchoolDownload.ps1 -username 0000cmillsap -reportname "studentemails" -outputfile studentemails.csv -InterfaceID STEML -Verbose' -Wait -NoNewWindow
	
	#Match student id's to AD and pull email address.
	$eschoolcids = Import-Csv studentemails.csv -Header ID,email,CID,LastName,FirstName
	$adstudents = Get-ADUser -Filter { Enabled -eq $True } -SearchBase "OU=Students,DC=gentry,DC=local" -Properties EmployeeNumber,Mail

	$students = ''
	$webaccessflag = ''
	$eschoolcids | ForEach-Object {
		$studentid = $PSItem.'ID' #eSchool contact ID
		try {
			$student = $adstudents | Where-Object { $_.EmployeeNumber -eq $studentid }
		} catch {
			return #no match found
		}

		if ($PSItem.'email' -ne $student.Mail) {
			$students += "$($PSItem.'CID'),$($student.'Mail'),$($student.'EmployeeNumber')`r`n"
		}
		
		$webaccessflag += "$($PSItem.'CID'),$($student.'EmployeeNumber'),M`r`n"
		
	}

	Out-File -Encoding ASCII -InputObject $students -FilePath studentemailsimport.csv -Force -NoNewline
	Out-File -Encoding ASCII -InputObject $webaccessflag -FilePath webaccessflag.csv -Force -NoNewline

	if ((Import-Csv studentemailsimport.csv -Header 'Contact ID','Student Email','Student ID' | Measure-Object).Count -ge 1) {
		#Upload the matched ID's csv and run Upload Definition.
		Start-Process -FilePath 'powershell.exe' -ArgumentList 'c:\scripts\eSchoolUpload\eSchoolUpload.ps1 -username 0000cmillsap -InFile studentemailsimport.csv -InterfaceID EMAIL -RunMode R -Verbose' -Wait -NoNewWindow
	}

	#Upload the web access flag and run the upload definition
	Start-Process -FilePath 'powershell.exe' -ArgumentList 'c:\scripts\eSchoolUpload\eSchoolUpload.ps1 -username 0000cmillsap -InFile webaccessflag.csv -InterfaceID WEBAC -RunMode R -Verbose' -Wait -NoNewWindow


	#Generating HAC logins requires the eSchoolUpload definition to finish so it needs to be scheduled in the future.
	#Start-Process -FilePath 'powershell.exe' -ArgumentList 'c:\scripts\eSchoolUpload\eSchoolGenerateHACLogins.ps1 -username 0000cmillsap -buildings """13,15,703""" -addtime 10 -Verbose' -Wait -NoNewWindow
} catch {
	write-host "Failed somewhere."
}