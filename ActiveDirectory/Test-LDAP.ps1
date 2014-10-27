function Test-LDAP {
    <#
    .SYNOPSIS
    Test LDAP binding of one or more remote systems.
    
    .DESCRIPTION
    Test LDAP binding of one or more remote systems.
    
    .PARAMETER ComputerName
    Computer to test network port against.
    
    .PARAMETER Filter
    Filter to attempt to test binding for.

    .PARAMETER Scope
    AD scope.
  
    .EXAMPLE
    Test-LDAP -ComputerName DC1 -Verbose

    Description
    -----------
    Test LDAP bind against DC1, be verbose about what it is doing, show the default results.
    
    .LINK
    http://the-little-things.net/
 
    .NOTES
    Author:  Zachary Loeber
    Created: 07/07/2014
    #>

    [CmdletBinding()]
    param (
        [Parameter(HelpMessage='Filter to attempt to test binding for.')]
        [string]$Filter = '(cn=krbtgt)',
        
        [Parameter(HelpMessage='Server to attempt to bind to.',
                   Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$ComputerName,
        
        [Parameter(HelpMessage='AD scope (default is Subtree).')]
        [ValidateSet("Base","Subtree","OneLevel")]
        [string]$Scope = 'Subtree'
    )
    begin {
        $Servers = @()
        $Results = @()
    }
    process {
        $Servers += $ComputerName
    }
    end {
        $Servers | Foreach {
            $domain = 'LDAP://' + $_
            $root = New-Object DirectoryServices.DirectoryEntry $domain
            $searcher = New-Object DirectoryServices.DirectorySearcher
            $searcher.SearchRoot = $root
            $searcher.PageSize = 1
            $searcher.Filter = $Filter
            $result = @{
                'ComputerName' = $_
                'Connected' = $false
                'Exception' = $null
            }
            try {
                Write-Verbose ('Test-LDAP: Trying to LDAP bind - {0}' -f $server)
                $adObjects = $searcher.FindAll()
                Write-Verbose ('Test-LDAP: LDAP Server {0} is up (object path = {1})' -f $server, $adObjects.Item(0).Path)
                $result.Connected = $true
            }
            catch [Exception] {
                throw
            }
            $Results += New-Object psobject -Property $result
        }
        return $Results
    }
}