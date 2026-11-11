# 分批提交推送未提交的 md 文件，每 1000 个一组
# 用法: ./push_all_batches.ps1 <start> <end>  处理指定范围
# 例如: ./push_all_batches.ps1 1001 133810

param(
    [int]$Start = 1001,
    [int]$End = 133810
)

$RepoDir = "D:\docs\wiki\sec-llm-wiki"
$FileList = "$env:TEMP\md_files.txt"

Set-Location $RepoDir

$totalBatches = [math]::Ceiling(($End - $Start + 1) / 1000)
$currentBatch = 0

for ($i = $Start; $i -le $End; $i += 1000) {
    $batchEnd = [math]::Min($i + 999, $End)
    $currentBatch++
    $BatchNum = [math]::Ceiling($i / 1000)
    $lockFile = Join-Path $RepoDir ".git\index.lock"

    Write-Host "=== Batch ${currentBatch}/${totalBatches}: files $i to $batchEnd ==="

    # 清理残留的 git 进程和 lock 文件
    Get-Process | Where-Object {$_.ProcessName -like "*git*"} | Stop-Process -Force 2>$null
    Start-Sleep -Seconds 1
    if (Test-Path $lockFile) { Remove-Item $lockFile -Force }

    # 一次性添加所有文件
    $count = 0
    Get-Content $FileList | Select-Object -Skip ($i - 1) -First ($batchEnd - $i + 1) | ForEach-Object { $count++; $_ } | git update-index --add --stdin 2>$null
    if ($count -eq 0) {
        Write-Host "  No files to add."
        continue
    }
    Write-Host "  added $count files to index."

    # 再次清理
    Get-Process | Where-Object {$_.ProcessName -like "*git*"} | Stop-Process -Force 2>$null
    Start-Sleep -Seconds 1
    if (Test-Path $lockFile) { Remove-Item $lockFile -Force }

    # Commit
    Write-Host "  Committing..."
    git commit -m "add md files batch $BatchNum ($i-$batchEnd)" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Commit failed, skipping push."
        continue
    }

    # Push
    Write-Host "  Pushing to origin master..."
    git push origin master 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Push failed."
        continue
    }

    Write-Host "  === Batch $BatchNum done ==="
}

Write-Host "=== All batches completed ==="
