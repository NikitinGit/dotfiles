{
  homeModule =
    { pkgs, ... }:

    {
      home.packages =
        with pkgs;
        [
          biome
          bun
          nodejs_24
          typescript-language-server
        ]
        ++ (with pkgs; [
          npm-check-updates
          tsx
        ]);
    };
}
