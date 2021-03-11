<#

This script downloads the latest Home Access Center Codes and puts them in a variable $records.
If the existing downloaded file matches then we do not do any work.

#>

Param(
    [parameter(Position=0,mandatory=$true,Helpmessage="eSchool username")][string]$username,
    [parameter(mandatory=$false)][switch]$sendemailviagam, #Send an email directly to the parent with the information. Template is located at template.txt
    [parameter(mandatory=$false)][string]$sendtestemailto, #Send a single email to this account instead of sending it to the actual parent.
    [parameter(mandatory=$false)][switch]$savecsv,
    [parameter(mandatory=$false)][switch]$skipdownload,
    [parameter(mandatory=$false)][switch]$Force #Do not compare to existing downloaded file. Send anyways!
)

#Login and get session.
if (-Not($eSchoolSession)) {
    . ./eSchool-Login.ps1 -username $username
}

#Needed directory.
if (-Not(Test-Path "$PSScriptRoot\temp")) { New-Item -Name temp -ItemType Directory -Force }

#Get existing file hash.
if (Test-Path "$PSScriptRoot\temp\HomeAccessPasswords.csv") {
    $existingHash = (Get-FileHash "$PSScriptRoot\temp\HomeAccessPasswords.csv").Hash
}

#Download new file.
if (-Not($skipdownload)) {
    .\eSchoolDownload.ps1 -username 0403cmillsap -reportnamelike "HomeAccessPasswords" -outputfile "$PSScriptRoot\temp\HomeAccessPasswords.csv"
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
    $records | ForEach-Object {
        $body = (Get-Content "$PSScriptRoot\template.txt") -Replace '{{Guardian_name}}',"$($PSItem.Guardian_name)" -Replace '{{Student_name}}',"$($PSItem.Student_name)" -Replace '{{Guardian_accesscode}}',"$($PSItem.Guardian_accesscode)"
        if ($sendtestemailto) {
            Write-Host "Info: We will only process one record and will send a sample email to $sendtestemailto"
            & gam sendemail $sendtestemailto subject "Home Access Center" message "$body" html
            exit(0)
        } else {
            #send it.
            & gam sendemail $PSItem.Guardian_email subject "Home Access Center" message "$body" html
        }
        
    }
}

if ($savecsv) {
    if ($PSVersionTable.PSVersion -gt [version]"7.0.0") {
        $records | ConvertTo-Csv -UseQuotes AsNeeded -NoTypeInformation | Out-File Home_Access_Center_Codes.csv
    } else {
        #EVERYTHING GETS QUOTES!
        $records | ConvertTo-Csv -NoTypeInformation | Out-File Home_Access_Center_Codes.csv
    }
}