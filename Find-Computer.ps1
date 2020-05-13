<#
This is a wildcard search for anything found for the computer string you typed, it will list the computer objects found in AD and then ping them and give you more info about each one.

Example:
    Find-Computer Batman-Cave01
#>


function Find-Computer
{
    #Provide these parameters
    param([string]$Computer)

    $found = Get-ADComputer -Filter "Name -like '*$Computer*'" | select name | foreach {
        Write-Host 'Pinging...' $_.name -ForegroundColor Yellow
    }

    $comps = Get-ADComputer -Filter "Name -like '*$Computer*'" | ForEach-Object {

        $ping = Test-Connection -CN $_.name -Count 2 -Quiet
      
        If ($ping -match 'True') 
        {
            
            #Logged on User
            try
            {
                $LoggedOnUser = (Get-WmiObject -Class win32_computersystem -ComputerName $_.name -ErrorAction Stop | select username |Format-Table -HideTableHeaders | out-string).Trim()
            }
            catch
            {
                Write-Warning "Error getting logged on user. RPC service is probably unavailable."
            }

            $AdditionalInfo = (Get-ADComputer -Identity $_.name -Properties Ipv4Address, OperatingSystem, DistinguishedName | select ipv4Address, OperatingSystem, DistinguishedName | Format-List Ipv4*, oper*, DistinguishedName | Out-String).Trim()

            #Results output
            write-host -ForegroundColor green $_.name " is online!"
            write-host "Logged On User: $LoggedOnUser`n$AdditionalInfo`n"

        }
        else 
        {
            write-host -ForegroundColor red $_.name " is offline"
        }
      
      }
}
