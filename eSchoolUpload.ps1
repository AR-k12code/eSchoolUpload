#Charles Weber 1/27/2020
#Thank you to Ben Janelle for the base script
#V1 convert from args to parameters
#V1 configured to use same password file as Cognosdownload script if on the same machine
#V1 Testing the flexible $currentyear to dynamically set the school year based off the current month.

Parameter(
[paramater(Position=0,mandatory=$false,Helpmessage="Optional year input will default to current school year")]
[String]$CurrentYear = (IF((Get-date).month -le "6") {(Get-date).year} else {(Get-date).year+1}),
[paramater(Position=1,mandatory=$true,Helpmessage="What file do you want to upload")]
[String]$InFile = "C:\scripts\Mass-EmailUpdate-Eschool.csv", #***Variable*** Change to default upload file if you want to specify one
[paramater(Position=2,mandatory=$false,Helpmessage="Eschool username")]
[String] $username = "Schoolaccount", #***Variable*** Change to default eschool usename
[paramater(Position=3,mandatory=$false,Helpmessage="Run mode, V for verfiy and R to commit data changes to eschool")][ValidateSet("R","V")]
[String]$RunMode = "V",
[paramater(Position=4,mandatory=$false,Helpmessage="Interface upload Definition to run")]
[String]$InterfaceID, #**Variable** Default upload definition you want to call, can be found on the upload/download defintiion Interface ID
[parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")]
[string]$passwordfile="C:\Scripts\apscnpw.txt" #--- VARIABLE --- change to a file path for SSO password
)

If ((Test-Path ($passwordfile))) {
    $password = Get-Content $passwordfile | ConvertTo-SecureString
}
Else {
    Write-Host("Password file does not exist! [$passwordfile]. Please enter a password to be saved on this computer for scripts") -ForeGroundColor Yellow
    Read-Host "Enter Password" -AsSecureString |  ConvertFrom-SecureString | Out-File $passwordfile
    $password = Get-Content $passwordfile | ConvertTo-SecureString
}
# ---------------------------------------------------------------------------------------------------------------------
# Various URL variables.  Up top for when SunGard inevitably changes them all... --------------------------------------
$baseUrl = "https://eschool40.esp.k12.ar.us/eSchoolPLUS40/"
$loginUrl = "https://eschool40.esp.k12.ar.us/eSchoolPLUS40/Account/LogOn?ReturnUrl=%2feSchoolPLUS40%2f"
$envUrl = "https://eschool40.esp.k12.ar.us/eSchoolPLUS40/Account/SetEnvironment/SessionStart"
$uploadUrl = "https://eschool40.esp.k12.ar.us/eSchoolPLUS40/Utility/UploadFile"
$runuploadUrl = "https://eschool40.esp.k12.ar.us/eSchoolPLUS40/Utility/RunUpload"

# ---------------------------------------------------------------------------------------------------------------------

#Grab the eSchool login page and create websession
$response = Invoke-WebRequest -Uri $loginUrl -SessionVariable rb

#Get the first HTML <form> element on the page (login form in this case)
$form = $response.Forms[0]

#Set the username and password fields for the session
$form.Fields["UserName"] = $username
$form.Fields["Password"] = $password

#Login to eSchool with the created session (which now includes username/password)
$response2 = Invoke-WebRequest -Uri $loginUrl -WebSession $rb -Method POST -Body $form.Fields

#Get the first HTML <form> element on the page (set environment form in this case)
$form2 = $response2.Forms[0]

#Something with the environment page turns the initial html form field names with underscores into ones with dots/periods instead.  
#The .Database field/value is also created on the server side, and not part of the initial html form (found both of these changes with Chrome dev tools, network tab)
#$form2.Fields["EnvironmentConfiguration_SchoolYear"] = "2019"
#$form2.Fields["EnvironmentConfiguration_SummerSchool"] = ""

$form2.Fields["EnvironmentConfiguration.SchoolYear"] = $CurrentYear #change for alternate years' databases
$form2.Fields["EnvironmentConfiguration.SummerSchool"] = "false" #"not supported in AR at this time"
$form2.Fields["EnvironmentConfiguration.Database"] = "2360" #not sure what this does, but the form will not submit without it
$form2.Fields["EnvironmentConfiguration.ImpersonatedUser"] = "" 

#Pass the environment setting screen to finish logging in
$response3 = Invoke-WebRequest -Uri $envUrl -WebSession $rb -Method POST -Body $form2.Fields

#After logging in, and setting environment variables, navigate to the upload file page
$response4 = Invoke-WebRequest -Uri $uploadUrl -WebSession $rb -Method GET

#Get the first HTML <form> element on the page (upload file form in this case)
$form3 = $response4.Forms[0]

#set the eSchool upload location (don't know of any other option other than what's below)
$form3.Fields["UploadLocation"] = "UserReportDir"

#variables and formatting for uploading the file
$mimeType = [System.Web.MimeMapping]::GetMimeMapping($InFile)
$fileName = Split-Path $InFile -leaf
$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
$boundary = [guid]::NewGuid().ToString()
$fileBin = [System.IO.File]::ReadAllBytes($InFile)
$template = @'
--{0}
Content-Disposition: form-data; name="fileData"; filename="{1}"
Content-Type: {2}
{3}
--{0}--
'@

$body = $template -f $boundary, $fileName, $mimeType, $enc.GetString($fileBin)
$body += $form3.Fields

#Post the upload file
$response5 = Invoke-WebRequest -Uri $uploadUrl -Method Post -WebSession $rb -ContentType "multipart/form-data; boundary=$boundary" -Body $body 

#If just wanting to upload a file to eSchool, you're done!  
#Below is specific to an Upload Interface I've made in eSchool.  You'll either have to modify it to match what you're doing, or comment out here below.
#You can schedule eSchool upload interfaces to run on a schedule within eSchool, if you don't want to mess with this.
#-----------------------------------------------------------------------------------------------------------------------------

#Navigate to Run Upload page
$response6 = Invoke-WebRequest -Uri $runuploadUrl -WebSession $rb -Method GET

#Get the first HTML <form> element on the page (run upload process form in this case)
$form4 = $response6.Forms[0]

#Copied/pasted fields out of chrome dev tools, added variables to some.  Need better parameters for various options (blanks, update only, etc.)
$form4.Fields["Filter.GroupingMask"] = ""
$form4.Fields["Filter.LoginId"] = $username
$form4.Fields["Filter.Predicates[0].DataType"] = "Char"
$form4.Fields["Filter.Predicates[0].PredicateIndex"] = "1"
$form4.Fields["Filter.SearchNumber"] = "0"
$form4.Fields["Filter.SearchType"] = "upload_filter"
$form4.Fields["GridEndDateData"] = "" #[]
$form4.Fields["GridStartDateData"] = "" #[]
$form4.Fields["ImportDirectory"] = "UD" #"User's Report Directory"
$form4.Fields["InsertNewRec"] = "true" #"insert new records checkbox"
$form4.Fields["InterfaceId"] = $InterfaceID #Upload interface ID from eSchool
$form4.Fields["ProgramDatesEnabled"] = "N"
$form4.Fields["ProgramEndDate"] = "" #null
$form4.Fields["ProgramStartDate"] = "" #null
$form4.Fields["RunMode"] = $RunMode #"V" for "Verify upload data without updating database "R" for "Run Upload"
$form4.Fields["RunType"] = "UPLOAD"
$form4.Fields["SearchType"] = "upload_filter"
$form4.Fields["SortType"] = ""
$form4.Fields["StudWithoutOpenProg"] = "USD"
$form4.Fields["TaskScheduler.CurrentTask.Classname"] = "LTDB4_0.CRunUpload"
$form4.Fields["TaskScheduler.CurrentTask.Friday"] = "false"
$form4.Fields["TaskScheduler.CurrentTask.Monday"] = "false"
$form4.Fields["TaskScheduler.CurrentTask.Saturday"] = "false"
$form4.Fields["TaskScheduler.CurrentTask.SchdInterval"] = "1"
$form4.Fields["TaskScheduler.CurrentTask.ScheduleType"] = "N"
$form4.Fields["TaskScheduler.CurrentTask.ScheduledTimeDate"] = get-date -UFormat %m/%d/%Y #"05/07/2019"
$form4.Fields["TaskScheduler.CurrentTask.ScheduledTimeTime"] = (get-date).AddMinutes(1).ToString("hh:mm tt") #Set forward 1 minute(s) "03:45 PM"
$form4.Fields["TaskScheduler.CurrentTask.Sunday"] = "false"
$form4.Fields["TaskScheduler.CurrentTask.TaskDescription"] = "Run Interface Upload (automated, AKA Ben Rules)"
$form4.Fields["TaskScheduler.CurrentTask.Thursday"] = "false"
$form4.Fields["TaskScheduler.CurrentTask.Tuesday"] = "false"
$form4.Fields["TaskScheduler.CurrentTask.Wednesday"] = "false"
$form4.Fields["UpdateBlankRec"] = "false"  #"Only Update Blank Records" checkbox
$form4.Fields["UpdateExistRec"] = "true" #"Update Existing Records" checkbox
$form4.Fields["groupPredicate"] = "false"
$form4.Fields["tableKey"] = ""

#Submit the Run Upload form with set variables
$response7 = Invoke-WebRequest -Uri $runuploadUrl -WebSession $rb -Method POST -Body $form4.Fields
