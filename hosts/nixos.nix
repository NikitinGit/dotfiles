{ inputs, lib, ... }:
let
  self-lib = import ../lib.nix { inherit lib; };
  inherit (self-lib) modules getHomeModules getNixosModules;

  mkNixosConfiguration =
    {
      host,
      user,
      useremail,
      userdesc ? user,
      system,
      nixosStateVersion,
      homeStateVersion,
      hostModules ? [ ],
      hostConfig ? null,
      nixpkgs ? inputs.nixpkgs,
      home-manager ? inputs.home-manager,
    }:
    let
      specialArgs = inputs // {
        inherit
          inputs
          user
          useremail
          userdesc
          host
          ;
        username = user;
        hostname = host;
      };
    in
    {
      flake.nixosConfigurations.${host} = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          {
            system.stateVersion = nixosStateVersion;
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = []
            ++ (import ../overlays);

            nix = {
              gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 14d";
              };
              settings = {
                auto-optimise-store = true;
                experimental-features = [
                  "nix-command"
                  "flakes"
                ];
              };
            };
          }
          inputs.stylix.nixosModules.stylix
          inputs.disko.nixosModules.disko
          inputs.preservation.nixosModules.preservation
          inputs.lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              inputs.nix-index-database.homeModules.nix-index
            ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.${user} =
              { pkgs, ... }:
              {
                imports = getHomeModules hostModules;
                home = {
                  username = user;
                  homeDirectory = "/home/${user}";
                  stateVersion = homeStateVersion;
                };
              };
          }
        ]
        ++ getNixosModules hostModules
        ++ lib.optional (hostConfig != null) hostConfig;
      };
    };

  igor-desktop = import ./igor-desktop { inherit modules; };

in
{
  flake.colmena =
    let
      conf = inputs.self.nixosConfigurations;
    in
    {
      meta = {
        nixpkgs = import inputs.nixpkgs-stable { system = "x86_64-linux"; };
        nodeNixpkgs = builtins.mapAttrs (name: value: value.pkgs) conf;
        nodeSpecialArgs = builtins.mapAttrs (name: value: value._module.specialArgs) conf;
      };
    };

  imports = [
    (mkNixosConfiguration {
      inherit (igor-desktop)
        host
        system
        user
        useremail
        userdesc
        nixosStateVersion
        homeStateVersion
        ;
      hostModules = igor-desktop.modules;
      hostConfig = igor-desktop.config;
    })
  ];
}
