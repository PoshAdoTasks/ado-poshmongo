[CmdletBinding()]
param()

[string]$DatabaseName = Get-VstsInput -Name DatabaseName
[string]$CollectionName = Get-VstsInput -Name CollectionName
[string]$DocumentId = Get-VstsInput -Name DocumentId

Trace-VstsEnteringInvocation $MyInvocation;

Write-Host "DatabaseName   : $($DatabaseName)"
Write-Host "CollectionName : $($CollectionName)"
Write-Host "DocumentId     : $($DocumentId)"