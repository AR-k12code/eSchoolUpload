<#

This script will set a variable called $eSchoolSession that you can reference with subsequent Invoke-RestMethod or Invoke-WebRequests.

You must dot source this script.

if (-Not($eSchoolSession)) {
    . ./eSchool-Login.ps1 -username $username
}

#>

Param(
    [parameter(Mandatory=$false,Helpmessage="eSchool username")][string]$username,
    [parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")][String]$passwordfile="C:\Scripts\apscnpw.txt"
)

if (Test-Path "$PSScriptRoot\..\CognosDefaults.ps1") {
    #Use CognosDefaults if exists
    . $PSScriptRoot\..\CognosDefaults.ps1
}

if ($null -eq $username -or $username -eq '') {
    Write-Host "Error: You need to specify your username and password path. You can use the CognosDefaults.ps1 file if you need." -ForegroundColor Red
    exit(1)
}

$baseUrl = "https://eschool23.esp.k12.ar.us/eSchoolPLUS/"
$loginUrl = $baseUrl + '/Account/LogOn?ReturnUrl=%2feSchoolPLUS20%2f'
$envUrl = $baseUrl + '/Account/SetEnvironment/SessionStart'
$hacloginsurl = $baseUrl + '/HomeAccess/Utility/GenerateLogins'
$uploadUrl = $baseUrl + "/Utility/UploadFile"
$runuploadUrl = $baseUrl + "/Utility/RunUpload"
$runDownloadUrl = $baseUrl + '/Utility/RunDownload'
$massUpdateUrl = $baseUrl + "/Utility/RunMassUpdate"
$massUpdateFilterResultsUrl = "/Utility/GetContactsMUFilterResultsGridData"

if (-Not($passwordfile)) {
    $passwordfile = "C:\Scripts\apscnpw.txt"
}

#encrypted password file.
If (Test-Path $passwordfile) {
    #$password = Get-Content $passwordfile | ConvertTo-SecureString -AsPlainText -Force
    $password = (New-Object pscredential "user",(Get-Content $passwordfile | ConvertTo-SecureString)).GetNetworkCredential().Password
}
Else {
    Write-Host("Password file does not exist! [$passwordfile]. Please enter a password to be saved on this computer for scripts") -ForeGroundColor Yellow
    Read-Host "Enter Password" -AsSecureString |  ConvertFrom-SecureString | Out-File $passwordfile
    $password = Get-Content $passwordfile | ConvertTo-SecureString -AsPlainText -Force
}

if (-Not($CurrentYear)) {
    if ((Get-date).month -le "6") {
        $CurrentYear = (Get-date).year
    } else {
        $CurrentYear = (Get-date).year + 1
    }
}

#Get Verification Token.
$response = Invoke-WebRequest -Uri $loginUrl -SessionVariable eSchoolSession

#Login
$params = @{
    'UserName' = $username
    'Password' = $password
    '__RequestVerificationToken' = $response.InputFields[0].value
}

$response2 = Invoke-WebRequest -Uri $loginUrl -WebSession $eSchoolSession -Method POST -Body $params -ErrorAction Stop
if (($response2.ParsedHtml.title -eq "Login") -or ($response2.StatusCode -ne 200)) { write-host "Failed to login."; exit(1); }

$fields = $response2.InputFields | Group-Object -Property name -AsHashTable
$database = $response2.RawContent | Select-String -Pattern 'selected="selected" value="....' -All | Select-Object -Property Matches | ForEach-Object { $PSItem.Matches[0].Value }
$database = $database -replace "[^0-9]" #$Database.Substring($Database.Length-4,4)
#Set Environment
$params2 = @{
    'ServerName' = $fields.'ServerName'.value
    'EnvironmentConfiguration.Database' = $database
    'UserErrorMessage' = ''
    'EnvironmentConfiguration.SchoolYear' = $fields.'EnvironmentConfiguration.SchoolYear'.value
    'EnvironmentConfiguration.SummerSchool' = 'false'
    'EnvironmentConfiguration.ImpersonatedUser' = ''
}

$response3 = Invoke-WebRequest -Uri $envUrl -WebSession $eSchoolSession -Method POST -Body $params2
if ($response3.StatusCode -ne 200) {
    Write-Host "Failed to Set Environment."
    $eSchoolLoggedIn = $False
    exit(1)
} else {
    $eSchoolLoggedIn = $True
}


# The $eSchoolSession should now be available for running the other scripts.
