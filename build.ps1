param(
	[Int32]$BuildNumber=0,
	[String]$BuildConfiguration="Debug",
	[String]$BranchName="localBuild",
	[String]$GitCommitHash="unknownHash",
	[Switch]$IsMainBranch=$False
)

cls

#'[p]sake is the same as psake but no error propagation s
Remove-Module [p]sake

Import-Module .\packages\psake.*\tools\psake.psm1

Invoke-psake -buildFile .\Build\default.ps1 `
			 -taskList Clean `
			 -framework 4.5.1 `
			 -properties @{ 
				 "buildConfiguration" = $BuildConfiguration
				 "buildPlatform" = "Any CPU" } `
			 -parameters @{ 
				 "SolutionFile" = "..\B2BPlatform.sln"
				 "BuildNumber" = $BuildNumber
				 "BranchName" = $BranchName
				 "GitCommitHash" = $GitCommitHash
				 "IsMainBranch" = $IsMainBranch
			 }


Write-Host "Build exit code: $LastExitCode" 

exit $LastExitCode