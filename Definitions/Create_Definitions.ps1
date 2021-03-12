#Requires -Version 7.0.0

<#

This script will create the Upload/Downlaod Definitions needed for uploading email addresses to eSchoool.
Download Definition : EMLDL
Upload Definition : EMLUP

#>

Param(
    [parameter(Position=0,mandatory=$true,Helpmessage="eSchool username")][string]$username
)

#Login and get session.
if (-Not($eSchoolSession)) {
    . ./eSchool-Login.ps1 -username $username
}

<# 

Download Definition

#>

$ddhash = @{}

$ddhash["IsCopyNew"] = "False"
$ddhash["NewHeaderNames"] = @("")
$ddhash["InterfaceHeadersToCopy"] = @("")
$ddhash["InterfaceToCopyFrom"] = @("")
$ddhash["CopyHeaders"] = "False"
$ddhash["PageEditMode"] = 0
$ddhash["UploadDownloadDefinition"] = @{}
$ddhash["UploadDownloadDefinition"]["UploadDownload"] = "D"

$ddhash["UploadDownloadDefinition"]["DistrictId"] = 0
$ddhash["UploadDownloadDefinition"]["InterfaceId"] = "EMLDL"
$ddhash["UploadDownloadDefinition"]["Description"] = "Automated Student Email Download Definition"
$ddhash["UploadDownloadDefinition"]["UploadDownloadRaw"] = "D"
$ddhash["UploadDownloadDefinition"]["ChangeUser"] = $null
$ddhash["UploadDownloadDefinition"]["DeleteEntity"] = $False

$ddhash["UploadDownloadDefinition"]["InterfaceHeaders"] = @()

$ddhash["UploadDownloadDefinition"]["InterfaceHeaders"] += @{
    "InterfaceId" = "EMLDL"
    "HeaderId" = "1"
    "HeaderOrder" = 1
    "Description" = "Students Student ID Email and Contact ID"
    "FileName" = "student_email_download.csv"
    "LastRunDate" = $null
    "DelimitChar" = ","
    "UseChangeFlag" = $False
    "TableAffected" = "reg_contact"
    "AdditionalSql" = "INNER JOIN reg_stu_contact ON reg_stu_contact.contact_id = reg_contact.contact_id INNER JOIN reg ON reg.student_id = reg_stu_contact.student_id" # AND reg_stu_contact.contact_priority = 0 AND reg_stu_contact.contact_type = 'M'"
    "ColumnHeaders" = $True
    "Delete" = $False
    "CanDelete" = $True
    "ColumnHeadersRaw" = "Y"
    "InterfaceDetails" = @()
}

$rows = @()
$rows += @{ table = "reg"; column = "STUDENT_ID"; length = 20 }
$rows += @{ table = "reg_contact"; column = "CONTACT_ID"; length = 20 }
$rows += @{ table = "reg_contact"; column = "EMAIL"; length = 250 }
$rows += @{ table = "reg_stu_contact"; column = "WEB_ACCESS"; length = 1 }
$rows += @{ table = "reg_stu_contact"; column = "CONTACT_PRIORITY"; length = 2 }
$rows += @{ table = "reg_stu_contact"; column = "CONTACT_TYPE"; length = 1 }


$columns = @()
$columnNum = 1
$rows | ForEach-Object {
    $columns += @{
        "Edit" = $null
        "InterfaceId" = "EMLDL"
        "HeaderId" = "1"
        "FieldId" = "$columnNum"
        "FieldOrder" = $columnNum
        "TableName" = $PSItem.table
        "TableAlias" = $null
        "ColumnName" = $PSItem.column
        "ScreenType" = $null
        "ScreenNumber" = $null
        "FormatString" = $null
        "StartPosition" = $null
        "EndPosition" = $null
        "FieldLength" = "$($PSItem.length)"
        "ValidationTable" = $null
        "CodeColumn" = $null
        "ValidationList" = $null
        "ErrorMessage" = $null
        "ExternalTable" = $null
        "ExternalColumnIn" = $null
        "ExternalColumnOut" = $null
        "Literal" = $null
        "ColumnOverride" = $null
        "Delete" = $False
        "CanDelete" = $True
        "NewRow" = $True
        "InterfaceTranslations" = @("")
    }
    $columnNum++
}

$ddhash["UploadDownloadDefinition"]["InterfaceHeaders"][$headerorder - 1]["InterfaceDetails"] += $columns

$jsonpayload = $ddhash | ConvertTo-Json -depth 6

$checkIfExists = Invoke-WebRequest -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=EMLDL" -WebSession $eSchoolSession
if (($checkIfExists.InputFields | Where-Object { $PSItem.name -eq 'UploadDownloadDefinition.InterfaceId' } | Select-Object -ExpandProperty value) -eq '') {

    #create download definition.
    $response3 = Invoke-RestMethod -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/SaveUploadDownload" `
    -WebSession $eSchoolSession `
    -Method "POST" `
    -ContentType "application/json; charset=UTF-8" `
    -Body $jsonpayload

    if ($response3.PageState -eq 1) {
        Write-Host "Error: " -ForegroundColor RED
        $($response3.ValidationErrorMessages)
    }
} else {
    Write-Host "Info: Job already exists. You need to delete the job at https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=EMLDL"
}


<#
    Upload Definition
#>

$udhash = @{}
$udhash["IsCopyNew"] = "False"
$udhash["NewHeaderNames"] = @("")
$udhash["InterfaceHeadersToCopy"] = @("")
$udhash["InterfaceToCopyFrom"] = @("")
$udhash["CopyHeaders"] = "False"
$udhash["PageEditMode"] = 0
$udhash["UploadDownloadDefinition"] = @{}
$udhash["UploadDownloadDefinition"]["UploadDownload"] = "U"

$udhash["UploadDownloadDefinition"]["DistrictId"] = 0
$udhash["UploadDownloadDefinition"]["InterfaceId"] = "EMLUP"
$udhash["UploadDownloadDefinition"]["Description"] = "Automated Student Email Upload Definition"
$udhash["UploadDownloadDefinition"]["UploadDownloadRaw"] = "U"
$udhash["UploadDownloadDefinition"]["ChangeUser"] = $null
$udhash["UploadDownloadDefinition"]["DeleteEntity"] = $False

$udhash["UploadDownloadDefinition"]["InterfaceHeaders"] = @()

$udhash["UploadDownloadDefinition"]["InterfaceHeaders"] += @{
    "InterfaceId" = "EMLUP"
    "HeaderId" = "1"
    "HeaderOrder" = 1
    "Description" = "Students Student ID Email and Contact ID"
    "FileName" = "student_email_upload.csv"
    "LastRunDate" = $null
    "DelimitChar" = ","
    "UseChangeFlag" = $False
    "TableAffected" = "reg_contact"
    "AdditionalSql" = $null
    "ColumnHeaders" = $True
    "Delete" = $False
    "CanDelete" = $True
    "ColumnHeadersRaw" = "Y"
    "InterfaceDetails" = @()
}

$rows = @()
$rows += @{ table = "reg_contact"; column = "CONTACT_ID"; length = 20 }
$rows += @{ table = "reg_contact"; column = "EMAIL"; length = 250 }

$columns = @()
$columnNum = 1
$rows | ForEach-Object {
    $columns += @{
        "Edit" = $null
        "InterfaceId" = "EMLUP"
        "HeaderId" = "1"
        "FieldId" = "$columnNum"
        "FieldOrder" = $columnNum
        "TableName" = $PSItem.table
        "TableAlias" = $null
        "ColumnName" = $PSItem.column
        "ScreenType" = $null
        "ScreenNumber" = $null
        "FormatString" = $null
        "StartPosition" = $null
        "EndPosition" = $null
        "FieldLength" = "$($PSItem.length)"
        "ValidationTable" = $null
        "CodeColumn" = $null
        "ValidationList" = $null
        "ErrorMessage" = $null
        "ExternalTable" = $null
        "ExternalColumnIn" = $null
        "ExternalColumnOut" = $null
        "Literal" = $null
        "ColumnOverride" = $null
        "Delete" = $False
        "CanDelete" = $True
        "NewRow" = $True
        "InterfaceTranslations" = @("")
    }
    $columnNum++
}

$udhash["UploadDownloadDefinition"]["InterfaceHeaders"][$headerorder - 1]["InterfaceDetails"] += $columns

$udhash["UploadDownloadDefinition"]["InterfaceHeaders"][0]["AffectedTableObject"] = @{
    "Code" = "reg_contact"
    "Description" = "Contacts"
    "CodeAndDescription" = "reg_contact - Contacts"
    "ActiveRaw" = "Y"
    "Active" = $True
}

$jsonpayload = $udhash | ConvertTo-Json -depth 6

$checkIfExists = Invoke-WebRequest -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=EMLUP" -WebSession $eSchoolSession
if (($checkIfExists.InputFields | Where-Object { $PSItem.name -eq 'UploadDownloadDefinition.InterfaceId' } | Select-Object -ExpandProperty value) -eq '') {

    #create download definition.
    $response3 = Invoke-RestMethod -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/SaveUploadDownload" `
    -WebSession $eSchoolSession `
    -Method "POST" `
    -ContentType "application/json; charset=UTF-8" `
    -Body $jsonpayload

    if ($response3.PageState -eq 1) {
        Write-Host "Error: " -ForegroundColor RED
        $($response3.ValidationErrorMessages)
    }
} else {
    Write-Host "Info: Job already exists. You need to delete the job at https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=EMLUP"
}

<#
    Web Access Upload Definition.
#>

$wahash = @{}
$wahash["IsCopyNew"] = "False"
$wahash["NewHeaderNames"] = @("")
$wahash["InterfaceHeadersToCopy"] = @("")
$wahash["InterfaceToCopyFrom"] = @("")
$wahash["CopyHeaders"] = "False"
$wahash["PageEditMode"] = 0
$wahash["UploadDownloadDefinition"] = @{}
$wahash["UploadDownloadDefinition"]["UploadDownload"] = "U"

$wahash["UploadDownloadDefinition"]["DistrictId"] = 0
$wahash["UploadDownloadDefinition"]["InterfaceId"] = "EMLAC"
$wahash["UploadDownloadDefinition"]["Description"] = "Automated Student Web Access Upload Definition"
$wahash["UploadDownloadDefinition"]["UploadDownloadRaw"] = "U"
$wahash["UploadDownloadDefinition"]["ChangeUser"] = $null
$wahash["UploadDownloadDefinition"]["DeleteEntity"] = $False

$wahash["UploadDownloadDefinition"]["InterfaceHeaders"] = @()

$wahash["UploadDownloadDefinition"]["InterfaceHeaders"] += @{
    "InterfaceId" = "EMLAC"
    "HeaderId" = "1"
    "HeaderOrder" = 1
    "Description" = "Students Contact ID and WEB_ACCESS"
    "FileName" = "webaccess_upload.csv"
    "LastRunDate" = $null
    "DelimitChar" = ","
    "UseChangeFlag" = $False
    "TableAffected" = "reg_stu_contact"
    "AdditionalSql" = $null
    "ColumnHeaders" = $True
    "Delete" = $False
    "CanDelete" = $True
    "ColumnHeadersRaw" = "Y"
    "InterfaceDetails" = @()
}

$rows = @()
$rows += @{ table = "reg_stu_contact"; column = "CONTACT_ID"; length = 20 }
$rows += @{ table = "reg_stu_contact"; column = "STUDENT_ID"; length = 20 }
$rows += @{ table = "reg_stu_contact"; column = "WEB_ACCESS"; length = 1 }
$rows += @{ table = "reg_stu_contact"; column = "CONTACT_TYPE"; length = 1 }

$columns = @()
$columnNum = 1
$rows | ForEach-Object {
    $columns += @{
        "Edit" = $null
        "InterfaceId" = "EMLAC"
        "HeaderId" = "1"
        "FieldId" = "$columnNum"
        "FieldOrder" = $columnNum
        "TableName" = $PSItem.table
        "TableAlias" = $null
        "ColumnName" = $PSItem.column
        "ScreenType" = $null
        "ScreenNumber" = $null
        "FormatString" = $null
        "StartPosition" = $null
        "EndPosition" = $null
        "FieldLength" = "$($PSItem.length)"
        "ValidationTable" = $null
        "CodeColumn" = $null
        "ValidationList" = $null
        "ErrorMessage" = $null
        "ExternalTable" = $null
        "ExternalColumnIn" = $null
        "ExternalColumnOut" = $null
        "Literal" = $null
        "ColumnOverride" = $null
        "Delete" = $False
        "CanDelete" = $True
        "NewRow" = $True
        "InterfaceTranslations" = @("")
    }
    $columnNum++
}

$wahash["UploadDownloadDefinition"]["InterfaceHeaders"][$headerorder - 1]["InterfaceDetails"] += $columns

$wahash["UploadDownloadDefinition"]["InterfaceHeaders"][0]["AffectedTableObject"] = @{
    "Code" = "reg_stu_contact"
    "Description" = "Contacts"
    "CodeAndDescription" = "reg_stu_contact - Contacts"
    "ActiveRaw" = "Y"
    "Active" = $True
}

$jsonpayload = $wahash | ConvertTo-Json -depth 6

$checkIfExists = Invoke-WebRequest -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=EMLAC" -WebSession $eSchoolSession
if (($checkIfExists.InputFields | Where-Object { $PSItem.name -eq 'UploadDownloadDefinition.InterfaceId' } | Select-Object -ExpandProperty value) -eq '') {

    #create download definition.
    $response3 = Invoke-RestMethod -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/SaveUploadDownload" `
    -WebSession $eSchoolSession `
    -Method "POST" `
    -ContentType "application/json; charset=UTF-8" `
    -Body $jsonpayload

    if ($response3.PageState -eq 1) {
        Write-Host "Error: " -ForegroundColor RED
        $($response3.ValidationErrorMessages)
    }
} else {
    Write-Host "Info: Job already exists. You need to delete the job at https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=EMLAC"
}