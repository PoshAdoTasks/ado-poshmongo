$DatabaseName = Get-VstsInput -Name DatabaseName
$CollectionName = Get-VstsInput -Name CollectionName
$DocumentId = Get-VstsInput -Name DocumentId

& pwsh ./GetMongoDBDOcument.ps1 -DatabaseName $DatabaseName -CollectionName $CollectionName -DocumentId $DocumentId