[CmdletBinding()]
param(
 [string]$DatabaseName,
 [string]$CollectionName,
 [string]$DocumentId
)

try {
 $ErrorActionPreference = 'Stop';
 $Error.Clear();

 Import-Module .\ps_modules\VstsTaskSdk\VstsTaskSdk.psd1 -Verbose:$VerbosePreference;

 Trace-VstsEnteringInvocation $MyInvocation;

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