<#
Set it up as a scheduled task before leaving work. If it's cold outside (snow or -1C or below), receive an email reminder to start your car to get it warmed up.
#>

#Enter your location. See supported location types @ https://wttr.in/:help
$location = "MyCityName"

$additionalarguments = "QFd0"
$additionalargumentsemail = "_QFd1"
$urlpath = $location + $additionalarguments
$urlpathemail = $location + $additionalargumentsemail
$data = (curl http://wttr.in/$urlpath -UserAgent "curl" ).Content

#Remove lines with km so they dont conflict with the regex that looks for negative numeric values from -1 to -50.
$data = (($data -split "`n") | ? {$_ -notmatch 'km'}) -join "`n"

#Regex. If "snow" or temperature below -1 is detected then send email alert.
if ($data -match '(snow)|(?:-[1-9]|-[1-4][0-9]|-50)')
{
    ############
    #SEND EMAIL#
    ############
    ###########Define Variables Below######## 
    $Date = (Get-Date)
    $fromaddress = "me@example.com"
    $toaddresses = @("you@example.com", "youtoo@example.com")
    $Subject = "Start Your Car - It is cold/snowy outside!" 
    $smtpserver = "my-smtp-server.example.com" 
    #################################### 
    $message = new-object System.Net.Mail.MailMessage 
    $message.From = $fromaddress 

    #Loop through and add multiple receipients from the $toaddresses array above.
    foreach ($toaddress in $toaddresses)
    {
        $message.To.Add($toaddress) 
    }

    $message.IsBodyHtml = $True 
    $message.Subject = $Subject 

    #Output the saved report as body of the email message
    $message.body = "<img src=`"http://wttr.in/$urlpathemail`">"
    $smtp = new-object Net.Mail.SmtpClient($smtpserver) 
    $smtp.Send($message) 
}
else
{
    #Exit script and dont send email if weather conditions are not met.
    exit
}
