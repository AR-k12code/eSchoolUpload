<#

Generate HAC Logins for Students that are Active & Guardians with Priority of X and below.
Craig Millsap - 3/10/2021

I'm pretty sure you shouldn't use this anymore. But its here if you need it.
You should be able to schedule generating HAC Access Codes in eSchool Now.

Guardians must have the Web_Access Flag set to Y before it will generate their logins.
exit #until we get things figured out for the access code.

Username format is as follows:
1 - FirstInitial.LastName
2 - FirstInitial.MiddleInitial.LastName
3 - FirstName.LastName
4 - LastName.FirstInitial
5 - LastName.FirstInitial.MiddleInitial
6 - LastName.FirstName
7 - Email Address (Default)

#>

Param(
	[parameter(mandatory=$true,Helpmessage="Which buildings do you want to generate HAC logins for? Example:'1,2,3'")][String]$buildings, #***Variable*** What Buildings. Specified as a comma separated string.
	[parameter(mandatory=$true,Helpmessage="Eschool username")][string]$username,
	[parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")][string]$passwordfile="C:\Scripts\apscnpw.txt",
	[parameter(mandatory=$false,Helpmessage="Specify the time to wait before running the task")][int]$addtime = 1, #Specify the time in minutes to wait to run task
	[parameter(mandatory=$false,Helpmessage="Specify the username template to generate.")][int]$GenerateLoginAs = 7, # 7 is default using the email address.
	[parameter(mandatory=$false)][switch]$Guardians, #Generate Guardians Logins
	[parameter(mandatory=$false)][int]$GuardianPriority = 1, #Guardian Priority X and below. Want both guardians then put 2. Want all? Use something ridiculous like 9999
	[parameter(mandatory=$false)][switch]$OverrideExistingLogins #I would only ever use this on guardians to generate a new account using their email address.
)

if ((-Not($eSchoolLoggedIn)) -or (-Not(Get-Variable -Name eSchoolSession))) {
    Write-Host "Error: Failed to login to eSchool." -ForegroundColor Red
    exit(1)
}

#Generate HAC Logins
#This needs to be an array joined with '&' to produce an encoded URL form. You can not use a hash table because it has duplicate key names.
$params = @()

if ($Guardians) {
	$params += "SelectedTypes=G"
} else {
	$params += "SelectedTypes=M"
}

if ($OverrideExistingLogins) {
	$params += "OverrideExisting=true"
} else {
	$params += "OverrideExisting=false"
}

$params += @("SearchType=HACGENLOGINS","SortType=","SelectedBuildingsFlag=SELECTED","Buildings=$buildings","SelectedBuildingsAll=false","SelectedTypesCheckAll=false","GenerateLoginsFlag=L","GenerateLoginsAsFlag=$($GenerateLoginAs)","TaskScheduler.CurrentTask.Classname=Utilities4_0.CGenerateHACLogins","TaskScheduler.CurrentTask.TaskDescription=Generate HAC Logins & Passwords")

#Field #1 - Active Students Only.
$params += @("groupPredicate=false","Filter.Predicates[0].PredicateIndex=1","tableKey=reg","Filter.Predicates[0].TableName=reg","columnKey=reg.current_status","Filter.Predicates[0].ColumnName=current_status","Filter.Predicates[0].DataType=Char","Filter.Predicates[0].Operator=Equal","Filter.Predicates[0].Value=A")

if ($Guardians) {
	$params += @("groupPredicate=false","Filter.Predicates[1].LogicalOperator=And","Filter.Predicates[1].PredicateIndex=2","tableKey=reg_stu_contact","Filter.Predicates[1].TableName=reg_stu_contact","columnKey=reg_stu_contact.contact_priority","Filter.Predicates[1].ColumnName=contact_priority","Filter.Predicates[1].DataType=SmallInt","Filter.Predicates[1].Operator=LessThanOrEqualTo","Filter.Predicates[1].Value=$($GuardianPriority)")
	#not real sure specifying guardians again is needed but it makes me feel better.
	$params += @("groupPredicate=false","Filter.Predicates[2].LogicalOperator=And","Filter.Predicates[2].PredicateIndex=3","tableKey=reg_stu_contact","Filter.Predicates[2].TableName=reg_stu_contact","columnKey=reg_stu_contact.contact_type","Filter.Predicates[2].ColumnName=contact_type","Filter.Predicates[2].DataType=Char","Filter.Predicates[2].Operator=Equal","Filter.Predicates[2].Value=G")
}

#Not convinced this is needed.
#$params = @("groupPredicate=false","Filter.Predicates[1].LogicalOperator=And","Filter.Predicates[1].PredicateIndex=2","Filter.Predicates[1].DataType=Char")

#the rest.
$params += @("Filter.LoginId=$username","Filter.SearchType=HACGENLOGINS","Filter.SearchNumber=0","Filter.GroupingMask=","TaskScheduler.CurrentTask.ScheduleType=N","TaskScheduler.CurrentTask.SchdInterval=1","TaskScheduler.CurrentTask.ScheduledTimeTime=$((Get-Date).AddMinutes($addtime).ToString("hh:mm tt"))","TaskScheduler.CurrentTask.ScheduledTimeDate=$(Get-Date -UFormat %m/%d/%Y)","TaskScheduler.CurrentTask.Monday=false","TaskScheduler.CurrentTask.Tuesday=false","TaskScheduler.CurrentTask.Wednesday=false","TaskScheduler.CurrentTask.Thursday=false","TaskScheduler.CurrentTask.Friday=false","TaskScheduler.CurrentTask.Saturday=false","TaskScheduler.CurrentTask.Sunday=false")

$response3 = Invoke-WebRequest -Uri $hacloginsurl -WebSession $eSchoolSession -Method POST -Body $params

exit