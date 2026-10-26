{ modules }:

{
  host = "igor-desktop";
  system = "x86_64-linux";
  user = "igor";
  useremail = "andnikitn5@gmail.com";
  userdesc = "Igor Nikitin";

  nixosStateVersion = "25.05";
  homeStateVersion = "26.05";

  modules = with modules; [
    audio
    bluetooth
    de.gnome
    games
    locale
    shell.zsh
    stylix

    alarm
    claude
    bat
    btop
    docker
    eza
    firefox
    fd
    git
    helix
    k8s
    lazydocker
    lazygit
    neovim
    nix-index
    nvidia
    postgresql
    ripgrep
    skim
    starship
    tealdeer
    yazi
    zed
    zsh

    languages.go
    languages.jdk
    languages.js
    languages.kotlin
    languages.python
    languages.rust
  ];

  config =
    {
      pkgs,
      inputs,
      hostname,
      username,
      userdesc,
      ...
    }:
    {
      imports = [
        inputs.nixos-facter-modules.nixosModules.facter
        ./storage.nix
      ];

      facter.reportPath = ./facter.json;

      security.sudo.enable = false;
      security.sudo-rs = {
        enable = true;
        execWheelOnly = false;
      };

      programs.coolercontrol.enable = true;

      security = {
        polkit.enable = true;
      };

      # Suppress systemd-machine-id-commit.service since machine-id is persisted via preservation
      systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

      services.printing.enable = true;

      hardware = {
        cpu.intel.updateMicrocode = true;
        graphics = {
          enable = true;
          enable32Bit = true;
        };
      };

      networking = {
        hostName = hostname;
        networkmanager.enable = true;
        firewall.enable = false;
      };
      
      networking.extraHosts =
      ''
        127.0.0.1 local.strikerstat-stage.twc1.net
        127.0.0.1 local.strikerstat-preprod.twc1.net
      '';

      boot = {
        loader = {
          systemd-boot.enable = true;
          systemd-boot.memtest86.enable = true; # ВРЕМЕННО: проверка памяти из меню загрузки
          efi.canTouchEfiVariables = true;
        };
        initrd.systemd.enable = true;
        kernelPackages = pkgs.linuxPackages_zen;
        kernel.sysctl."kernel.sysrq" = 1;

        # Super I/O материнки (NCT6798D на PRIME Z690-A): обороты вентиляторов
        # и напряжения. Без этого CoolerControl не видит кулеры вообще.
        kernelModules = [ "nct6775" ];
        kernelParams = [
          "acpi_enforce_resources=lax"

          # ВРЕМЕННО: отключаем энергосбережение шины PCIe и глубокие состояния
          # простоя процессора. Windows задействует их куда осторожнее, а на
          # этой машине зависания случаются в том числе в полном простое.
          "pcie_aspm=off"
          "intel_idle.max_cstate=1"

          # Диск Patriot P400 отваливался в простое (systemd: "Failed to spawn
          # executor: Input/output error"). Запрещаем NVMe уходить в глубокие
          # состояния сна.
          "nvme_core.default_ps_max_latency_us=0"

          # Запрещаем диску одалживать системную память под свою таблицу
          # адресов (HMB). Было 128 МБ в 32 сегментах — способ выделения в
          # Linux отличается от Windows, под который отлажена прошивка.
          # Последний непроверенный механизм. Снять после замены накопителя.
          "nvme.max_host_mem_size_mb=0"

          # Диагностика: превращаем oops и зависания в панику, чтобы ядро
          # сбросило отчёт в pstore. panic=0 — не перезагружаться, текст
          # остаётся на экране для фото.
          "oops=panic"
          "softlockup_panic=1"
          "nmi_watchdog=panic"
          "panic=0"
        ];
      };

      # ВРЕМЕННО: режем потолок мощности видеокарты со 160 до 120 Вт.
      # Причина: диск отвалился с шины PCIe ровно в тот момент, когда GPU
      # потребляла 159.46 Вт из 160. Проверяем версию с просадкой питания.
      systemd.services.gpu-power-limit = {
        description = "Ограничение мощности видеокарты";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # "-" в начале: не валить активацию, если драйвер в ядре и nvidia-smi
          # разошлись в версиях после обновления (лечится перезагрузкой).
          ExecStart = "-/run/current-system/sw/bin/nvidia-smi -pl 120";
        };
      };

      # ВРЕМЕННО, диагностика зависаний: раз в 30 с пишем в журнал состояние
      # видеокарты, процессора и давление подсистем (PSI). Зависает графика,
      # а ядро и systemd живут — значит журнал сохранит последние показания.
      systemd.services.hw-sampler = {
        description = "Сбор показаний железа для диагностики зависаний";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.lm_sensors pkgs.coreutils pkgs.gawk ];
        serviceConfig = {
          Restart = "always";
          RestartSec = 10;
        };
        script = ''
          while true; do
            gpu=$(/run/current-system/sw/bin/nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu,power.draw,clocks_event_reasons.hw_slowdown --format=csv,noheader,nounits 2>/dev/null | tr -d " ")
            cpu=$(sensors 2>/dev/null | awk '/Package id 0/{print $4}')
            fan=$(sensors 2>/dev/null | awk '/^fan2:/{print $2}')
            load=$(cut -d" " -f1-3 /proc/loadavg)
            mem=$(awk '/MemAvailable/{printf "%.1fG", $2/1048576}' /proc/meminfo)
            psi_io=$(awk '/^some/{print $2}' /proc/pressure/io)
            psi_cpu=$(awk '/^some/{print $2}' /proc/pressure/cpu)
            psi_mem=$(awk '/^some/{print $2}' /proc/pressure/memory)
            echo "HW gpu=$gpu cpu=$cpu fan2=$fan load=$load memfree=$mem io=$psi_io cpu_psi=$psi_cpu mem_psi=$psi_mem"
            sleep 30
          done
        '';
      };

      # ВРЕМЕННО: режем лимиты мощности CPU со штатных 125/181 Вт.
      # Причина: под нагрузкой процессор упирается в TjMax 100 C за 5 секунд
      # при исправно работающем вентиляторе (fan2 разгоняется до 2160 RPM),
      # то есть отказал термоинтерфейс. Снять после переборки охлаждения.
      systemd.services.cpu-power-limit = {
        description = "Ограничение PL1/PL2 процессора";
        wantedBy = [ "multi-user.target" ];
        after = [ "sysinit.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          echo 95000000  > /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
          echo 110000000 > /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw
        '';
      };

      home-manager.users.${username} = {
        services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;

        xdg.configFile."autostart/org.coolercontrol.CoolerControl.desktop".source =
          "${pkgs.coolercontrol.coolercontrol-gui}/share/applications/org.coolercontrol.CoolerControl.desktop";
      };

      users = {
        defaultUserShell = pkgs.zsh;
        mutableUsers = false;
        users.${username} = {
          isNormalUser = true;
          description = userdesc;
          extraGroups = [
            "networkmanager"
            "wheel"
            "docker"
          ];
          hashedPassword = "$6$KsXM94WpuFhxSCjz$ci5yTkLvgsOtFbS/ARWWM6lsEjMBo4mKxUuwDxQ3K3LEwU9d/SY0uA.GlCDqulDWOfC0KzTgejqhbvXPlMS6c.";
        };
      };

      environment.systemPackages = with pkgs; [
        nh
        home-manager

        # sensors
        lm_sensors
        coolercontrol.coolercontrold
        coolercontrol.coolercontrol-ui-data

        pinentry-gnome3

        brave
        discord
        gnumake
        gpg-tui
        insomnia
        just
        libreoffice-qt
        prismlauncher
        telegram-desktop
        tor-browser
        usbutils
        jetbrains.idea
        mariadb
        obsidian
        obs-studio
        google-chrome
        gcc
        zoom-us
        maven
        gh
        wireguard-tools
        php
        phpPackages.composer
        drawing
        sing-box
      ];

      programs.amnezia-vpn.enable = true;

      programs.throne = {
        enable = true;
        tunMode.enable = true;
      };
    };
}
