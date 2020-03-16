
$NetConfigs = Get-NetIPConfiguration -All
Foreach ($NetConfig in $NetConfigs) { 
  If ( $NetConfig.IPv4DefaultGateway ) {
    Write-Host $NetConfig.ComputerName
    $NetConfig.IPV4Address|ForEach-Object { $_.IPAddress }
    $NetConfig.AllIPAddresses|ForEach-Object { $_ }
    Write-Host $NetConfig.IPv4DefaultGateway.NextHop
  }
}

#Help Get-NetIPConfiguration -Full

$MainWindow                = New-Object System.Windows.Forms.Form
$ToolTip = New-Object System.Windows.Forms.ToolTip

$ToolTip.BackColor = [System.Drawing.Color]::LightGoldenrodYellow
$ToolTip.IsBalloon = $true
# $ToolTip.InitialDelay = 500
# $ToolTip.ReshowDelay = 500

# ������������� ��������� �����
# ������ � �������
$CloseButton                   = New-Object System.Windows.Forms.Button

# �������
$ComputerTextBoxLabel           = New-Object System.Windows.Forms.Label
$IPTextBoxLabel              = New-Object System.Windows.Forms.Label
$GatewayTextBoxLabel        = New-Object System.Windows.Forms.Label
#$SignTextBoxLabel              = New-Object System.Windows.Forms.Label

# �������� ������, �� ������� �������� ����� ��������
$CloseButton.Location          = New-Object System.Drawing.Point(315,150)
$CloseButton.Text              = "������� ����"
$CloseButton.add_click({ $MainWindow.Close() })
$CloseButton.Autosize          = 1
$CloseButton.TabIndex          = 7
$ToolTip.SetToolTip($CloseButton, "������-�� ������")

# ������� �����
$MainWindow.StartPosition  = "CenterScreen"
$MainWindow.Text           = "������� �����������"
$MainWindow.Width          = 470
$MainWindow.Height         = 220
# ��������� ������ � ��������� �����������
#$Win.ControlBox           = 0 # ��������� ������ ��������, ����������� � ��������.
# $Win.ShowIcon             = 0
# $Win.ShowInTaskbar        = 0
# $Win.HelpButton           = 1
# ���������� ����� ������������ ���� ��� ����� - � ������� ���� ������ "������� ������"
# $Win.Autosize             = 1
# $Win.AutoSizeMode         = "GrowAndShrink"
# ����� ���������� � �����.
# $Win.FormBorderStyle      = [System.Windows.Forms.FormBorderStyle]::Fixed3D
# $Win.Font                 = New-Object System.Drawing.Font("Verdana",32)


# ������� � ��������� �����
$ComputerTextBoxLabel.Location   = New-Object System.Drawing.Point(10,12)
$ComputerTextBoxLabel.Text       = "��� ����������: " + $NetConfig.ComputerName
$ComputerTextBoxLabel.Autosize     = 1

$IPTextBoxLabel.Location     = New-Object System.Drawing.Point(10,28)
$IPTextBoxLabel.Text         = "IP-�����: " + $NetConfig.IPV4Address.IPAddress
$IPTextBoxLabel.Autosize     = 1

$GatewayTextBoxLabel.Location  = New-Object System.Drawing.Point(10,44)
$GatewayTextBoxLabel.Text      = "�������� ����"
$GatewayTextBoxLabel.Autosize  = 1

# ������ � ���� �������� ���������, �������� ������ ������� ������, ������� ���� � ������� ������� � �����, ����� �� ��������.
#$ToolTip.SetToolTip($MessageTextBoxLabel, "���� �����������, � �� � ��������� ���� � ����������� �� �����")


# ��������� �������� � ����� � �������� � ������
$MainWindow.Controls.Add($CloseButton)

$MainWindow.Controls.Add($ComputerTextBoxLabel)
$MainWindow.Controls.Add($IPTextBoxLabel)
$MainWindow.Controls.Add($GatewayTextBoxLabel)
#$MainSendWindow.Controls.Add($SignTextBoxLabel)

$MainWindow.ShowDialog() | Out-Null