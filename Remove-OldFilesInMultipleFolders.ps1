# Multiple folders to run through, dont forget the backslash at the end of the folder path:
$allFolders = @(
    "\\path1\to\folderA\",
    "\\path2\to\folderB\",
    "\\path3\to\folderC\")

# Keep only files from the last $days days
$days = 31

foreach ($location in $allFolders)
{
    $logfile = $location + "README-logfile.txt"

    # Start a log file from scratch, this will act as a readme and log file.
    # The script will delete old files, we want to make sure the log file gets new timestamp so it doesnt get deleted.
    # This readme file will also act as a guide to anyone wondering why old files in this folder are getting auto deleted
    "Script running from $env:COMPUTERNAME..." | Out-File $logfile
    "$(get-date) - Deleting files in this folder that are older than $days days." | Out-File $logfile -Append

    # Remove any files (not folders) older than $days
    Get-ChildItem –Path $location -File -Recurse | Where-Object { ($_.LastWriteTime -lt (Get-Date).AddDays(-$days)) } | foreach {
        # Log to console
        Write-Host "Deleting: "$_.fullname " - Last write time: "$_.LastWriteTime

        # Delete file
        try
        {
            Remove-Item $_.fullname -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch [System.Management.Automation.ItemNotFoundException]
        {
            Write-Host "Warning: "$_.fullname " - FILE NOT FOUND"
        }
        catch [System.IO.FileNotFoundException]
        {
            Write-Host "Warning: "$_.fullname " - FILE NOT FOUND"
        }
        catch [System.NotSupportedException]
        {
            Write-Host "Warning: "$_.fullname "- Error occurred outputting to log file"
        }
    }

    # After taking care of files, recurse through the folder again and delete any empty subfolders
    Get-ChildItem -Path $location -Recurse | Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName | Where-Object { !$_.PSIsContainer }) -eq $null } | foreach {
        Write-Host "Deleting: $($_.FullName)"; $_ 
    } | Remove-Item -Recurse -Force
}
