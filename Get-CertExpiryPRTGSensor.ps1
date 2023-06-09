# Get certificate expiry date of a provided site and output the info into XML format for PRTG's EXEXML sensor.

Param (
    [STRING]$uri

)

# Create Web Http request to URI
$webRequest = [Net.HttpWebRequest]::Create($uri)
# Get URL Information
$webRequest.ServicePoint
# Retrieve the Information for URI
$response = $webRequest.GetResponse()
# Get SSL Certificate and its details
$webRequest.ServicePoint.Certificate
# Get SSL Certificate Expiration Date
$expiryDate = $webRequest.ServicePoint.Certificate.GetExpirationDateString()

# Close and dispose of the HttpWebRequest object. Otherwise, Powershell session may get stuck.
$response.Close()
$response.Dispose()

# Write-Host "Certificate for $uri expires on $expiryDate."

# Calculate time left in days
$datedifference = New-TimeSpan -Start (Get-Date) -End ($expiryDate)
$daysleft = $datedifference.days

$name = $webRequest.ServicePoint.Certificate.Subject

# Output for PRTG sensor
$xmlOutput = '<?xml version="1.0" encoding="UTF-8" ?><prtg>'
$xmlOutput = $xmlOutput + "<result>
<channel>$($name)</channel>
<value>$($daysleft)</value>
<limitmode>1</limitmode>
<LimitMinWarning>30</LimitMinWarning>
<LimitMinError>20</LimitMinError>
</result>"
$xmlOutput = $xmlOutput + "</prtg>"

# Output in console so PRTG sees the data
$xmlOutput
