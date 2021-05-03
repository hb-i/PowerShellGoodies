# Start a custom interval timer and show Windows notification when it reaches 0, reset with a 60 second cooldown.

Add-Type -AssemblyName System.Windows.Forms 

[int]$custominput = Read-Host "Enter interval time in minutes [Default: 60]"

while ($true)
{
    if ($custominput -eq '')
    {
        $i = 3600
    }
    else
    {
        $i = $custominput * 60 
    }

    do
    {
        $ts = [timespan]::fromseconds($i)
        Write-Host -NoNewLine "`r$ts"
        Sleep 1
        $i--
    } while ($i -gt 0)

    $global:balloon = New-Object System.Windows.Forms.NotifyIcon
    $path = (Get-Process -id $pid).Path
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path) 
    $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info 
    $balloon.BalloonTipText = 'Countdown timer is now resetting, entering cooldown.'
    $balloon.BalloonTipTitle = "Attention $Env:USERNAME" 
    $balloon.Visible = $true 
    $balloon.ShowBalloonTip(10000)

    $j = 60
    do
    {
        $cooldown = [timespan]::fromseconds($j)
        Write-Host -NoNewLine "`r$cooldown"
        Sleep 1
        $j--
    } while ($j -gt 0)

}
