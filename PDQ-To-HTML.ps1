<#
Author: https://github.com/hb-i/

Ensure you have the Queries.txt file from https://pastebin.com/xEuZQWR7 placed in C:\scripts\ folder on your PDQ server.

Modify $PDQServer, $finalcsv, $webserverfolder, and $outputlocation to fit your environment.
You may need to modify $QueryParameters if Database.db is not in original location.

PSWriteHTML and MergeCsv PowerShell modules are required!

### Overview of script ###
SQL query in Queries.txt file is run against the PDQ Inventory database. This dumps to query output to csv files in C:\temp\ on PDQ server. In the next step, the CSV files are combined using a like key (in this case it's "ComputerName" header) into one CSV file ($finalcsv). This process could probably be eliminated by someone who has more SQL experience and can have it run multiple queries and combine the data properly.

Next, PSWriteHTML PowerShell module is used to take the CSV and use fancy magic by http://evotec.xyz/ to turn it into a nice HTML page. In this case, this is dumped straight to the IIS server.

#>

$PDQServer = "MyPDQServerNAME"
$finalcsv = "\\$PDQServer\c$\temp\combined.csv"
$webserverfolder = "\\MyWEBserverNAME\c$\inetpub\inventory\"
$outputlocation = $webserverfolder + "index.html"

# Place the Queries.txt in C:\scripts\ on $PDQServer beforehand!
$QueryParameters = '"C:\Program Files (x86)\Admin Arsenal\PDQ Inventory\sqlite3.exe" "c:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db"' + " < c:\scripts\Queries.txt"

# Verify PSWriteHTML module (https://github.com/EvotecIT/PSWriteHTML) is installed for the Out-HTMLView command
if (Get-Module -ListAvailable -Name PSWriteHTML)
{
    Write-Host "PSWriteHTML module exists" -ForegroundColor Green
} 
else
{
    Write-Host "PSWriteHTML module does not exist, installing it now. Accept any/all prompts that may popup." -ForegroundColor Red
    install-module PSWriteHTML -Force
}
    
Write-Host "--Importing PSWriteHTML module" -ForegroundColor Green
Import-Module PSWriteHTML -Force
    
# Verify MergeCsv module (https://www.powershelladmin.com/wiki/Merge_CSV_files_or_PSObjects_in_PowerShell) is installed for the Out-HTMLView command
if (Get-Module -ListAvailable -Name MergeCsv)
{
    Write-Host "MergeCsv module exists" -ForegroundColor Green
} 
else
{
    Write-Host "MergeCsv module does not exist, installing it now. Accept any/all prompts that may popup." -ForegroundColor Red
    install-module MergeCsv -Force
}
    
Write-Host "--Importing MergeCsv module" -ForegroundColor Green
Import-Module MergeCsv -Force
    
Write-Host "Connecting to PDQ server..." -ForegroundColor Green
# Run the sql queries in Queries.txt on PDQ server against the PDQ Inventory database file
Invoke-Command -ComputerName $PDQServer -ScriptBlock {
    #Create temp folder to store csv files on the PDQ server
    $temppath = "C:\temp"
    $querypath = "C:\scripts\Queries.txt"
    
    If (!(test-path $temppath))
    {
        Write-Host "Creating $temppath on PDQ server" -ForegroundColor Green
        New-Item -ItemType Directory -Force -Path $temppath
    }
    If (!(test-path $querypath))
    {
        Write-Host "ERROR! Could not find the Queries.txt file mentioned in the ($)QueryParameter and ($)querypath variable in c:\scripts\ path on PDQ server. Fix this issue and run again!" -ForegroundColor Red
    }

    # Launch sql query
    Write-Host "Running sql query on PDQ Server" -ForegroundColor Green
    cmd.exe /c $using:QueryParameters
}
    
# The query above generates the csv files below, combine them into one file using the merge-csv module
$Overview = "\\$PDQServer\c$\temp\Overview.csv"
$Applications = "\\$PDQServer\c$\temp\Applications.csv"
$DiskSpace = "\\$PDQServer\c$\temp\DiskSpace.csv"
$PhysicalDisks = "\\$PDQServer\c$\temp\PhysicalDisks.csv"
$Displays = "\\$PDQServer\c$\temp\Displays.csv"
$LocalAdmins = "\\$PDQServer\c$\temp\LocalAdmins.csv"
    
Write-Host "Merging output from the exported csv files..." -ForegroundColor Green
Write-Host "This may take some time depending on how much data there is to merge" -ForegroundColor Yellow
# Merge using MergeCsv module
merge-csv -Path $Overview, $DiskSpace, $PhysicalDisks, $Displays, $Applications, $LocalAdmins -Id ComputerName | export-csv $finalcsv
    
Write-Host "Outputting csv to html on the web server..." -ForegroundColor Green
# Output the csv to html using Out-HtmlView module and save it to web server

<#
Details on each parameter:
"-Style display" Makes it not put applications in the overview instead it's collapsed under the plus (+) button for each entry
"-DisablePaging" By default it shows 20(?) entries per page, this will change it to infinite.
"-Title "PDQ Inventory" Change the title of the HTML page, this text shows up inside the browser tab
"-FixedHeader and -FixedFooter" The headers at the top and bottom follow as you scroll
#>
(import-csv $finalcsv) | Out-HtmlView -Style display -DisablePaging -FilePath $outputlocation -Title "PDQ Inventory" -FixedHeader -FixedFooter -DisableStateSave
