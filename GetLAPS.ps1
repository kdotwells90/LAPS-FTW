# Pulls LAPS passwords from AD and writes them to a text file,
# then copies that file to a destination path.
#
# Edit the three paths below before running.

$oupath   = "OU=,OU=,DC=,DC="
$LAPSFile = "C:\Path\To\file.txt"
$destPath = "C:\Path\To\Copy\Destination\file.txt"

$computers = Get-ADComputer -Filter * -SearchBase $oupath |
    Where-Object { $_.DistinguishedName -notmatch "OU=Zero-Clients" } |
    Sort-Object Name

if (Test-Path $LAPSFile) {
    Write-Host "$LAPSFile exists, deleting and refreshing"
    Remove-Item -Path $LAPSFile -Force
}
else {
    Write-Host "No current LAPS password file. Creating a new one."
}

$writtenCount = 0
$skippedCount = 0
$errorCount   = 0

foreach ($C in $computers) {
    try {
        $laps = Get-LapsADPassword -Identity $C.Name -AsPlainText -ErrorAction Stop

        if (-not $laps.Password) {
            Write-Warning "No password returned for $($C.Name) - check decrypt/read permissions"
            $skippedCount++
            continue
        }

        Add-Content -Path $LAPSFile -Value "Computer: $($C.Name)"
        Add-Content -Path $LAPSFile -Value "Password: $($laps.Password)"
        Add-Content -Path $LAPSFile -Value "Expires:  $($laps.ExpirationTimestamp)"
        Add-Content -Path $LAPSFile -Value ""
        $writtenCount++
    }
    catch {
        Write-Warning "Could not get password for $($C.Name): $($_.Exception.Message)"
        $errorCount++
    }
}

Write-Host ""
Write-Host "Summary:"
Write-Host "  Written: $writtenCount"
Write-Host "  Skipped (no password returned): $skippedCount"
Write-Host "  Errors: $errorCount"
Write-Host ""

if (Test-Path $LAPSFile) {
    Copy-Item -Path $LAPSFile -Destination $destPath -Force
    Write-Host "Copied $LAPSFile to $destPath"
}
else {
    Write-Warning "No LAPS file was created - nothing to copy. Check the warnings above."
}
