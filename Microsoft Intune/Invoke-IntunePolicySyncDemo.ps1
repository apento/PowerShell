# Connenct to MSGraph
Connect-MSGraph

# Get a list of all Devices
Get-IntuneManagedDevice | ft

# Select the OS you need to update
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'iOS')"
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Android')" 
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Windows')"

# More than 1000 Objects
$Devices = Get-IntuneManagedDevice -Filter "contains(operatingsystem, 'Windows')" | Get-MSGraphAllPages

# Count number of devices
$Devices.Count


# Invoke a sync on all devices
Foreach ($Device in $Devices)
{
    Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $Device.managedDeviceId
    Write-Host "Sending Sync request to Device with DeviceID $($Device.managedDeviceId)" -ForegroundColor Yellow
}
 

