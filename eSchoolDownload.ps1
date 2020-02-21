#eSchool Run/Download File
#2/8/2020 Craig Millsap - Still needs error control

Param(
[parameter(Position=0,mandatory=$true,Helpmessage="Eschool username")]
[String]$username="SSOusername", #***Variable*** Change to default eschool usename
[parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")]
[String]$passwordfile="C:\Scripts\apscnpw.txt", #--- VARIABLE --- change to a file path for SSO password
[parameter(Position=1,mandatory=$false,Helpmessage="Report Name")]
[String]$reportname,
[parameter(Position=2,mandatory=$false,Helpmessage="Report Name that starts with X")]
[String]$reportnamelike,
[parameter(Position=3,mandatory=$false,Helpmessage="Output File")]
[String]$outputfile,
[parameter(Position=4,mandatory=$false,Helpmessage="Run Download InterfaceID")]
[String]$InterfaceID
)

Add-Type -AssemblyName System.Web

#encrypted password file.
If (Test-Path $passwordfile) {
    #$password = Get-Content $passwordfile | ConvertTo-SecureString -AsPlainText -Force
    $password = (New-Object pscredential "user",(Get-Content C:\Scripts\apscnpw.txt | ConvertTo-SecureString)).GetNetworkCredential().Password
}
Else {
    Write-Host("Password file does not exist! [$passwordfile]. Please enter a password to be saved on this computer for scripts") -ForeGroundColor Yellow
    Read-Host "Enter Password" -AsSecureString |  ConvertFrom-SecureString | Out-File $passwordfile
    $password = Get-Content $passwordfile | ConvertTo-SecureString -AsPlainText -Force
}

$eSchoolDomain = 'https://eschool40.esp.k12.ar.us'
$baseUrl = $eSchoolDomain + "/eSchoolPLUS40/"
$loginUrl = $eSchoolDomain + "/eSchoolPLUS40/Account/LogOn?ReturnUrl=%2feSchoolPLUS40%2f"
$envUrl = $eSchoolDomain + "/eSchoolPLUS40/Account/SetEnvironment/SessionStart"

#Login
$params = @{
    'UserName' = $username
    'Password' = $password
}
$response = Invoke-WebRequest -Uri $loginUrl -SessionVariable rb -Method POST -Body $params -ErrorAction Stop
if (($response.ParsedHtml.title -eq "Login") -or ($response.StatusCode -ne 200)) { write-host "Failed to login."; exit 1; }

#Set Environment
$params2 = @{
    'ServerName' = $response.ParsedHtml.getElementById('ServerName').value
    'EnvironmentConfiguration.Database' = $response.ParsedHtml.getElementById('EnvironmentConfiguration_Database').value
    'UserErrorMessage' = ''
    'EnvironmentConfiguration.SchoolYear' = $response.ParsedHtml.getElementById('EnvironmentConfiguration_SchoolYear').value
    'EnvironmentConfiguration.SummerSchool' = 'false'
    'EnvironmentConfiguration.ImpersonatedUser' = ''
}
$response2 = Invoke-WebRequest -Uri $envUrl -WebSession $rb -Method POST -Body $params2
if (($response2.ParsedHtml.title -ne "Home") -or ($response.StatusCode -ne 200)) { write-host "Failed to Set Environment."; exit 1; }

#run download task
if ($InterfaceID) {
    $runDownloadUrl = $eSchoolDomain + '/eSchoolPLUS40/Utility/RunDownload'
    $params = @{
        'SearchType' = 'download_filter'
        'SortType' = ''
        'InterfaceId' = $InterfaceID
        'StartDate' = '07/01/2019'
        'ImportDirectory' = 'UD'
        'TxtImportDirectory' = ''
        'TaskScheduler.CurrentTask.Classname' = 'LTDB4_0.CRunDownload'
        'TaskScheduler.CurrentTask.TaskDescription' = 'Run Interface Download'
        'groupPredicate' = 'false'
        'Filter.Predicates[0].PredicateIndex' = '1'
        'tableKey' = 'reg'
        'Filter.Predicates[0].TableName' = 'reg'
        'columnKey' = 'reg.current_status'
        'Filter.Predicates[0].ColumnName' = 'current_status'
        'Filter.Predicates[0].DataType' = 'Char'
        'Filter.Predicates[0].Operator' = 'Equal'
        'Filter.Predicates[0].Value' = 'A'
        'Filter.Predicates[1].LogicalOperator' = 'And'
        'Filter.Predicates[1].PredicateIndex' = '2'
        'Filter.Predicates[1].DataType' = 'Char'
        'Filter.LoginId' = $username
        'Filter.SearchType' = 'download_filter'
        'Filter.SearchNumber' = '0'
        'Filter.GroupingMask' = ''
        'SortFields.Fields[0].SortFieldIndex' = '1'
        'sortFieldTableKey' = ''
        'SortFields.LoginId' = $username
        'SortFields.SearchType' = 'download_filter'
        'SortFields.SearchNumber' = '0'
        'TaskScheduler.CurrentTask.ScheduleType' = 'O'
        'TaskScheduler.CurrentTask.ScheduledTimeTime' = Get-Date -UFormat %m/%d/%Y
        'TaskScheduler.CurrentTask.ScheduledTimeDate' = (Get-Date).AddMinutes($addtime).ToString("hh:mm tt")
        'TaskScheduler.CurrentTask.SchdInterval' = '1'
        'TaskScheduler.CurrentTask.Monday' = 'false'
        'TaskScheduler.CurrentTask.Tuesday' = 'false'
        'TaskScheduler.CurrentTask.Wednesday' = 'false'
        'TaskScheduler.CurrentTask.Thursday' = 'false'
        'TaskScheduler.CurrentTask.Friday' = 'false'
        'TaskScheduler.CurrentTask.Saturday' = 'false'
        'TaskScheduler.CurrentTask.Sunday' = 'false'
    }

    $response = Invoke-WebRequest -Uri $runDownloadUrl -WebSession $rb -Method POST -Body $params

    #wait until all tasks are completed
    $tasksurl = $eSchoolDomain + '/eSchoolPLUS40/Task/TaskAndReportData?includeTaskCount=true&includeReports=true&maximumNumberOfReports=-1&includeTasks=true&runningTasksOnly=false'
    do {
        Start-Sleep -Seconds 5
        try {
            $response = Invoke-WebRequest -Uri $tasksurl -WebSession $rb
            $inactiveTasks = $($response.ParsedHtml.body.innerHTML | ConvertFrom-Json | Select-Object -ExpandProperty InactiveTasks | Measure-Object).count
            $activeTasks = $($response.ParsedHtml.body.innerHTML | ConvertFrom-Json | Select-Object -ExpandProperty ActiveTasks | Measure-Object).count 
        } catch {
            write-host "Error checking for tasks"
            exit 2
        }
        Write-Host "Waiting on $($inactiveTasks + $activeTasks) to finish..."
    } until (($inactiveTasks -eq 0) -and ($activeTasks -eq 0))

    #we have to wait a few seconds for the file to be written even though the task is completed.
    Start-Sleep -Seconds 10
}


#Get JSON of files and tasks.
try {
    $reportsurl = $eSchoolDomain + '/eSchoolPLUS40/Task/TaskAndReportData?includeTaskCount=true&includeReports=true&maximumNumberOfReports=-1&includeTasks=true&runningTasksOnly=false'
    $response3 = Invoke-WebRequest -Uri $reportsurl -WebSession $rb
    $reportsjson = $response3.ParsedHtml.body.innerHTML | ConvertFrom-Json | Select-Object -ExpandProperty Reports | Sort-Object -Property ModifiedDate -Descending

    if ($reportname) {
        $fileurl = $reportsjson | Where-Object { $_.'DisplayName' -eq $reportname } | Select-Object -First 1
    } elseif ($reportnamelike) {
        $fileurl = $reportsjson | Where-Object { $_.'DisplayName' -like "$reportnamelike*" } | Select-Object -First 1
    } else {
    	$fileurl = $reportsjson | Out-GridView -OutputMode Single
    }

    if (-Not($outputfile)) {
        $outputfile = $fileurl.RawFileName
    }

    Invoke-WebRequest -Uri "$($baseUrl)/Reports$($fileurl.ReportPath -replace ('\\','/'))" -WebSession $rb -OutFile $outputfile

} catch {
	write-host 'Error getting reports list.'
    exit 1
}

exit