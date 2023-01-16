$ConnectionString = Get-VstsInput -Name ConnectionString
$ForceTls12 = Get-VstsInput -Name ForceTls12

& pwsh ./ConnectMongoDb.ps1 -ConnectionString $ConnectionString -ForceTls12 $ForceTls12