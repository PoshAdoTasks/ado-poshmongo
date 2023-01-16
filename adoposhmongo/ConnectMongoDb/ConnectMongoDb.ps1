[CmdletBinding()]
param(
 [string]$ConnectionString,
 [string]$ForceTls12
)

try {
 $ErrorActionPreference = 'Stop';
 $Error.Clear();

 Import-Module .\ps_modules\VstsTaskSdk\VstsTaskSdk.psd1-Verbose:$VerbosePreference;

 Trace-VstsEnteringInvocation $MyInvocation;

 Write-Host "ConnectionString : $($ConnectionString)"
 Write-Host "ForceTls12       : $($ForceTls12)"

 Import-Module PoshMongo

 Connect-MongoDBInstance -ConnectionString $ConnectionString -ForceTls12 $ForceTls12 -Verbose:$VerbosePreference;
}
catch {
 throw $_;
}
finally {
 Trace-VstsLeavingInvocation $MyInvocation
}