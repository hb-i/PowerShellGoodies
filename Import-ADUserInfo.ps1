<#
Purpose: Update Active Directory user data from csv file.
Script will read the csv file and try to find AD user from the person's display name. If user is found, it will make the changes entered into CSV in AD and then email out a report. Errors will be logged in the report as well if username cannot be found from the display name provided.
CSV needs to contain the headers in the image below. 'First' and 'Last' columns are not required, but you can easily populate the 'FullName' column by using the =CONCATENATE forumla in excel.

#>

$filelocation = "\\ExampleServer\share\contactsupdate.csv"
$names = Import-Csv $filelocation

#Array used to store the data which will later be turned into a table for the html email.
$TableFields = @()
$TableFieldsHeader = @"
<style>
body { background-color:#f6f6f6; font-family:calibri; margin:0px;}
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #34495e; color:#ffffff}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
TR:Nth-Child(Even) {Background-Color: #dddddd;}
</style>
"@


#check if file has data or not. Without this check an email will be sent out even if there is nothing in the CSV.
$CheckCSV = @($names)    
if ($CheckCSV.Length -eq 0)
{
    Write-Host "File has no data!" -ForegroundColor Red
}
else
{
    Write-Host "File does have data!" -ForegroundColor Green

    #HTML code for the email message
    $Body += '<div style="padding: 5px 10px; position: relative; top: 0px; background-color: #34495e; margin-bottom: 20px;">
    <h1 style="text-align: center;"><span style="color: #ffffff;">EMPLOYEE CONTACT INFO UPDATE</span></h1>
    </div>'

    ForEach ($name in $names)
    {
    
        #get column values for the selected $name. Used to enter data in the table.
        $DisplayName = $($name.FullName)
        $ShoreTel = $($name.ShoreTel)
        $Title = $($name.Title)
        $Dept = $($name.Department)
        $City = $($name.City)
        $Cell = $($name.Cell)
        $Office = ($name.Office)
        $Fax = ($name.Fax)
        $StreetAddress = ($name.StreetAddress)
        $PostalCode = ($name.PostalCode)
        $State = ($name.State)
        $Country = ($name.Country)
        $Company = ($name.Company)
        $otherTelephone = ($name.otherTelephone)
    
        #Only run the script on the user if $EmailAddress is not empty (meaning the user was found and it didnt through an error). Otherwise skip it.
    try {
        if ($EmailAddress = Get-ADUser -Filter "DisplayName -eq '$DisplayName'" -Properties UserPrincipalName | Select-Object -ExpandProperty UserPrincipalName)
        {
    
            #remove everything after @ in $EmailAddress
            $ADUser = $EmailAddress.Substring(0, $EmailAddress.IndexOf('@'))

            $Parameters = @{
                Identity = $ADUser
            }

            #If the csv column's cell is filled out then add the coresponding AD attribute to the $Parameters array, if blank then leave it alone. (Prevents blank cells from overwriting the existing data in the AD attribute)
            If ($name.ShoreTel) 
            {
                $Parameters.add("OfficePhone", $($name.ShoreTel))
            }

            If ($name.Title) 
            {
                $Parameters.add("title", $($name.Title))
            }

            If ($name.Department) 
            {
                $Parameters.add("department", $($name.Department))
            }

            If ($name.City) 
            {
                $Parameters.add("city", $($name.City))
            }

            If ($name.Cell) 
            {
                $Parameters.add("mobilePhone", $($name.Cell))
            }

            If ($name.Office) 
            {
                $Parameters.add("Office", $($name.Office))
            }

            If ($name.Fax) 
            {
                $Parameters.add("Fax", $($name.Fax))
            }
            
            If ($name.StreetAddress) 
            {
                $Parameters.add("StreetAddress", $($name.StreetAddress))
            }

            If ($name.PostalCode) 
            {
                $Parameters.add("PostalCode", $($name.PostalCode))
            }

            If ($name.State) 
            {
                $Parameters.add("State", $($name.State))
            }

            If ($name.Country) 
            {
                #To change country you need to change it in 3 different places and have to use the -replace arguement.
                if ($name.Country -eq "CA")
                {
                    Set-ADUser $ADUser -Replace @{c = "CA"; co = "Canada"; countrycode = 124 }
                }
                if ($name.Country -eq "US")
                {
                    Set-ADUser $ADUser -Replace @{c = "US"; co = "United States"; countrycode = 840 }
                }
            }

            If ($name.Company) 
            {
                $Parameters.add("Company", $($name.Company))
            }

            If ($name.otherTelephone) 
            {
                #Using -Add instead of -Replace will add it to AD but not show the value in Outlook under contact's properties.
                Set-ADUser $ADUser -Replace @{otherTelephone = "$otherTelephone" }
            }
            
            Set-ADUser @Parameters

            #Add the updated user's info in a table
            $TableFields += New-Object -Type psobject -Property @{'NAME' = "$DisplayName"; 'USER' = "$ADUser"; 'SHORETEL' = "$ShoreTel"; 'DEPT' = "$Dept"; 'CITY' = "$City"; 'CELL' = "$Cell"; 'OFFICE' = "$Office"; 'FAX' = "$Fax"; 'STREET' = "$StreetAddress"; 'POSTAL' = "$PostalCode"; 'STATE' = "$State"; 'COUNTRY' = "$Country"; 'COMPANY' = "$Company"; 'TITLE' = "$Title"; 'BUSINESS #' = "$otherTelephone" }

        }
        else
        {
            $NameErrors += @"
        <hr />
        <span style="color: #ff0000;"><h3><strong>ERROR</strong></h3></span>
        <div>
        <div>Username associated with <span style="color: #ff0000;"><strong>$DisplayName couldn't be found!</strong></span> Please check that the name is correct so Active Directory can pick it up and convert it to a username. Ask IT to match the name from the CSV file with the display name found in Active Directory.</div>
        <div>&nbsp;</div>
        </div>
"@
        }
    }
        #Throw error if $EmailAddress is empty because of an error. (probably user not being found from the Display Name provided)
        catch
        {
            $NameErrors += @"
        <hr />
        <span style="color: #ff0000;"><h3><strong>ERROR</strong></h3></span>
        <div>
        <div>Username associated with <span style="color: #ff0000;"><strong>$DisplayName couldn't be found!</strong></span> Please check that the name is correct so Active Directory can pick it up and convert it to a username. Ask IT to match the name from the CSV file with the display name found in Active Directory.</div>
        <div>&nbsp;</div>
        </div>
"@
        }
    
    }

    Write-Host "$TableFields"

    #Convert the TableFields to raw HTML for the email report
    $Body += $TableFields | ConvertTo-Html -Head $TableFieldsHeader | Out-String

    #Show the errors for users which couldnt be edited.
    $Body += $NameErrors

    #Add footer to the HTML report
    $Body += @"
    <div style="padding: 5px 10px; position: relative; top: 0px; background-color: #34495e; margin-bottom: 20px;">
<p style="text-align: center;"><span style="color: #ffffff;">CONFIRM THE UPDATES ABOVE ARE ACCURATE AND THEN <strong>CLEAR THE ENTRIES IN THE CSV</strong> FILE BEFORE NEXT JOB RUNS! </span></p>
<p style="text-align: center;"><span style="font-size:11px;"><em><span style="color: #ffffff;">CSV location: $filelocation</span></em></span></p>
<p style="text-align: center;"><span style="font-size:11px;"><em><span style="color: #ffffff;">Generated at $(Get-Date). Ran from $env:COMPUTERNAME.</span></em></span></p>
</div>
"@

    ############
    #SEND EMAIL#
    ############
    ###########Define Variables Below######## 
    $Date = (Get-Date)
    $fromaddress = "EmployeeContactUpdate@example.com"
    $toaddresses = @("receipent@example.com")
    $Subject = "Weekly Employee Contact Update - $Date" 
    $smtpserver = "MySmtpServerName" 
    #################################### 
    $message = New-Object System.Net.Mail.MailMessage 
    $message.From = $fromaddress 

    #Loop through and add multiple receipients in the $toaddresses array above.
    foreach ($toaddress in $toaddresses)
    {
        $message.To.Add($toaddress) 
    }

    $message.IsBodyHtml = $True 
    $message.Subject = $Subject 

    #Output the saved report as body of the email message instead of adding it as an attachment (that's why the lines above are commented out)
    $message.body = $Body
    $smtp = New-Object Net.Mail.SmtpClient($smtpserver) 
    $smtp.Send($message) 

}
#Clear variable in case you're running this multiple times in one powershell session
$Body = ""
$NameErrors = ""
$TableFieldsHeader = ""
$TableFields = @()
