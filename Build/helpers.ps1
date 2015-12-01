function Find-PackagePath
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=1)]$packagePath,
		[Parameter(Position=1, Mandatory=1)]$packageName
	)

	return (Get-ChildItem("$packagePath\$packageName*")).FullName | Sort-Object $_ | select -Last 1
}

function Prepare-Tests 
{
	param(
		[Parameter(Position=0, Mandatory=1)]$testRunnerName,
		[Parameter(Position=1, Mandatory=1)]$publishedTestDirectory,
		[Parameter(Position=2, Mandatory=1)]$testResultsDirectory,
		[Parameter(Position=3, Mandatory=1)]$testCoverageDirectory
	)

	$projects = Get-ChildItem $publishedTestDirectory

	if($projects.Count -eq 1) 
	{
		Write-Host "1 $testRunnerName project was found: "
	}
	else 
	{
		Write-Host "$projects.Count $testRunnerName projects were found: "
	}

	Write-Host ($projects | select $_.Name)

	#Create the test results directory if needed
	if(!(Test-Path $testResultsDirectory))
	{
		Write-Host "Create test result directory located at $testResultsDirectory"
		mkdir $testResultsDirectory | Out-Null
	}

	#Create the test coverage directory if needed
	if(!(Test-Path $testCoverageDirectory))
	{
		Write-Host "Create test coverage directory located at $testCoverageDirectory"
		mkdir $testCoverageDirectory | Out-Null
	}

	#Get the list of test DLLs
	$testAssembliesPath = $projects | ForEach-Object { 
		"`"`"" + $_.FullName + "\bin\" + $_.Name + ".dll`"`""
	}

	$testAssemblies = [string]::Join(" ", $testAssembliesPath)

	return $testAssemblies
}

function Run-Tests
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=1)]$openCoverExe,
		[Parameter(Position=1, Mandatory=1)]$targetExe,
		[Parameter(Position=2, Mandatory=1)]$targetArgs,
		[Parameter(Position=3, Mandatory=1)]$coveragePath,
		[Parameter(Position=4, Mandatory=1)]$filter,
		[Parameter(Position=5, Mandatory=1)]$excludeByAttribute,
		[Parameter(Position=6, Mandatory=1)]$excludeByFile
	)

	Write-Host "Running tests"

	Exec { &$openCoverExe -target:$targetExe `
						  -targetargs:$targetArgs `
						  -output:$coveragePath `
						  -register:user `
						  -filter:$filter `
						  -excludebyattribute:$excludeByAttribute `
						  -excludebyfile:$excludeByFile `
						  -skipautoprops `
						  -mergebyhash `
						  -mergeoutput `
						  -hideskipped:All `
						  -returntargetcode }
}