####################################################
#
# DEMO: 
# Force an Intune Policy Sync for all Devices in a Tenant
#
# Author: Ronni Pedersen, APENTO
# Twitter: @ronnipedersen
# Email: rop@apento.com
#
####################################################

# Step 1 - Connenct to MSGraph
Connect-MSGraph

# Step 2 - Get a list of all Devices
Get-IntuneManagedDevice | ft

# Step 3A - Select the Operating System
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'iOS')"
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Android')" 
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Windows')"

# Step 3B - If you have more than 1000 Objects
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Windows')" | Get-MSGraphAllPages

# Step 4 - Count number of selected Devices
$Devices.Count

# Step 5 - Invoke a sync on all devices
Foreach ($Device in $Devices)
{
    Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $Device.managedDeviceId
    Write-Host "Sending Sync request to Device with DeviceID $($Device.managedDeviceId)" -ForegroundColor Yellow
}
 
