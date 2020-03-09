# eSchoolUpload

Ben Janelle - 5/7/2019 - First working version  
Charles Weber 1/31/2020  
Craig Millsap 2/7/2020 - Automated Database Selection, Current Year, and Cognos Password  
Craig Millsap 2/8/2020 - Generate HAC logins for Students and eSchool Download  
Craig Millsap 2/9/2020 - Sample Script with Download/Upload Definitions PDF

eSchool Scripts
tldr:These scripts log you into eSchool, runs Upload or Download definitions, Uploads files or Downloads files. This requires a completed and ready file to upload, pre-built Upload or Download Definitions. Sample script and Upload/Download definitions are provided.

The initial use case for this was uploading and then inserting/updating student emails into their mailing contact records.
Our office folks often mis-type student email address, or don't put them in at all, and then those records don't come accross to Clever, iStation, etc., causing various issues for students.

eSchoolDownload.ps1
-------------------------------------------------------------------------
./eSchoolDownload.ps1  
  -username 0000username  
  -reportname "studentemails" #Files that have a specific name  
  -reportnamelike "HomeAccessPasswords" #Files that have the timestamp put at the end. This will download the latest version.  
  -outputfile #Path to place downloaded file. If not specified it will use the filename from eSchool  
  -InterfaceID #Your Download Definition. This will create the file specified by reportname. Script waits until all tasks are complete. This must be 5 characters. If you have a 3 character InterfaceID you must character pad it with spaces. Example:"WEB  "

eSchoolGenerateHACLogins.ps1
-------------------------------------------------------------------------
./eSchoolGenerateHACLogins.ps1  
  -username 0000username  
  -buildings "1,2,3" #comma separated building number

Troubleshooting command examples
-------------------------------------------------------------------------
$form | Format-List :Shows the form method, action, and fields (with what they're currently set to, if space allows)
$form.Fields  :Shows all the individual fields, and what they're currently set to

Could also do something like: $response.Forms[0] | Format-List

Sources
-------------------------------------------------------------------------
"Man" page (specifically "Example 2"): https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-4.0
Decent general overview of Invoke-WebRequest: https://www.adamtheautomator.com/invoke-webrequest-powershell/
For multipart/form-data I used a (way) simplified version of: http://blog.majcica.com/2016/01/13/powershell-tips-and-tricks-multipartform-data-requests/

Special thanks to all the Cognos Downloader folks.  I don't even know who all did that initial work, but you proved there was a way!
