param(
	[Int32]$BuildNumber=0,
	[String]$BranchName="localBuild",
	[String]$GitCommitHash="unknownHash",
	[Switch]$IsMainBranch=$False
)

cls

#'[p]sake is the same as psake but no error propagation
Remove-Module [p]sake

Import-Module .\packages\psake.*\tools\psake.psm1

Invoke-psake -buildFile .\Build\default.ps1 `
			 -taskList Package `
			 -framework 4.6 `
			 -properties @{ 
				 "buildConfiguration" = "Release"
				 "buildPlatform" = "Any CPU" } `
			 -parameters @{ 
				 "SolutionFile" = "..\psake.sln"
				 "BuildNumber" = $BuildNumber
				 "BranchName" = $BranchName
				 "GitCommitHash" = $GitCommitHash
				 "IsMainBranch" = $IsMainBranch
			 }


Write-Host "Build exit code: $LastExitCode" 

exit $LastExitCode