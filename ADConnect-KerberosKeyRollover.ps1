# Use the commands below once to generate a hashed password file for the script to use with Azure.
# $credential = Get-Credential
# $credential.Password | ConvertFrom-SecureString | set-content C:\Scripts\Azure_Encrypted.txt

# Use the commands below to generate a hashed passworrd file for on-premise user.
# $credential = Get-Credential
# $credential.Password | ConvertFrom-SecureString | set-content C:\Scripts\Onprem_Encrypted.txt

# Use the Azure and on-premise user credentials to roll over Kerberos decryption key
$CloudUser = 'myusername@example.onmicrosoft.com'
$CloudEncrypted = Get-Content "C:\Scripts\Azure_Encrypted.txt" | ConvertTo-SecureString
$CloudCred = New-Object System.Management.Automation.PsCredential($CloudUser,$CloudEncrypted)

$OnpremUser = 'example.com\domainadministrator'
$OnpremEncrypted = Get-Content "C:\Scripts\Onprem_Encrypted.txt" | ConvertTo-SecureString
$OnpremCred = New-Object System.Management.Automation.PsCredential($OnpremUser,$OnpremEncrypted)

Import-Module 'C:\Program Files\Microsoft Azure Active Directory Connect\AzureADSSO.psd1'
New-AzureADSSOAuthenticationContext -CloudCredentials $CloudCred

# Run the command and log it so the logs can be send via email
$loglocation = "C:\Scripts\Rollover_Kerberos.log"
Start-Transcript -Path $loglocation

Update-AzureADSSOForest -OnPremCredentials $OnpremCred

Stop-Transcript

# Remove the header info at the top of the log file which isnt needed.
# This will remove everything before the first occurence of  'output file is' string in the text file.
$output = (Get-Content $loglocation -raw) -replace '(.+\n)+(.+)?(?=output file is)'
$output | Out-File $loglocation

# Text to prepend to the email body
$emailbody = "The Kerberos decryption key rollover command ran on $env:COMPUTERNAME via scheduled task. See output of the command below to confirm it was successful.`n`n"

$emailbody = $emailbody + $(Get-Content $loglocation -raw)

############
#SEND EMAIL#
############
###########Define Variables Below######## 
$fromaddress = "sender@example.com"
$toaddresses = @("recipient@example.com", "recipient2@example.com")
$Subject = "$env:COMPUTERNAME - Kerberos Key Rollover - $(get-date -Format dd-MM-yyyy)" 
$body = $emailbody
$smtpserver = "mailserver.example.com" 
#################################### 
$message = new-object System.Net.Mail.MailMessage 
$message.From = $fromaddress 

#Loop through and add multiple receipients in the $toaddresses array above.
foreach ($toaddress in $toaddresses)
{
    $message.To.Add($toaddress) 
}

$message.IsBodyHtml = $False 
$message.Subject = $Subject 
$message.body = $body
$smtp = new-object Net.Mail.SmtpClient($smtpserver) 
$smtp.Send($message) 
