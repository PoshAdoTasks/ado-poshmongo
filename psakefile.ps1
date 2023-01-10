$script:WorkingDir = $PSScriptRoot;
$script:GithubRepo = 'ado-poshmongo'
$script:FriendlyName = "ADO PoshMongo"
$script:Description = 'An Azure DevOps extension for working with MongoDB'
$script:Version = "1.0.0"
$script:TaskName = $script:GithubRepo.Replace('-', '')
$script:Author = 'Jeffrey S. Patton'
$script:Publisher = "pattontech"
$script:GithubUrl = "https://github.com/PoshAdoTasks/$($script:GithubRepo)"
$script:MarketplaceUrl = "https://marketplace.visualstudio.com/items?itemName=pattontech.$($script:TaskName)"

Task CreateAdoTask -depends Clean, SetupTfx, AddVstsTaskSdk, UpdateVssExtension

Task clean {
 Remove-Item "$($script:WorkingDir)\Output" -Recurse -ErrorAction Ignore;
 New-Item -Name "Output" -ItemType Directory -Force;
}

Task UpdateVssExtension -Action {
 $vssExtension = Get-Content "$($script:WorkingDir)\vss-extension.json" | ConvertFrom-Json;
 $vssExtension.links.getstarted.uri = "$($script:GithubUrl)/blob/main/README.md";
 $vssExtension.links.getstarted.uri = "$($script:GithubUrl)/blob/main/LICENSE";
 $vssExtension.links.getstarted.uri = "$($script:GithubUrl)/issues";
 $vssExtension.repository.uri = "$($script:GithubUrl)";
 $vssExtension | ConvertTo-Json -Depth 10 | Out-File "$($script:WorkingDir)\vss-extension.json" -Force
}

Task NewExtensionManifest {
 #
 # Import poshadotask
 #
 $Manifest = New-Manifest -Id $script:TaskName -Version $script:Version -Name $script:FriendlyName -Publisher $script:Publisher -Description $script:Description;
 $Manifest | Set-Category -AzurePipelines;
 $Manifest | Add-File -Path $script:TaskName;
 $Manifest.Content = New-Content -Details 'overview.md' -License 'LICENSE';
 $Manifest.Links = New-Link -GetStarted "$($script:GithubUrl)/blob/main/README.md" -License "$($script:GithubUrl)/blob/main/LICENSE" -Support "$($script:GithubUrl)/issues";
 $Manifest.Repository = New-Repository -Type Git -Url "$($script:GithubUrl)";
 $Manifest | Add-Contribution -Id $script:TaskName -Type "ms.vss-distributed-task.task";
 $Manifest | Out-Manifest | Out-File vss-extension.json -Force
}

Task NewTask {
 #
 # Import poshadotask
 #
 $Manifest = Get-Manifest (Get-Item .\vss-extension.json).FullName;
 if (!(Test-Path .\task-version.json)) { [System.Guid]::NewGuid() | Select-Object -Property Guid | ConvertTo-Json | Out-File task-version.json }
 if (!(Test-Path $Manifest.Id)) { New-Item -Name $Manifest.Id -ItemType Directory }
 $Task = New-Task -Id (Get-Content .\task-version.json | ConvertFrom-Json).Guid -Name $script:TaskName -FriendlyName $script:FriendlyName -Description $script:Description -Author $script:Author -Version $script:Version;
 $Task.HelpMarkdown = "If you have any issues, please create an issue ($($($script:GithubUrl))/issues)";
 $Task.MinimumAgentVersion = '1.95.0';
 $Task | Set-Category -Utility;
 $Task | New-Execution -Execution 'PowerShell3' -Target "$($script:TaskName).ps1";
 $Task | Set-Visibility -Build -Release;
 $Task | Out-Task | Out-File ".\$($script:TaskName)\task.json" -Force
}

Task UpdateTask {
 #
 # Import poshadotask
 #
 $Task = Get-Task (Get-Item ".\$($script:TaskName)\task.json")
 $Task | Add-Input -Name "Name" -Type string -Label "Name Value" -Required -HelpMarkDown "Prove a name for this item"
 $Task | Out-Task | Out-File ".\$($script:TaskName)\task.json" -Force
}
Task SetupTfx {
 npm install -g tfx-cli
}

Task SetupTask {
 tfx build tasks create --task-name $script:TaskName --friendly-name $script:TaskName --description $script:Description --author $script:Author
}

Task AddVstsTaskSdk -depends SetupTask {
 Save-Module –Name VstsTaskSdk –Path ".\$($script:TaskName)\ps_modules" –Force;
 Set-Location ".\$($script:TaskName)\ps_modules\VstsTaskSdk";
 $VstsTaskSdkDirectory = (Get-Item .).FullName;
 $VersionDirectory = (Get-Item .).GetDirectories().FullName;
 Write-Output $VstsTaskSdkDirectory
 Write-Output $VersionDirectory
 Move-Item "$($VersionDirectory)\*" $VstsTaskSdkDirectory -Verbose
 Remove-Item $VersionDirectory -Recurse -Force;
}

Task CreatePackage -depends Clean {
 tfx extension create --manifest-globs vss-extension.json --output-path "$($script:WorkingDir)\Output"
}

Task NewTaggedRelease -Description "Create a tagged release" -Action {
 $Version = Get-Content "$($script:WorkingDir)\vss-extension.json" | ConvertFrom-Json | Select-Object -ExpandProperty Version
 git tag -a v$version -m "$($script:TaskName) Version $($Version)"
 git push origin v$version
}

Task Post2Discord -Description "Post a message to discord" -Action {
 $version = Get-Content "$($script:WorkingDir)\vss-extension.json" | ConvertFrom-Json | Select-Object -ExpandProperty Version
 $Discord = Get-Content .\discord.poshmongo | ConvertFrom-Json
 $Discord.message.content = "Version $($version) of $($script:TaskName) released. Please visit Github ($script:GithubUrl) or the MarketPlace ($script:MarketplaceUrl) to download."
 Invoke-RestMethod -Uri $Discord.uri -Body ($Discord.message | ConvertTo-Json -Compress) -Method Post -ContentType 'application/json; charset=UTF-8'
}
