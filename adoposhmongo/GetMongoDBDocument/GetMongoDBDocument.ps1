[CmdletBinding()]
param(
 [string]$DatabaseName,
 [string]$CollectionName,
 [string]$DocumentId
)

try {
 Trace-VstsEnteringInvocation $MyInvocation;

 $ErrorActionPreference = 'Stop';
 $Error.Clear();

 $DatabaseName = Get-VstsInput -Name DatabaseName
 $CollectionName = Get-VstsInput -Name CollectionName
 $DocumentId = Get-VstsInput -Name DocumentId

 Write-Host "DatabaseName   : $($DatabaseName)"
 Write-Host "CollectionName : $($CollectionName)"
 Write-Host "DocumentId     : $($DocumentId)"

 Import-Module PoshMongo

 $jsonDocument = Get-MongoDBDocument -DatabaseName $DatabaseName -CollectionName $CollectionName -DocumentId $DocumentId -Verbose:$VerbosePreference;

 Write-Host $jsonDocument;
}
catch {
 throw $_;
}
finally {
 Trace-VstsLeavingInvocation $MyInvocation
}