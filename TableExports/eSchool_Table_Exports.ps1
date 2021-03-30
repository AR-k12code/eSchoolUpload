
#eSchool Craate Download Definition for ALL tables specified.
#You can not have an existing upload/download definition called "DBEXP"

Param(
    [parameter(Mandatory=$false,Helpmessage="eSchool username")][string]$username,
    [parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")][String]$passwordfile="C:\Scripts\apscnpw.txt",
    [parameter(Mandatory=$false)][String]$DefinitionName="DBEXP" #By Default the Definition will be called DBEXP. Call it what you want but it must be EXACTLY than 5 characters.
)

if (-Not($tables)) {
    $tables = @('REG','REG_STU_CONTACT','REG_CONTACT')
}

if ($DefinitionName.Length -ne 5) {
    Write-Host "Error: Definition Name MUST BE 5 CHARACTERS LONG!" -ForegroundColor Red
    exit(1)
}

if (-Not($eSchoolSession)) {
    . $PSScriptRoot\..\eSchool-Login.ps1 -username $username
}

if (-Not(Get-Variable -Name eSchoolSession)) {
    Write-Host "Error: Failed to login to eSchool." -ForegroundColor Red
    exit(1)
}

#dd = download definition
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
$ddhash["UploadDownloadDefinition"]["InterfaceId"] = "$DefinitionName"
$ddhash["UploadDownloadDefinition"]["Description"] = "Export All eSchool Tables"
$ddhash["UploadDownloadDefinition"]["UploadDownloadRaw"] = "D"
$ddhash["UploadDownloadDefinition"]["ChangeUser"] = $null
$ddhash["UploadDownloadDefinition"]["DeleteEntity"] = $False

$ddhash["UploadDownloadDefinition"]["InterfaceHeaders"] = @()

$headerorder = 0
Import-Csv $PSScriptRoot\eSchoolDatabase.csv | Where-Object { $tables -contains $PSItem.tblName } | Group-Object -Property tblName | ForEach-Object {
    $tblName = $PSItem.Name

    if ($tblName.IndexOf('_') -ge 1) {
        $tblShortName = $tblName[0]
        $tblName | Select-String '_' -AllMatches | Select-Object -ExpandProperty Matches | ForEach-Object {
            $tblShortName += $tblName[$PSItem.Index + 1]
        }
    } else {
        $tblShortName = $tblName
    }

    if ($tblShortName.length -gt 5) {
        $tblShortName = $tblShortName.SubString(0,5)
    }

    $ifaceheader = $tblShortName
    $description = $tblName
    $filename = "$($tblName).csv"

    $ifaceheader,$description,$filename

    $headerorder++
    $ddhash["UploadDownloadDefinition"]["InterfaceHeaders"] += @{
        "InterfaceId" = "$DefinitionName"
        "HeaderId" = "$ifaceheader"
        "HeaderOrder" = $headerorder
        "Description" = "$description"
        "FileName" = "$filename"
        "LastRunDate" = $null
        "DelimitChar" = '|'
        "UseChangeFlag" = $False
        "TableAffected" = "$($tblName.ToLower())"
        "AdditionalSql" = $null
        "ColumnHeaders" = $True
        "Delete" = $False
        "CanDelete" = $True
        "ColumnHeadersRaw" = "Y"
        "InterfaceDetails" = @()
    }
   
    $columns = @()
    $columnNum = 1
    $PSItem.Group | ForEach-Object {
        $columns += @{
            "Edit" = $null
            "InterfaceId" = "$DefinitionName"
            "HeaderId" = "$ifaceheader"
            "FieldId" = "$columnNum"
            "FieldOrder" = "$columnNum"
            "TableName" = "$($tblName.ToLower())"
            "TableAlias" = $null
            "ColumnName" = $PSItem.colName
            "ScreenType" = $null
            "ScreenNumber" = $null
            "FormatString" = $null
            "StartPosition" = $null
            "EndPosition" = $null
            "FieldLength" = [int]$PSItem.colMaxLength + 2 #This fixes the dates that are cut off.
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

}

$jsonpayload = $ddhash | ConvertTo-Json -depth 6

$checkIfExists = Invoke-WebRequest -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=$($DefinitionName)" -WebSession $eSchoolSession
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
    Write-Host "Info: Job already exists. You need to delete the job at https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=$($DefinitionName)"
}

