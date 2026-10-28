#!/usr/bin/env bash
#
# Перенос системы igor-desktop со сбойного Patriot P400 на Kingston FURY Renegade.
# Запускать из работающей системы с правами root:
#
#     /run/wrappers/bin/sudo bash /home/igor/migrate-to-kingston.sh
#
# Скрипт останавливается и спрашивает подтверждение перед разметкой диска.
# Всё остальное идёт без вопросов. Журнал: /home/igor/migrate-to-kingston.log

set -euo pipefail

LOG=/home/igor/migrate-to-kingston.log
touch "$LOG"; chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1

TARGET_ID='/dev/disk/by-id/nvme-KINGSTON_SFYRSK1000G_50026B7283B26CAB'
EXPECT_SERIAL='50026B7283B26CAB'
EXPECT_MODEL='KINGSTON SFYRSK1000G'
FLAKE='/home/igor/dotfiles'
ATTR='igor-desktop'
export NIX_CONFIG="extra-experimental-features = nix-command flakes"

say() { printf '\n\033[1m=== %s ===\033[0m  %s\n' "$1" "$(date '+%H:%M:%S')"; }
die() { printf '\n\033[1;31mОТМЕНА: %s\033[0m\n' "$1"; exit 1; }

# rsync возвращает 24, если файлы исчезли во время копирования. На живой
# системе это нормально и не считается ошибкой.
run_rsync() {
    local c=0
    rsync "$@" || c=$?
    case "$c" in
        0)  ;;
        24) echo "  (код 24: часть файлов исчезла во время копирования — для живой системы нормально)" ;;
        *)  die "rsync завершился с кодом $c" ;;
    esac
}

say 'НАЧАЛО'
echo "скрипт: $0"
echo "журнал: $LOG"

# ---------------------------------------------------------------- проверки
say 'ПРОВЕРКИ БЕЗОПАСНОСТИ'

[ "$(id -u)" = 0 ] || die 'нужны права root'
[ -e "$TARGET_ID" ] || die "нет устройства $TARGET_ID"

REAL=$(readlink -f "$TARGET_ID")
echo "цель:            $TARGET_ID"
echo "ведёт на:        $REAL"

GOT_SERIAL=$(lsblk -dno SERIAL "$REAL" | tr -d ' ')
GOT_MODEL=$(lsblk -dno MODEL "$REAL" | sed 's/ *$//')
echo "модель:          $GOT_MODEL"
echo "серийный номер:  $GOT_SERIAL"

[ "$GOT_SERIAL" = "$EXPECT_SERIAL" ] || die "серийный номер не совпадает (ждали $EXPECT_SERIAL)"
[ "$GOT_MODEL"  = "$EXPECT_MODEL"  ] || die "модель не совпадает (ждали $EXPECT_MODEL)"

ROOTSRC=$(findmnt -no SOURCE / | sed 's/\[.*//')
ROOTDISK=/dev/$(lsblk -no PKNAME "$ROOTSRC")
echo "системный диск:  $ROOTDISK  (корень с $ROOTSRC)"
[ "$ROOTDISK" != "$REAL" ] || die 'цель совпадает с системным диском'

grep -q "^${REAL}p" /proc/mounts && die 'с цели что-то смонтировано'

PCI=$(basename "$(readlink -f "/sys/block/$(basename "$REAL")/device/device")")
LINK_SPEED=$(cat "/sys/bus/pci/devices/$PCI/current_link_speed" 2>/dev/null || echo '?')
LINK_WIDTH=$(cat "/sys/bus/pci/devices/$PCI/current_link_width" 2>/dev/null || echo '?')
echo "линия PCIe:      $LINK_SPEED  x$LINK_WIDTH"
[ "$LINK_WIDTH" = 4 ] || echo "  ВНИМАНИЕ: ширина линии не x4, возможна плохая посадка в слоте"

echo "свободно на цели: $(( $(cat "/sys/block/$(basename "$REAL")/size") * 512 / 1000000000 )) ГБ"
echo
echo 'ПРОВЕРКИ ПРОЙДЕНЫ'

# ------------------------------------------------------------ подтверждение
cat > /dev/tty <<MSG

------------------------------------------------------------------
  Сейчас будет ПОЛНОСТЬЮ СТЁРТ диск:

      $REAL
      $GOT_MODEL, серийный $GOT_SERIAL

  Системный диск $ROOTDISK не затрагивается.
  Отменить: Ctrl+C или любой ответ кроме yes.
------------------------------------------------------------------

MSG
printf 'напишите yes и нажмите Enter: ' > /dev/tty
read -r ANSWER < /dev/tty
echo "ответ пользователя: $ANSWER"
[ "$ANSWER" = yes ] || die 'отменено пользователем'

# ------------------------------------------------------------- шаг 1: disko
say 'ШАГ 1/5 — РАЗМЕТКА НОВОГО ДИСКА'
nix run github:nix-community/disko -- \
    --mode destroy,format,mount --flake "${FLAKE}#${ATTR}"

say 'проверяю результат разметки'
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL "$REAL"
for m in /mnt /mnt/boot /mnt/home /mnt/persist /mnt/nix; do
    findmnt -no TARGET,SOURCE "$m" || die "не смонтировано: $m"
done

# ------------------------------------------------- шаг 2: остановить Docker
say 'ШАГ 2/5 — ОСТАНАВЛИВАЮ DOCKER'
RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ' ' || true)
echo "работали контейнеры: ${RUNNING:-нет}"
echo "$RUNNING" > /home/igor/.docker-was-running
systemctl stop docker.socket  || true
systemctl stop docker.service || true
sleep 3
if awk '$2 ~ "^/persist/"' /proc/mounts | grep -q .; then
    echo 'ВНИМАНИЕ: под /persist остались точки монтирования:'
    awk '$2 ~ "^/persist/" {print "  " $2}' /proc/mounts
    die 'Docker не отпустил /persist, копировать нельзя'
fi
echo 'OK: /persist чист, вложенных монтирований нет'

# --------------------------------------------------- шаг 3: копирование
say 'ШАГ 3/5 — КОПИРУЮ /persist'
echo "объём: $(du -sh /persist 2>/dev/null | cut -f1)"
run_rsync -aHAX --partial --info=progress2 /persist/ /mnt/persist/

say 'КОПИРУЮ /home'
run_rsync -aHAX --partial --info=progress2 \
    --exclude='igor/.local/share/Steam/steamapps' \
    --exclude='igor/.cache' \
    --exclude='igor/java_error_in_idea.hprof' \
    --exclude='igor/iso' \
    /home/ /mnt/home/

say 'что получилось'
df -h /mnt /mnt/home /mnt/persist | sed 's/^/  /'
echo "  /mnt/home/igor:   $(du -sh /mnt/home/igor 2>/dev/null | cut -f1)"
echo "  /mnt/persist:     $(du -sh /mnt/persist 2>/dev/null | cut -f1)"

say 'выборочная проверка важного'
for f in /mnt/home/igor/.ssh /mnt/home/igor/.zsh_history /mnt/home/igor/dotfiles \
         /mnt/home/igor/backup /mnt/persist/etc/machine-id \
         /mnt/persist/var/lib/docker /mnt/persist/etc/NetworkManager/system-connections \
         /mnt/home/igor/.local/share/Steam/userdata; do
    if [ -e "$f" ]; then echo "  есть: $f"; else echo "  НЕТ:  $f"; fi
done

# ------------------------------------------------- шаг 4: установка системы
say 'ШАГ 4/5 — УСТАНАВЛИВАЮ СИСТЕМУ'
nixos-install --root /mnt --flake "${FLAKE}#${ATTR}" --no-root-passwd

# --------------------------------------- шаг 5: догнать изменения и Docker
say 'ШАГ 5/5 — ДОГОНЯЮ ИЗМЕНЕНИЯ В /home'
run_rsync -aHAX --partial --info=progress2 \
    --exclude='igor/.local/share/Steam/steamapps' \
    --exclude='igor/.cache' \
    --exclude='igor/java_error_in_idea.hprof' \
    --exclude='igor/iso' \
    /home/ /mnt/home/

say 'ВОЗВРАЩАЮ DOCKER'
systemctl start docker.socket docker.service || true
sleep 5
for c in $RUNNING; do docker start "$c" >/dev/null 2>&1 && echo "  запущен: $c" || echo "  не удалось запустить: $c"; done

say 'ГОТОВО'
cat <<'DONE'

Система установлена на новый диск. Дальше:

  1. Выключить компьютер:  shutdown -h now
  2. Вынуть кабель питания, открыть корпус
  3. Достать Patriot из верхнего слота M.2_1 у процессора.
     НЕ ВЫБРАСЫВАТЬ — нужен для гарантии в DNS.
  4. Дожать защёлку Kingston или вкрутить винт M2x3
  5. Закрыть корпус, включить
  6. Если не загрузится — Del при включении, раздел Boot,
     поставить Kingston первым

DONE
echo "полный журнал: $LOG"
