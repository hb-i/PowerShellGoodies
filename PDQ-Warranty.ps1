# PDQ Inventory scanner profile to capture warranty info on Dell and Microsoft devices.
# Dont forget to change $ApiKey and $KeySecret, you can request the api key using your Dell TechDirect account.

$vendor = (Get-WMIObject Win32_ComputerSystemProduct).Vendor

# Output/proceed if vendor is Dell
if ($vendor -like "*Dell*")
{
    $computername = $env:COMPUTERNAME
    $servicetags = (Get-WmiObject win32_bios).SerialNumber

    $ApiKey = 'ENTER YOUR OWN API KEY HERE!'
    $KeySecret = 'ENTER YOUR OWN KEY SECRET HERE!'

    [String]$servicetags = $ServiceTags -join ", "

    $AuthURI = "https://apigtwb2c.us.dell.com/auth/oauth/v2/token"
    $OAuth = "$ApiKey`:$KeySecret"
    $Bytes = [System.Text.Encoding]::ASCII.GetBytes($OAuth)
    $EncodedOAuth = [Convert]::ToBase64String($Bytes)
    $Headers = @{ }
    $Headers.Add("authorization", "Basic $EncodedOAuth")
    $Authbody = 'grant_type=client_credentials'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Try
    {
        $AuthResult = Invoke-RESTMethod -Method Post -Uri $AuthURI -Body $AuthBody -Headers $Headers
        $Global:token = $AuthResult.access_token
    }
    Catch
    {
        $ErrorMessage = $Error[0]
        Write-Error $ErrorMessage
        BREAK        
    }
    #Write-Host "Access Token is: $token`n"

    $headers = @{"Accept" = "application/json" }
    $headers.Add("Authorization", "Bearer $token")

    $params = @{ }
    $params = @{servicetags = $servicetags; Method = "GET" }

    $Global:response = Invoke-RestMethod -Uri "https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements" -Headers $headers -Body $params -Method Get -ContentType "application/json"

    foreach ($Record in $response)
    {
        $servicetag = $Record.servicetag
        $Json = $Record | ConvertTo-Json
        $Record = $Json | ConvertFrom-Json
        $Device = $Record.productLineDescription
        $shipDate = ($Record.shipDate)
        $Support = ($Record.entitlements | Select -Last 1).serviceLevelDescription
        $shipDate = $shipDate | Get-Date -f "MM-dd-yyyy"

        $EndDate = ($Record.entitlements | Select -Last 1).endDate
        $EndDate = $EndDate | Get-Date -f "MM-dd-yyyy"
        $today = get-date

        #Write-Host "$servicetag, $shipDate - $EndDate"



        $PSObject = [PSCustomObject]@{
            ComputerName   = $computername
            ServiceTag     = $servicetag
            PurchaseDate   = $shipDate
            ExpirationDate = $EndDate
        }
        Write-Output $PSObject
    }
}
# following Microsoft API code is taken from link below and customized to suit PDQ.
# https://www.cyberdrain.com/automating-with-powershell-automating-warranty-information-reporting/
elseif ($vendor -like "*Microsoft*")
{

    $SourceDevice = (Get-WmiObject win32_bios).SerialNumber
    
    $body = ConvertTo-Json @{
        sku          = "Surface_"
        SerialNumber = "$SourceDevice"
        ForceRefresh = $false
    }

    $today = Get-Date -Format MM-dd-yyyy
    $PublicKey = Invoke-RestMethod -Uri 'https://surfacewarrantyservice.azurewebsites.net/api/key' -Method Get
    $AesCSP = New-Object System.Security.Cryptography.AesCryptoServiceProvider 
    $AesCSP.GenerateIV()
    $AesCSP.GenerateKey()
    $AESIVString = [System.Convert]::ToBase64String($AesCSP.IV)
    $AESKeyString = [System.Convert]::ToBase64String($AesCSP.Key)
    $AesKeyPair = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$AESIVString,$AESKeyString"))
    $bodybytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $bodyenc = [System.Convert]::ToBase64String($AesCSP.CreateEncryptor().TransformFinalBlock($bodybytes, 0, $bodybytes.Length))
    $RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    $RSA.ImportCspBlob([System.Convert]::FromBase64String($PublicKey))
    $EncKey = [System.Convert]::ToBase64String($rsa.Encrypt([System.Text.Encoding]::UTF8.GetBytes($AesKeyPair), $false))
      
    $FullBody = @{
        Data = $bodyenc
        Key  = $EncKey
    } | ConvertTo-Json
      
    $WarReq = Invoke-RestMethod -uri "https://surfacewarrantyservice.azurewebsites.net/api/v2/warranty" -Method POST -body $FullBody -ContentType "application/json"
    if ($WarReq.warranties)
    {
        $WarrantyState = foreach ($War in ($WarReq.warranties.effectiveenddate -split 'T')[0])
        {
            if ($War -le $today) { "Expired" } else { "OK" }
        }
        $WarObj = [PSCustomObject]@{
            'ComputerName'   = $env:COMPUTERNAME
            'ServiceTag'     = $SourceDevice
            #'Warranty Product name' = $WarReq.warranties.name -join "`n"
            'PurchaseDate'   = (($WarReq.warranties.effectivestartdate | sort-object -Descending | select-object -last 1) -split 'T')[0] | Get-Date -f "MM-dd-yyyy"
            'ExpirationDate' = (($WarReq.warranties.effectiveenddate | sort-object | select-object -last 1) -split 'T')[0] | Get-Date -f "MM-dd-yyyy"
            #'Warranty Status'       = $WarrantyState
        }
    }
    else
    {
        $WarObj = [PSCustomObject]@{
            'ComputerName'   = $env:COMPUTERNAME
            'ServiceTag'     = $SourceDevice
            #'Warranty Product name' = 'Could not get warranty information'
            'PurchaseDate'   = ""
            'ExpirationDate' = ""
            #'Warranty Status'       = 'Could not get warranty information'
        }
    }
    Write-Output $WarObj
}
# Just take the serial number if not Dell/Microsoft. This is needed because PDQ reporting will not output non-Dell/Microsoft devices if this custom PDQ sensor fields dont exist for non-Dell/Microsoft devices.
else
{
    $computername = $env:COMPUTERNAME
    $servicetag = (Get-WmiObject win32_bios).SerialNumber

    $PSObject = [PSCustomObject]@{
        ComputerName   = $computername
        ServiceTag     = $servicetag
        PurchaseDate   = ""
        ExpirationDate = ""
    }
    Write-Output $PSObject

}
