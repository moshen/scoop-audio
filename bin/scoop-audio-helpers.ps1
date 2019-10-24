$scoopAudioName = 'scoop-audio'

if ([Environment]::Is64BitOperatingSystem) {
    $systemArch = '64bit'
} else {
    $systemArch = '32bit'
}

Function GetScoopAudioVst2Folder {
    param (
        [string]$arch
    )

    if ($arch -eq '32bit' -and $systemArch -eq '64bit') {
        $defaultVst2FolderRegistryPath = 'HKLM:\SOFTWARE\Wow6432Node\VST'
        $defaultVst2Folder = 'C:\Program Files (x86)\Common Files\VST2'
    } else {
        $defaultVst2FolderRegistryPath = 'HKLM:\SOFTWARE\VST'
        $defaultVst2Folder = 'C:\Program Files\Common Files\VST2'
    }

    try {
        $vstFolder = Get-ItemPropertyValue -Path $defaultVst2FolderRegistryPath -Name "VSTPluginsPath" -ErrorAction Stop
        [Console]::WriteLine("Found VST folder of $vstFolder")
    } catch {
        $vstFolder = $defaultVst2Folder
        [Console]::WriteLine("No VST folder found. Using $vstFolder")
        if (-Not (Test-Path -Path $defaultVst2FolderRegistryPath)) {
            New-Item -Path $defaultVst2FolderRegistryPath -Name "VSTPluginsPath" -Force -ErrorAction Stop
        }
        Set-ItemProperty -Path $defaultVst2FolderRegistryPath -Name "VSTPluginsPath" -Value $vstFolder -Force -ErrorAction Stop
    }
    
    return "$(Join-Path "$vstFolder" $scoopAudioName)"
}

Function GetInstallArch {
    param (
        [string]$appPath
    )

    $appInstallPath = [io.Path]::Combine([string[]]($appPath, 'install.json'))
    $appJson = Get-Content $appInstallPath | ConvertFrom-Json

    return $appJson.architecture
}

Function PostInstallVst2Folder {
    param (
        [string]$arch,
        [string]$appName,
        [string]$targetPath
    )

    if ([string]::IsNullOrEmpty($arch)) {
        Write-Error "No arch argument provided"
        exit 
    }
    
    if ([string]::IsNullOrEmpty($appName)) {
        Write-Error "No appName argument provided"
        exit 
    }
    
    if ([string]::IsNullOrEmpty($targetPath)) {
        Write-Error "No target argument provided"
        exit
    }
    
    $scoopVstFolder = GetScoopAudioVst2Folder -arch $arch
    $appArchVstFolder = [io.Path]::Combine([string[]]($scoopVstFolder, "$($appName)-$($arch)"))
    
    Write-Output "Linking $appName, $arch into $scoopVstFolder"

    New-Item -Path "$scoopVstFolder" -ItemType 'directory' -Force -ErrorAction Stop | Out-Null
    New-Item -Path "$appArchVstFolder" -ItemType Junction -Target "$targetPath" -ErrorAction Stop | Out-Null
}

Function PostUninstallVst2Folder {
    param (
        [string]$appPath,
        [string]$appName
    )

    if ([string]::IsNullOrEmpty($appPath)) {
        Write-Error "No appPath argument provided"
        exit 
    }

    if ([string]::IsNullOrEmpty($appName)) {
        Write-Error "No appName argument provided"
        exit 
    }

    $arch = GetInstallArch -appPath $appPath
    $scoopVstFolder = GetScoopAudioVst2Folder -arch $arch
    $appArchVstFolder = [io.Path]::Combine([string[]]($scoopVstFolder, "$($appName)-$($arch)"))

    Write-Output "Removing $appName, $arch link in $scoopVstFolder"
    try {
        [io.Directory]::Delete($appArchVstFolder)
    } catch {
        # Do nothing
    }
}

$command = $args[0]

if ([string]::IsNullOrEmpty($command)) {
    Write-Output "No command argument provided"
    exit
}

switch ($command) {
    'postinstall-vst2-folder' {
        PostInstallVst2Folder -appName $args[1] -targetPath $args[2] -arch $args[3] 
    }
    'postuninstall-vst2-folder' {
        PostUninstallVst2Folder -appName $args[1] -appPath $args[2]
    }
    Default {
        Write-Output "'$command' is an invalid command"
        exit
    }
}