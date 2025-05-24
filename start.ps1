# MoneyPrinterTurbo 统一启动脚本 (使用 uv)
Write-Host "MoneyPrinterTurbo 启动助手" -ForegroundColor Cyan

# 定义项目根目录
$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location $projectRoot

# 检查 uv 是否安装
$uvInstalled = $null
try {
    $uvInstalled = Get-Command uv -ErrorAction SilentlyContinue
} catch {}

if (-not $uvInstalled) {
    Write-Host "未检测到 uv 工具。是否要安装？ (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "正在安装 uv..." -ForegroundColor Cyan
        pip install uv
    } else {
        Write-Host "请手动安装 uv 后再运行此脚本：pip install uv" -ForegroundColor Red
        exit 1
    }
}

# 检查虚拟环境
$venvPath = Join-Path -Path $projectRoot -ChildPath ".venv"
if (-not (Test-Path $venvPath)) {
    Write-Host "虚拟环境不存在。是否创建新环境？ (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "正在创建 Python 3.11 虚拟环境..." -ForegroundColor Cyan
        uv venv -p=3.11 .venv
        
        Write-Host "正在安装依赖..." -ForegroundColor Cyan
        uv pip install -r requirements.txt
    } else {
        Write-Host "无法继续，需要虚拟环境" -ForegroundColor Red
        exit 1
    }
} else {    # 如果环境存在，询问是否要同步依赖
    Write-Host "虚拟环境已存在。是否同步最新依赖？ (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "正在同步依赖..." -ForegroundColor Cyan
        uv pip sync requirements.txt
    }    # 检查关键依赖是否已安装
}

# 激活虚拟环境
$activateScript = Join-Path -Path $venvPath -ChildPath "Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    & $activateScript
    
    # 显示Python版本验证环境
    Write-Host "当前环境: " -NoNewline -ForegroundColor Cyan
    python --version
      # 启动两个终端窗口分别运行服务
    Write-Host "启动 MoneyPrinterTurbo 服务..." -ForegroundColor Green
    
    # 定义虚拟环境中的 Python 和 Streamlit 路径
    $pythonPath = Join-Path -Path $venvPath -ChildPath "Scripts\python.exe"
    $streamlitPath = Join-Path -Path $venvPath -ChildPath "Scripts\streamlit.exe"
    
    # 验证路径是否存在
    if (-not (Test-Path $pythonPath)) {
        Write-Host "警告: 找不到 Python 可执行文件: $pythonPath" -ForegroundColor Yellow
        $pythonPath = "python"  # 回退到系统 Python
    }
    
    if (-not (Test-Path $streamlitPath)) {
        Write-Host "警告: 找不到 streamlit 可执行文件，尝试通过模块启动" -ForegroundColor Yellow
        # 使用 Python 启动 streamlit 模块
        $streamlitCommand = "$pythonPath -m streamlit run .\webui\Main.py --browser.gatherUsageStats=False --server.enableCORS=True"
    } else {
        $streamlitCommand = "$streamlitPath run .\webui\Main.py --browser.gatherUsageStats=False --server.enableCORS=True"
    }
      # 启动 API 服务
    Write-Host "正在启动 API 服务..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$projectRoot'; & '${pythonPath}' main.py"
    Start-Sleep -Seconds 2
      # 启动 Web UI
    Write-Host "正在启动 Web UI..." -ForegroundColor Cyan
    # 使用 Invoke-Expression 确保命令正确解析
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$projectRoot'; & $pythonPath -m streamlit run .\webui\Main.py --browser.gatherUsageStats=False --server.enableCORS=True"
    
    # 显示信息
    Write-Host "`n✅ 所有服务已启动" -ForegroundColor Green
    Write-Host "`n📊 Web 界面: http://localhost:8501" -ForegroundColor Magenta
    Write-Host "📘 API 文档: http://127.0.0.1:8080/docs" -ForegroundColor Magenta
    Write-Host "`n提示: 关闭命令行窗口将停止相应的服务" -ForegroundColor Yellow
} else {
    Write-Host "错误: 无法找到虚拟环境激活脚本" -ForegroundColor Red
}
