
<#

 This script is built to validate whether Azure AD Apps are configured with the new authenticationBehavior block option for non-validated
 email accounts in incoming claims.

 For more details: https://learn.microsoft.com/en-us/graph/applications-authenticationbehaviors?tabs=http

﻿ The script is a n0Auth vulnerability check for Microsoft Entra (Formerly known as Azure Active Directory)
 It validates whether Azure AD Apps are configured with the new authenticationBehavior block option for non-validated email accounts in incoming claims. 
 For more details: https://learn.microsoft.com/en-us/graph/applications-authenticationbehaviors?tabs=http
  
    Author: Peter Selch Dahl from APENTO ApS
    Website: https://www.APENTO.com - github.com/APENTO
    Last Updated: 08/15/2023
    Version 1.0 
 
    #DISCLAIMER 
    The script is provided AS IS without warranty of any kind. 
 
#>


##################
### Initialize ###
##################

Write-Host "Initializing" -ForegroundColor Cyan

##Check what powershell edition is used. If it's desktop the maximum function count has to be increased due to the large amount of functions in the Microsoft Graph module
if ($PSEdition -eq "Desktop") {
    Write-Host "Powershell Desktop detected. Increasing 'maximum function count' to accommodate all functions in microsoft graph" -ForegroundColor Yellow
    $global:maximumfunctioncount = 32768
}

## Check if Microsoft Graph module is already installed or already imported
if ( -Not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta.Applications)) {
    Write-Host "Installing Microsoft Graph Module"
    Install-Module Microsoft.Graph.Beta.Applications -Scope CurrentUser
} elseif ( -Not (Get-Module -Name Microsoft.Graph.Beta.Applications)) {
    Write-Host "Updating Microsoft Graph Module"
    Update-Module Microsoft.Graph.Beta.Applications
} 

Write-Host "Importing Microsoft Graph Module"
Import-Module Microsoft.Graph.Beta.Applications

Write-Host "Please use the prompt to login. Sign-in with AppAdmin role."
Connect-MgGraph

Write-Host "Collecting Azure AD App info" -ForegroundColor Cyan
#Get-MgBetaApplication -Property "id,displayName,appId,signInAudience,authenticationBehaviors"


Write-Host "Processing the Azure AD apps" -ForegroundColor Cyan
Start-Sleep 1

# Get Azure AD Multi-Tenant Applications
$aadApplications = Get-MgBetaApplication -All -Property "id,displayName,appId,signInAudience,authenticationBehaviors" -Filter "signInAudience eq 'AzureADMultipleOrgs'"
$aadApplications += Get-MgBetaApplication -All -Property "id,displayName,appId,signInAudience,authenticationBehaviors" -Filter "signInAudience eq 'AzureADandPersonalMicrosoftAccount'"
$aadApplications += Get-MgBetaApplication -All -Property "id,displayName,appId,signInAudience,authenticationBehaviors" -Filter "signInAudience eq 'PersonalMicrosoftAccount'"
#$aadApplications

#https://learn.microsoft.com/en-us/azure/active-directory/develop/supported-accounts-validation


#$aadApplications | Select-Object -ExpandProperty authenticationBehaviors | Get-Member
#$aadApplications

#$aadApplicationExpand = $aadApplications | Select-Object -Property authenticationBehaviors
#$aadApplicationExpand | Select-Object -Property RemoveUnverifiedEmailClaim
#$aadApplicationExpand | where {($_.RemoveUnverifiedEmailClaim -eq $null)} | Select-Object -Property displayName

#Get-MgBetaApplication -All -Property "id,displayName,appId,signInAudience,authenticationBehaviors"

$AppsForReview=@() 
$counter = 0

Write-Host "All potential impacted applications that doesn't enforce validate e-mail in incoming claims" -ForegroundColor Cyan

foreach ($aadApplication in $aadApplications) {
   $aadApplicationExpand = $aadApplication | Select-Object -Property authenticationBehaviors

   if ($null -eq $_.RemoveUnverifiedEmailClaim){
    Write-Host ($aadApplication).displayName -ForegroundColor Red
    $counter++
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $aadApplication.DisplayName
    $obj | Add-Member -MemberType NoteProperty -Name "id" -Value $aadApplication.id 
    $obj | Add-Member -MemberType NoteProperty -Name "AppId" -Value $aadApplication.AppId 
    $AppsForReview += $obj

    Start-Sleep -Milliseconds 250

    }
    else{
     Write-Host ($aadApplication).displayName -ForegroundColor Green
   }

}

#$AppsForReview | Out-GridView








