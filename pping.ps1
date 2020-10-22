# Summary: "Smart" ping which alerts you if host comes online or if the host goes down and then comes back online again. Useful for server reboots where you start pinging as soon as server restart command is sent but it stills pings until server is completely offline.
function pping
{
    param($hostname)

    # If ping-able
    if (Test-Connection $hostname -Quiet -Count 1)
    {

        # Ping until $hostname can no longer be pinged
        Write-Host "$hostname is currently online, waiting until it goes offline..."
        do {
            $ping = Test-Connection $hostname -Quiet -Count 1
            #write-host "host is still online..."
            start-sleep -Seconds 1.5
        } until (!$ping)

        # Wait for $hostname to come back online to notify
        Write-Host "$hostname is now offline, waiting for it to come online..."
        while (-not (Test-Connection $hostname -Quiet -Count 1))
        {
            Start-Sleep -Seconds 1.5
            #Write-Host "host is no longer online..."
        }
        Add-Type -AssemblyName Microsoft.VisualBasic
        $result = [Microsoft.VisualBasic.Interaction]::MsgBox("$hostname is BACK online!", 'OKOnly,SystemModal,Information', 'PPING')
        
        # Exit script otherwise the while loop below will trigger causing duplicate online message
        exit
    }

    while (-not (Test-Connection $hostname -Quiet -Count 1))
    {
        Start-Sleep -Seconds 1.5
    }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $result = [Microsoft.VisualBasic.Interaction]::MsgBox("$hostname is online!", 'OKOnly,SystemModal,Information', 'PPING')

}
