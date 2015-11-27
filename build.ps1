cls

#'[p]sake is the same as psake but no error propagation
Remove-Module [p]sake

Import-Module .\packages\psake.*\tools\psake.psm1

Invoke-psake -buildFile .\Build\default.ps1 `
			 -taskList Test `
			 -framework 4.6 `
			 -properties @{ 
				 "buildConfiguration" = "Release"
				 "buildPlatform" = "Any CPU" } `
			 -parameters @{ 
				 "SolutionFile" = "..\psake.sln" }


Write-Host "Build exit code: $LastExitCode" 

exit $LastExitCode