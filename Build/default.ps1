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
		msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
	}
}



task TestNUnit -depends Compile `
			   -description 'Run NUnit tests'

task TestMSUnit -depends Compile `
			    -description 'Run MSUnit tests'


task Test -depends Compile, TestNUnit, TestMSUnit `
		  -description 'Run unit tests' {
	Write-Host $testMessage
}