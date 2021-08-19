<#

eSchool Upload File
Craig Millsap - Gentry Public Schools
3/10/2021 - Rewrite for Powershell 7 and using the CognosDefaults.ps1 if exists.

Thank you to Ben Janelle for the base script
1/31/2020 - Charles Weber - convert from args to parameters

Please don't edit this file unless you're pushing code back to the Github repository.
It makes helping you later a LOT harder. These scripts are designed to be invoked from another script.
If you need a modification please contact one of the AR-k12code developers.

#>

Param(
    [parameter(mandatory=$false,Helpmessage="eSchool username")][string]$username,
    [parameter(mandatory=$false,Helpmessage="What file do you want to upload, Full path c:\scripts\filename.csv")][String]$InFile,
    [parameter(mandatory=$false,Helpmessage="Run mode, V for verfiy and R to commit data changes to eschool")][ValidateSet("R","V")][String]$RunMode="V",
    [parameter(mandatory=$false,Helpmessage="Interface upload Definition to run")][string]$InterfaceID, #Upload definition you want to call, can be found on the upload/download defintiion Interface ID [CASE SENSTIVE!]
    [parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")][string]$passwordfile="C:\Scripts\apscnpw.txt",
    [parameter(mandatory=$false,Helpmessage="Specify the time to wait before running the upload script")][int]$addtime = "1", #Specify the time in minutes to wait to run the upload definition
    [parameter(mandatory=$false,Helpmessage="Insert New Records?")][string]$InsertNewRecords='false' #Do you want the upload definition to insert new records?
)

if (-Not(Test-Path "$InFile")) {
    Write-Host "Error: Can not find the file ""$InFile""" -ForegroundColor Red
    exit(1)
}

if (-Not($eSchoolSession)) {
    . $PSScriptRoot\eSchool-Login.ps1 -username $username -passwordfile $passwordfile
    if ($LASTEXITCODE -eq '1'){
        exit(1)
    }
}

if (-Not(Get-Variable -Name eSchoolSession)) {
    Write-Host "Error: Failed to login to eSchool." -ForegroundColor Red
    exit(1)
}

$fileName = Split-Path $InFile -leaf
$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
$boundary = [guid]::NewGuid().ToString()
$fileBin = [System.IO.File]::ReadAllBytes($InFile)
#Don't mess with spacing till after the last '@ it matters!
$template = @'
--{0}
Content-Disposition: form-data; name="fileData"; filename="{1}"
Content-Type: {2}

{3}
--{0}--

'@
$body = $template -f $boundary, $fileName, $mimeType, $enc.GetString($fileBin)

try {
    Write-Host "Info: Uploading file $($fileName)..." -NoNewline
    $response1 = Invoke-WebRequest -Uri $uploadUrl -ContentType "multipart/form-data; boundary=$boundary" -Method Post -WebSession $eSchoolSession -Body $body
    Write-Host "Success."
} catch {
    Write-Host "Error: Failed to upload file to eSchool. $_" -ForegroundColor Red
    exit(1)
}

#If just wanting to upload a file to eSchool, you're done!  
#Below is specific to an Upload Interface I've made in eSchool.  You'll either have to modify it to match what you're doing, or comment out here below.
#You can schedule eSchool upload interfaces to run on a schedule within eSchool, if you don't want to mess with this.
#-----------------------------------------------------------------------------------------------------------------------------

If ($InterfaceID) {

    $params = @{
        'SearchType' = 'upload_filter'
        'SortType' = ''
        'InterfaceId' = "$InterfaceID"
        'RunMode' = "$RunMode"
        'InsertNewRec' = "$InsertNewRecords"
        'UpdateExistRec' = 'true'
        'UpdateBlankRec' = 'false'
        'ImportDirectory' = 'UD'
        'StudWithoutOpenProg' = 'USD'
        'RunType' = 'UPLOAD'
        'ProgramDatesEnabled' = 'N'
        'TaskScheduler.CurrentTask.Classname' = 'LTDB20_4.CRunUpload'
        'TaskScheduler.CurrentTask.TaskDescription' = "Run Interface Upload $InterfaceID"
        'groupPredicate' = 'false'
        'Filter.Predicates[0].PredicateIndex' = '1'
        'tableKey' = ''
        'Filter.Predicates[0].DataType' = 'Char'
        'Filter.LoginId' = "$username"
        'Filter.SearchType' = 'upload_filter'
        'Filter.SearchNumber' = '0'
        'Filter.GroupingMask' = ''
        'TaskScheduler.CurrentTask.ScheduleType' = 'N'
        'TaskScheduler.CurrentTask.SchdInterval' = '1'
        'TaskScheduler.CurrentTask.ScheduledTimeTime' = (get-date).AddMinutes($addtime).ToString("hh:mm tt") #Set forward 1 minute(s) "03:45 PM"
        'TaskScheduler.CurrentTask.ScheduledTimeDate' = get-date -UFormat %m/%d/%Y #"05/07/2019"
        'TaskScheduler.CurrentTask.Monday' = 'false'
        'TaskScheduler.CurrentTask.Tuesday' = 'false'
        'TaskScheduler.CurrentTask.Wednesday' = 'false'
        'TaskScheduler.CurrentTask.Thursday' = 'false'
        'TaskScheduler.CurrentTask.Friday' = 'false'
        'TaskScheduler.CurrentTask.Saturday' = 'false'
        'TaskScheduler.CurrentTask.Sunday' = 'false'
        'ProgramStartDate' = ''
        'ProgramEndDate' = ''
        'GridEndDateData' = @{}
        'GridStartDateData' = @{}
    }

    

    $jsonpayload = $params | ConvertTo-Json -Depth 3

    #Submit the Run Upload form with set variables
    try {
        $response2 = Invoke-RestMethod -Uri $runuploadUrl -WebSession $eSchoolSession -Method POST -Body $jsonpayload -ContentType "application/json; charset=UTF-8"
        Write-Host "Upload finished and task has been scheduled to run in $addtime minutes" -ForegroundColor Cyan -BackgroundColor Black
    } catch {
        Write-Host "Error: Failed to scheduled task." -ForegroundColor Red
        exit(1)
    }
    
} else {
    Write-Host "Upload has finished to Eschool" -ForegroundColor Yellow -BackgroundColor Black
}
