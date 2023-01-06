$script:WorkingDir = $PSScriptRoot;
$script:GithubRepo = 'ado-taskname'
$script:TaskName = $script:GithubRepo.Replace('-', '')
$script:Description = 'An Azure DevOps PowerShell Task'
$script:Author = 'Jeffrey S. Patton'
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
