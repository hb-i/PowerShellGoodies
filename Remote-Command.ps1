#This script will run given command on remote computer and give you the result of it, it will enable psremoting via psexec if it's not enabled already and then try again.

###INSTRUCTIONS###
<#
Run this script first and then run commands below.

Run a command on remote computer and output the result here.
Ensure you have C:\Users\YourUsername\psexec.exe present.
Run this script, then run the Remote-Command command.

Examples:
Remote-Command -Computer remotecomputer1 -Command ipconfig
Remote-Command -Computer remotecomputer1 -Command "Get-Service -Name *dh*"
Remote-Command -Computer remotecomputer1 -Command "wmic bios get serialnumber"
Remote-Command -Computer remotecomputer1 -Command "Get-WmiObject -Class Win32_Product | Select-Object -Property Name, Version | Sort-Object Name, Version"

Make sure to use quotation if -Command input contains spaces (examples above). PSExec is required.
#>


function Remote-Command
{
    #Provide these parameters
    param([string]$Computer, [string]$Command)

    #Try to run invoke-command on remote PC, if it fails then try enabling PSRemoting via PSExec
    try
    {
        Invoke-Command -ComputerName $Computer -ScriptBlock {powershell.exe -command $using:Command} -ErrorAction Stop
        
        Exit
    }
    catch
    {
    
        #Enable PSRemoting via PSExec and then try command again
        Write-Host "Remoting is NOT enabled on $Computer. Enabling it now." -ForegroundColor Yellow
    
        psexec.exe \\$Computer -s powershell Enable-PSRemoting -Force
    
        Write-Host "Trying to run command again." -ForegroundColor Yellow

        Start-Sleep -Seconds 3

        Invoke-Command -ComputerName $Computer -ScriptBlock {powershell.exe -command $using:Command} -ErrorAction Stop
    
        Exit
    }
    #Execute function
    Remote-Command
}
