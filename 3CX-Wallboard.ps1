<#
####DESCRIPTION####
Run periodically to open 3CX wallboard. On first run, go to the 3CX web client login, auto login by pressing the login button (Note: Credentials must be saved in IE beforehand).
Once logged in wait ten seconds for it to finish loading.
Navigate directly to the wallboard page (since we're already logged in, it should just display the wallboard and not login page)
When script is run periodically it will check to see if IE is already open, if it's open then it will refresh the IE page to make sure in case there is an internet connectivity problem then it will refresh the page to get it up to date. 
#>

$loginurl = "https://3cx.server.com:5001/webclient/#/login"
$wallboardurl = "https://3cx.server.com:5001/webclient/#/wallboard"


#Get process name of internet explorer to kick off the if else statement below
$ProcessActive = Get-Process iexplore -ErrorAction SilentlyContinue

#Start Internet Explorer in full screen and navigate to $loginurl, this is to get 3CX web client to login first, then later we can go directly to the wallboard url since we're already logged in.


#If internet explorer is not running then open it in fullscreen, click login button on the 3CX web client login page, wait 10 seconds then navigate to 3CX wallboard page.
if ($ProcessActive -eq $null) {

    $IE = New-Object -com internetexplorer.application; 
    $IE.visible = $true; 
    $ie.fullscreen = $true;


    $IE.navigate($loginurl); 

    while ($IE.Busy -eq $true) { 
        Start-Sleep -Milliseconds 2000; 
    } 


    #Click the login button on the 3CX web client login page
    $IE.Document.getElementById("submitBtn").Click() 
 
    while ($IE.Busy -eq $true) { 
        Start-Sleep -Milliseconds 2000; 
    }

    #Wait 10 seconds after clicking Login button and then navigate straight to wallboard url
    start-sleep -Seconds 10
    $IE.navigate($wallboardurl); 

}

#Else if internet explorer isn't running then refresh the internet explorer windows
else {
    $ieSet = (New-Object -ComObject Shell.Application).Windows() |  Where-Object {$_.LocationUrl -like "*"}
    $ieSet.Refresh()
}
