function LogIt
{
  param (
  [Parameter(Mandatory=$true)]
  $message,
  [Parameter(Mandatory=$true)]
  $component,
  [Parameter(Mandatory=$true)]
  $type )

  switch ($type)
  {
    1 { $type = "Info" }
    2 { $type = "Warning" }
    3 { $type = "Error" }
    4 { $type = "Verbose" }
  }

  if (($type -eq "Verbose") -and ($Global:Verbose))
  {
    $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ":" + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
    $toLog | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $Global:LogFile)
    Write-Host $message
  }
  elseif ($type -ne "Verbose")
  {
    $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ":" + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
    $toLog | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $Global:LogFile)
    Write-Host $message
  }
  if (($type -eq 'Warning') -and ($Global:ScriptStatus -ne 'Error')) { $Global:ScriptStatus = $type }
  if ($type -eq 'Error') { $Global:ScriptStatus = $type }

  if ((Get-Item $Global:LogFile).Length/1KB -gt $Global:MaxLogSizeInKB)
  {
    $log = $Global:LogFile
    Remove-Item ($log.Replace(".log", ".lo_"))
    Rename-Item $Global:LogFile ($log.Replace(".log", ".lo_")) -Force
  }
} 

function GetScriptDirectory
{
  $invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $invocation.MyCommand.Path
} 




$VerboseLogging = "true"

$LogFileName="GetAzureAD_DR_Devices.log"
#write-host $LogFileName
[bool]$Global:Verbose = [System.Convert]::ToBoolean($VerboseLogging)
$Global:LogFile = Join-Path (GetScriptDirectory) $LogFileName
$Global:PasswordFile = Join-Path (GetScriptDirectory) PWD_ServiceAccount.txt
$Global:CSVFile = Join-Path (GetScriptDirectory) AzureAD_DR_Devices.csv
$Global:MaxLogSizeInKB = 10240
$Global:ScriptName = 'GetAzureAD_DR_Devices.ps1' 
$Global:ScriptStatus = 'Success'
$Global:Results = 0
$Global:AzureDRCount = 0
$Global:AzureNoDRCount = 0
$Global:AzureSRVDRCount = 0
$Username = "ServiceAccount@Company.com"
#$Password = Get-Content .\PWD_ServiceAccount.txt | ConvertTo-SecureString
$Password = Get-Content $PasswordFile | ConvertTo-SecureString

#$password = "SecretPassword"

$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password

#Import SCCM Module

$SCCMModulePath="C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"

$getModuleResults = Get-Module
$SCCMModuleImported=0
$MSOnlineModuleImported=0
$getModuleResults | ForEach-Object {If ($_.Name -eq "ConfigurationManager"){
                                                                            LogIt -message ("ConfigurationManager Module is imported") -component "Main()" -type 1
                                                                            $SCCMModuleImported=1
                                                                            }}
                            
$getModuleResults | ForEach-Object {If ($_.Name -eq "msonlie"){
                                                                            LogIt -message ("MSONLINE Module is imported") -component "Main()" -type 1
                                                                            $MSOnlineModuleImported=1
                                                                            }}

If($SCCMModuleImported -eq 0)
    {
    LogIt -message ("No SCCM modules are imported, import " + $SCCMModulePath) -component "Main()" -type 1
    
    Try
    {
    Import-Module $SCCMModulePath -verbose #-ErrorAction SilentlyContinue
    }
    Catch
    {

    LogIt -message ("unable to import SCCM modules " + $SCCMModulePath +" Error: " + $error[0].Exception) -component "Main()" -type 1
    }
    
    }

#Import MSONline module

If($MSOnlineModuleImported -eq 0)
    {
    LogIt -message ("No MSOnline modules are imported, import" ) -component "Main()" -type 1
    
    Try
    {
    import-module msonline
    }
    Catch
    {

    LogIt -message ("unable to import MSOnline module, Error: " + $error[0].Exception) -component "Main()" -type 1
    }
    
    }

logit -message ("Connect to MSOnline") -component "Main()" -type 1

Connect-MsolService –Credential $Cred #$LiveCred

logit -message ("Get all Domain Joined devices in Azure") -component "Main()" -type 1
$AzureDevices = @{}
$AzureDevices = Get-MsolDevice -All | Where-Object {$_.DeviceTrustType -eq "Domain Joined"} | select displayname | Out-String #-Stream #Get-MsolDevice -Name $SCCMDevice.name -ErrorAction SilentlyContinue

logit -message ($AzureDevices.count) -component "Main()" -type 1

logit -message ("Connect to SCCM Server SRV01") -component "Main()" -type 1

#CSV Header
$Results = "Computername,DeviceOS,LastActiveTime,AzureJoined`n"

CD Q01:


$SCCMDevices= ""
$SCCMDevices = Get-CMDevice | Where-Object {$_.ClientActiveStatus -eq 1} | select Name,DeviceOS,LastActiveTime

logit -message ("Found " + $SCCMDevices.count + " in SCCM") -component "Main()" -type 1

foreach ($SCCMDevice in $SCCMDevices)

{

If ($AzureDevices.contains($SCCMDevice.name))

{
#logit -message ("Node : " + $SCCMDevice.name + " OS : " + $SCCMDevice.Deviceos + " LastActiveTime : "+ $SCCMDevice.LastActiveTime + " Managed : Yes") -component "Main()" -type 1
$Results += $SCCMDevice.name +"," + $SCCMDevice.Deviceos +"," + $SCCMDevice.LastActiveTime +",Yes`n"
If($SCCMDevice.Deviceos.contains("Server"))
{

$AzureSRVDRCount += 1
}
else
{
$AzureDRCount += 1
}
}
else
{
#logit -message ("Node : " + $SCCMDevice.name + " OS : " + $SCCMDevice.Deviceos + " LastActiveTime : "+ $SCCMDevice.LastActiveTime + " - Unable to find the node in Azure") -component "Main()" -type 2
$Results += $SCCMDevice.name +"," + $SCCMDevice.Deviceos +"," + $SCCMDevice.LastActiveTime +",No`n"
If($SCCMDevice.Deviceos.contains("Server"))
{

$AzureNoSRVDRCount += 1
}
else
{
$AzureNoDRCount += 1
}
}



}

logit -message ("Connect to SCCM Server SRV01") -component "Main()" -type 1
CD SRV01:


$SCCMDevices= ""
$SCCMDevices = Get-CMDevice | Where-Object {$_.ClientActiveStatus -eq 1} | select Name,DeviceOS,LastActiveTime

logit -message ("Found " + $SCCMDevices.count + " in SCCM") -component "Main()" -type 1

foreach ($SCCMDevice in $SCCMDevices)

{

If ($AzureDevices.contains($SCCMDevice.name))

{
#logit -message ("Node : " + $SCCMDevice.name + " OS : " + $SCCMDevice.Deviceos + " LastActiveTime : "+ $SCCMDevice.LastActiveTime + " Managed : Yes") -component "Main()" -type 1
$Results += $SCCMDevice.name +"," + $SCCMDevice.Deviceos +"," + $SCCMDevice.LastActiveTime +",Yes`n"
If($SCCMDevice.Deviceos.contains("Server"))
{
$AzureSRVDRCount += 1
}
else
{
$AzureDRCount += 1
}

}
else
{
#logit -message ("Node : " + $SCCMDevice.name + " OS : " + $SCCMDevice.Deviceos + " LastActiveTime : "+ $SCCMDevice.LastActiveTime + " - Unable to find the node in Azure") -component "Main()" -type 2
$Results += $SCCMDevice.name +"," + $SCCMDevice.Deviceos +"," + $SCCMDevice.LastActiveTime +",No`n"
If($SCCMDevice.Deviceos.contains("Server"))
{
$AzureNoSRVDRCount += 1
}
else
{
$AzureNoDRCount += 1
}
}



}



logit -message ("Azure Deviceregistration Count : WKS Not Joined = $AzureNoDRCount , SRV Not Joined = $AzureNoSRVDRCount" ) -component "Main()" -type 2
logit -message ("Azure Deviceregistration Count : WKS Joined = $AzureDRCount , SRV Joined = $AzureSRVDRCount" ) -component "Main()" -type 1
Remove-Item $CSVFile -Confirm:$false -Force
$Results | Add-Content -Path $CSVFile
