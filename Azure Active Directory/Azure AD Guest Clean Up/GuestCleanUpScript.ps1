<#Connect as XXXXXX

Connect-AzureAD #$Cred
Connect-AzureRmAccount #$Cred 
#$signins = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId 7af40e4c-0969-4f2f-xxxx-5423a6b90026 -Query "SigninLogs | where TimeGenerated > datetime(2015-01-01) | where UserPrincipalName !contains 'arlafoods.com' | summarize max(CreatedDateTime) by UserId"
$signins = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId 7af40e4c-0969-4f2f-xxxx-5423a6b90026 -Query "SigninLogs | where TimeGenerated > datetime(2015-01-01) | where UserPrincipalName !contains 'arlafoods.com' | summarize max(CreatedDateTime) by UserId"
#>

$x = Get-Date
"**********************" | Out-File "d:\logs\B2B-usercleanup.log" -Append
$x | Out-File "d:\logs\B2B-usercleanup.log" -Append
"**********************" | Out-File "d:\logs\B2B-usercleanup.log" -Append

$signins = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId 7af40e4c-0969-4f2f-a022-5423a6b90026 -Query "SigninLogs | where TimeGenerated > datetime(2015-01-01) | where UserPrincipalName !contains 'domain.com' | summarize max(CreatedDateTime) by UserId"
$gid = Get-AzureADGroup -SearchString "AADB2B-WhiteList"
$whiteList = Get-AzureADGroupMember -All $true -ObjectId $gid.ObjectId

If ($Signins) {
    $Filter = "UserType eq 'Guest'"
    $Guests = Get-AzureADUser -all $True -Filter $Filter | Select-Object Objectid, userprincipalname,mail,RefreshTokensValidFromDateTime,accountenabled,ExtensionProperty | where accountenabled -eq $True
    Foreach ($User in $Guests) {
        If ($whiteList.UserPrincipalName -notcontains $user.UserPrincipalName) {
            try {
                $lastSignin = ([DateTime]::Parse(($signins.Results | Where-Object { $_.UserId  -eq $user.ObjectId })[0].max_CreatedDateTime))
            } catch {
                $lastSignin = $null
            }

            try {
                $extension = $User | Select -ExpandProperty ExtensionProperty
                $createdDatetime = ([DateTime]::Parse($extension.createdDateTime))
            } catch {
                $createdDatetime = $null
            }

            If ($createdDatetime -le (Get-Date).AddDays(-90) -and ($lastSignin -le (Get-Date).AddDays(-90) -or $lastSignin -eq $null)) {
                "Time to cleanup: $($User.mail) : $($User.UserPrincipalName) : $($createdDatetime) : $($lastSignin)" | Out-File d:\logs\B2B-usercleanup.log -Append
                If ($($User.Mail)) {
                    Set-AzureADUser -ObjectId $User.ObjectId -AccountEnabled $false
                    $txt = "Your Domain Azure guest account has been disabled.`r`n`r`nThis is due to the fact that it has not been active within the past 90 days.`r`n`r`nIf you need to enable your account, you will need to contact the IT service desk.`r`nPlease note: Remember to log into your account within 24 hours of the enabling, otherwise your account will automatically be disabled again."
                    $mail = $User.mail
                    Send-MailMessage -From 'UserGovernance@domain.com' -To $mail -BCC User@domain.com -Subject 'Your domain Azure guest account has been disabled' -Body $txt  -Priority High -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer 'smtp.Domain.net' -Encoding UTF32
                }
                $c=$c+1
            }

        }
        Else {
            Write-host "$($User.mail) whitelisted - Skip"
            $w = $w +1
        } 
    }
}

Write-Host "Cleanup: $c - Whitelist: $w"


