# Map drive via PowerShell for logged in user by getting the list of people using explorer.exe process.

$ComputerName = "remote-computer01"
$DriveLetter = "w"
$DrivePath = "\\example.com\path\to\folder"

# Get users that are logged in
$Sessions = Get-WmiObject -ComputerName $ComputerName -Class win32_process | Where-Object {$_.name -eq "explorer.exe"}

# Get SID of users
$sid = $Sessions.GetOwnerSid().sid

# See which user is being modified
$user = $Sessions.GetOwner().user

$Path = "REGISTRY::HKEY_USERS\$sid\Network"

New-Item -Path $Path -Name $DriveLetter
New-ItemProperty -Path $Path\$DriveLetter\ -Name ConnectFlags -PropertyType DWORD -Value 0
New-ItemProperty -Path $Path\$DriveLetter\ -Name ConnectionType -PropertyType DWORD -Value 1
New-ItemProperty -Path $Path\$DriveLetter\ -Name DeferFlags -PropertyType DWORD -Value 4
New-ItemProperty -Path $Path\$DriveLetter\ -Name ProviderName -PropertyType String -Value "Microsoft Windows Network"
New-ItemProperty -Path $Path\$DriveLetter\ -Name ProviderType -PropertyType DWORD -Value 131072
New-ItemProperty -Path $Path\$DriveLetter\ -Name RemotePath -PropertyType String -Value "$DrivePath"
New-ItemProperty -Path $Path\$DriveLetter\ -Name UserName -PropertyType String
