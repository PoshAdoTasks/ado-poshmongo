$ConnectionString = Get-VstsInput -Name ConnectionString
$ForceTls12 = Get-VstsInput -Name ForceTls12

& pwsh ./GetMongoDBDOcument.ps1 -DatabaseName $ConnectionString -CollectionName $ForceTls12