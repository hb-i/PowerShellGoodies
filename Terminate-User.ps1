Clear-Host

Import-Module MSOnline -Force

#Verify ad user exists before running script
do
{
    $termUser = Read-Host "Enter username to terminate"
    if (dsquery user -samid $termUser) {write-host "Success: User found in AD." -ForegroundColor Green}

    elseif ($termUser = "null") {write-host "Error: User not found. :(" -ForegroundColor Red} 
}
while ($termUser -eq "null")

#Secure permissions to this path
$savefile = "\\server\share\$termUser.txt"

$date = Get-Date -Format g

Write-Host @"
--------------------------------------------
Which Disabled OU is this user going under? |
--------------------------------------------
Enter 1 for Company1    |
Enter 2 for Company2    |
-------------------------
"@ -ForegroundColor Yellow

$company = read-host "Enter selection"

#Put user in the correct Disabled OU based on which company they belong to.
if ($company -eq 1) {$OUpath = 'OU=Company1 Disabled,OU=Disabled,DC=domain,DC=com'}; if ($company -eq 2) {$OUpath = 'OU=Company2 Disabled,OU=Disabled,DC=domain,DC=com'}

$GroupMemberships = Get-ADPrincipalGroupMembership $termUser | Select-Object -ExpandProperty name

#Add header to text file
"------------------------------------------------`nNEW USER TERMINATION PROCESS $date`n------------------------------------------------`n---FOLLOWING GROUP MEMBERSHIPS WILL BE REMOVED---" | Out-File $savefile -Append

#Write group memberships to text file before removing them
Write-Host "Starting log file for termination at $savefile." -BackgroundColor Yellow -ForegroundColor Black

$GroupMemberships | Out-File $savefile -Append

#Remove group memberships except "Domain Users"
try {
    Write-host "Following group memberships are being removed" -ForegroundColor Yellow
    Get-ADPrincipalGroupMembership -Identity  $termUser | Format-Table -Property name

    $ADgroups = Get-ADPrincipalGroupMembership -Identity  $termUser | Where-Object {$_.Name -ne "Domain Users"}
    Remove-ADPrincipalGroupMembership -Identity  $termUser -MemberOf $ADgroups -Confirm:$false
    Write-host "User removed from all groups except 'Domain Users'." -ForegroundColor Green
}
catch {
    Write-Host "Error removing group memberships" -ForegroundColor Red
}

#Move user to 'To be deleted' OU
try {
    Get-ADUser -Identity $termUser | Move-ADObject -TargetPath $OUpath
    Write-Host "User object moved to $ouPath." -ForegroundColor Green

    "`nUser object moved to $ouPath." | Out-File $savefile -Append
}
catch {
    Write-Host "Error moving user object to $ouPath" -ForegroundColor Red
}

#Get current Description from AD user
"`nFollowing user description is being removed..." | Out-File $savefile -Append
$currentDesc = get-aduser $termUser -Properties Description | Select-Object -ExpandProperty Description | Out-File $savefile -Append
Write-Host "Replacing user description "$currentDesc"" -ForegroundColor Yellow

#Change Description to "DISABLED YYYY.MM.DD - CURRENT USER"
$terminatedby = $env:username
$termDate = get-date -uformat "%Y.%m.%d"
$termUserDesc = "DISABLED " + $termDate + " - " + $terminatedby
set-ADUser $termuser -Description $termUserDesc 
Write-Host "$termUser description has been set to "$termUserDesc"" -ForegroundColor Green

"`n$termUser description has been set to `"$termUserDesc`"" | Out-File $savefile -Append

#Generate random password using dinopass.com API and reset AD user password.
$GeneratePassword = Invoke-restmethod -uri "http://www.dinopass.com/password/strong"
$Password = $GeneratePassword

try {
    Set-ADAccountPassword -Identity $termUser -NewPassword (ConvertTo-SecureString -AsPlainText "$Password" -Force) -Reset
    Write-Host "Password changed to: $password" -ForegroundColor Green
    "`nPassword changed to: $password" | Out-File $savefile -Append
}
catch {
    Write-Host "`nError changing user password to $Password" -ForegroundColor Red
}

#Disable Account
try {
    Disable-ADAccount -Identity $termuser
    Write-Host "ACCOUNT HAS BEEN DISABLED!" -ForegroundColor Green
    "`nACCOUNT HAS BEEN DISABLED!" | Out-File $savefile -Append
}
catch {
    Write-Host "ERROR DISABLING THE ACCOUNT! Dont forget to hide user for Global Address List in Exchange." -ForegroundColor Red
}

$CommentPrompt = read-host "Type 'y' if you want to enter additional comments to the log file"
    if ($CommentPrompt -eq "y")
    {
        "`nAdditional Comments:" | Out-File $savefile -Append
        read-host "Enter Comment" | Out-File $savefile -Append
    }
    else {
        Read-Host "Press any key to exit"
    }
