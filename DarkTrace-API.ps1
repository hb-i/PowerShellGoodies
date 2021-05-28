# Provide the vars below, for api help visit https://customerportal.darktrace.com/product-guides/main/api-authentication-new
$publictoken = "YourPublicTokenFromDarkTraceAppliance"
$privatetoken = "YourPrivateTokenFromDarkTraceAppliance"
$request = "/modelbreaches"
$uri = "https://darktrace.example.com"
$fullpath = $uri + $request
#########################################

# Get time in UTC
$TimeNow = Get-Date
#get-date $TimeNow -f "yyyy-MM-dd HH:mm:ss"
$Time = $TimeNow.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

# Format the hmac text string properly
$message = ""
$message += "$request`n"
$message += "$publictoken`n"
$message += "$time"
$secret = "$privatetoken"

## Create the signature from the DarkTrace API's public and private tokens
$hmacsha = New-Object System.Security.Cryptography.HMACSHA1
$hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
$signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($message))
$signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()

#Write-Host $signature -ForegroundColor Green
#Write-Host $message -ForegroundColor Yellow

# Make the API call
Invoke-RestMethod -Uri $fullpath -Headers @{
    'DTAPI-Token' = $publictoken;
    'DTAPI-Date'  = $Time;
    'DTAPI-Signature' = $signature     
}

