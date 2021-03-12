<#

This script downloads the latest Home Access Center Codes and puts them in a variable $records.
If the existing downloaded file matches then we do not do any work.

To send emails using the the latest generated file from eSchool using GAM.
.\HAC_AccessCodes.ps1 -username 0401cmillsap -sendemailviagam -emailsubject "Gentry Schools - Home Access Center" -fromemail "noreply@gentrypioneers.com" -sendtestemailto "technology@gentrypioneers.com" -Force

To just save a CSV as Home_Access_Center_Codes.csv so you can process later (or in my case import to my db later)
.\HAC_AccessCodes.ps1 -username 0403cmillsap -savetocsv

#>

Param(
    [parameter(mandatory=$false,Helpmessage="eSchool username")][string]$username,
    [parameter(mandatory=$false)][switch]$sendemailviagam, #Send an email directly to the parent with the information. Template is located at template.txt
    [parameter(mandatory=$false)][string]$sendtestemailto, #Send a single email to this account instead of sending it to the actual parent.
    [parameter(mandatory=$false)][switch]$savecsv,
    [parameter(mandatory=$false)][switch]$skipdownload,
    [parameter(mandatory=$false)][string]$emailsubject="Home Access Center",
    [parameter(mandatory=$false)][string]$fromemail="noreply@yourdomain.com",
    [parameter(mandatory=$false)][switch]$Force #Do not compare to existing downloaded file. Send anyways!
)

#Login and get session.
if (-Not($eSchoolSession)) {
    . ./eSchool-Login.ps1 -username $username
}

if (-Not(Get-Variable -Name eSchoolSession)) {
    Write-Host "Error: Failed to login to eSchool." -ForegroundColor Red
    exit(1)
}

#Needed directory.
if (-Not(Test-Path "$PSScriptRoot\temp")) { New-Item -Name temp -ItemType Directory -Force }

#Get existing file hash.
if (Test-Path "$PSScriptRoot\temp\HomeAccessPasswords.csv") {
    $existingHash = (Get-FileHash "$PSScriptRoot\temp\HomeAccessPasswords.csv").Hash
}

#Download new file.
if (-Not($skipdownload)) {
    try {
        .\eSchoolDownload.ps1 -username $username -reportnamelike "HomeAccessPasswords" -outputfile "$PSScriptRoot\temp\HomeAccessPasswords.csv"
        if ($LASTEXITCODE -ge 1) { Throw }
    } catch {
        write-host "Error: Could not download a file named HomeAccessPasswords* from $username directory." -ForegroundColor Red
        exit(1)
    }
}

#Compare existing hash to new hash to know if there is work to do.
if ($existingHash -eq ((Get-FileHash "$PSScriptRoot\temp\HomeAccessPasswords.csv").Hash) -and -Not($Force)) {
    Write-Host "Info: New file matches the existing file. No work to do."
    exit(0)
}

#Import Latest File and replace LF with semicolon then replace record delimeter with line return.
(Get-Content -Path "$PSScriptRoot\temp\HomeAccessPasswords.csv" -Raw).replace("`n",';').replace('#',"`r`n") | Out-File -Force "$PSScriptRoot\temp\HAC_Guardian_AccessCodes.csv" -NoNewline

$accesscodes = Import-Csv "$PSScriptRoot\temp\HAC_Guardian_AccessCodes.csv" -Delimiter '|'

$records = @()

$accesscodes | ForEach-Object {

    $guardian = $PSItem

    $PSItem.students.split(';') | ForEach-Object {
    
        $student = $PSItem

        $records += [PSCustomObject]@{
            Student_id = $PSItem.split('(')[1].split(')')[0]
            Student_name = $PSItem.split('(')[0]
            Guardian_name = $guardian.parent_first_name + ' ' + $guardian.parent_last_name
            Guardian_email = $guardian.email
            Guardian_loginid = $guardian.login_id
            Guardian_accesscode = $guardian.access_code
        }

    }

}

if ($sendemailviagam) {

    if (-Not("$PSScriptRoot\template.txt")) {
        Write-Host "Error: You must have a template.txt file available to do the mail merge to send to parents. Please see the sample-template.txt file and modify for your district."
        exit(1)
    }

    $records | ForEach-Object {
        $body = (Get-Content "$PSScriptRoot\template.txt") -Replace '{{Guardian_name}}',"$($PSItem.Guardian_name)" -Replace '{{Student_name}}',"$($PSItem.Student_name)" -Replace '{{Guardian_accesscode}}',"$($PSItem.Guardian_accesscode)"
        
        if ($PSItem.Guardian_email -notlike "*@*.*") { 
            Write-Host "Error: Guardian $($PSItem.Guardian_name) for $($PSItem.Student_id) does not have a valid email address."
        }
        
        if ($sendtestemailto) {
            Write-Host "Info: We will only process one record and will send a sample email to $sendtestemailto"
            & gam sendemail $sendtestemailto from $fromemail subject $emailsubject message "$body" html
            exit(0)
        } else {
            #send it.
            & gam sendemail $PSItem.Guardian_email from $fromemail subject $emailsubject message "$body" html
        }
        
    }
}

if ($savecsv) {
    if ($PSVersionTable.PSVersion -gt [version]"7.0.0") {
        $records | ConvertTo-Csv -UseQuotes AsNeeded -NoTypeInformation | Out-File "$PSScriptRoot\Home_Access_Center_Codes.csv"
    } else {
        #EVERYTHING GETS QUOTES!
        $records | ConvertTo-Csv -NoTypeInformation | Out-File "$PSScriptRoot\Home_Access_Center_Codes.csv"
    }
}