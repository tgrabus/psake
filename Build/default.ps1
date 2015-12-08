Include ".\helpers.ps1"

properties {

	$solutionDirectory = (Get-Item $SolutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	
	#Project's output directories
	$temporaryOutputDirectory = "$outputDirectory\temp"
	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedApplicationsDirectory = "$temporaryOutputDirectory\_PublishedApplications"
	$publishedWebsitesDirectory = "$temporaryOutputDirectory\_PublishedWebsites"
	$publishedLibrariesDirectory = "$temporaryOutputDirectory\_PublishedLibraries"

	$packagesOutputDirectory = "$outputDirectory\Packages"
	$applicationsOutputDirectory = "$packagesOutputDirectory\Applications"
	$librariesOutputDirectory = "$packagesOutputDirectory\Libraries"

	#Test results directories
	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	
	#Test coverage directory and default configuration
	$testCoverageDirectory = "$outputDirectory\TestCoverage"
	$testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
	$testCoverageFilter = "+[*]* -[*.NUnitTests]* -[*.Tests]*"
	$testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
	$testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"

	#Tools
	$packagesPath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagesPath "NUnit.Console") + "\tools\nunit3-console.exe"
	$OpenCoverExe = (Find-PackagePath $packagesPath "OpenCover") + "\tools\OpenCover.Console.exe"
	$ReportGeneratorExe = (Find-PackagePath $packagesPath "ReportGenerator") + "\tools\ReportGenerator.exe"
	$7ZipExe = (Find-PackagePath $packagesPath "7-Zip.CommandLine") + "\tools\7za.exe"
	$NugetExe = (Find-PackagePath $packagesPath "NuGet.CommandLine") + "\tools\NuGet.exe"


	#MSBuild default configuration
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
		   -failureMessage "NUnit Exe could not be found at $NUnitExe"

	Assert -conditionToCheck (Test-Path $OpenCoverExe) `
		   -failureMessage "OpenCover Exe could not be found at $OpenCoverExe"

	Assert -conditionToCheck (Test-Path $ReportGeneratorExe) `
		   -failureMessage "ReportGenerator Exe could not be found at $ReportGeneratorExe"

	Assert -conditionToCheck (Test-Path $7ZipExe) `
		   -failureMessage "7-Zip Exe could not be found at $7ZipExe"

	Assert -conditionToCheck (Test-Path $NugetExe) `
		   -failureMessage "NuGet Exe could not be found at $NugetExe"

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

task Compile -depends Init `
			 -description 'Compile the code' `
			 -requiredVariables SolutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory {
	Write-Host "Building solution $SolutionFile"

	Exec {
		msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory;NuGetExePath=$NugetExe"
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
		Write-Host "Generating HTML test coverage report"

		Exec { &$ReportGeneratorExe $testCoverageReportPath $testCoverageDirectory }

		#Parse OpenCover report
		Write-Host "Parsing OpenCover report"

		$coverage = [xml](Get-Content -Path $testCoverageReportPath)
		$coverageSummary = $coverage.CoverageSession.Summary

		#Write class coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N2}']" -f(($coverageSummary.visitedClasses / $coverageSummary.numClasses) * 100) | foreach {$_.replace(",",".") })

		#Write method coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N2}']" -f(($coverageSummary.visitedMethods / $coverageSummary.numMethods) * 100) | foreach {$_.replace(",",".") })

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

task Package -depends Compile, Test `
			 -description 'Package applications' `
			 -requiredVariables publishedWebsitesDirectory, publishedApplicationsDirectory, applicationsOutputDirectory, publishedLibrariesDirectory, librariesOutputDirectory `
{
	$applications = @(Get-ChildItem $publishedWebsitesDirectory) + @(Get-ChildItem $publishedApplicationsDirectory)

	if($applications.Length -gt 0 -and !(Test-Path $applicationsOutputDirectory))
	{
		New-Item $applicationsOutputDirectory -ItemType Directory | Out-Null
	}

	foreach($application in $applications) 
	{
		$nuspecPath = "$($application.FullName)\bin\$($application.Name).nuspec"

		if(Test-Path $nuspecPath)
		{
			Write-Host "Packaging $($application.Name) as a NuGet package"

			#Parse nuspec file
			$nuspec = [xml](Get-Content -Path $nuspecPath)
			$metadata = $nuspec.package.metadata

			#Update package version
			$metadata.version = $metadata.version.Replace("[buildNumber]", $BuildNumber)
			if(!$IsMainBranch) 
			{
				$metadata.version = $metadata.version + "-$BranchName"
			}

			#Update package release notes
			$metadata.releaseNotes = "Build Number: $BuildNumber`r`nBranch Name: $BranchName`r`nGit Commit Hash: $GitCommitHash"

			$nuspec.Save((Get-Item $nuspecPath))

			Exec { &$NugetExe pack $nuspecPath -OutputDirectory $applicationsOutputDirectory }
		}
		else
		{
			Write-Host "Packaging $($application.Name) as a zip file"

			$archivePath = "$applicationsOutputDirectory\$($application.Name).zip"
			$inputDirectory = "$($application.FullName)\*"

			Exec { &$7ZipExe a -r -mx3 $archivePath $inputDirectory }
		}
	}

	if(Test-Path $publishedLibrariesDirectory)
	{
		if(!(Test-Path $librariesOutputDirectory))
		{
			mkdir $librariesOutputDirectory | Out-Null
		}

		Get-ChildItem -Path $publishedLibrariesDirectory -Filter "*.nupkg" -Recurse | Move-Item -Destination $librariesOutputDirectory
	}
}


task Clean -depends Compile, Test, Package `
		   -description 'Remove temporary files' `
		   -requiredVariables temporaryOutputDirectory `
{
	if(Test-Path $temporaryOutputDirectory)
	{
		Write-Host "Removing temp directory located at $temporaryOutputDirectory"
		Remove-Item $temporaryOutputDirectory -Force -Recurse
	}

	Write-Host "Cleaned!"
}