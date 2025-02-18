<#
.SYNOPSIS
    Adds an SSH public key to a Linux server's authorized_keys file.

.DESCRIPTION
    This script connects to a specified Linux server and appends the given SSH public key 
    to the `~/.ssh/authorized_keys` file for the specified user.

.PARAMETER key
    (Optional) The file path of the public key to add. 
    Defaults to "$env:USERPROFILE\.ssh\id_rsa.pub" if not provided.

.PARAMETER server
    (Required) The hostname or IP address of the Linux server.

.PARAMETER user
    (Required) The username on the Linux server.

.EXAMPLE
    PS C:\> .\Add-SSHKeytoLinux.ps1 -server "192.168.1.10" -user "admin"

    Uses the default public key file and adds it to the "admin" user on the server "192.168.1.10".

.EXAMPLE
    PS C:\> .\Add-SSHKeytoLinux.ps1 -key "C:\Users\John\.ssh\custom_key.pub" -server "linux.example.com" -user "john"

    Adds the specified public key file to the "john" user on "linux.example.com".
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$key, # public key file path

    [Parameter(Mandatory = $true)]
    $server, # Linux server

    [Parameter(Mandatory = $true)]
    $user # Linux user
)

if (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('key'))
{
    $key = "$env:USERPROFILE\.ssh\id_rsa.pub"
    Write-Host "No `"key`" parameter provided, set to default public key: $key"
}
else
{
    Write-Host "Key: $key"
}

Write-Host "Connecting to $user@$server"

try
{
    Get-Content $key | ssh $user@$server "cat >> .ssh/authorized_keys"

    # Check if SSH command failed
    if ($LASTEXITCODE -ne 0)
    {
        throw "SSH command failed with exit code $LASTEXITCODE"
    }
    Write-Host "Public key successfully added to $user@$server" -ForegroundColor Green
}
catch
{
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
