function Start-Sleep {
Param(
  [Parameter(Position=1,Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='Seconds')] [int]$Seconds,
  [Parameter(Mandatory=$True,ParameterSetName='Milliseconds')] [int]$Milliseconds
)
    If ($Seconds) {
      $Milliseconds = $seconds * 1000
    }
    $doneDT = (Get-Date).AddMilliseconds($Milliseconds)
    while($doneDT -gt (Get-Date)) {
        $TimeRemaining = $doneDT.Subtract((Get-Date))
        $Percent = ($Milliseconds - $TimeRemaining.TotalMilliseconds) / $Milliseconds * 100
        Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining $TimeRemaining.TotalSeconds -PercentComplete $Percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}
Start-Sleep 5
