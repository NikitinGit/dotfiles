#!/usr/bin/env bash
# Исправленная сверка. Только чтение.
#     /run/wrappers/bin/sudo bash /home/igor/verify2.sh
set -uo pipefail
LOG=/home/igor/verify2.log
: > "$LOG"; chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
say() { printf '\n\033[1m=== %s ===\033[0m  %s\n' "$1" "$(date '+%H:%M:%S')"; }
[ "$(id -u)" = 0 ] || { echo 'нужен root'; exit 1; }

BLOBS='var/lib/docker/containerd/daemon/io.containerd.content.v1.content/blobs/sha256'

say 'ТОТ САМЫЙ БЛОБ: целы ли оба экземпляра'
B=af166387641d84cdf7a5b00f7127dcdd3f9829c942fc697d6275e92b331abe0f
for root in /persist /mnt/persist; do
    f="$root/$BLOBS/$B"
    if [ -e "$f" ]; then
        printf '  %-16s размер %12s  ' "$root" "$(stat -c %s "$f")"
        got=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
        if [ "$got" = "$B" ]; then echo 'sha256 СОВПАДАЕТ с именем — файл цел'
        elif [ -z "$got" ]; then echo 'ПРОЧИТАТЬ НЕ УДАЛОСЬ'
        else echo "НЕ СОВПАДАЕТ: $got"; fi
    else
        echo "  $root — файла нет"
    fi
done

say 'ВСЕ БЛОБЫ DOCKER НА НОВОМ ДИСКЕ: каждый проверяется своим именем'
cd "/mnt/persist/$BLOBS" 2>/dev/null || { echo '  каталог не найден'; exit 1; }
n=0; bad=0
for f in *; do
    [ -f "$f" ] || continue
    n=$((n+1))
    got=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
    if [ "$got" != "$f" ]; then
        bad=$((bad+1))
        echo "  РАСХОЖДЕНИЕ: $f"
        echo "     посчитано: ${got:-не прочитался}"
    fi
done
echo "  проверено блобов: $n, расхождений: $bad"

say 'СВЕРКА /persist — на этот раз со ссылками (-l)'
d=$(rsync -rlni --checksum --no-times /persist/ /mnt/persist/ 2>/dev/null | grep -cE '^[<>]f')
echo "  файлов с различающимся содержимым: $d"
rsync -rlni --checksum --no-times /persist/ /mnt/persist/ 2>/dev/null | grep -E '^[<>]f' | head -40 | sed 's/^/    /'

say 'СВЕРКА /home — тоже со ссылками'
EX=(--exclude='igor/.local/share/Steam/steamapps' --exclude='igor/.cache'
    --exclude='igor/java_error_in_idea.hprof' --exclude='igor/iso')
d=$(rsync -rlni --checksum --no-times "${EX[@]}" /home/ /mnt/home/ 2>/dev/null | grep -cE '^[<>]f')
echo "  файлов с различающимся содержимым: $d"
rsync -rlni --checksum --no-times "${EX[@]}" /home/ /mnt/home/ 2>/dev/null | grep -E '^[<>]f' | head -60 | sed 's/^/    /'

say 'ОШИБКИ ДИСКА ЗА ВРЕМЯ ПРОВЕРКИ'
journalctl -k --no-pager --since '-10min' | grep -iE 'fs-verity|I/O error|bdev <missing disk>' | tail -5 | sed 's/^/  /'
echo "  всего: $(journalctl -k --no-pager --since '-10min' | grep -icE 'fs-verity|I/O error|bdev <missing disk>')"

say 'ГОТОВО'
echo "журнал: $LOG"
