﻿function Get-WebFile {
    <#
    .SYNOPSIS
    Downloads file from the web and returns the full path when complete.

    .DESCRIPTION
    Downloads file from the web and returns the full path when complete.

    .EXAMPLE
    $source = 'http://download.microsoft.com/download/3/E/4/3E4AF215-E418-47B8-BB89-D5555E858728/EwsManagedApi.MSI'
    Get-WebFile -source $source
    
    Description
    -----------
    Downloads the EWS managed api installer to a temporary directory and returns the final location when completed.
    #>
    [CmdLetBinding()]
    param(
        [string]$source,
        [string]$destination
    )
    if ([string]::IsNullOrEmpty($destination)) {
        $TempDirPath = "$($Env:TEMP)\$([System.Guid]::NewGuid().ToString())"
        Write-Verbose "$($MyInvocation.MyCommand): Creating temporary directory $TempDirPath"
        [string]$NewDir = New-Item -Type Directory -Path $TempDirPath
        $filename = $source.Split('/') | Select -Last 1
        $destfullpath = $NewDir + '\' + $filename
    }
    elseif (Test-Path (Split-Path $destination -Parent)){
        $destfullpath = $destination
    }
    else {
        throw '$($MyInvocation.MyCommand): Unable to validate destination path exists!'
    }
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($source, $destfullpath)
        return $destfullpath
    }
    catch {
        throw '$($MyInvocation.MyCommand): Unable to download file!'
    }
}
