<#

eSchool Run/Download File
Craig Millsap - Gentry Public Schools
3/10/2021

Please don't edit this file unless you're pushing code back to the Github repository.
It makes helping you later a LOT harder. These scripts are designed to be invoked from another script.
If you need a modification please contact one of the AR-k12code developers.

#>

Param(
    [parameter(mandatory=$false,Helpmessage="eSchool username")][String]$username,
    [parameter(mandatory=$false,HelpMessage="File for ADE SSO Password")][String]$passwordfile="C:\Scripts\apscnpw.txt",
    [parameter(mandatory=$false,Helpmessage="Report Name")][String]$reportname,
    [parameter(mandatory=$false,Helpmessage="Report Name that starts with X")][String]$reportnamelike,
    [parameter(mandatory=$false,Helpmessage="Output File Name")][String]$outputfile,
    [parameter(mandatory=$false,Helpmessage="Run Download InterfaceID")][String]$InterfaceID
)

if (-Not($eSchoolSession)) {
    . ./eSchool-Login.ps1 -username $username
}

if (-Not(Get-Variable -Name eSchoolSession)) {
    Write-Host "Error: Failed to login to eSchool." -ForegroundColor Red
    exit(1)
}

#run download task
if ($InterfaceID) {
    $params = @{
        'SearchType' = 'download_filter'
        'SortType' = ''
        'InterfaceId' = $InterfaceID
        'StartDate' = '07/01/2019'
        'ImportDirectory' = 'UD'
        'TxtImportDirectory' = ''
        'TaskScheduler.CurrentTask.Classname' = 'LTDB20_4.CRunDownload'
        'TaskScheduler.CurrentTask.TaskDescription' = "Run Interface Download $InterfaceID"
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
        'TaskScheduler.CurrentTask.ScheduledTimeTime' = (Get-Date).AddMinutes(1).ToString("hh:mm tt")
        'TaskScheduler.CurrentTask.ScheduledTimeDate' = Get-Date -UFormat %m/%d/%Y
        'TaskScheduler.CurrentTask.SchdInterval' = '1'
        'TaskScheduler.CurrentTask.Monday' = 'false'
        'TaskScheduler.CurrentTask.Tuesday' = 'false'
        'TaskScheduler.CurrentTask.Wednesday' = 'false'
        'TaskScheduler.CurrentTask.Thursday' = 'false'
        'TaskScheduler.CurrentTask.Friday' = 'false'
        'TaskScheduler.CurrentTask.Saturday' = 'false'
        'TaskScheduler.CurrentTask.Sunday' = 'false'
    }

    Write-Host "Info: Starting $InterfaceID download."
    $response = Invoke-RestMethod -Uri $runDownloadUrl -WebSession $eSchoolSession -Method POST -Body $params

    #wait until all tasks are completed
    $tasksurl = $baseUrl + '/Task/TaskAndReportData?includeTaskCount=true&includeReports=true&maximumNumberOfReports=-1&includeTasks=true&runningTasksOnly=false'
    do {
        Start-Sleep -Seconds 5
        try {
            $response2 = Invoke-RestMethod -Uri $tasksurl -WebSession $eSchoolSession
            $inactiveTasks = $($response2.InactiveTasks | Where-Object { $PSItem.TaskName -eq "Run Interface Download $InterfaceID" } | Measure-Object).count
            $activeTasks = $($response2.ActiveTasks | Where-Object { $PSItem.TaskName -eq "Run Interface Download $InterfaceID" } | Measure-Object).count

            #check for ErrorOccurred -eq true
            if ($activeTasks -ge 1) {
                $response2.ActiveTasks | ForEach-Object {
                    if ($PSItem.ErrorOccurred -eq "true") {
                        Write-Host "Error: Task", $PSItem.TaskName, "has failed. Clearing error." -ForegroundColor RED
                        $clearErrorURL = $eschoolDomain + '/Task/ClearErroredTask'
                        $errorpayload = @{ paramKey = $PSItem.TaskKey }
                        $response3 = Invoke-WebRequest -Uri $clearErrorURL -WebSession $eSchoolSession -Method POST -Body $errorpayload
                    }
                }
            }
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
    $reportsurl = $baseUrl + '/Task/TaskAndReportData?includeTaskCount=true&includeReports=true&maximumNumberOfReports=-1&includeTasks=true&runningTasksOnly=false'
    $response3 = Invoke-RestMethod -Uri $reportsurl -WebSession $eSchoolSession
    $reportsjson = $response3.Reports | Sort-Object -Property ModifiedDate -Descending

    if ($reportname) {
        $file = $reportsjson | Where-Object { $_.'DisplayName' -eq $reportname } | Select-Object -First 1
    } elseif ($reportnamelike) {
        $file = $reportsjson | Where-Object { $_.'DisplayName' -like "$reportnamelike*" } | Select-Object -First 1
    } else {
    	$file = $reportsjson | Out-GridView -OutputMode Single
    }

    if (-Not($outputfile)) {
        $outputfile = $file.RawFileName
    }

    try {
        Write-Host "Info: Attemtping to download ""$($file.RawFileName)"" to ""$outputfile"" ... " -NoNewline
        Invoke-WebRequest -Uri "$($baseUrl)/Reports$($file.ReportPath -replace ('\\','/'))" -WebSession $eSchoolSession -OutFile $outputfile
        Write-Host "Success."
    } catch {
        Write-Host "Error: Failed to download file. $_" -ForegroundColor RED
        exit(1)
    }

} catch {
	write-host 'Error getting reports list.'
    exit(1)
}

exit