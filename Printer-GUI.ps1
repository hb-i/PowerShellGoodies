<#
Description: WPF and WinForm GUI to have user self manage the installation of printers in addition to setting default printers.


WPF GUI is created using Visual Studio. See guide in the links below
https://foxdeploy.com/series/learning-gui-toolmaking-series/
https://foxdeploy.com/2015/04/16/part-ii-deploying-powershell-guis-in-minutes-using-visual-studio/

Use ps2exe script on Microsoft technet website to convert this to exe for users to run it.
#>

#Your XAML goes here :)
$inputXML = @"
<Window x:Class="Install_Printer.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:Install_Printer"
        mc:Ignorable="d"
        Title="Printer Utility" Height="496.716" Width="499.682">
    <Grid Margin="0,0,-8,0" Height="402" VerticalAlignment="Top">
        <Grid.ColumnDefinitions>
            <ColumnDefinition/>
            <ColumnDefinition Width="0*"/>
        </Grid.ColumnDefinitions>
        <Label x:Name="title1" Content="1. Select Location" HorizontalAlignment="Left" Margin="0,10,0,0" VerticalAlignment="Top" FontSize="20" FontWeight="Bold" Height="37" Width="174"/>
        <TextBlock x:Name="infolabel" HorizontalAlignment="Left" Margin="10,79,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="21" Width="455"></TextBlock>
        <ListBox x:Name="printerlist" HorizontalAlignment="Left" Height="211" Margin="10,105,0,0" VerticalAlignment="Top" Width="463"/>
        <Label x:Name="title2" Content="2. Default Printer" HorizontalAlignment="Left" Margin="0,367,0,-2" VerticalAlignment="Top" FontSize="20" FontWeight="Bold" Height="37" Width="174"/>
        <Button x:Name="defaultprinterbutton" Content="Launch Default Printer Wizard" HorizontalAlignment="Left" Margin="10,404,0,-38" VerticalAlignment="Top" Width="171" Height="36"/>
        <ComboBox x:Name="combobox" HorizontalAlignment="Left" Margin="10,52,0,0" VerticalAlignment="Top" Width="174"/>
        <Button x:Name="addprinterbutton" Content="Add Selected Printer" HorizontalAlignment="Left" Margin="10,321,0,0" VerticalAlignment="Top" Width="171" Height="36"/>
        <GridSplitter x:Name="gridsplitter" HorizontalAlignment="Left" Height="5" Margin="0,362,0,0" VerticalAlignment="Top" Width="490"/>
    </Grid>
</Window>
"@ 
 
$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
 
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try
{
    $Form = [Windows.Markup.XamlReader]::Load( $reader )
}
catch
{
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}





#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
  
$xaml.SelectNodes("//*[@Name]") | % {
    try {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop}
    catch {throw}
}
 
Function Get-FormVariables
{
    #Commented parts below so when turned into an exe file, it wont spam you will messages it's suppose to display in powershell output console.

    if ($global:ReadmeDisplay -ne $true) {<#Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;#> $global:ReadmeDisplay = $true}
    #write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
    #get-variable WPF*
}
 
Get-FormVariables




#===========================================================================
# Use this space to add code to the various form elements in your GUI
#===========================================================================

#For instruction message when user double clicks a printer from the list
$wshell = New-Object -ComObject Wscript.Shell

#wildcard strings to do a lookup for printers for each location.
$CityEurope = "*euro*"
$CityUSA = "*USA*"

$PrintServer = "myprintservername"                                           

#Add locations to combobox.
@('CityEurope', 'CityUSA') | ForEach-Object {[void] $WPFcombobox.items.Add($_)}

$WPFcombobox.add_SelectionChanged( {
        $CurrentLocation = $WPFcombobox.SelectedItem
        $WPFinfolabel.Text = 'Select the printer below and click "Add Selected Printer" button.'


        if ($CurrentLocation -eq "CityEurope")
        {
            $WPFprinterlist.Items.Clear()
            Get-Printer -ComputerName $PrintServer | where {$_.name -like "$CityEurope"} | ForEach-Object {
                [void]$WPFprinterlist.Items.Add($_.name)
            }
        }
       

        if ($CurrentLocation -eq "CityUSA")
        {
            $WPFprinterlist.Items.Clear()
            Get-Printer -ComputerName $PrintServer | where {$_.name -like "$CityUSA"} | ForEach-Object {
                [void]$WPFprinterlist.Items.Add($_.name)
            }
        }

        $WPFaddprinterbutton.Add_Click( {
                $SelectedPrinter = $WPFprinterlist.SelectedItem
                rundll32 printui.dll, PrintUIEntry /in /n"\\$PrintServer\$SelectedPrinter"
                $wshell.Popup("$SelectedPrinter should be installed shortly, continue through any warning about trusting the printer.", 0, "Instructions")
            })

    })

#Default Printer Wizard button. Note that this is still created using WinForm rather than WPF as WPF is mainly used above to prevent unresponsiveness of the GUI when loading printer list.
$WPFdefaultprinterbutton.Add_Click( { 

        $wshell = New-Object -ComObject Wscript.Shell
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Application]::EnableVisualStyles()
    
        $DefaultPrinterForm = New-Object system.Windows.Forms.Form
        $DefaultPrinterForm.ClientSize = '400,154'
        $DefaultPrinterForm.text = "Default Printer"
        $DefaultPrinterForm.BackColor = "#ffffff"
        $DefaultPrinterForm.TopMost = $false
    
        $DefaultPrinterLabel = New-Object system.Windows.Forms.Label
        $DefaultPrinterLabel.text = "Set Default Printer"
        $DefaultPrinterLabel.AutoSize = $true
        $DefaultPrinterLabel.width = 25
        $DefaultPrinterLabel.height = 10
        $DefaultPrinterLabel.location = New-Object System.Drawing.Point(20, 17)
        $DefaultPrinterLabel.Font = 'Microsoft Sans Serif,16,style=Bold'
    
        $PrinterBox = New-Object system.Windows.Forms.ComboBox
        $PrinterBox.text = "comboBox"
        $PrinterBox.width = 345
        $PrinterBox.height = 65
        $PrinterBox.location = New-Object System.Drawing.Point(20, 48)
        $PrinterBox.Font = 'Microsoft Sans Serif,10'
    
        $submitbutton = New-Object system.Windows.Forms.Button
        $submitbutton.text = "Save Default Printer"
        $submitbutton.width = 150
        $submitbutton.height = 25
        $submitbutton.location = New-Object System.Drawing.Point(20, 79)
        $submitbutton.Font = 'Microsoft Sans Serif,10'
    
        ############################################
    
        $AvailablePrinters = Get-WmiObject -ClassName Win32_Printer
        $DefaultPrinter = $AvailablePrinters | Where-Object Default -EQ 'True'
    
    
        $AvailablePrinters | ForEach-Object {[void] $PrinterBox.Items.Add($_.Name)}
        $PrinterBox.SelectedItem = $DefaultPrinter.Name
    
    
        $submitbutton.Add_Click( { 
                Set-DefaultPrinter -printername $PrinterBox.Text 
            })
    
    
        Function Set-DefaultPrinter
        {
            param(
                [Parameter(Mandatory = $True,
                    HelpMessage = 'Please Enter Printer Name')]
                [string]$printername
            )
          
            #Set Default Printer
            ($AvailablePrinters | Where-Object -FilterScript {$_.Name -eq "$PrinterName"}).SetDefaultPrinter()
            #$form.Dispose()
            $wshell.Popup("Default printer has been set to $PrinterName.", 0, "Instructions")
            #Return
              
        }
    
        $DefaultPrinterForm.controls.AddRange(@($DefaultPrinterLabel, $PrinterBox, $submitbutton))
        [void]$DefaultPrinterForm.ShowDialog()

    })

$Form.ShowDialog() | out-null
 
