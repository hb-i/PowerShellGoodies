<#
Followed guide in the link below. Script is a modified version of the one found there.
https://myworldofit.net/?p=9127
WinSCP must be installed. Modify variables below if any locations change. Fill out switches.csv file as this grabs the switch info from there to sftp into it via WinSCP.
Create a table from the results as they come in from each switch and email them out.
#####HP SWITCH GUIDE#####
- SSH into switch
- Aruba Switch command: config
- Aruba Switch command to enable sftp: ip ssh filetransfer
- Aruba Switch command to save configuration permanently: write memory 
#>


#location of backups
$backuplocation = "c:\git\Switches\"

<# 
# Delete all Files in $backuplocation older than 60 days. (prevent too many copies)
# Not needed with Git :D
write-host "deleting files older than 60 days in $backuplocation."
$Daysback = "-60"
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem -File $backuplocation -include * -Recurse | Where-Object { $_.CreationTime -lt $DatetoDelete } | Remove-Item -Force -Recurse
#>

$headstyle = @"
<style>
TABLE{border-width: 1px;border-style: solid;border-color:black;}
Table{background-color:#ffffff;border-collapse: collapse;}
TH{border-width:1px;padding:0px;border-style:solid;border-color:black;}
TD{border-width:1px;padding-left:5px;border-style:solid;border-color:black;}
</style>
"@

#Load the .NET assembly for WinSCP
Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"

#Import the CSV containing switch details and store it in a variable. Secure permissions to this file!
$switches = Import-Csv -Path "C:\Git\Switches\switches.csv"

#Get the current system date in the format year/month/date which will be used to name the backup files. Again, not needed with Git.
#$date = Get-Date -Format yyyy-M-d-[HH-mmtt]

#Create Table object
$tabName = "Switch Backup Report"
$table = New-Object system.Data.DataTable "$tabName"

#Define Columns
$col1 = New-Object system.Data.DataColumn "Switch", ([string])
$col2 = New-Object system.Data.DataColumn "Status", ([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)

#Loop over the lines in the CSV
Foreach ($line in $switches)
{

    #Define the folder to store the output in and create it if it does not exist (if the folder exists already this will generate a non-blocking error)
    $outputfolder = "c:\git\Switches\Backup\" + $line.hostname + "\"

    if (Test-Path $outputfolder)
    {
        
    }
    else
    {
        New-Item $outputfolder -ItemType Directory
    }


    #Define the path to store the result of the download
    $outputpath = $outputfolder + "Backup"

    #define the additional columns to store from excel file
    $path = $line.path
    $sourcefile = $line.sourcefile
    $file = $path + $sourcefile

    #Store the session details
    $sessionOptions = New-Object WinSCP.SessionOptions
    $sessionOptions.Protocol = [WinSCP.Protocol]::Sftp
    $sessionOptions.HostName = $line.hostname
    $sessionOptions.UserName = $line.username
    $sessionOptions.Password = $line.password
    $sessionOptions.SshHostKeyFingerprint = $line.sshhostfingerprint
    $session = New-Object WinSCP.Session

    #Connect to the host
    $session.Open($sessionOptions)

    #Define the transfer options
    $transferOptions = New-Object WinSCP.TransferOptions
    $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

    #Download the startup-config (the result of the last 'write memory' from the switches CLI) and save it to the outputpath
    $transferResult = $session.GetFiles($file, $outputpath, $False, $transferOptions)

    #Disconnect from the server
    $session.Dispose()

    #Check if file has been copied or not
    if (test-path -LiteralPath $outputpath)
    {
        $hostname = $sessionOptions.HostName
        Write-Host "$hostname backed up successfully." -ForegroundColor Green

        #Create a row
        $row = $table.NewRow()
        #Enter data in the row
        $row.Switch = "$hostname" 
        $row.Status = 'Success' 
        #Add the row to the table
        $table.Rows.Add($row)

    }
    else 
    {
        $hostname = $sessionOptions.HostName
        Write-Host "$hostname backup failed." -ForegroundColor Red

        #Create a row
        $row = $table.NewRow()
        #Enter data in the row
        $row.Switch = "$hostname" 
        $row.Status = "Failed" 
        #Add the row to the table
        $table.Rows.Add($row)
    }

}

#Display the table
#$emailbody = $table | select Switch,Status | ConvertTo-Html -Head $style | Out-String

$body += $table | select Switch, Status | ConvertTo-Html -Head $headstyle | Out-String
$body += "Ran from $env:COMPUTERNAME on $Date."
$body += "`nBackup location: $backuplocation."
$body += "`nFiles older than $DatetoDelete have been deleted automatically.`n"

#Git Push
cd C:\Git\Switches
$logAdd = git add .
$logCommit = git commit -m 'scheduled'
$logPush = git push -u origin master -q

$Body += "`n Git Push Update...`n"
$Body += $logAdd
$Body += $logCommit
$Body += $logPush


############
#SEND EMAIL#
############
###########Define Variables Below######## 
$Date = (Get-Date)
$fromaddress = "SwitchesBackup@example.com"
$toaddresses = @("receiver@example.com")
$Subject = "Switches Backup Report - $Date"
$smtpserver = "dc-relay.example.com" 
#################################### 
$message = new-object System.Net.Mail.MailMessage 
$message.From = $fromaddress 

#Loop through and add multiple receipients in the $toaddresses array above.
foreach ($toaddress in $toaddresses)
{
    $message.To.Add($toaddress) 
}

$message.IsBodyHtml = $True 
$message.Subject = $Subject 
$message.body = $body
$smtp = new-object Net.Mail.SmtpClient($smtpserver) 
$smtp.Send($message) 

#clear $body, this is so if you're testing the script, it will prevent keeping tables without clearing them when you run it over and over in one powershell session.
$body = ""

#end of code
