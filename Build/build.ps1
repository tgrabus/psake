cls

Remove-Module [p]sake

Import-Module ..\packages\psake.*\tools\psake.psm1

Invoke-psake -buildFile .\default.ps1 -taskList Test -properties @{ "testMessage"="What am I doing" }