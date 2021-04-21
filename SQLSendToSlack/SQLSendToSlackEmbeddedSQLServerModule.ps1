function Exit-WithCode
{
  param ( $exitcode )
  Write-Output ($exitcode)
  #$host.SetShouldExit($exitcode)
  #exit $exitcode
}

#
# I want receive all messages in English
#
$currentThread = [System.Threading.Thread]::CurrentThread
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$currentThread.CurrentCulture = $culture
$currentThread.CurrentUICulture = $culture

$Computer = '$(ESCAPE_NONE(MACH))'
$BotName = $Computer + ' SQL Server'
$Uri = 'https://hooks.slack.com/services/T00000000/B00000000/AAAAAAAAAAAAAAAAAAAAAAAA'
# Generates POST message to be sent to the slack channel. 

Try {
$DataSet = Read-SqlTableData -DatabaseName $database -SchemaName dbo -ServerInstance $server -TableName dba_SendToSlackQueue
} # Try 
Catch {
  Write-Host ( "Error: Exeption during SQL select query!" )
  Write-Host ( "Error: " + $Error[0].ToString() )
  Exit-WithCode 1
} # Catch 

$DataSet|Foreach-Object {
  $PostMessage = @{channel='';text='';username="$BotName";icon_emoji=":robot_face:"}
  $PostMessage.channel = $_.channel
  $PostMessage.text = $_.message_text
  #ConvertTo-JSON $PostMessage

  Try {
    # Sends HTTPS request to the Slack Web API service. 
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    $WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $Uri -ContentType "application/json; charset=utf-8" -Method Post -Body (ConvertTo-JSON $PostMessage)
    # Conditional logic to generate custom error message if JSON object response contains a top-level error property. 
    #$WebRequest.Content
    If ($WebRequest.Content -like '*"ok":false*') {
      # Terminates with error if the response contains an error property, parses the error code and stops processing of the command. 
      #Throw ( $WebRequest.Content -split '"error":"') [1] -replace '"}',''
      Write-Host ( "Error: Error sending Slack web request!" )
      #Write-Host ( "Error: " + $Error[0].ToString() )
      Write-Host ( "Error: " + (( $WebRequest.Content -split '"error":"')[1] -replace '"}','') )
      Continue
    } # If 
  } # Try 
  Catch {
    # Terminates with error and stops processing of the command. 
    #Throw ("Unable to send request to the web service with the following exception: " + $Error[0].Exception.Message )
    Write-Host ( "Error: Exeption during sending Slack web request!" )
    Write-Host ( "Error: " + $Error[0].ToString() )
    #Write-Host ( "Error: " + $Error[0].Exception.Message )
    #Exit-WithCode 2
    Continue
  } # Catch 
<#
  Try { # Success - can delete message record
    $sql = "SET LANGUAGE us_english; DELETE FROM msdb.dbo.dba_SendToSlackQueue where message_id='"+$_.message_id+"'"
    $SqlCmd.CommandText = $sql
    #$SqlConnection.Open()
    $rowsAffected = $SqlCmd.ExecuteNonQuery();
  } # Try 
  Catch {
    Write-Host ( "Error: Exeption during SQL delete query!" )
    Write-Host ( "Error: " + $Error[0].ToString() )
  } # Catch 
#>
} # Foreach-Object
Exit-WithCode 0
