<#

Craig Millsap
Gentry Public Schools
3/11/2021

This script will verify that eSchool students have the generated AD email address on their eSchool Account.
It will also make sure that the WEB_ACCESS flag is set on their account.

Be sure you created the Download and Upload Definitions before running this.
.\Definitions\Create_Definitions.ps1 should make them for you.

Please don't edit this file unless you're pushing code back to the Github repository.
It makes helping you later a LOT harder. These scripts are designed to be invoked from another script.
If you need a modification please contact one of the AR-k12code developers.

#>

Param(
    [parameter(Mandatory=$false,Helpmessage="eSchool username")][string]$username,
    [parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")][string]$passwordfile="C:\Scripts\apscnpw.txt",
	[parameter(Mandatory=$false,HelpMessage="What AD Field Contains your Student ID?")][string]$ADField="EmployeeNumber"
)

try {
	
	#Login and store $eSchoolSession
	. .\eSchool-Login.ps1 -username $username -passwordfile $passwordfile
	
	#Run Download Definition for Student Emails
	. .\eSchoolDownload.ps1 -reportname "student email download" -outputfile "$PSScriptRoot\temp\studentemails.csv" -InterfaceID EMLDL
	
	#Get AD Accounts and build Hash Table on $ADField
	$adAccounts = Get-ADUser -Filter { Enabled -eq $True -and $ADField -like "*" } -Properties $ADField,Mail | Group-Object -Property $ADField -AsHashTable

	#Match student id's to AD and pull email address.
	$eSchoolStudents = Import-Csv "$PSScriptRoot\temp\studentemails.csv"
	
	$records = @()
	$webaccess = @()

	$eSchoolStudents | ForEach-Object {

		$student = $PSItem
		$studentId = $PSitem.'STUDENT_ID'

		if ($adAccounts.$studentId) {

			#Check for mismatched email address. Then add to $records to be exported to csv later.
			$adEmailAddress = ($adAccounts.$studentId).Mail
			if ($adEmailAddress -ne $student.'EMAIL') {
				
				$records += [PSCustomObject]@{
					CONTACT_ID = $student.'CONTACT_ID'
					EMAIL = $adEmailAddress
				}
		
			}

			if ($student.'WEB_ACCESS' -ne 'Y') {
				#Always ensure students webaccess flag is enabled.
				$webaccess += [PSCustomObject]@{
					CONTACT_ID = $student.'CONTACT_ID'
					STUDENT_ID = $studentId
					WEB_ACCESS = 'Y'
					CONTACT_TYPE = 'M'
				}
			}

		} else {
			Write-Host "Error: No Active Directory account found for $studentId"
		}
	}
		
	if ($records.Count -ge 1) {

		Write-Host "Info: Found $($records.Count) mismatched or missing email addresses in eSchool. Uploading."
		#Export CSV without header row.
		$records | ConvertTo-CSV -UseQuotes Never -NoTypeInformation | Select-Object -Skip 1 | Out-File "$PSScriptRoot\temp\student_email_upload.csv" -Force
		. .\eSchoolUpload.ps1 -InFile "$PSScriptRoot\temp\student_email_upload.csv" -InterfaceID EMLUP -RunMode R

	}

	if ($webaccess.Count -ge 1) {
		#Create Web Access Flag CSV and Run EMLWA
		$webaccess | ConvertTo-CSV -UseQuotes Never -NoTypeInformation | Select-Object -Skip 1 | Out-File "$PSScriptRoot\temp\webaccess_upload.csv" -Force
		. .\eSchoolUpload.ps1 -InFile "$PSScriptRoot\temp\webaccess_upload.csv" -InterfaceID EMLAC -RunMode R -addtime 0
	}
		
} catch {
	write-host "Error: $_"
}