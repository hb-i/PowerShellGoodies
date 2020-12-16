<#
Export Active Directory users to a formatted HTML file that can be viewed from the browser. A simple and easy way to create a company directory using PowerShell.
#>

#Download the PSWriteHTML module if it isn't installed already
if (Get-Module -ListAvailable -Name PSWriteHTML)
{
    Write-Host "PSWriteHTML Powershell module exists. Continuing..." -ForegroundColor Green
} 
else
{
    Write-Host "PSWriteHTML Powershell module does not exist. Installing it now. Accept the next prompt!" -ForegroundColor Yellow
    install-module PSWriteHTML -Force
}

#Needed for the Out-HTMLView command
Import-Module PSWriteHTML -Force

# Enter the output location here (probably the web server directory)
$indexFile = "c:\temp\index.html"

# Logo url to display on top of the html file
$logo = '<img src="https://i.imgur.com/t1vwblV.jpg" /><p>This site is best viewed in Chrome, Edge &amp; Firefox. Internet Explorer is not recommended.</p><hr />'

#Get enabled user accounts which have an email address. Rename some of the column headers when creating the output.
Get-ADUser -Filter { EmailAddress -like "*@*" } `
    -Properties * `
    | where { $_.enabled -eq $True } `
    | select Name, `
        @{Name = 'Email Address'; Expression = { $_.EmailAddress } }, `
        Title, Company, Department, `
        @{Name = 'Office Phone'; Expression = { $_.OfficePhone } }, `
        @{Name = 'Mobile Phone'; Expression = { $_.mobilePhone } }, `
        Fax, `
        Office, `
        City, `
        @{Name = 'Address'; Expression = { $_.StreetAddress } }, `
        @{Name = 'Zip/Postal Code'; Expression = { $_.PostalCode } }, `
        @{Name = 'State/Province'; Expression = { $_.State } } `
| Out-HtmlView -DisablePaging -DefaultSortColumn Name -FilePath $indexFile -Title "Employee Directory"

#Find and replace <html> tag to add logo to the raw html file.
(Get-Content $indexFile) -replace "<html>", $logo | Set-Content ($indexFile)
