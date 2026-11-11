#!/bin/bash
# 分批提交推送未提交的 md 文件，每 1000 个一组
# 用法: ./push_batches.sh <start_index> <end_index>
# 例如: ./push_batches.sh 1 1000  处理第 1-1000 个文件

set -e

REPO_DIR="D:/docs/wiki/sec-llm-wiki"
FILE_LIST="/tmp/md_files.txt"
START=${1:-1}
END=${2:-1000}

cd "$REPO_DIR"

# 清理可能的残留 lock
rm -f .git/index.lock
taskkill //F //IM git.exe 2>/dev/null || true
sleep 1
rm -f .git/index.lock

BATCH=$(( (START + 999) / 1000 ))

echo "=== Processing batch $BATCH: files $START to $END ==="

COUNT=0
sed -n "${START},${END}p" "$FILE_LIST" | while IFS= read -r f; do
  git add "$f"
  COUNT=$((COUNT + 1))
  if [ $((COUNT % 100)) -eq 0 ]; then
    echo "  added $COUNT files..."
  fi
done

echo "  added $COUNT files total. Committing..."
git commit -m "add md files batch $BATCH ($START-$END)"

echo "  Pushing to origin master..."
git push origin master

echo "=== Batch $BATCH done ==="
