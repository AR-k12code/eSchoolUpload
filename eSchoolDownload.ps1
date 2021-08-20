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
    [parameter(mandatory=$false,Helpmessage="Run Download InterfaceID")][String]$InterfaceID,
    [parameter(Mandatory=$false)][switch]$TrimCSVWhiteSpace, #Remove Spaces in CSV files. This requires Powershell 7.1+
    [parameter(Mandatory=$false)][switch]$CSVUseQuotes, #If you Trim CSV White Space do you want to wrap everything in quotes?
    [parameter(mandatory=$false,Helpmessage="Timeout in Minutes")][int]$Timeout=60 #How long until we consider the task failed? An hour should be enough but you can make it shorter.
)

$startTime = Get-Date

if (-Not($eSchoolSession)) {
    . $PSScriptRoot\eSchool-Login.ps1 -username $username
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
                        $clearErrorURL = $baseUrl + '/Task/ClearErroredTask'
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

        #if task has taken longer than the Timeout we need to exit and close completely.
        if ((Get-Date) -gt $startTime.AddMinutes($Timeout)) {
            Write-Host "Error: Task took longer than $Timeout minutes." -ForegroundColor Red
            exit(1)
        }

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
        #The Download Definition has ran but we didn't specify to download a file. Exit properly.
        exit(0)
    	#$file = $reportsjson | Out-GridView -OutputMode Single
    }

    if (-Not($outputfile)) {
        $outputfile = $file.RawFileName
    }

    try {
        Write-Host "Info: Attemtping to download ""$($file.RawFileName)"" to ""$outputfile"" ... " -NoNewline
        Invoke-WebRequest -Uri "$($baseUrl)/Reports$($file.ReportPath -replace ('\\','/'))" -WebSession $eSchoolSession -OutFile $outputfile
        Write-Host "Success."

        if ($TrimCSVWhiteSpace) {
            if ($PSVersionTable.PSVersion -lt [version]"7.1.0") {
                Write-Host "Error: You specified you wanted to remove the CSV Whitespaces but his requires Powershell 7.1. Not modifying downloaded file." -ForegroundColor RED
            } else {

                #Find delimeter. This could be pipe or comma.
                $headers = Get-Content "$outputfile" | Select-Object -First 1
                if ($headers.IndexOfAny(',') -gt $headers.IndexOfAny('|')) {
                    $delimiter = ','
                } else {
                    $delimiter = '|'
                }

                Write-Host "Info: Cleaning up white spaces in CSV."
                $filecontents = Import-CSV "$outputfile" -Delimiter $delimiter

                #If file is empty we still need to replace | for , then exit.
                if (-Not($filecontents)) {
                    (Get-Content "$outputfile" -Raw) -replace '\|',',' | Out-File "$outputfile" -Force -NoNewline
                    exit
                }

                $filecontents | Foreach-Object {  
                    $_.PSObject.Properties | Foreach-Object {
                        try { $_.Value = $_.Value.Trim() } catch {} #after using pipe delimiter this fails sometimes.
                    }
                }

                if ($CSVUseQuotes) {
                    Write-Host "Info: Exporting CSV using quotes."
                    $filecontents | Export-Csv -UseQuotes Always -Path $outputfile -Force
                } else {
                    $filecontents | Export-Csv -UseQuotes AsNeeded -Path $outputfile -Force
                }

            }
        }



    } catch {
        Write-Host "Error: Failed to download file. $_" -ForegroundColor RED
        exit(1)
    }

} catch {
	write-host 'Error getting reports list.'
    exit(1)
}

exit