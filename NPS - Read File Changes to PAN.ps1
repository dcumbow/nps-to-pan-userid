<#
##Modified by Nick Shores - 5-17-19
- Script updated to read new XML format used in newer versions of NPS server


How to Setup:
For your NPS log files (NPS -> Accounting -> Log File Properties):
Check the boxes for Accounting Requests and Periodic Accounting Status
Uncheck the boxes for Authentication Requests and Periodic Authentication Status


Put the PS1 and XML file in a folder (C:\scripts\PANuserID, for example) on your NPS server.
Run this script as a scheduled task that starts running at 12:00:05AM daily.
Call with powershell.exe -NoExit -File "C:\scripts\PANuserID\NPS - Read File Changes to PAN.ps1" (change if needed)
Set the task to stop existing instances when a new one starts (Under Settings when setting up the task, very bottom).
Update the CHANGE ME IF NEEDED info below to match log and script locations as well as your PAN URL and API key.


#>

#check if the job already exists, unregistere the filewatch event and remove job
if ([bool](get-job -Name PAN-UserID-Mapping -ErrorAction SilentlyContinue))
{
    Unregister-Event PAN-UserID-Mapping
    Remove-Job -Name PAN-UserID-Mapping -Force
}

#create file and folder location variables
$date = get-date -Format "yyMMdd"
# CHANGE ME IF NEEDED
$folder = 'C:\Windows\System32\LogFiles' # Default location for Microsoft NPS lineogs
# CHANGE ME IF NEEDED
$filter = 'IN' + $date + '.log' # Using date variable identified above, default name for NPS logs

#setup file system watcher object
$fsw = New-Object IO.FileSystemWatcher $folder, $filter -Property @{IncludeSubdirectories = $true;NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'}

#register file system watcher object as an event, start monitoring file
Register-ObjectEvent $fsw Changed -SourceIdentifier PAN-UserID-Mapping -Action {
#Bypass TLS check
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$path = $Event.SourceEventArgs.FullPath
Out-File -FilePath C:\scripts\PANuserID\debug.txt -Append -InputObject "Path is $path"

#get last line of NPS log, create an XML object
[xml] $xdoc = (Get-Content -Tail 1 $path)

#assign variable for user, NPS has username in 6th column (index 5)
$newUser = $xdoc.Event.'User-Name'.'#text'

#grab ip of user
$newIP = $xdoc.Event.'NAS-IP-Address'.'#text'
#create final user variable with PAN formated username
$user = $newUser.ToLower()

# Optional log file that can be created to monitor what's being pulled from the log file.
Out-File -FilePath C:\scripts\PANuserID\config_changes.txt -Append -InputObject "$(Get-Date), Username: $user, IP Address: $newIP"

#dir to find the XML template file
# CHANGE ME IF NEEDED
$dir = "C:\scripts\"

#full path of the XML template file
# CHANGE ME IF NEEDED
$pathXml = $dir + "userIDfile.xml"

#read the XML file
$xml = [xml](Get-Content $pathXml)

#read the node that contains username and ip
$node = $xml.'uid-message'.payload.login.entry
#assign user to node.name
$node.name = $User
#assign ip to node.ip
$node.ip = $newIP

#save modified information back to XML template
$xml.Save($pathXml)

#create a web-clietn object, upload XML template file to PAN box
$wc = New-Object System.Net.WebClient
# CHANGE ME - PAN URL and API key
$wc.UploadFile( 'https://<IPADDRESS>/api/?type=user-id&key=<API_KEY>',$pathXml)

}


# To stop the monitoring, run the following commands:
# Unregister-Event PAN-UserID-Mapping
# Remove-Job -Name PAN-UserID-Mapping -Force

