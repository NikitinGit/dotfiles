{
  homeModule =
    { pkgs, ... }:

    {
      programs.java = {
        enable = true;
      };

      home.packages = with pkgs; [
        jdt-language-server
        keystore-explorer
        visualvm
      ];
    };

  nixosModule =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        eclipse-mat
      ];
    };
}
