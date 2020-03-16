
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

# Инициализация контролов формы
# Кнопки и чекбокс
$CloseButton                   = New-Object System.Windows.Forms.Button

# Подписи
$ComputerTextBoxLabel           = New-Object System.Windows.Forms.Label
$IPTextBoxLabel              = New-Object System.Windows.Forms.Label
$GatewayTextBoxLabel        = New-Object System.Windows.Forms.Label
#$SignTextBoxLabel              = New-Object System.Windows.Forms.Label

# Кнопочка выхода, по событию вызывает метод закрытия
$CloseButton.Location          = New-Object System.Drawing.Point(315,150)
$CloseButton.Text              = "Закрыть окно"
$CloseButton.add_click({ $MainWindow.Close() })
$CloseButton.Autosize          = 1
$CloseButton.TabIndex          = 7
$ToolTip.SetToolTip($CloseButton, "Пойдем-ка отсюда")

# Главная форма
$MainWindow.StartPosition  = "CenterScreen"
$MainWindow.Text           = "Быстрая диагностика"
$MainWindow.Width          = 470
$MainWindow.Height         = 220
# несколько плюшек и обещанных красивостей
#$Win.ControlBox           = 0 # отключить кнопки свернуть, минимизацию и закрытие.
# $Win.ShowIcon             = 0
# $Win.ShowInTaskbar        = 0
# $Win.HelpButton           = 1
# авторазмер может отрабатывать если вся форма - к примеру одна кнопка "Сделать хорошо"
# $Win.Autosize             = 1
# $Win.AutoSizeMode         = "GrowAndShrink"
# стиль обрамления и шрифт.
# $Win.FormBorderStyle      = [System.Windows.Forms.FormBorderStyle]::Fixed3D
# $Win.Font                 = New-Object System.Drawing.Font("Verdana",32)


# Подписи к текстовым полям
$ComputerTextBoxLabel.Location   = New-Object System.Drawing.Point(10,12)
$ComputerTextBoxLabel.Text       = "Имя компьютера: " + $NetConfig.ComputerName
$ComputerTextBoxLabel.Autosize     = 1

$IPTextBoxLabel.Location     = New-Object System.Drawing.Point(10,28)
$IPTextBoxLabel.Text         = "IP-Адрес: " + $NetConfig.IPV4Address.IPAddress
$IPTextBoxLabel.Autosize     = 1

$GatewayTextBoxLabel.Location  = New-Object System.Drawing.Point(10,44)
$GatewayTextBoxLabel.Text      = "Основной шлюз"
$GatewayTextBoxLabel.Autosize  = 1

# Плюшка в виде красивой подсказки, делается другим методом вызова, поэтому идет к каждому обьекту в блоке, чтобы не теряться.
#$ToolTip.SetToolTip($MessageTextBoxLabel, "Надо подписаться, а то в заголовке окна с сообщениями не видно")


# Добавляем контролы в форму и вызываем её запуск
$MainWindow.Controls.Add($CloseButton)

$MainWindow.Controls.Add($ComputerTextBoxLabel)
$MainWindow.Controls.Add($IPTextBoxLabel)
$MainWindow.Controls.Add($GatewayTextBoxLabel)
#$MainSendWindow.Controls.Add($SignTextBoxLabel)

$MainWindow.ShowDialog() | Out-Null