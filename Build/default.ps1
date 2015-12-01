Include ".\helpers.ps1"

properties {
	$testMessage = 'Executed Test!'
	$compileMessage = 'Executed Compile!'
	$cleanMessage = 'Executed Clean!'

	$solutionDirectory = (Get-Item $SolutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$testCoverageDirectory = "$outputDirectory\TestCoverage"
	$testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
	$testCoverageFilter = "+[*]* -[*.NUnitTests]* -[*.Tests]*"
	$testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
	$testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"

	$packagesPath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagesPath "NUnit.Console") + "\tools\nunit3-console.exe"
	$OpenCoverExe = (Find-PackagePath $packagesPath "OpenCover") + "\tools\OpenCover.Console.exe"
	$ReportGeneratorExe = (Find-PackagePath $packagesPath "ReportGenerator") + "\tools\ReportGenerator.exe"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"
	

}

FormatTaskName "`r`n`r`n--------- Executing {0} Task ----------"

task default -depends Test

task Init -description 'Init thee build by removing previous artifacts and creating output directories' `
		  -requiredVariables outputDirectory, temporaryOutputDirectory {

	Assert -conditionToCheck ("Debug", "Release" -contains $buildConfiguration) `
		   -failureMessage "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'."

	Assert -conditionToCheck ("x86", "x64", "Any CPU" -contains $buildPlatform) `
		   -failureMessage "Invalid build platform '$buildPlatform'. Valid values are 'x86' or 'x64' or 'Any CPU'."

	#Check if all tools are available
	Write-Host "Check if all required tools are available"

	Assert -conditionToCheck (Test-Path $NUnitExe) `
		   -failureMessage "NUnit Console could not be found at $NUnitExe"

	Assert -conditionToCheck (Test-Path $OpenCoverExe) `
		   -failureMessage "OpenCover Console could not be found at $OpenCoverExe"

	Assert -conditionToCheck (Test-Path $ReportGeneratorExe) `
		   -failureMessage "ReportGenerator Console could not be found at $ReportGeneratorExe"

	#Removing previous build results
	if(Test-Path $outputDirectory) {
		Write-Host "Removing output directory located at $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
	}


	Write-Host "Creating output directory located at $outputDirectory"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temp directory located at $temporaryOutputDirectory"
	New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}

task Clean -description 'Remove temporary files' {
	Write-Host $cleanMessage
}

task Compile -depends Init `
			 -description 'Compile the code' `
			 -requiredVariables SolutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory {
	Write-Host "Building solution $SolutionFile"

	Exec {
		msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory" | Out-Null
	}
}



task TestNUnit -depends Compile `
			   -description 'Run NUnit tests' `
			   -precondition { return Test-Path  $publishedNUnitTestsDirectory } `
{
	$testAssemblies = Prepare-Tests -testRunnerName:"NUnit" `
									-publishedTestDirectory:$publishedNUnitTestsDirectory `
									-testResultsDirectory:$NUnitTestResultsDirectory `
									-testCoverageDirectory:$testCoverageDirectory

	Write-Host "Test assemblies: $testAssemblies"

	$targetArgs = "$testAssemblies /result:`"`"$NUnitTestResultsDirectory\NUnit.xml`"`""

	Run-Tests -openCoverExe:$OpenCoverExe `
			  -targetExe:$NUnitExe `
			  -targetArgs:$targetArgs `
			  -coveragePath:$testCoverageReportPath `
			  -filter:$testCoverageFilter `
			  -excludeByAttribute:$testCoverageExcludeByAttribute `
			  -excludeByFile:$testCoverageExcludeByFile

}

task Test -depends Compile, TestNUnit `
		  -description 'Run unit tests' `
{

	if(Test-Path $testCoverageReportPath) 
	{
		#Generate HTML test coverage report
		Write-Host "`r`nGenerating HTML test coverage report"

		Exec { &$ReportGeneratorExe $testCoverageReportPath $testCoverageDirectory }

		#Parse OpenCover report
		Write-Host "Parsing OpenCover report"

		$coverage = [xml](Get-Content -Path $testCoverageReportPath)
		$coverageSummary = $coverage.CoverageSession.Summary

		#Write class coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N0}']" -f(($coverageSummary.visitedClasses / $coverageSummary.numClasses) * 100))

		#Write method coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N0}']" -f(($coverageSummary.visitedMethods / $coverageSummary.numMethods) * 100))

		#Write branch coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBCovered' value='$($coverageSummary.visitedBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBTotal' value='$($coverageSummary.numBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageB' value='$($coverageSummary.branchCoverage)']"

		#Write sequence point coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSCovered' value='$($coverageSummary.visitedSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSTotal' value='$($coverageSummary.numSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageS' value='$($coverageSummary.sequenceCoverage)']"
	}
	else
	{
		Write-Host "No coverage file was found: $testCoverageReportPath"
	}

}