[CmdletBinding()]
param(
    # Dry run mode lists startup programs without making changes.
    [switch]$DryRun,

    # Disable mode turns off a startup program that matches -ProgramName.
    [switch]$Disable,

    # Enable mode restores a previously disabled startup program that matches -ProgramName.
    [switch]$Enable,

    # Program display name (or part of it) to disable when -Disable is used.
    [string]$ProgramName,

    # Include RunOnce keys in discovery. Disabled by default to avoid one-time setup entries.
    [switch]$IncludeRunOnce
)

# Section: Logging helper.
# This keeps script output consistent and easy to scan.
function Write-Info {
    param(
        [string]$Message
    )

    Write-Output ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

# Section: Startup source map.
# These are the common startup locations for user and machine scope.
$startupSources = @(
    [pscustomobject]@{ Type = 'Registry'; Scope = 'CurrentUser'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
    [pscustomobject]@{ Type = 'Registry'; Scope = 'LocalMachine'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' }
)

if ($IncludeRunOnce) {
    $startupSources += [pscustomobject]@{ Type = 'Registry'; Scope = 'CurrentUser'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' }
    $startupSources += [pscustomobject]@{ Type = 'Registry'; Scope = 'LocalMachine'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' }
}

$startupSources += [pscustomobject]@{ Type = 'Folder'; Scope = 'CurrentUser'; Path = [Environment]::GetFolderPath('Startup') }
$startupSources += [pscustomobject]@{ Type = 'Folder'; Scope = 'AllUsers'; Path = [Environment]::GetFolderPath('CommonStartup') }

# Section: Discovery functions.
# These functions collect startup entries as normalized objects.
function Get-StartupEntriesFromRegistry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistryPath,

        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    $results = @()

    if (-not (Test-Path -Path $RegistryPath)) {
        return $results
    }

    try {
        $item = Get-Item -Path $RegistryPath -ErrorAction Stop
        foreach ($valueName in $item.GetValueNames()) {
            $command = $item.GetValue($valueName)
            $results += [pscustomobject]@{
                Name       = $valueName
                Command    = [string]$command
                SourceType = 'Registry'
                Scope      = $Scope
                SourcePath = $RegistryPath
                Enabled    = $true
                IsManagedDisabled = $false
            }
        }

        $disabledPath = "${RegistryPath}_DisabledByAuditor"
        if (Test-Path -Path $disabledPath) {
            $disabledItem = Get-Item -Path $disabledPath -ErrorAction Stop
            foreach ($valueName in $disabledItem.GetValueNames()) {
                $command = $disabledItem.GetValue($valueName)
                $results += [pscustomobject]@{
                    Name       = $valueName
                    Command    = [string]$command
                    SourceType = 'Registry'
                    Scope      = $Scope
                    SourcePath = $RegistryPath
                    Enabled    = $false
                    IsManagedDisabled = $true
                }
            }
        }
    }
    catch {
        Write-Info "WARN failed reading registry path '$RegistryPath': $($_.Exception.Message)"
    }

    return $results
}

function Get-StartupEntriesFromFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,

        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    $results = @()

    if ([string]::IsNullOrWhiteSpace($FolderPath) -or -not (Test-Path -Path $FolderPath)) {
        return $results
    }

    try {
        $files = Get-ChildItem -Path $FolderPath -File -ErrorAction Stop
        foreach ($file in $files) {
            $isDisabled = $file.Name.EndsWith('.disabled', [System.StringComparison]::OrdinalIgnoreCase)
            $displayName = if ($isDisabled) { [System.IO.Path]::GetFileNameWithoutExtension($file.BaseName) } else { $file.BaseName }
            $results += [pscustomobject]@{
                Name       = $displayName
                Command    = $file.FullName
                SourceType = 'Folder'
                Scope      = $Scope
                SourcePath = $FolderPath
                Enabled    = -not $isDisabled
                IsManagedDisabled = $isDisabled
            }
        }
    }
    catch {
        Write-Info "WARN failed reading startup folder '$FolderPath': $($_.Exception.Message)"
    }

    return $results
}

function Get-AllStartupEntries {
    $all = @()

    foreach ($source in $startupSources) {
        if ($source.Type -eq 'Registry') {
            $all += Get-StartupEntriesFromRegistry -RegistryPath $source.Path -Scope $source.Scope
        }
        elseif ($source.Type -eq 'Folder') {
            $all += Get-StartupEntriesFromFolder -FolderPath $source.Path -Scope $source.Scope
        }
    }

    return $all | Sort-Object -Property SourceType, Scope, Name
}

# Section: Disable operations.
# Registry entries are moved to a disabled key; folder entries are renamed with .disabled.
function Disable-RegistryStartupEntry {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry
    )

    $disabledPath = "$($Entry.SourcePath)_DisabledByAuditor"

    if (-not (Test-Path -Path $disabledPath)) {
        New-Item -Path $disabledPath -ItemType Directory -Force | Out-Null
    }

    $originalItem = Get-Item -Path $Entry.SourcePath -ErrorAction Stop
    $value = $originalItem.GetValue($Entry.Name)

    Set-ItemProperty -Path $disabledPath -Name $Entry.Name -Value $value -Type String -Force
    Remove-ItemProperty -Path $Entry.SourcePath -Name $Entry.Name -Force

    Write-Info "Disabled registry startup entry '$($Entry.Name)' by moving it to '$disabledPath'."
}

function Disable-FolderStartupEntry {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry
    )

    $fullPath = $Entry.Command

    if (-not (Test-Path -Path $fullPath)) {
        throw "Startup file not found: $fullPath"
    }

    if ($fullPath.EndsWith('.disabled', [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Info "Startup file already disabled: $fullPath"
        return
    }

    $newPath = "$fullPath.disabled"

    if (Test-Path -Path $newPath) {
        throw "Disabled target already exists: $newPath"
    }

    Rename-Item -Path $fullPath -NewName ([System.IO.Path]::GetFileName($newPath)) -ErrorAction Stop
    Write-Info "Disabled startup file '$fullPath' by renaming to '$newPath'."
}

function Enable-RegistryStartupEntry {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry
    )

    $disabledPath = "$($Entry.SourcePath)_DisabledByAuditor"

    if (-not (Test-Path -Path $disabledPath)) {
        throw "Disabled registry container not found: $disabledPath"
    }

    $disabledItem = Get-Item -Path $disabledPath -ErrorAction Stop
    $value = $disabledItem.GetValue($Entry.Name)

    if ($null -eq $value) {
        throw "Disabled registry value not found for '$($Entry.Name)' in '$disabledPath'."
    }

    Set-ItemProperty -Path $Entry.SourcePath -Name $Entry.Name -Value $value -Type String -Force
    Remove-ItemProperty -Path $disabledPath -Name $Entry.Name -Force

    Write-Info "Enabled registry startup entry '$($Entry.Name)' by restoring it to '$($Entry.SourcePath)'."
}

function Enable-FolderStartupEntry {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry
    )

    $fullPath = $Entry.Command

    if (-not (Test-Path -Path $fullPath)) {
        throw "Disabled startup file not found: $fullPath"
    }

    if (-not $fullPath.EndsWith('.disabled', [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Info "Startup file already enabled: $fullPath"
        return
    }

    $newPath = $fullPath.Substring(0, $fullPath.Length - '.disabled'.Length)

    if (Test-Path -Path $newPath) {
        throw "Enabled target already exists: $newPath"
    }

    Rename-Item -Path $fullPath -NewName ([System.IO.Path]::GetFileName($newPath)) -ErrorAction Stop
    Write-Info "Enabled startup file '$newPath' by removing '.disabled' suffix."
}

# Section: Parameter validation.
if ($Disable -and $Enable) {
    throw 'Use either -Disable or -Enable, not both.'
}

if (($Disable -or $Enable) -and [string]::IsNullOrWhiteSpace($ProgramName)) {
    throw 'When using -Disable or -Enable, provide -ProgramName.'
}

if (-not $Disable -and -not $Enable -and -not $DryRun) {
    # Default safe behavior: list entries if no action switch is provided.
    $DryRun = $true
}

$entries = Get-AllStartupEntries

# Section: Dry run output.
if ($DryRun) {
    Write-Info 'Startup program audit (dry run). No changes made.'

    if (-not $entries -or $entries.Count -eq 0) {
        Write-Output 'No startup entries found in configured sources.'
        return
    }

    $entries |
        Select-Object Name, Enabled, SourceType, Scope, Command |
        Format-Table -AutoSize

    Write-Output ''
    Write-Output ("Total startup entries found: {0}" -f $entries.Count)
}

# Section: Disable execution.
if ($Disable) {
    $matches = $entries | Where-Object {
        $_.Name -like "*$ProgramName*" -or $_.Command -like "*$ProgramName*"
    }

    if (-not $matches -or $matches.Count -eq 0) {
        throw "No startup program matched '$ProgramName'. Run with -DryRun to see available names."
    }

    # Avoid disabling ambiguous targets in one run unless user provides a more specific name.
    $enabledMatches = $matches | Where-Object { $_.Enabled }

    if (-not $enabledMatches -or $enabledMatches.Count -eq 0) {
        Write-Info "Matched entries are already disabled for '$ProgramName'."
        return
    }

    if ($enabledMatches.Count -gt 1) {
        Write-Output 'Multiple enabled entries matched. Please refine -ProgramName to one target:'
        $enabledMatches |
            Select-Object Name, SourceType, Scope, Command |
            Format-Table -AutoSize
        throw 'Ambiguous program name. No changes applied.'
    }

    $target = $enabledMatches[0]
    Write-Info "Disabling startup target: Name='$($target.Name)' SourceType='$($target.SourceType)' Scope='$($target.Scope)'"

    try {
        if ($target.SourceType -eq 'Registry') {
            Disable-RegistryStartupEntry -Entry $target
        }
        elseif ($target.SourceType -eq 'Folder') {
            Disable-FolderStartupEntry -Entry $target
        }
        else {
            throw "Unsupported source type: $($target.SourceType)"
        }

        Write-Info 'Disable operation completed successfully.'
    }
    catch {
        throw "Failed disabling startup entry '$($target.Name)': $($_.Exception.Message)"
    }
}

# Section: Enable execution.
if ($Enable) {
    $matches = $entries | Where-Object {
        $_.Name -like "*$ProgramName*" -or $_.Command -like "*$ProgramName*"
    }

    if (-not $matches -or $matches.Count -eq 0) {
        throw "No startup program matched '$ProgramName'. Run with -DryRun to see available names."
    }

    $disabledMatches = $matches | Where-Object { -not $_.Enabled }

    if (-not $disabledMatches -or $disabledMatches.Count -eq 0) {
        Write-Info "Matched entries are already enabled for '$ProgramName'."
        return
    }

    if ($disabledMatches.Count -gt 1) {
        Write-Output 'Multiple disabled entries matched. Please refine -ProgramName to one target:'
        $disabledMatches |
            Select-Object Name, SourceType, Scope, Command |
            Format-Table -AutoSize
        throw 'Ambiguous program name. No changes applied.'
    }

    $target = $disabledMatches[0]
    Write-Info "Enabling startup target: Name='$($target.Name)' SourceType='$($target.SourceType)' Scope='$($target.Scope)'"

    try {
        if ($target.SourceType -eq 'Registry') {
            Enable-RegistryStartupEntry -Entry $target
        }
        elseif ($target.SourceType -eq 'Folder') {
            Enable-FolderStartupEntry -Entry $target
        }
        else {
            throw "Unsupported source type: $($target.SourceType)"
        }

        Write-Info 'Enable operation completed successfully.'
    }
    catch {
        throw "Failed enabling startup entry '$($target.Name)': $($_.Exception.Message)"
    }
}
