# eSchoolUpload

> Ben Janelle - 5/7/2019 - First working version  
Charles Weber 1/31/2020 - Parameters
Craig Millsap 2/7/2020 - Automated Database Selection, Current Year, and Cognos Password  
Craig Millsap 2/8/2020 - Generate HAC logins for Students and eSchool Download  
Craig Millsap 2/9/2020 - Sample Script with Download/Upload Definitions PDF  
Craig Millsap 10/12/2020 - Fix for stuck tasks that would indefinitely hang script.  
Craig Millsap 11/16/2020 - Choose the username format for Generating the HAC logins.  
Craig Millsap 3/11/2021 - Major overhaul. Now works with Powershell 7. Designed to be invoked with parameters eSchool Email Upload is now District Agnostic. Email Guardians Access Codes via GAM. Generate HAC Logins for Guardians and Students. Use CognosDefaults.ps1 if exists.


# eSchool Scripts
tldr:These scripts log you into eSchool, runs Upload or Download definitions, Uploads files or Downloads files. This requires a completed and ready file to upload, pre-built Upload or Download Definitions. Sample script and Upload/Download definitions are provided.

The initial use case for this was uploading and then inserting/updating student emails into their mailing contact records.
Our office folks often mis-type student email address, or don't put them in at all, and then those records don't come across to Clever, iStation, etc., causing various issues for students.

# eSchoolUpload.ps1
````
.\eSchoolUpload.ps1
  -username 0401cmillsap
  -InFile "students.csv"          #Any file you want uploaded to your user directory.
  -InterfaceID ASDFG              #Any Upload Definition you want to run after uploading the file.
  -RunMode V                      #V for Verify or R for Run.
````

# eSchoolDownload.ps1
````
.\eSchoolDownload.ps1  
  -username 0000username  
  -reportname "studentemails"             #Files that have a specific name  
  -reportnamelike "HomeAccessPasswords"   #Files that have the timestamp put at the end. This will download the latest version.  
  -outputfile                             #Path to place downloaded file. If not specified it will use the filename from eSchool.
  -InterfaceID                            #Your Download Definition. This will create the file specified by reportname. Script waits until all tasks are complete. This must be 5 characters. If you have a 3 character InterfaceID you must character pad it with spaces. Example:"WEB  "
````

# eSchoolGenerateHACLogins.ps1
````
.\eSchoolGenerateHACLogins.ps1  
  -username 0000username  
  -buildings "1,2,3"                       #Comma separated building number
  -GenerateLoginAs 7                       #Choose your format. Documented in the script.
  -Guardians                               #Generate guardians only.
  -GuardianPriority 2                      #Up to this number Priority Guardian.
````  

# .\Upload_Student_Email_Addresses.ps1
````
.\Upload_Student_Email_Addresses.ps1
  -username 0000username
  -ADField EmployeeID                      #What Active Directory Field do we need to match on?
  -skipupload                              #Create upload files but don't upload them.
  -EnableWebAccess                         #Optionally enable WEB_ACCESS flag on student accounts.
  -EnableGuardianWebAccess                 #Enable Guardians WEB_ACCESS flag.
  -GuardianPriority 2                      #Enable WEB_ACCESS for Guardians up to this Priority Number.
  -RunMode R                               #Everything is run in VERIFY mode by default.
````
# Download\Upload Definitions
Some sample definitions are supplied in the Definitions folder. Using Powershell 7 can you can run:
````
.\Definitions\Create_Definitions.ps1
````
This will create three definitions used to accomplish this task. This will not overwrite any existing definitions. The definitions will need to be named EMLDL,EMLUP,EMLAC.

# eSchool Table Exports
This script creates a Download Definition for the eSchool tables specified in the $tables variable.

The hard coded ones are @('REG','REG_STU_CONTACT','REG_CONTACT')

You can customize what tables you want in your export by specifying the $tables variable then running the script.
````
$tables = @('REG','REG_STU_CONTACT_ALERT')
.\TableExports\eSchool_Table_Exports.ps1 -username "0401cmillsap" -DefinitionName "EXPDB"
.\eSchoolDownload.ps1 -username "0401cmillsap" -InterfaceID "EXPDB" -reportname "REG CONTACT" -TrimCSVWhiteSpace
.\eSchoolDownload.ps1 -username "0401cmillsap" -reportname "REG STU CONTACT" -TrimCSVWhiteSpace
.\eSchoolDownload.ps1 -username "0401cmillsap" -reportname "REG CONTACT" -TrimCSVWhiteSpace
etc...
````

Alternatively you can schedule your Download Definitions to run a specific time then download the files that should be available in your directory.

Note: The delimiter is PIPE to work with fields that have commas in them. -TrimCSVWhiteSpace converts the file from PIPE delimiter to comma.
