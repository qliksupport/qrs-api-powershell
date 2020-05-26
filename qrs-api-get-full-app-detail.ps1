<#
    
    .DESCRIPTION
    This script calls QRS APIs to a Qlik Sense central node to extract appobjects for an app. The results are then written to JSON files. 
​
    .PARAMETER  FQDN
    Hostname to Qlik Sense central node, towards which QRS API call is execute to.  
​
    .PARAMETER  UserName
    User to be impersonated during QRS API call. Note, API call result reflects the user's authorized access right.
​
    .PARAMETER  UserDomain
    Domain that user belongs to in Qlik Sense user list. 
​
    .PARAMETER  CertIssuer
    Hostname used to sign the Qlik Sense CA certificate
​
    .PARAMETER  AppIds
    Comma separate list of App IDs to extract full detail for 

    .PARAMETER  Output
    Folder to store JSON exports in
​
    .EXAMPLE
    C:\PS> .\qrs-powershell-full-app.ps1 -AppId 4812958e-15fc-49b6-b7bd-7f450f444192
​
    .EXAMPLE
    C:\PS> .\qrs-powershell-full-app.ps1 -UserName User1 -UserDomain Domain
​
    .EXAMPLE
    C:\PS> .\qrs-powershell-full-app.ps1 -UserName User1 -UserDomain Domain -FQDN qilk.domain.local
​
    .NOTES
    This script is provided "AS IS", without any warranty, under the MIT License. 
    Copyright (c) 2020 
#>
​
# Paramters for REST API call
# Default to node where script is executed and the executing user
param (
    [Parameter()]
    [string] $UserName   = $env:USERNAME, 
    [Parameter()]
    [string] $UserDomain = $env:USERDOMAIN,
    [Parameter()]
    [string] $FQDN       = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname, 
    [Parameter()]
    [string] $CertIssuer = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname,
    [Parameter()]
    [string] $Output     = $PSScriptRoot,
    [Parameter(Mandatory=$true)]
    [string[]] $AppIds
)
​
# Qlik Sense client certificate to be used for connection authentication
# Note, certificate lookup must return only one certificate. 
$ClientCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Issuer -like "*$($CertIssuer)*"}
​
# Timestamp for output files
$ScriptTime = Get-Date -Format "ddMMyyyyHHmmss"
​
# Only continue if one unique client cert was found 
if (($ClientCert | measure-object).count -ne 1) { 
    Write-Host "Failed. Could not find one unique certificate." -ForegroundColor Red
    Exit 
}
​
# 16 character Xrefkey to use for QRS API call
# Reference XrfKey; https://help.qlik.com/en-US/sense-developer/Subsystems/RepositoryServiceAPI/Content/Sense_RepositoryServiceAPI/RepositoryServiceAPI-Connect-API-Using-Xrfkey-Headers.htm
$XrfKey = "hfFOdh87fD98f7sf"
​
# HTTP headers to be used in REST API call
$HttpHeaders = @{}
$HttpHeaders.Add("X-Qlik-Xrfkey","$XrfKey")
$HttpHeaders.Add("X-Qlik-User", "UserDirectory=$UserDomain;UserId=$UserName")
$HttpHeaders.Add("Content-Type", "application/json")
​
# HTTP body for REST API call
$HttpBody = @{}

# PRint confirming output in the host prompt
Write-Host -ForegroundColor Green `
"QRS: $FQDN 
User: $UserDomain\$UserName"
​
# Request detail for each AppID
foreach ($AppId in $AppIds) {

    $FileAppDetails      = "$Output\QRS_App_$AppId`_$ScriptTime.json"
    ​
    # Invoke REST API call - QRS/App/{AppID}/full - app details - get all app objects    ​
    Invoke-RestMethod -Uri "https://$($FQDN):4242/qrs/app/$($AppId)/open/full?xrfkey=$($xrfkey)" `
                    -Method GET `
                    -Headers $HttpHeaders  `
                    -Body $HttpBody `
                    -ContentType 'application/json' `
                    -Certificate $ClientCert | `
    ConvertTo-Json -Depth 10 | `
    Out-File -FilePath $FileAppDetails
​
    # Print confirming output in the host prompt
    Write-Host -ForegroundColor Green "$AppId exported to $FileAppDetails"

}