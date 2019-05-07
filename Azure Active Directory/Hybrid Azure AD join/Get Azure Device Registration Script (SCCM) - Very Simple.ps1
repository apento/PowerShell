<#  
.SYNOPSIS  
  Compare Azure AD Hybrid joined machines in Azure Active Directory with active clients in ConfMgr.
  
.DESCRIPTION  
   Compare Azure AD Hybrid joined machines in Azure Active Directory with active clients in ConfMgr.
         
.NOTES  
    Author: Peter Selch Dahl from APENTO ApS  
    Website: https://www.APENTO.com 
    Last Updated: 11/17/2018 
    Version 1.0 
 
    #DISCLAIMER 
    The script is provided AS IS without warranty of any kind. 
 
#>  
 

##############################################################
# Set credentials for the cloud....
##############################################################

$Username = "Account@Company.com"
$Password = ConvertTo-SecureString 'SECRET' -AsPlainText -Force

##############################################################

# Remove Existing files....
##############################################################
Remove-Item "c:\output\exportnoclient.csv" -Confirm:$false
Remove-Item "c:\output\CompareResults.csv" -Confirm:$false
Remove-Item "c:\output\AzureADDevices.csv" -Confirm:$false

 ##############################################################

# Get information from SCCM 2012 R2 
##############################################################
# Load the CM Module using Implicit Remoting
Cd "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\”
Import-Module -Name .\ConfigurationManager.psd1

# Check the module is available locally
Get-Module -Name ConfigurationManager

CD P01:

# run the CM cmdlets locally
Get-CMSite

Get-CMDevice | Where-Object {$_.ClientActiveStatus -eq 1} | select Name,DeviceOS | Export-Csv c:\output\exportnoclient.csv -NoTypeInformation

##############################################################


# Get Information from Azure Active Directory
##############################################################
import-module msonline

$LiveCred = New-Object System.Management.Automation.PSCredential $Username, $Password

Connect-MsolService –Credential $LiveCred

Get-MsolDevice -All | Where-Object {$_.DeviceTrustType -eq "Domain Joined"} | Select DisplayName,DeviceOSVersion | Export-Csv c:\output\AzureADDevices.csv -NoTypeInformation

##############################################################


Function CheckDevice ($computername2,$DeviceOS2)
{



ForEach ($device in $AzureADDevices){
$devicename = $($device.DisplayName)
$DeviceOsVersion = $($device.DeviceOsVersion)

#Write-host $computername2 -ForegroundColor Cyan
#Write-host $DeviceOS2 -ForegroundColor Cyan
#Write-host $devicename -ForegroundColor DarkMagenta

#Start-Sleep -Seconds 1

If ($devicename -eq $computername2) {

Write-host $computername2 -ForegroundColor Green 
Write-host $devicename -ForegroundColor Green 
#Start-Sleep -Seconds 1
$QueryResult = "$computername2,$DeviceOS2,$DeviceOsVersion,Yes`n"

break

}
else
{
#Write-host $devicename -ForegroundColor Red
$QueryResult = "$computername2,$DeviceOS2,$DeviceOsVersion,No`n"
}


}



return $QueryResult
}


$Results = "Computername,DeviceOS,DeviceOsVersion,AzureJoined`n"

##############################################################
Write-host "Start loading CSV...." -ForegroundColor Yellow 
$computers = import-csv “C:\Output\exportnoclient.csv”
$AzureADDevices = import-csv “C:\Output\AzureADDevices.csv”
Write-host "CSV loaded" -ForegroundColor Yellow 
##############################################################

ForEach ($computer in $computers){

$computername = $($computer.Name)
$DeviceOS = $($computer.DeviceOS)


#Checking the device
##############################################################

Write-host "Checking..... " $computername -ForegroundColor Yellow

$Results +=  CheckDevice $computername $DeviceOS

##############################################################


}

Write-host "Results...." -ForegroundColor Yellow 
Start-Sleep -Seconds 5
#Write-Host "Press any key to continue ..."
#$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#Write-host $Results

$Results | Add-Content -Path "c:\output\CompareResults.csv"


##############################################################