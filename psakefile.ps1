$script:WorkingDir = $PSScriptRoot;
$script:MarketplaceUrl = "https://marketplace.visualstudio.com/items?itemName"

if (Get-Module -ListAvailable | Where-Object -Property Name -eq 'PoshAdoTask') {
 if (!(Get-Module PoshAdoTask)) {
  Import-Module PoshAdoTask -Force;
 }
}
else {
 Install-Module PoshAdoTask -Scope CurrentUser -AllowClobber -Force
 Import-Module PoshAdoTask -Force;
}

Task SetupProject -depends Clean, CreateProject, AddVstsTaskSdk, SetupTfx

Task CreateProject {
 #
 # Read in metadata
 #
 $Meta = Get-Content "$($script:WorkingDir)\metadata.json" | ConvertFrom-Json;
 #
 # Create Project Folder
 #
 if (Test-Path $Meta.Project.ExtensionName) {
  $ProjectDir = Get-Item -Path $Meta.Project.ExtensionName;
 }
 else {
  $ProjectDir = New-Item -Name $Meta.Project.ExtensionName -ItemType Directory;
 }
 #
 # Create Manifest
 #
 $Manifest = New-Manifest -Id $Meta.Manifest.Id -Version $Meta.Manifest.Version -Name $Meta.Manifest.Name -Publisher $Meta.Manifest.Publisher -Description $Meta.Manifest.Description -ManifestVersion $Meta.Manifest.ManifestVersion;
 switch ($Meta.Manifest.Category) {
  "AzurePipelines" {
   $Manifest | Set-Category -AzurePipelines;
  }
 }
 #
 # Define details (overview.md and LICENSE required for public)
 #
 if ((Test-Path -Path "$($script:WorkingDir)\overview.md") -and (Test-Path -Path "$($script:WorkingDir)\LICENSE")) {
  $Manifest.Content = New-Content -Details 'overview.md' -License 'LICENSE';
 }
 #
 # Add Repository
 #
 $Manifest.Repository = New-Repository -Type Git -Url $Meta.Project.GithubUrl
 #
 # Create links
 #
 $Manifest.Links = New-Link -GetStarted "$($Meta.Project.GithubUrl)/blob/main/README.md" -License "$($Meta.Project.GithubUrl)/blob/main/LICENSE" -Support "$($Meta.Project.GithubUrl)/issues";
 #
 # Create extension file
 #
 $Manifest | Out-Manifest | Out-File -FilePath "$($script:WorkingDir)\vss-extension.json" -Force
 foreach ($t in $Meta.Manifest.Tasks) {
  #
  # Create Task Folder
  #
  if (Test-Path -Path "$($ProjectDir.FullName)\$($t.Name)") {
   $TaskFolder = Get-Item -Path "$($ProjectDir.FullName)\$($t.Name)";
  }
  else {
   $TaskFolder = New-Item -Path "$($ProjectDir.FullName)\$($t.Name)" -ItemType Directory;
  }
  #
  # Create Task
  #
  if (!(Test-Path "$($TaskFolder.FullName)\task-id.json")) { [System.Guid]::NewGuid() | Select-Object -Property Guid | ConvertTo-Json | Out-File -FilePath "$($TaskFolder.FullName)\task-version.json" }
  $TaskId = (Get-Content -Path "$($TaskFolder.FullName)\task-id.json" | ConvertFrom-Json).Guid
  $Task = New-Task -Id $TaskId -Name $t.Name -FriendlyName $t.FriendlyName -Description $t.Description -Author $t.Author -Version $t.Version;
  $Task.HelpMarkDown = $t.HelpMarkDown,
  $Task.MinimumAgentVersion = '1.95.0';
  $Task | Set-Category -Utility;
  $Task | New-Execution -Execution 'PowerShell3' -Target "$($t.Name).ps1";
  $Task | Set-Visibility -Build -Release;
  New-Item -Path "$($TaskFolder.FullName)\$($t.Name).ps1" -Force;
  #
  # Update Manifest with Tasks
  #
  $Manifest = Get-Manifest -Path "$($script:WorkingDir)\vss-extension.json";
  #
  # Add Files for Tasks
  #
  $Manifest | Add-File -Path "$($ProjectDir.BaseName)/$($TaskFolder.BaseName)";
  #
  # Add Task Contributions
  #
  $Manifest | Add-Contribution -Id "$($Meta.Manifest.Id)-$($t.Name)" -Type "ms.vss-distributed-task.task" -Name "$($Meta.Project.ExtensionName)/$($t.Name.ToLower())";
  $Manifest | Out-Manifest | Out-File -FilePath "$($script:WorkingDir)\vss-extension.json" -Force;
  foreach ($i in $t.Inputs) {
   #
   # Create Inputs
   #
   $Task | Add-Input -Name $i.Name -Type $i.Type -Label $i.Label -Required:$i.Required -HelpMarkDown $i.HelpMarkDown;
  }
  $Task | Out-Task | Out-File "$($TaskFolder.FullName)\task.json" -Force;
 }
}

Task AddVstsTaskSdk {
 $Meta = Get-Content "$($script:WorkingDir)\metadata.json" | ConvertFrom-Json;
 $TaskFolder = Get-Item "$($Meta.Project.ExtensionName)"
 Save-Module –Name VstsTaskSdk –Path "$($TaskFolder.FullName)\ps_modules" –Force;
 Set-Location "$($TaskFolder.FullName)\ps_modules\VstsTaskSdk";
 $VstsTaskSdkDirectory = (Get-Item .).FullName;
 $VersionDirectory = (Get-Item .).GetDirectories().FullName;
 Move-Item "$($VersionDirectory)\*" $VstsTaskSdkDirectory -Verbose
 Remove-Item $VersionDirectory -Recurse -Force;
}

Task TogglePublic {
 $Manifest = Get-Manifest -Path "$($script:WorkingDir)\vss-extension.json";
 if ($Manifest.Public -eq $true) {
  $Manifest.Public = $false;
  Write-Output "Extension is now Private"
 }
 else {
  $Manifest.Public = $true;
  Write-Output "Extension is now Public"
 }
 $Manifest | Out-Manifest | Out-File -FilePath "$($script:WorkingDir)\vss-extension.json" -Force
}

Task clean {
 Remove-Item "$($script:WorkingDir)\Output" -Recurse -ErrorAction Ignore;
 New-Item -Name "Output" -ItemType Directory -Force;
}

Task SetupTfx {
 npm install -g tfx-cli
}

Task CreatePackage -depends Clean {
 tfx extension create --manifest-globs "$($script:WorkingDir)\vss-extension.json" --output-path "$($script:WorkingDir)\Output" --no-prompt
}

Task PublishExtension {
 $Manifest = Get-Manifest -Path "$($script:WorkingDir)\vss-extension.json";
 $Token = Get-Content "$($script:WorkingDir)\ado.token" | ConvertFrom-Json;
 $OutputFolder = Get-Item -Path "$($script:WorkingDir)\Output";
 $VisxFile = Get-ChildItem -Path $OutputFolder | Where-Object -Property BaseName -Contains $Manifest.Version;
 tfx extension publish --vsix $VisxFile.FullName --token $Token.PAT --json --no-prompt
}

Task NewTaggedRelease -Description "Create a tagged release" -Action {
 $Meta = Get-Content "$($script:WorkingDir)\metadata.json" | ConvertFrom-Json;
 $Version = Get-Content "$($script:WorkingDir)\vss-extension.json" | ConvertFrom-Json | Select-Object -ExpandProperty Version
 git tag -a v$version -m "$($Meta.Project.ExtensionName) Version $($Version)"
 git push origin v$version
}

Task Post2Discord -Description "Post a message to discord" -Action {
 $Meta = Get-Content "$($script:WorkingDir)\metadata.json" | ConvertFrom-Json;
 $version = Get-Content "$($script:WorkingDir)\vss-extension.json" | ConvertFrom-Json | Select-Object -ExpandProperty Version
 $Discord = Get-Content .\discord.poshmongo | ConvertFrom-Json
 $Discord.message.content = "Version $($version) of $($Meta.Project.ExtensionName) released. Please visit Github ($($Meta.Project.GithubUrl)) or the MarketPlace ($($script:MarketplaceUrl)=$($Meta.Manifest.Publisher).$($Meta.Project.ExtensionName)) to download."
 Invoke-RestMethod -Uri $Discord.uri -Body ($Discord.message | ConvertTo-Json -Compress) -Method Post -ContentType 'application/json; charset=UTF-8'
}
