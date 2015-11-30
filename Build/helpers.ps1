function Find-PackagePath
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=1)]$packagePath,
		[Parameter(Position=1, Mandatory=1)]$packageName
	)

	return (Get-ChildItem("$packagePath\$packageName*")).FullName | Sort-Object $_ | select -Last 1
}