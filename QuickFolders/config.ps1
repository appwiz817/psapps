$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    New-Item -Path $envFile -ItemType File -Force | Out-Null
}

function Get-EnvFilePath {
    return $envFile
}

function Get-FolderOpenMode {
    $settingLine = Get-Content $envFile | Where-Object { $_ -match '^# QuickFoldersOpenMode=(NewWindow|NewTab)$' } | Select-Object -First 1
    if ($settingLine -match '^# QuickFoldersOpenMode=(NewWindow|NewTab)$') {
        return $Matches[1]
    }

    return 'NewWindow'
}

function Set-FolderOpenMode ([ValidateSet('NewWindow', 'NewTab')][string]$mode) {
    $remainingLines = Get-Content $envFile | Where-Object { $_ -notmatch '^# QuickFoldersOpenMode=' }
    @("# QuickFoldersOpenMode=$mode") + $remainingLines | Set-Content $envFile
}

function Get-FoldersList {
    $folders = [System.Collections.Generic.List[PSCustomObject]]::new()
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $name, $targetPath = $line.Split("=", 2)
                $name = $name.Trim()
                $targetPath = $targetPath.Trim().Trim('"').Trim("'")
                if ($name -and $targetPath) {
                    $folders.Add([PSCustomObject]@{ Name = $name; Path = $targetPath })
                }
            }
        }
    }
    return $folders
}

function Add-FolderEntry ([string]$name, [string]$path) {
    $hasContent = (Test-Path $envFile) -and ((Get-Content $envFile).Length -gt 0)
    $newLinePrefix = if ($hasContent) { "`r`n" } else { "" }
    $newLine = "$newLinePrefix$name=$path"
    [System.IO.File]::AppendAllText($envFile, $newLine)
}

function Remove-FolderEntry ([string]$name) {
    $remainingLines = Get-Content $envFile | Where-Object {
        $_.Trim() -and -not $_.Trim().StartsWith("$name=")
    }
    $remainingLines | Set-Content $envFile
}
