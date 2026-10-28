#!/usr/bin/env bash
# Последняя синхронизация перед выключением. Docker останавливается и больше
# не поднимается — сразу после этого компьютер выключается.
#     /run/wrappers/bin/sudo bash /home/igor/final-sync.sh
set -uo pipefail
LOG=/home/igor/final-sync.log
: > "$LOG"; chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
say() { printf '\n\033[1m=== %s ===\033[0m  %s\n' "$1" "$(date '+%H:%M:%S')"; }
[ "$(id -u)" = 0 ] || { echo 'нужен root'; exit 1; }

findmnt -no TARGET /mnt/home >/dev/null || { echo 'ОТМЕНА: /mnt/home не смонтирован'; exit 1; }
findmnt -no TARGET /mnt/persist >/dev/null || { echo 'ОТМЕНА: /mnt/persist не смонтирован'; exit 1; }

say 'ОСТАНАВЛИВАЮ DOCKER — базы должны скопироваться согласованно'
systemctl stop docker.socket  || true
systemctl stop docker.service || true
sleep 3
if awk '$2 ~ "^/persist/"' /proc/mounts | grep -q .; then
    echo 'ОТМЕНА: Docker не отпустил /persist'; exit 1
fi
echo '  OK, /persist свободен'

say 'ДОГОНЯЮ /persist'
rsync -aHAX --info=stats2 /persist/ /mnt/persist/ | grep -E 'Number of (regular )?files transferred|Total transferred' | sed 's/^/  /'

say 'ДОГОНЯЮ /home'
rsync -aHAX --info=stats2 \
    --exclude='igor/.local/share/Steam/steamapps' \
    --exclude='igor/.cache' \
    --exclude='igor/java_error_in_idea.hprof' \
    --exclude='igor/iso' \
    /home/ /mnt/home/ | grep -E 'Number of (regular )?files transferred|Total transferred' | sed 's/^/  /'

say 'КОНТРОЛЬНАЯ СВЕРКА'
d=$(rsync -rlni --checksum --no-times \
    --exclude='igor/.local/share/Steam/steamapps' --exclude='igor/.cache' \
    --exclude='igor/java_error_in_idea.hprof' --exclude='igor/iso' \
    /home/ /mnt/home/ 2>/dev/null | grep -cE '^[<>]f')
echo "  различий в /home осталось: $d  (ожидаемо 1-3: журналы пишутся прямо сейчас)"
echo
echo '  важные файлы на новом диске:'
for f in .ssh/nikitinssh .zsh_history .claude/projects/-home-igor dotfiles backup/mysql-all-2026-10-28.sql.gz; do
    [ -e "/mnt/home/igor/$f" ] && echo "    есть: $f" || echo "    НЕТ:  $f"
done

say 'ЗАПИСЫВАЮ ВСЁ НА ДИСКИ'
sync
echo '  готово'

say 'МОЖНО ВЫКЛЮЧАТЬСЯ'
cat <<'DONE'

  Выполните:   shutdown -h now

  Затем:
   1. Вынуть кабель питания, нажать кнопку включения на 5 секунд
   2. Открыть корпус, снять статику рукой о металл
   3. Достать Patriot из верхнего слота M.2_1 у радиатора процессора.
      НЕ ВЫБРАСЫВАТЬ — это доказательство для гарантии в DNS
   4. Дожать защёлку Kingston до щелчка или вкрутить винт M2x3
   5. Закрыть корпус, подключить питание, включить
   6. Если не загрузится: Del при включении -> раздел Boot ->
      поставить Kingston первым в порядке загрузки

DONE
echo "журнал: $LOG"
