<#
Find user by name or username (wildcard accepted) instead of looking in ADUC saving you many milliseconds of clicking!

Examples:
  Wildcard search: Find-User -name Mich
  Find-User -username MichaelScott

#>
function Find-User
{
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "Username")]
        $Username,
        [Parameter(Mandatory = $true, ParameterSetName = "Name")]
        $Name
    )

    if ($Username) 
    {
        $found = Get-ADUser -Filter "SamAccountName -like '*$Username*'" -Properties * | select name, CanonicalName, Title | foreach {
            write-host $_.name -ForegroundColor Green
            write-host `t $_.CanonicalName -ForegroundColor DarkGray
            write-host `t $_.Title -ForegroundColor DarkGray
        }
    }

    if ($Name)
    {
        $found = Get-ADUser -Filter "Name -like '*$Name*'" -Properties * | select name, CanonicalName, Title, SamAccountName | foreach {
            write-host $_.name -ForegroundColor Green
            write-host `t $_.SamAccountName -ForegroundColor DarkGray
            write-host `t $_.CanonicalName -ForegroundColor DarkGray
            write-host `t $_.Title -ForegroundColor DarkGray
        }
    }
}
