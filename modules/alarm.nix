{
  homeModule =
    { pkgs, ... }:
    let
      stateDir = ".config/alarm-clock";
      stateFileRel = "${stateDir}/state";

      alarmNotify = pkgs.writeShellApplication {
        name = "alarm-notify";
        runtimeInputs = [
          pkgs.libnotify
          pkgs.pipewire
          pkgs.sound-theme-freedesktop
        ];
        text = ''
          notify-send -u critical -i appointment-soon "Будильник" "Прошёл ещё один час"
          pw-play "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" || true
        '';
      };

      alarmCheck = pkgs.writeShellApplication {
        name = "alarm-check";
        runtimeInputs = [ alarmNotify ];
        text = ''
          state="$HOME/${stateFileRel}"
          mkdir -p "$HOME/${stateDir}"
          [ -f "$state" ] || printf 'enabled=1\nminute=0\nlast=\n' > "$state"

          # shellcheck source=/dev/null
          . "$state"

          now_minute="$(date +%M)"
          now_hour_key="$(date +%Y%m%d%H)"
          want_minute="$(printf '%02d' "''${minute:-0}")"

          if [ "''${enabled:-1}" = "1" ] && [ "$now_minute" = "$want_minute" ] && [ "''${last:-}" != "$now_hour_key" ]; then
            alarm-notify
            if grep -q '^last=' "$state"; then
              sed -i "s/^last=.*/last=$now_hour_key/" "$state"
            else
              echo "last=$now_hour_key" >> "$state"
            fi
          fi
        '';
      };

      alarmctl = pkgs.writeShellApplication {
        name = "alarmctl";
        text = ''
          state="$HOME/${stateFileRel}"
          mkdir -p "$HOME/${stateDir}"
          [ -f "$state" ] || printf 'enabled=1\nminute=0\nlast=\n' > "$state"

          usage() {
            echo "Использование: alarmctl on|off|status|set <минута 0-59>" >&2
          }

          # shellcheck source=/dev/null
          . "$state"

          case "''${1:-}" in
            on)
              sed -i 's/^enabled=.*/enabled=1/' "$state"
              echo "Будильник включен (срабатывает каждый час в :$(printf '%02d' "''${minute:-0}")"
              ;;
            off)
              sed -i 's/^enabled=.*/enabled=0/' "$state"
              echo "Будильник выключен"
              ;;
            set)
              m="''${2:-}"
              if ! [ "$m" -eq "$m" ] 2>/dev/null || [ "$m" -lt 0 ] || [ "$m" -gt 59 ]; then
                echo "Минута должна быть числом от 0 до 59" >&2
                exit 1
              fi
              sed -i "s/^minute=.*/minute=$m/" "$state"
              echo "Будильник будет срабатывать каждый час в :$(printf '%02d' "$m")"
              ;;
            status)
              # shellcheck source=/dev/null
              . "$state"
              if [ "''${enabled:-1}" = "1" ]; then
                echo "Статус: включен, срабатывает каждый час в :$(printf '%02d' "''${minute:-0}")"
              else
                echo "Статус: выключен"
              fi
              ;;
            *)
              usage
              exit 1
              ;;
          esac
        '';
      };
    in
    {
      home.packages = [
        alarmctl
        alarmNotify
        alarmCheck
      ];

      systemd.user.services.alarm-check = {
        Unit.Description = "Проверка часового будильника";
        Service = {
          Type = "oneshot";
          ExecStart = "${alarmCheck}/bin/alarm-check";
        };
      };

      systemd.user.timers.alarm-check = {
        Unit.Description = "Таймер проверки часового будильника";
        Timer = {
          OnStartupSec = "30s";
          OnUnitActiveSec = "60s";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
