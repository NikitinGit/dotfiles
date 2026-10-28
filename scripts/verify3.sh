#!/usr/bin/env bash
# Проверка вхолодную: сбрасываем кеш страниц и перечитываем с пластин.
# Только чтение данных. drop_caches ничего не удаляет, лишь освобождает кеш.
#     /run/wrappers/bin/sudo bash /home/igor/verify3.sh
set -uo pipefail
LOG=/home/igor/verify3.log
: > "$LOG"; chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
say() { printf '\n\033[1m=== %s ===\033[0m  %s\n' "$1" "$(date '+%H:%M:%S')"; }
[ "$(id -u)" = 0 ] || { echo 'нужен root'; exit 1; }

BLOBS='var/lib/docker/containerd/daemon/io.containerd.content.v1.content/blobs/sha256'
B=af166387641d84cdf7a5b00f7127dcdd3f9829c942fc697d6275e92b331abe0f

check() {   # $1 = путь к блобу, $2 = ожидаемый хеш
    local got; got=$(sha256sum "$1" 2>/dev/null | cut -d' ' -f1)
    if   [ -z "$got" ];      then echo 'ПРОЧИТАТЬ НЕ УДАЛОСЬ (ошибка ввода-вывода)'
    elif [ "$got" = "$2" ];  then echo 'цел'
    else echo "ИСПОРЧЕН: $got"; fi
}

say 'СБРАСЫВАЮ КЕШ СТРАНИЦ'
sync; echo 3 > /proc/sys/vm/drop_caches; sleep 2
echo '  кеш сброшен, дальше всё читается прямо с дисков'

say 'ПОДОЗРИТЕЛЬНЫЙ БЛОБ ВХОЛОДНУЮ'
printf '  старый диск (Patriot): '; check "/persist/$BLOBS/$B" "$B"
sync; echo 3 > /proc/sys/vm/drop_caches; sleep 1
printf '  новый диск (Kingston): '; check "/mnt/persist/$BLOBS/$B" "$B"

say 'ВСЕ 200 БЛОБОВ НА НОВОМ ДИСКЕ ВХОЛОДНУЮ'
sync; echo 3 > /proc/sys/vm/drop_caches; sleep 1
cd "/mnt/persist/$BLOBS" || exit 1
n=0; bad=0
for f in *; do
    [ -f "$f" ] || continue
    n=$((n+1))
    got=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
    [ "$got" = "$f" ] || { bad=$((bad+1)); echo "  РАСХОЖДЕНИЕ: $f -> ${got:-не прочитался}"; }
done
echo "  проверено: $n, расхождений: $bad"

say 'ТОМА DOCKER С БАЗАМИ — ЧИТАЮТСЯ ЛИ ЦЕЛИКОМ'
sync; echo 3 > /proc/sys/vm/drop_caches; sleep 1
for v in /mnt/persist/var/lib/docker/volumes/*/; do
    [ -d "$v" ] || continue
    name=$(basename "$v")
    err=$(find "$v" -type f -exec cat {} + 2>&1 >/dev/null | head -1)
    sz=$(du -sh "$v" 2>/dev/null | cut -f1)
    if [ -n "$err" ]; then echo "  $name ($sz): ОШИБКА — $err"
    else echo "  $name ($sz): читается полностью"; fi
done

say 'ОШИБКИ ДИСКОВ ЗА ВРЕМЯ ЭТОЙ ПРОВЕРКИ'
journalctl -k --no-pager --since '-3min' | grep -iE 'fs-verity|I/O error|bdev <missing disk>' | tail -6 | sed 's/^/  /'
echo "  всего: $(journalctl -k --no-pager --since '-3min' | grep -icE 'fs-verity|I/O error|bdev <missing disk>')"
echo "  из них по новому диску nvme0n1: $(journalctl -k --no-pager --since '-3min' | grep -cE 'nvme0n1')"

say 'ГОТОВО'
echo "журнал: $LOG"
