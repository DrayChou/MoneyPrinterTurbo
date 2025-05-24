# MoneyPrinterTurbo Unified Startup Script (using uv)
Write-Host "MoneyPrinterTurbo Startup Helper" -ForegroundColor Cyan

# Define project root directory
$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location $projectRoot

# Check if uv is installed
$uvInstalled = $null
try {
    $uvInstalled = Get-Command uv -ErrorAction SilentlyContinue
} catch {}

if (-not $uvInstalled) {
    Write-Host "UV tool not detected. Do you want to install it? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "Installing uv..." -ForegroundColor Cyan
        pip install uv
    } else {
        Write-Host "Please install uv manually and run this script again: pip install uv" -ForegroundColor Red
        exit 1
    }
}

# Check virtual environment
$venvPath = Join-Path -Path $projectRoot -ChildPath ".venv"
if (-not (Test-Path $venvPath)) {
    Write-Host "Virtual environment does not exist. Create new environment? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "Creating Python 3.11 virtual environment..." -ForegroundColor Cyan
        uv venv -p=3.11 .venv
        
        Write-Host "Installing dependencies..." -ForegroundColor Cyan
        uv pip install -r requirements.txt
    } else {
        Write-Host "Cannot continue without virtual environment" -ForegroundColor Red
        exit 1
    }
} else {
    # If environment exists, ask to sync dependencies
    Write-Host "Virtual environment exists. Sync latest dependencies? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "Syncing dependencies..." -ForegroundColor Cyan
        uv pip sync requirements.txt
    }
    
    # Check critical dependencies
    Write-Host "Checking critical dependencies..." -ForegroundColor Cyan
    $missingDeps = @()
    
    # Critical dependencies list
    $criticalDeps = @(
        "streamlit",
        "fastapi",
        "blinker",
        "click",
        "google.protobuf",
        "win32_setctime",
        "typing_extensions",
        "toml",
        "colorama"
    )
    
    foreach ($dep in $criticalDeps) {
        $depName = $dep
        
        # Special package name mappings
        switch ($dep) {
            "google.protobuf" { $importName = "google.protobuf"; $depName = "protobuf" }
            "win32_setctime" { $importName = "win32_setctime"; $depName = "win32-setctime" }
            "typing_extensions" { $importName = "typing_extensions"; $depName = "typing-extensions" }
            default { $importName = $dep.Replace(".", " ").Split(" ")[0] }
        }
        
        $pythonCode = @"
try:
    import $importName
    print('OK')
except ImportError:
    print('MISSING')
    exit(1)
"@
        
        # Execute Python code
        & $venvPath\Scripts\python.exe -c $pythonCode
        if ($LASTEXITCODE -ne 0) {
            $missingDeps += $depName
        }
    }
    
    # If there are missing dependencies, prompt to install
    if ($missingDeps.Count -gt 0) {
        Write-Host "Missing dependencies detected: $($missingDeps -join ', ')" -ForegroundColor Yellow
        Write-Host "Install missing dependencies? (Y/N)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq "Y" -or $response -eq "y") {
            Write-Host "Installing missing dependencies..." -ForegroundColor Cyan
            
            # Try to install all missing dependencies
            $depArgs = $missingDeps
            & $venvPath\Scripts\python.exe -m pip install $depArgs
            
            # Verify installation
            $stillMissing = @()
            
            foreach ($dep in $missingDeps) {
                $importName = $dep.Replace("-", "_")
                $checkCode = @"
try:
    import $importName
    print('OK')
    exit(0)
except ImportError:
    print('MISSING')
    exit(1)
"@
                & $venvPath\Scripts\python.exe -c $checkCode
                if ($LASTEXITCODE -ne 0) {
                    $stillMissing += $dep
                }
            }
            
            if ($stillMissing.Count -gt 0) {
                Write-Host "Warning: The following dependencies failed to install: $($stillMissing -join ', ')" -ForegroundColor Red
            } else {
                Write-Host "All dependencies installed successfully" -ForegroundColor Green
            }
        } else {
            Write-Host "Warning: Missing dependencies may prevent proper operation" -ForegroundColor Yellow
        }
    } else {
        Write-Host "All critical dependencies verified" -ForegroundColor Green
    }
}

# Activate virtual environment
$activateScript = Join-Path -Path $venvPath -ChildPath "Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    & $activateScript
    
    # Display Python version
    Write-Host "Current environment: " -NoNewline -ForegroundColor Cyan
    python --version
    
    # Start services
    Write-Host "Starting MoneyPrinterTurbo services..." -ForegroundColor Green
    
    # Define paths
    $pythonPath = Join-Path -Path $venvPath -ChildPath "Scripts\python.exe"
    $streamlitPath = Join-Path -Path $venvPath -ChildPath "Scripts\streamlit.exe"
    
    # Verify paths
    if (-not (Test-Path $pythonPath)) {
        Write-Host "Warning: Python executable not found: $pythonPath" -ForegroundColor Yellow
        $pythonPath = "python"  # Fallback to system Python
    }
    
    if (-not (Test-Path $streamlitPath)) {
        Write-Host "Warning: Streamlit executable not found, trying module startup" -ForegroundColor Yellow
        $streamlitCommand = "$pythonPath -m streamlit run .\webui\Main.py --browser.gatherUsageStats=False --server.enableCORS=True"
    } else {
        $streamlitCommand = "$streamlitPath run .\webui\Main.py --browser.gatherUsageStats=False --server.enableCORS=True"
    }
    
    # Start API service
    Write-Host "Starting API service..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$projectRoot'; & '${pythonPath}' main.py"
    Start-Sleep -Seconds 2
    
    # Start Web UI
    Write-Host "Starting Web UI..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$projectRoot'; $streamlitCommand"
    
    # Display info
    Write-Host "`nAll services started" -ForegroundColor Green
    Write-Host "`nWeb Interface: http://localhost:8501" -ForegroundColor Magenta
    Write-Host "API Documentation: http://127.0.0.1:8080/docs" -ForegroundColor Magenta
    Write-Host "`nNote: Closing command windows will stop respective services" -ForegroundColor Yellow
} else {
    Write-Host "Error: Virtual environment activation script not found" -ForegroundColor Red
}
