﻿Function Set-ContactFromUser
{
    <#
    .SYNOPSIS
        Based on a matching attribute this function will update an AD contact with an AD user's attributes.
    .DESCRIPTION
        Based on a matching attribute this function will update an AD contact with an AD user's attributes.
    .PARAMETER UserAttribute
        Attribute on user account to update a matching contact with. By default this is UserPrincipalName.
    .PARAMETER UserMatchAttribute
        Attribute on contact to update. If not defined or blank we attempt to update an attribute on the contact 
        by the same name as the UserAttribute parameter.
    .PARAMETER ContactAttribute
        Attribute on contact to update. If not defined or blank we attempt to update an attribute on the contact 
        by the same name as the UserAttribute parameter.
    .PARAMETER ContactMatchAttribuet
        Attribute on user account to try and match with a contact in the same domain.
    .PARAMETER Overwrite
        Do not skip over contacts that already have values in the attribute specified for updating
    .EXAMPLE
        Set-ContactFromUser -UserAttribute OfficePhone -ContactAttribute Phone -Verbose -Whatif
        
        Description
        -----------
        Find all contacts where WindowsEmailAddress matches to a user UserPrincipalName attribute and attempt
        to set the contact 'phone' attribute with the users 'OfficePhone' attribute value in testing mode. 
        
        This update would only occur when the AD user 'OfficePhone' attribute is populated with some value and the 
        contact 'Phone' attribute is not already populated.
    .EXAMPLE        
        Set-ContactFromUser -UserAttribute MobilePhone -Verbose -Whatif -Overwrite
        
        Description
        -----------
        Find all contacts where WindowsEmailAddress matches to a user UserPrincipalName attribute and attempt
        to set the contact 'MobilePhone' attribute with the users 'MobilePhone' attribute value in testing mode.
        
        This update would only occur when the AD user 'MobilePhone' attribute is populated with some value and 
        would overwrite the matching contact's current 'MobilePhone' attribute if it is set already.
        
    .NOTES
        Version    : 1.0 06/07/2014
                     - Initial release
        Author     : Zachary Loeber
    .LINK
        the-little-things.net
    #>
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='High')]
    param (
        [Parameter( Mandatory=$true, HelpMessage="Attribute on user account to associate with a contact match." )]
        [string]$UserAttribute,
        
        [Parameter( HelpMessage="Attribute on user account to update matched contact with." )]
        [string]$UserMatchAttribute='UserPrincipalName',
        
        [Parameter( HelpMessage='Attribute on contact to update. If not defined or blank we attempt to update an attribute on the contact by the same name as the UserAttribute parameter.')]
        [string]$ContactAttribute='',
        
        [Parameter( HelpMessage='Attribute on user account to try and match with a contact in the same domain.' )]
        [string]$ContactMatchAttribute='WindowsEmailAddress',
        
        [Parameter( HelpMessage="Do not skip over contacts that already have values in the attribute specified for updating" )]
        [switch]$Overwrite
    )
    
    begin {
        Write-Verbose "$($MyInvocation.MyCommand): Begin"
        
        $ADModuleLoaded = $false
        if(-not(Get-Module -name ActiveDirectory)) 
        {
            if(Get-Module -ListAvailable | Where-Object { $_.name -eq 'ActiveDirectory' }) 
            { 
                try {
                    Write-Verbose "Set-ContactFromUser: Attempting to load ActiveDirectory module...."
                    Import-Module -Name ActiveDirectory
                    $ADModuleLoaded = $true
                }
                catch
                {}
            }
            else
            {
                Write-Warning "Set-ContactFromUser: ActiveDirectory Module is not available on this system"
            }
        }

        $UpdatedContacts = 0
        $UserFilter = [scriptblock]::create("($UserAttribute -like `"*`")")

        if ($ContactAttribute -eq '')
        {
            $ContactAttribute = $UserAttribute
        }
        if ($Overwrite)
        {
            $SkipPopulatedFilter =  "}"
        }
        else
        {
            $SkipPopulatedFilter =  " -and (-not ($ContactAttribute -like `"*`"))}"
        }
    }    
    process {}
    end {
        if ($ADModuleLoaded)
        {
            try {
                # all users that have the source attribute populated
                Write-Verbose "$($MyInvocation.MyCommand): User Filter - $UserFilter"
                Get-ADUser -Filter $UserFilter -Properties $UserAttribute | Foreach {
                    $ContactFilter = [scriptblock]::create("{($ContactMatchAttribute -eq `"$($_.$UserMatchAttribute)`")$SkipPopulatedFilter")
                    $SamAccountName = $_.SamAccountName
                    $FoundAttrib = $_.$UserAttribute
                    try {
                        Get-Contact -Filter $ContactFilter | Foreach {
                            Write-Verbose "$($MyInvocation.MyCommand): Found matching attribute for $SamAccountName - (User) $UserMatchAttribute == (Contact) $ContactMatchAttribute"
                            if ( $PSCmdlet.ShouldProcess("$SamAccountName") ) 
                            {
                                $ContactSplat = @{
                                    $ContactAttribute = $FoundAttrib
                                }
                                $_ | Set-Contact @ContactSplat
                                $UpdatedContacts++
                            }
                        }
                    }
                    catch {
                        Write-Warning '$($MyInvocation.MyCommand): Issue querying or updating AD contacts.'
                    }
                }
            }
            catch {
                Write-Warning '$($MyInvocation.MyCommand): Issue querying AD for users'
                Write-Warning -Message ('Set-ContactFromUser: Error - {0}' -f $_.Exception.Message)
            }
        }
        Write-Verbose "$($MyInvocation.MyCommand): Number of updated contacts - $UpdatedContacts"
    }
    
    Write-Verbose "$($MyInvocation.MyCommand): End"
}
