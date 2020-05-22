<#
Author: https://github.com/hb-i

Purpose: Schedule Hyper-V Virtual Machine memory/cpu change to happen automatically outside of production time. In other words, free up your evenings and weekends...

Overview of steps:
- Stop VM if running
- Change startup memory/cpu cores
- Start VM

Save this on the host server where the VM exists and create a scheduled task in Windows with the settings below. Make sure the change -VMName and -cpu values to your liking, if one or both parameters arent used, the tasks will be skipped.

#### Scheduled Task ####
Action: Start a program
Program/script: powershell
Add arguments (optional): -executionpolicy bypass -command "& {. C:\temp\Set-VMConfig.ps1; Set-VMConfig -VMName MyCoolVM -cpu 2 -Memory 4}"
########################

Function examples without scheduling task:
Set-VMConfig -VMName WebServer01 -Memory 8 -cpu 4
Set-VMConfig -VMName WebServer01 -Memory 6
Set-VMConfig -VMName WebServer01 -cpu 2
#>

function Set-VMConfig
{

    param(
        [Parameter()]
        $VMName,
     
        [Parameter()]
        [int64]$Memory,
    
        [Parameter()]
        $cpu
    )
    
    # Start logging
    $temppath = "C:\temp"
    If (!(test-path $temppath))
    {
        Write-Host "Creating $temppath to store logs" -ForegroundColor Green
        New-Item -ItemType Directory -Force -Path $temppath
    }

    Start-Transcript -Path $temppath\Set-VMConfig-Log.txt

    $vm = get-vm $VMName
    
    [int64]$NewMemory = 1GB * $Memory
    
    # Turn off VM if it's running
    if ($vm.state -eq 'running')
    {
        Write-Host "..Stopping $($vm.name)" -ForegroundColor Green
        Stop-VM -Name $vm.name
    }
    elseif ($vm.state -eq 'Off')
    {
        Write-Host "$($vm.name) is already turned off." -ForegroundColor Green
    }
    else
    {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Failed to get virtual machine $($vm.name)" -ForegroundColor Red
        write-host "There was an error! The error message was... `n $ErrorMessage `n Failed Item: $FailedItem" -ForegroundColor Red
    }

    $CurrentMemoryInBytes = Get-VMMemory $vmname | select -ExpandProperty Startup
    $CurrentMemory = $CurrentMemoryInBytes / 1GB
    
    # Set new memory if $Memory is provided
    if ($NewMemory -ne 0)
    {
        try
        {
            $NewMemoryInGB = $NewMemory / 1GB
            Write-Host "Changing memory from $CurrentMemory`GB to $NewMemoryInGB`GB" -ForegroundColor Green
            set-vmmemory $VMName -StartupBytes $NewMemory
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error changing memory on $($vm.name)" -ForegroundColor Red
            write-host "There was an error! The error message was... `n $ErrorMessage `n Failed Item: $FailedItem" -ForegroundColor Red
    
        }
    }
    else
    {
        write-host "Skipping memory change" -ForegroundColor Yellow
    }
    
    $Currentcpu = Get-VMProcessor $VMName | select -ExpandProperty Count
    
    # Set new CPU cores if $cpu is provided
    if ($cpu -ne $null)
    {
        try
        {
            Write-Host "Changing cpu cores from $Currentcpu to $cpu" -ForegroundColor Green
            Set-VM -Name $VMName -ProcessorCount $cpu
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error changing cpu on $($vm.name)" -ForegroundColor Red
            write-host "There was an error! The error message was... `n $ErrorMessage `n Failed Item: $FailedItem" -ForegroundColor Red
    
        }
    
    }
    else
    {
        write-host "Skipping cpu change" -ForegroundColor Yellow
    }
    
    # Start VM
    if ($vm.state -ne 'running')
    {
        Write-Host "..Starting $($vm.name)" -ForegroundColor Green
        Start-VM -Name $vm.name
    }
    else
    {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        write-host "There was an error starting VM! The error message was... `n $ErrorMessage `n Failed Item: $FailedItem" -ForegroundColor Red
    }
    
    # Stop logging
    Stop-Transcript
    
}    
