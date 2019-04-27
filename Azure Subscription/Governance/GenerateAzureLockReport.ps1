#Written by Peter Selch Dahl - APENTO ApS - www.apento.com - Version 1.0

Login-AzureRmAccount


# Output Path
$outPath = "C:\temp\Reports"


$ReportTemplate = [pscustomobject][ordered]@{
    ResourceGroupName = $null
    LockState = $null

}

$cssStyle = '<style>body{background:#252525;font:87.5%/1.5em Lato,sans-serif;padding:20px}table{border-spacing:1px;border-collapse:collapse;background:#F7F6F6;border-radius:6px;overflow:hidden;max-width:800px;width:100%;margin:0 auto;position:relative}td,th{padding-left:8px}thead tr{height:60px;background:#367AB1;color:#F5F6FA;font-size:1.2em;font-weight:700;text-transform:uppercase}tbody tr{height:48px;border-bottom:1px solid #367AB1;text-transform:capitalize;font-size:1em;&:last-child {;border:0}tr:nth-child(even){background-color:#dae5f4;}tr:nth-child(odd){background:#b8d1f3;}</style>'



$acceptedReport = @()
foreach ($resourceGroup in $resourceGroups){


    $lock = Get-AzureRmResourceLock -ResourceGroupName $resourceGroup.ResourceGroupName
        if ($lock -eq $null){
            Write-Host  -foregroundcolor Red "$($resourceGroup.ResourceGroupName) is missing a lock"
              $Locked = $false
        }
            else 
        {
            Write-Host  -foregroundcolor Green "$($resourceGroup.ResourceGroupName) is locked"
            $Locked = $true
        }



    $aReport = $ReportTemplate.PsObject.Copy()

    $aReport.ResourceGroupName = $resourceGroup.ResourceGroupName
    $aReport.LockState =  $Locked 
    $acceptedReport += $aReport 
}

$acceptedReport | ConvertTo-Html -Body $cssStyle | Out-File "$($outPath)\AzureLockReport.html"

