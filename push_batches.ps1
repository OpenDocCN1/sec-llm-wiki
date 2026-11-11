# 分批提交推送未提交的 md 文件，每 1000 个一组
# 用法: ./push_batches.ps1 <start> <end>
# 例如: ./push_batches.ps1 1 1000

param(
    [int]$Start = 1,
    [int]$End = 1000
)

$RepoDir = "D:\docs\wiki\sec-llm-wiki"
$FileList = "$env:TEMP\md_files.txt"
$Batch = [math]::Ceiling($Start / 1000)
$lockFile = Join-Path $RepoDir ".git\index.lock"

Set-Location $RepoDir

Write-Host "=== Processing batch ${Batch}: files $Start to $End ==="

# 清理残留的 git 进程和 lock 文件
Get-Process | Where-Object {$_.ProcessName -like "*git*"} | Stop-Process -Force 2>$null
Start-Sleep -Seconds 2
if (Test-Path $lockFile) { Remove-Item $lockFile -Force }

# 一次性添加所有文件（通过 stdin，只启动一个 git 进程，避免锁竞争）
$count = 0
Get-Content $FileList | Select-Object -Skip ($Start - 1) -First ($End - $Start + 1) | ForEach-Object { $count++; $_ } | git update-index --add --stdin 2>$null
if ($count -eq 0) {
    Write-Host "  No files to add in this range."
    exit 0
}
Write-Host "  added $count files to index."

# 再次清理可能残留的 lock
Get-Process | Where-Object {$_.ProcessName -like "*git*"} | Stop-Process -Force 2>$null
Start-Sleep -Seconds 1
if (Test-Path $lockFile) { Remove-Item $lockFile -Force }

Write-Host "  Committing..."
git commit -m "add md files batch $Batch ($Start-$End)"

Write-Host "  Pushing to origin master..."
git push origin master

Write-Host "=== Batch $Batch done ==="
