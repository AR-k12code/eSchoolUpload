# eSchoolUpload
<#
eSchool Upload Script
tldr:This script logs into eSchool, navigates to the Upload File page, uploads a file to your user directory, and then kicks off an upload interface process.
This requires a completed and ready file to upload, and a pre-built upload processes in eSchool for the last leg.  Not exactly an API, but it does build the last bridge needed for automating data into eSchool.

The initial use case for this was uploading and then inserting/updating student emails into their mailing contact records.
Our office folks often mis-type student email address, or don't put them in at all, and then those records don't come accross to Clever, iStation, etc., causing various issues for students.

Created: 5/7/2019 (first working version)
-Ben Janelle

Usage
-------------------------------------------------------------------------
Parameters: School Year, Upload file name/path, username, password, run mode (optional, only needed if automating upload interface), interface ID (optional, only needed if automating upload interface)

From PowerShell ex: C:\Scripts\eSchoolStudentEmail\eSchoolStudentEmail.ps1 2019 'C:\ImportFiles\eSchoolStudentEmail\ModifiedForUpload\names.txt' 5805bjanelle AwesomeDISpwNOspecials V UpSEm
From cmd or batch file ex: powershell.exe -executionpolicy bypass -file C:\ImportFiles\Scripts\eSchoolUpload3.ps1 


Troubleshooting command examples
-------------------------------------------------------------------------
$form | Format-List :Shows the form method, action, and fields (with what they're currently set to, if space allows)
$form.Fields  :Shows all the individual fields, and what they're currently set to

Could also do something like: $response.Forms[0] | Format-List

Sources
-------------------------------------------------------------------------
"Man" page (specifically "Example 2"): https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-4.0
Decent general overview of Invoke-WebRequest: https://www.adamtheautomator.com/invoke-webrequest-powershell/
For multipart/form-data I used a (way) simplified version of: http://blog.majcica.com/2016/01/13/powershell-tips-and-tricks-multipartform-data-requests/

Special thanks to all the Cognos Downloader folks.  I don't even know who all did that initial work, but you proved there was a way!
#>
