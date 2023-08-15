
$username = "Account@Domain.com"
$password = Get-Content ..\PWD_Account.txt | ConvertTo-SecureString
$Recipients = Get-Content .\Recipients.txt

function WriteLog ($LogText)
{
    $output = $(Get-Date -Format HH:mm:ss) + ";" + $LogText
    $output >> ".\Logs\Office365Roles_$(Get-Date -Format yyyy-MM-dd).log"
}

function SendMailList ($RoleName, $RoleObjectId, $ChangedUsersList)
{
    $Subject = "Azure Roles - $RoleName"
    $Body = ""
    $Body += "Role: $RoleName ($RoleObjectId)`n`n"
    $Body += $ChangedUsersList

    $SendMailParameters = @{}
    $SendMailParameters.Add("SmtpServer","smtp.domain.com")
    $SendMailParameters.Add("From","Azure AD Roles <ADRoles@domain.com>")
    $SendMailParameters.Add("To",$Recipients)
    $SendMailParameters.Add("Subject",$Subject)
    $SendMailParameters.Add("Body",$Body)

    Send-MailMessage @SendMailParameters
}

function NestedGroup ([string]$GroupObjectId)
{
    $Members = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true -ErrorAction Stop
    $Groups = @($Members | ? {$_.ObjectType -eq "Group"})
    $Users = @($Members | ? {$_.ObjectType -eq "User"})
    $UserList = @()

    if ($Users)
    {
        $UserList += $Users
    }
    
    foreach ($Group in $groups)
    {
        $UserList += (NestedGroup $Group.ObjectId)
    }

    return $UserList | sort ObjectId -Unique
}

function Office365Roles ([string]$RoleName, [string[]]$GroupNames, [switch]$WhatIf)
{
    [System.Collections.ArrayList]$AzureADRoleMembers = @()
    [System.Collections.ArrayList]$AzureADGroupMembersFromGroups = @()
    [System.Collections.ArrayList]$AzureADGroupMembers = @()
    [System.Collections.ArrayList]$NewUsers = @()
    [System.Collections.ArrayList]$RemoveUsers = @()
    [string]$ChangedUsersList

    try
    {
        $RoleObjectId = (Get-AzureADDirectoryRole -ErrorAction Stop | ? {$_.DisplayName -eq $RoleName}).ObjectId.ToString()

        WriteLog -LogText "START ROLENAME: $RoleName ($RoleObjectId)"
        
        if ($WhatIf)
        {
            WriteLog -LogText "$($RoleName) ($($RoleObjectId));Warning: WhatIf parameter is set - no users will be added/removed!"
        }

        # Getting all users with Role assigned
        #$AzureADRoleMembers = @(Get-AzureADDirectoryRoleMember -ObjectId $RoleObjectId -ErrorAction Stop | ? {$_.LastDirSyncTime -ne $null} | sort ObjectId)
        if (Test-Path .\Roles\$RoleName.csv)
        {
            $AzureADRoleMembers = Import-Csv .\Roles\$RoleName.csv | sort ObjectId
        }

        # Getting all members of AD groups
        foreach ($GroupName in $GroupNames)
        {
            $AzureADGroup = Get-AzureADGroup -SearchString $GroupName -ErrorAction Stop | ? {$_.DisplayName -eq $GroupName}
            @(NestedGroup -GroupObjectId $AzureADGroup.ObjectId | sort ObjectId) | % {$AzureADGroupMembersFromGroups.Add($_) | Out-Null}
        }

        $AzureADGroupMembers = $AzureADGroupMembersFromGroups | sort ObjectId -Unique

        # Comparing the groups to each together to find users being added/removed
        $indexAzureADGroupMembers = 0
        $indexAzureADRoleMembers = 0
        while ($indexAzureADGroupMembers -lt $AzureADGroupMembers.Count -and $indexAzureADRoleMembers -lt $AzureADRoleMembers.Count)
        {
            if ($AzureADGroupMembers[$indexAzureADGroupMembers].ObjectId -eq $AzureADRoleMembers[$indexAzureADRoleMembers].ObjectId)
            {
                $indexAzureADGroupMembers++
                $indexAzureADRoleMembers++
            }
            elseif ($AzureADGroupMembers[$indexAzureADGroupMembers].ObjectId -lt $AzureADRoleMembers[$indexAzureADRoleMembers].ObjectId)
            {
                $NewUsers.Add($AzureADGroupMembers[$indexAzureADGroupMembers])
                
                $indexAzureADGroupMembers++
            }
            else
            {
                $RemoveUsers.Add($AzureADRoleMembers[$indexAzureADRoleMembers])

                $indexAzureADRoleMembers++
            }
        }

        while ($indexAzureADGroupMembers -lt $AzureADGroupMembers.Count)
        {
            $NewUsers.Add($AzureADGroupMembers[$indexAzureADGroupMembers])
            
            $indexAzureADGroupMembers++
        }

        while ($indexAzureADRoleMembers -lt $AzureADRoleMembers.Count)
        {
            $RemoveUsers.Add($AzureADRoleMembers[$indexAzureADRoleMembers])
            
            $indexAzureADRoleMembers++
        }

        WriteLog -LogText "$($RoleName) ($($RoleObjectId));Number of new users: $($NewUsers.Count)"
        WriteLog -LogText "$($RoleName) ($($RoleObjectId));Number of removable users: $($RemoveUsers.Count)"
    }
    catch
    {
        WriteLog -LogText "Error: $($_.Exception.Message)"
        Exit
    }

    # Remove all users, that are having role, but are not member of AD group
    foreach ($u in $RemoveUsers)
    {
        # Remove role
        WriteLog -LogText "$($RoleName) ($($RoleObjectId));$($u.UserPrincipalName);Warning: The user is not member of any named groups"
        if (!$WhatIf)
        {
            try
            {
                $AzureADUser = Get-AzureADUser -ObjectId $u.UserPrincipalName
            }
            catch
            {
                WriteLog -LogText "$($RoleName) ($($RoleObjectId));$($u.UserPrincipalName);Error: $($_.Exception.ErrorContent.Code)"
            }

            if ($AzureADUser)
            {
                #Remove-AzureADDirectoryRoleMember -ObjectId $RoleObjectId -MemberId $u.ObjectId -ErrorAction Stop
                $ChangedUsersList += "Removed: $($u.UserPrincipalName) ($($u.ObjectId))`n"
            }
        }
        WriteLog -LogText "$($RoleName) ($($RoleObjectId));$($u.UserPrincipalName);Removed role"
    }

    # Granting role to new users of AD group
    foreach ($u in $NewUsers)
    {
        # Granting role for the user
        if (!$WhatIf)
        {
            try
            {
                #Add-AzureADDirectoryRoleMember -ObjectId $RoleObjectId -RefObjectId $u.ObjectId -ErrorAction Stop
                $ChangedUsersList += "Added: $($u.UserPrincipalName) ($($u.ObjectId))`n"
            }
            catch
            {
                WriteLog -LogText "$($RoleName) ($($RoleObjectId));$($u.UserPrincipalName);Error: $($_.Exception.Message)"
            }
        }
        WriteLog -LogText "$($RoleName) ($($RoleObjectId));$($u.UserPrincipalName);Granted new role"
    }

    if ($ChangedUsersList)
    {
        SendMailList -RoleName $RoleName -RoleObjectId $RoleObjectId -ChangedUsersList $ChangedUsersList
    }

    if ($NewUsers -or $RemoveUsers)
    {
        $AzureADGroupMembers | select ObjectId,UserPrincipalName | Export-Csv -Path .\Roles\$RoleName.csv -NoTypeInformation -Force
        Copy-Item -Path .\Roles\$RoleName.csv -Destination ".\Roles\History\$(Get-Date -Format yyyy-MM-dd_HHmmss)_$($RoleName).csv"
        Get-ChildItem .\Roles\History | ? {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item -Force
    }

    WriteLog -LogText "END ROLENAME: $RoleName ($RoleObjectId)"
}

WriteLog -LogText "START SCRIPT: Office365Roles"

try
{
    WriteLog -LogText "START LOGIN"
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
    Import-Module AzureAD -ErrorAction Stop
    Connect-AzureAD -Credential $cred -ErrorAction Stop
    WriteLog -LogText "END LOGIN"
}
catch
{
    WriteLog -LogText "Error: $($_.Exception.Message)"
    Send-MailMessage -From "NotificationMail@domain.com" -SmtpServer smtp.domain.com -Priority High -To MySelf@Domain.com -Subject "Office365Roles script error" -Body "Error: $($_.Exception.Message)"
    Exit
}

#############################################################################################################################
# Syntax:
# Office365Roles -RoleName <Role name> -GroupName <Group name>[,<Group name>...] [-WhatIf]

Office365Roles -RoleName "Service Support Administrator" -GroupNames "O365ServiceAdmins"
Office365Roles -RoleName "User Account Administrator" -GroupNames "O365ServiceAdmins"
Office365Roles -RoleName "Reports Reader" -GroupNames "O365ServiceAdmins","ReportsReader"
Office365Roles -RoleName "Directory Readers" -GroupNames "AzureADRole_DirectoryReaders"
Office365Roles -RoleName "Application Developer" -GroupNames "ApplicationDeveloper"

#############################################################################################################################

WriteLog -LogText "END SCRIPT: Office365Roles"

