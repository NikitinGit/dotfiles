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
          efi.canTouchEfiVariables = true;
        };
        initrd.systemd.enable = true;
        kernelPackages = pkgs.linuxPackages_zen;
        kernel.sysctl."kernel.sysrq" = 1;
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
