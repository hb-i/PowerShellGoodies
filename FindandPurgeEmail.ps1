<#
When those pesky spam/phishing emails slip through the spam filter, you can use this script to find it by subject, review it, and then delete it from all user mailboxes.
Note: This runs a soft delete, email will still be available in the deleted items folder of the mailbox.

Necessary steps are taken in this script to avoid accidental deletion of items in the mailbox. Use at your own risk!
#>

Function Connect-SecurityCompliance
{
 
    $credentials = Get-Credential -Credential $env:USERNAME@mydomain.com
    Write-Output "Getting the Security & Compliance Center cmdlets"
     
    $Session = New-PSSession -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid/ `
        -ConfigurationName Microsoft.Exchange -Credential $credentials `
        -Authentication Basic -AllowRedirection
    Import-PSSession $Session
     
}

function ComplianceConnected
{
    Get-ComplianceCaseStatistics -ErrorAction SilentlyContinue | out-null
    $result = $?
    return $result
}
if (-not (ComplianceConnected))
{
    Write-Warning "Security and Compliance PowerShell session not connected yet. Enter your credentials!"
    Connect-SecurityCompliance
}
else
{
    Write-Host "Security and Compliance PowerShell session is connected already." -ForegroundColor Green
}

$email = Read-Host "Enter sender email address" 
$subject = Read-Host "Enter any part of subject line"

$date = (Get-Date).AddDays(-2) | Get-Date -UFormat "%m/%d/%Y"

$random = Get-Random -Minimum 11111 -maximum 99999
$compSearchName = "$env:USERNAME-$date-$random"

$search = "sent>" + $date + " AND From:`"" + $email + "`"" + " AND Subject:" + "`"$subject`""

# Create new compliance search
New-ComplianceSearch -Name $compSearchName -ExchangeLocation all -ContentMatchQuery $search

# Start it
Start-ComplianceSearch -Identity $compSearchName

# Run this till it shows Completed
Write-host "Waiting until compliance search is completed.`n"
Do
{
    $k = $k + 1
    Write-Host "." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}
While ((Get-ComplianceSearch -Identity $compSearchName).Status -ne "Completed")

Write-Host "`n"

# Show list of matching mailboxes
$compliancesearch = Get-ComplianceSearch -Identity $compSearchName

$foundresults = $compliancesearch.SuccessResults


# Run the commands below all at once until the #### line
$array = $foundresults.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries) | Where {
    $_ -notlike "*Item count: 0*"
}

Write-host `n"Search results:"
If ($array.Count -eq 0)
{
    Write-Host "0 items have been found, try another queue."
}
else
{
    $array
}
########################################################

Write-Warning "READ THE FOLLOWING VERY CAREFULLY!"
$Caution = Read-Host "Do you want to send these emails to mailbox's deleted items? (Y/N)"
if ($Caution -eq "Y")
{
    # Purge from mailboxes
    Write-Host "Running a SoftDelete"
    New-ComplianceSearchAction -SearchName $compSearchName -Purge -PurgeType SoftDelete -Confirm:$False

    # Make sure it all purged fine
    Get-ComplianceSearchAction -Identity "$($compSearchName)_Purge"
} else
{
    "Skipping the purge."
}
Write-Host "***End of script***`nYou can find the report at https://compliance.microsoft.com/contentsearch"
