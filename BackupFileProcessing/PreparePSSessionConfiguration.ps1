[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Position=1,Mandatory=$True)] [string]$SQLAgentUsername
)

Register-PSSessionConfiguration -Name SQLAgent -RunAsCredential $SQLAgentUsername
Get-PSSessionConfiguration -Name SQLAgent | Set-PSSessionConfiguration -ShowSecurityDescriptorUI
