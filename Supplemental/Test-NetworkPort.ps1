﻿function Test-NetworkPort {
    <#
    .SYNOPSIS
    Test one or more network ports on a networked system.
    .DESCRIPTION
    Test one or more network ports on a networked system.
    .PARAMETER ComputerName
    Computer to test network port against.
    .PARAMETER Port
    Port to test.
    .PARAMETER Type
    Type of connection to attempt (udp or tcp).
    .PARAMETER Timeout
    Connection timeout period (default: ~200 ms).
    .EXAMPLE
    '443','80','65536' | Test-NetworkPort -ComputerName www.google.com -Verbose | select port,Connected,Exception

    Description
    -----------
    Test ports 443, 80, and an invalid port 65536 against www.google.com, show the results and be verbose when 
    running.

    .INPUTS
    .OUTPUTS
    PSObject
    .LINK
    http://the-little-things.net/
    .NOTES
    Author:  Zachary Loeber
    Created: 07/07/2014
    #>
    [cmdletbinding()]
    param (
        [Parameter(HelpMessage='Computer to test network port against.', Position=0)]
        [string]$ComputerName = 'localhost',
        
        [Parameter(HelpMessage='Port to test.', ValueFromPipeline=$true, Mandatory=$true, Position=1)]
        [ValidateRange(1,65536)]
        [int[]]$Port,
        
        [Parameter(HelpMessage='Type of connection to attempt (udp or tcp).')]
        [ValidateSet('tcp','udp')]
        [string]$Type = 'tcp',
        
        [Parameter(HelpMessage='Connection timeout period (default: ~200 ms).')]
        [int]$Timeout = 200,
        
        [Parameter(HelpMessage='Repeatedly attempts to connect to a port until you break the script processing. Only works on 1 port at a time.')]
        [switch]$Ping        
    )
    begin {
        $FunctionName = $MyInvocation.MyCommand.Name
        Write-Verbose "$($FunctionName): BEGIN"
        $Ports = @()
        $Results = @()
        $NameLookUpWorks = $true
        try {
            $IP = [System.Net.Dns]::GetHostAddresses($ComputerName)
            $Address = [System.Net.IPAddress]::Parse($IP[$IP.Count - 1])
            Write-Verbose "$($FunctionName): Scanning $ComputerName ($Address)"
        }
        catch {
            Write-Verbose "$($FunctionName): Computer name lookup failed for $computerName"
            $NameLookUpWorks = $false
        }
    }
    process {
        $Ports += $Port
    }
    end {
        if ($Ping) {
            $Ports = $Ports | Select -First 1
        }
        do {
            foreach ($PortNumber in $Ports) {
                if ($NameLookUpWorks) {
                    switch ($type) {
                        'tcp' {
                            $Socket = New-Object System.Net.Sockets.TcpClient
                        }
                        'udp' {
                            $Socket = New-Object System.Net.Sockets.UdpClient
                        }
                    }
                    Write-Verbose ('Test-NetworkPort: Trying to open Port ' + $type + ' ' + $PortNumber + ' on ' + $computerName)
                    try {
                        $Connect = $Socket.BeginConnect($Address,$PortNumber,$Null,$Null)
                        $TimeoutPeriod = (Get-Date).AddMilliseconds($timeout)
                        # I guess that this can cause issues in some specific environments (like testing through TMG)
                        #   $tcpPortWait = $Connect.AsyncWaitHandle.WaitOne($timeOut,$false)
                        # So I'm using the manual and clunky way of implementing a 'timeout' instead.....
                        while (-not $Socket.Connected -and ((Get-Date) -lt $TimeoutPeriod)) {
                            Sleep -Milliseconds 50
                        }
                        if ($Socket.Connected) {
                            Write-Verbose ('Test-NetworkPort: Computer={0} Type={1} Port={2} Status=Connected' -f $computerName,$type,$PortNumber)
                            Write-Verbose ('Test-NetworkPort: Endpoints Local={0} <-> Remote={1}' -f $Socket.Client.LocalEndPoint.ToString(),$Socket.Client.RemoteEndPoint.ToString()) 
                            $Socket.EndConnect($Connect)
                            New-Object PSObject -Property @{
                                Port=$PortNumber
                                Type=$type
                                Connected=$true
                                Exception=$null
                            }
                        }
                        else {
                            Write-Verbose ('Test-NetworkPort: Connection Failed - Timeout')
                            New-Object PSObject -Property @{
                                Port=$PortNumber
                                Type=$type
                                Connected=$false
                                Exception="Timeout"
                            }
                        }
                    }
                    catch [System.ArgumentNullException] {
                        Write-Verbose ('Test-NetworkPort: Connection Failed {0}' -f $_.Exception.Message)
                        New-Object PSObject -Property @{
                            Port=$PortNumber
                            Type=$type
                            Connected=$false
                            Exception="Null argument passed"
                        }
                    }
                    catch [ArgumentOutOfRangeException] {
                        Write-Verbose ('Test-NetworkPort: Connection Failed {0}' -f $_.Exception.Message)
                        New-Object PSObject -Property @{
                            Port=$PortNumber
                            Type=$type
                            Connected=$false
                            Exception="The port is not between MinPort and MaxPort"
                        }
                    }
                    catch [System.Net.Sockets.SocketException] {
                        Write-Verbose ('Test-NetworkPort: Connection Failed {0}' -f $_.Exception.Message)
                        New-Object PSObject -Property @{
                            Port=$PortNumber
                            Type=$type
                            Connected=$false
                            Exception=[string]::Format("Socket exception: {0}", $_)
                        }     
                    }
                    catch [System.ObjectDisposedException] {
                        Write-Verbose ('Test-NetworkPort: Connection Failed {0}' -f $_.Exception.Message)
                        New-Object PSObject -Property @{
                            Port=$PortNumber
                            Type=$type
                            Connected=$false
                            Exception="TcpClient is closed"
                        }
                    }
                    catch {
                        Write-Verbose ('Test-NetworkPort: Connection Failed {0}' -f $_.Exception.Message)
                        New-Object PSObject -Property @{
                            Port=$PortNumber
                            Type=$type
                            Connected=$false
                            Exception="Unhandled Error"
                        }
                    }
                    finally {
                        $Socket.Dispose()
                        $Socket.Close()
                    }
                }
                else {
                    New-Object PSObject -Property @{
                                    Port=$PortNumber
                                    Type=$type
                                    Connected=$false
                                    Exception='Server lookup failed'
                                }
                }
            }
        } While ($Ping)
        Write-Verbose "$($FunctionName): END"
    }
}