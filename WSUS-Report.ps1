###PURPOSE###
<#
This script can send out emails for all members of an AD group you specify. If you have a GPO which gets servers of an AD group to update and reboot every Sunday at 2AM. You could schedule this to be sent out to you at 7AM. Then, you can quickly check your email in the morning and know the servers are back online and if they've successfully updated or not.

Sample Email Report:
https://imgur.com/a/eSspU2l
#>

###REQUIREMENTS###
<#
Must be run on WSUS server so it can access the WSUS powershell commands. The server must have AD management tools installed so it can use commands from the ActiveDirectory Powershell module.
#>

#HTML header for the HTML file, keeping the code below but not using it since $Body will take all the output and package into an HTML email output so this HTML file will not be needed.


$head = @"
<Title>Weekly Server Patching Report - $(Get-Date)</Title>
<style>
body { background-color:#FFFFFF;
       font-family:Tahoma;
       font-size:12pt; }
td, th { border:1px solid black; 
         border-collapse:collapse; }
th { color:white;
     background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px }
tr:nth-child(odd) {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px;}
</style>
<br>
<H1>Weekly Server Patching Report - $(Get-Date)</H1>
"@

# variable for CSS styles: 
$style = "<style>BODY{font-family:Verdana, Arial; font-size:9pt;}"
$style = $style + "TABLE{border-collapse:collapse; border: 1px solid black;}"
$style = $style + "TH{border:1px solid black; padding:5px; background:#878489;}"
#$style = $style + "TD{border:1px solid black; padding:5px; background:#2E8B57;}"
$style = $style + "</style>"
$style = $style + "<title>HTML Output</title>"

#HTML body we will add our outputs/results to.
$Body = ""

#Connect to wsus server on port 8530
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer("MyWSUSServer", $False, 8530)

#import AD Module
import-module ActiveDirectory

#Threshold for server reboot time (in hours), used to turn "Last Reboot" output for each server green or red depending on result.
$RebootTime = (Get-Date).AddHours(-12)

#Grab list of servers from the AD groups below. Sort them so they show up alphabetically in the html report.
$groups = "WSUS_Servers - Test", "WSUS_Servers - PreProd", "WSUS_Servers - Prod"

#This code checks whether $server is part of any of these groups. It will then put that group name in the report for the $server.
$TestMembers = Get-ADGroupMember -Identity "WSUS_Servers - Test" -Recursive | Select -ExpandProperty Name
$PreProdMembers = Get-ADGroupMember -Identity "WSUS_Servers - PreProd" -Recursive | Select -ExpandProperty Name
$ProdMembers = Get-ADGroupMember -Identity "WSUS_Servers - Prod" -Recursive | Select -ExpandProperty Name

foreach ($group in $groups) {$servers += Get-ADGroupMember -Identity $group | select -ExpandProperty name}
$servers = $servers | Sort-Object

foreach ($server in $servers)
{

    #Check which AD group $server is a part of. Use this to put that group name in the report for the $sever.
    If ($TestMembers -contains $server)
    {
        $Membership = "Test Group"
    }
    If ($PreProdMembers -contains $server)
    {
        $Membership = "Pre Prod Group"
    }
    If ($ProdMembers -contains $server)
    {
        $Membership = "Prod Group"
    }

    #If server can be pinged...
    if (Test-Connection $server -Quiet)
    {

        $OS = Get-ADComputer $server -Properties operatingsystem | Select -ExpandProperty operatingsystem

        #Get windows update info for server from WSUS server.
        $wsus = Get-WsusServer
        $WSUSClient = $wsus.GetComputerTargets() | ? { $_.FullDomainName -imatch $server }
        $WSUSInfo = [PSCustomObject]@{
            "Operating System"      = $OS
            "Updates Not Installed" = $WSUSClient.GetUpdateInstallationSummary().NotInstalledCount
            "Updates Installed"     = $WSUSClient.GetUpdateInstallationSummary().InstalledCount
            "Updates Downloaded"    = $WSUSClient.GetUpdateInstallationSummary().DownloadedCount
            "Updates Failed"        = $WSUSClient.GetUpdateInstallationSummary().FailedCount
        } | ConvertTo-Html -Head $style



        #Check the last reboot time.
        $time = Get-CimInstance -ClassName win32_operatingsystem -ComputerName $server | select -ExpandProperty lastbootuptime

        ###Check if server requires reboot or not###
        # Querying WMI for build version 
        $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber, CSName -ComputerName $server -Authentication PacketPrivacy -Impersonation Impersonate

        # Making registry connection to the local/remote computer 
        $RegCon = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine", $server) 

        If ($WMI_OS.BuildNumber -ge 6001) 
        { 
            $RegSubKeysCBS = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\").GetSubKeyNames() 
            $CBSRebootPend = $RegSubKeysCBS -contains "RebootPending" 
        }
        else
        {
            $CBSRebootPend = $false
        }
           
        # Query WUAU from the registry 
        $RegWUAU = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\") 
        $RegSubKeysWUAU = $RegWUAU.GetSubKeyNames() 
        $WUAURebootReq = $RegSubKeysWUAU -contains "RebootRequired" 
		
        If ($CBSRebootPend –OR $WUAURebootReq)
        {
            $machineNeedsRestart = $true
        }
        else
        {
            $machineNeedsRestart = $false
        }


        #Determine the reboot time and compare it to $RebootTime and give it the approperiate colour. Output for the tables is pretty much the same except the "background-color:" property for the html formatting will be different based on the result of those properties.
        if ($time -gt $RebootTime)
        {

            $serverInfoTable = @"

<table style="width: 507px; height: 67px;">
	<tbody>
		<tr>
			<td bgcolor="#00427F" style="color:#ffffff;width: 244px;"><span style="font-size:22px;"><strong>$server</strong></span></td>
			<td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;"><strong>Last Reboot</strong></span></td>
            <td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;">Reboot Required</span></td>
            <td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;">WSUS Group</span></td>
		</tr>
		<tr>
			<td bgcolor="#00FF00" style="width: 244px;">ONLINE</td>
			<td bgcolor="#00FF00" style="width: 262px;">&nbsp;$time</td>
            <td style="width: 262px;">$machineNeedsRestart</span></td>
            <td style="width: 262px;">$Membership</span></td>
		</tr>
	</tbody>
</table>

"@


            $Body += $serverInfoTable
        }
        else
        {

            $serverInfoTable = @"
<table style="width: 507px; height: 67px;">
	<tbody>
		<tr>
			<td bgcolor="#00427F" style="color:#ffffff;width: 244px;"><span style="font-size:22px;"><strong>$server</strong></span></td>
			<td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;"><strong>Last Reboot</strong></span></td>
            <td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;">Reboot Required</span></td>
            <td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;">WSUS Group</span></td>
		</tr>
		<tr>
			<td bgcolor="#00FF00" style="width: 244px;">ONLINE</td>
			<td bgcolor="#FF0000" style="width: 262px;">&nbsp;$time</td>
            <td style="width: 262px;">$machineNeedsRestart</span></td>
            <td style="width: 262px;">$Membership</span></td>
		</tr>
	</tbody>
</table>

"@

            $Body += $serverInfoTable



        }

        $Body += $WSUSInfo

        #Show updates done in last X days. Sometimes updates installed dont require a reboot, check this table if server reboot time is red.
        $updates = Get-WmiObject -Class 'win32_quickfixengineering' -computername $server | Where {$_.InstalledOn -gt (Get-Date).AddDays(-25)} | select InstalledOn, HotFixID, Description | sort InstalledOn | ConvertTo-HTML -Fragment
        $Body += "$updates"
        $Body += "<hr>"
        $Body += "<br>"
    }
    else
    {

        $serverInfoTable = @"
<table style="width: 507px; height: 67px;">
	<tbody>
		<tr>
			<td bgcolor="#00427F" style="color:#ffffff;width: 244px;"><span style="font-size:22px;"><strong>$server</strong></span></td>
			<td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;"><strong>Last Reboot</strong></span></td>
            <td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;">Reboot Required</span></td>
            <td bgcolor="#00427F" style="color:#ffffff;width: 262px;"><span style="font-size:22px;">WSUS Group</span></td>
		</tr>
		<tr>
			<td bgcolor="#FF0000" style="width: 244px;">OFFLINE</td>
			<td bgcolor="#FF0000" style="width: 262px;">&nbsp;$time</td>
            <td style="width: 262px;">$machineNeedsRestart</span></td>
            <td style="width: 262px;">$Membership</span></td>
		</tr>
	</tbody>
</table>

"@

        $Body += $serverInfoTable
    }

}

#Save results as HTML
ConvertTo-HTML -Head $head -Body $body -CssUri C:\temp\blue.css -Title "File Report" -PostContent "<h6>Generated at $(Get-Date). Ran from $env:COMPUTERNAME.</h6>"|
    Out-File C:\temp\PatchReport.html -Encoding ascii

############
#SEND EMAIL#
############
###########Define Variables Below######## 
$Date = (Get-Date)
$fromaddress = "PatchReport@example.com"
$toaddresses = @("receipient@example.com")
$Subject = "Weekly Patch Report - $Date" 
$body = $Body
#$attachment = "C:\temp\PatchReport.html" 
$smtpserver = "mail.example.com" 
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
#$attach = new-object Net.Mail.Attachment($attachment) 
#$message.Attachments.Add($attach) 

#Output the saved report as body of the email message instead of adding it as an attachment (that's why the lines above are commented out)
$message.body = (get-content C:\temp\PatchReport.html | out-string) 
$smtp = new-object Net.Mail.SmtpClient($smtpserver) 
$smtp.Send($message) 
