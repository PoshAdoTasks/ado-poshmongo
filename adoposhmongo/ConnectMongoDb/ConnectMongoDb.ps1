[CmdletBinding()]
param(
 [string]$ConnectionString,
 [string]$ForceTls12
)

try {
 $ErrorActionPreference = 'Stop';
 $Error.Clear();

 Import-Module .\ps_modules\VstsTaskSdk\VstsTaskSdk.psd1 -Verbose:$VerbosePreference;

 $NewConnection = [System.Uri]::new($ConnectionString);

 Trace-VstsEnteringInvocation $MyInvocation;

 Write-Host "ConnectionString : $($NewConnection.Scheme)"
 Write-Host "ForceTls12       : $($ForceTls12)"

 Import-Module PoshMongo

 if ($ForceTls12.ToLower() -eq 'true')
 {
  $Client = Connect-MongoDBInstance -ConnectionString $NewConnection.AbsoluteUri -ForceTls12 -Verbose:$VerbosePreference;
 } else
 {
  $Client = Connect-MongoDBInstance -ConnectionString $NewConnection.AbsoluteUri -Verbose:$VerbosePreference;
 }
 $Client
 Write-Host "##vso[task.setvariable variable=Client;]$($Client)"
}
catch {
 throw $_;
}
finally {
 Trace-VstsLeavingInvocation $MyInvocation
}