# eSchoolUpload
These scripts log you into eSchool, runs Upload or Download definitions, Uploads files or Downloads files. This requires a completed and ready file to upload, pre-built Upload or Download Definitions. Sample script and Upload/Download definitions are provided.

The initial use case for this was uploading and then inserting/updating student emails into their mailing contact records.
Our office folks often mis-type student email address, or don't put them in at all, and then those records don't come across to Clever, iStation, etc., causing various issues for students.

Contributors: Ben Janelle, Charles Weber, Craig Millsap

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
Using Powershell 7 can you can run create the needed Upload/Download tasks for email by running:
````
.\Definitions\Create_Definitions.ps1
````
This will create three definitions used to accomplish this task. This will not overwrite any existing definitions. The definitions will need to be named EMLDL,EMLUP,EMLAC.

![EMLDL Definition](https://github.com/AR-k12code/eSchoolUpload/blob/master/Definitions/EMLDL.png?raw=true "Download Definition for emails from eSchool")
![EMLUP Definition](https://github.com/AR-k12code/eSchoolUpload/blob/master/Definitions/EMLUP.png?raw=true "Upload Definition for setting emails in eSchool")
![EMLAC Definition](https://github.com/AR-k12code/eSchoolUpload/blob/master/Definitions/EMLAC.png?raw=true "Upload Definition for turning on Web Acceess Flag")