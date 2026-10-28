#!/usr/bin/env bash
# Сверка скопированных данных по контрольным суммам, пока старый диск на месте.
# Только чтение, ничего не меняет.
#     /run/wrappers/bin/sudo bash /home/igor/verify-migration.sh

set -uo pipefail
LOG=/home/igor/verify-migration.log
: > "$LOG"; chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
say() { printf '\n\033[1m=== %s ===\033[0m  %s\n' "$1" "$(date '+%H:%M:%S')"; }

[ "$(id -u)" = 0 ] || { echo 'нужен root'; exit 1; }

say 'ЧТО ЗА ФАЙЛ СБОЙНУЛ (inode 19557 на старом диске)'
for sv in / /home /persist /nix /swap; do
    findmnt -no SOURCE "$sv" | grep -q nvme1n1p2 || continue
    r=$(btrfs inspect-internal inode-resolve 19557 "$sv" 2>/dev/null)
    [ -n "$r" ] && echo "  подтом $sv -> $r"
done
echo '  (строки выше — все кандидаты; нужный тот, чей размер больше 7,3 МБ)'

say 'ФАЙЛЫ С ВКЛЮЧЁННЫМ fs-verity'
echo '  ищу в /persist и /nix (там верити и бывает):'
find /persist /nix/store -maxdepth 6 -type f -size +7M 2>/dev/null \
  | head -4000 | while read -r f; do
      lsattr "$f" 2>/dev/null | grep -q 'V' && echo "    $f"
    done | head -20
echo '  (пусто — значит верити ни на одном крупном файле не включён)'

say 'СВЕРКА /persist ПО КОНТРОЛЬНЫМ СУММАМ'
rsync -rni --checksum --no-times --delete-missing-args /persist/ /mnt/persist/ \
  | grep -vE '^\.d|^cd' | head -60
echo "  различий (без каталогов): $(rsync -rni --checksum --no-times /persist/ /mnt/persist/ 2>/dev/null | grep -vcE '^\.d|^cd')"

say 'СВЕРКА /home ПО КОНТРОЛЬНЫМ СУММАМ'
rsync -rni --checksum --no-times \
    --exclude='igor/.local/share/Steam/steamapps' \
    --exclude='igor/.cache' \
    --exclude='igor/java_error_in_idea.hprof' \
    --exclude='igor/iso' \
    /home/ /mnt/home/ \
  | grep -vE '^\.d|^cd' | head -60
echo "  различий (без каталогов): $(rsync -rni --checksum --no-times \
    --exclude='igor/.local/share/Steam/steamapps' --exclude='igor/.cache' \
    --exclude='igor/java_error_in_idea.hprof' --exclude='igor/iso' \
    /home/ /mnt/home/ 2>/dev/null | grep -vcE '^\.d|^cd')"

say 'ОШИБКИ ВВОДА-ВЫВОДА ЗА ВРЕМЯ ПРОВЕРКИ'
journalctl -k --no-pager --since '-5min' | grep -icE 'fs-verity|I/O error|bdev <missing disk>' \
  | xargs echo '  совпадений:'

say 'ГОТОВО'
echo "журнал: $LOG"
echo
echo 'Как читать результат: строки с >f означают, что содержимое файла'
echo 'различается. Ожидаемо различаются только те, что менялись после'
echo 'копирования — журналы, история команд, данные Docker после перезапуска.'
echo 'Всё остальное в списке — настоящая проблема.'
