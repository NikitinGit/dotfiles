{
  nixosModule =
    { pkgs, ... }:
    let
      opacity = 0.95;
      fontSize = 12;
    in
    {
      stylix = {
        enable = true;

        polarity = "dark";

        base16Scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";

        opacity = {
          terminal = opacity;
          popups = opacity;
        };

        fonts = {
          serif = {
            package = pkgs.inter;
            name = "Inter";
          };

          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };

          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font";
          };

          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };

          sizes = {
            applications = 11;
            desktop = fontSize;
            popups = fontSize;
            terminal = 12;
          };
        };
      };
    };
}
