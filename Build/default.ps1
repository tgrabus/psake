properties {
	$testMessage = 'Executed Test!'
	$compileMessage = 'Executed Compile!'
	$cleanMessage = 'Executed Clean!'
}

task default -depends Test

task Clean {
	Write-Host $cleanMessage
}

task Compile -depends Clean {
	Write-Host $compileMessage
}

task Test -depends Compile, Clean {
	Write-Host $testMessage
}