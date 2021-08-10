$ConfigFile = "C:\Program Files\1cv8\srvinfo\reg_1541\1CV8Clst.lst"
If ( Test-Path $ConfigFile ) {
  Get-Content $ConfigFile | ConvertFrom-JSON | Get-Member
}

