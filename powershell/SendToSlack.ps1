<#
.Synopsis
    Скрипт для отправки сообщений в Slack из powershell
.Description
.Parameter Channel
    Канал, куда отправлять (можно и личное сообщение через @)
.Parameter Text
    Собственно текст сообщения
.Example
    PowerShell .\SendToSlack.ps1 '#backup' 'Database TESTDB backup completed succesfully.'
.Component
    powershell
.Notes
    Version: 0.4
    Date modified: 2020.06.20
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Position=1,Mandatory=$False)] [string]$Channel = '#notify'
  ,[Parameter(Position=2,Mandatory=$False)] [string]$Text = '!no message text given from caller!'
  ,[Parameter(Mandatory=$False)] [string]$Uri = 'https://hooks.slack.com/services/T00000000/B00000000/AAAAAAAAAAAAAAAAAAAAAAAA'
)

$BotName = 'Powershell Slack Bot'

function Exit-WithCode
{
  param ( $exitcode )
  #Write-Output ($exitcode)
  $host.SetShouldExit($exitcode)
  exit $exitcode
}

#
# I want receive all messages in English
#
$currentThread = [System.Threading.Thread]::CurrentThread
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$currentThread.CurrentCulture = $culture
$currentThread.CurrentUICulture = $culture

# Generates POST message to be sent to the slack channel. 
#$PostMessage = @{channel="$Channel";text="$Text";username="$BotName";icon_emoji=":robot_face:"}
$PostMessage = ("{""username"":""$Computer SQL Server"",""channel"":""$Channel"",""icon_emoji"":"":robot_face:"",""text"":""$Text""}"|ConvertFrom-JSON)
#ConvertTo-JSON $PostMessage

Try {
  # Sends HTTPS request to the Slack Web API service. 
  $WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $Uri -ContentType "application/json; charset=utf-8" -Method Post -Body (ConvertTo-JSON $PostMessage)
  # Conditional logic to generate custom error message if JSON object response contains a top-level error property. 
  If ($WebRequest.Content -like '*"ok":false*') {
    # Terminates with error if the response contains an error property, parses the error code and stops processing of the command. 
    #Throw ( $WebRequest.Content -split '"error":"') [1] -replace '"}',''
    Write-Host ( "Error: Error sending Slack web request!" )
    Write-Host ( "Error: " + (( $WebRequest.Content -split '"error":"')[1] -replace '"}','') )
    Exit-WithCode 1
  } # If 
} # Try 
Catch {
  # Terminates with error and stops processing of the command. 
  #Throw ("Unable to send request to the web service with the following exception: " + $Error[0].Exception.Message )
  Write-Host ( "Error: Exeption during sending Slack web request!" )
  Write-Host ( "Error: " + $Error[0].ToString() )
  Exit-WithCode 2
} # Catch 
Exit-WithCode 0
