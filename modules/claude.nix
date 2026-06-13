{
  homeModule =
    { config, pkgs, ... }:
    {
      programs.claude-code = {
        enable = true;

        lspServers = {
          go = {
            command = "${pkgs.gopls}/bin/gopls";
            args = [ "serve" ];
            extensionToLanguage = {
              ".go" = "go";
            };
          };
          typescript = {
            command = "${pkgs.typescript-language-server}/bin/typescript-language-server";
            args = [ "--stdio" ];
            extensionToLanguage = {
              ".ts" = "typescript";
              ".tsx" = "typescriptreact";
              ".js" = "javascript";
              ".jsx" = "javascriptreact";
            };
          };
          rust = {
            command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
            extensionToLanguage = {
              ".rs" = "rust";
            };
          };
          nix = {
            command = "${pkgs.nixd}/bin/nixd";
            extensionToLanguage = {
              ".nix" = "nix";
            };
          };
          python = {
            command = "${pkgs.ruff}/bin/ruff";
            args = [ "server" ];
            extensionToLanguage = {
              ".py" = "python";
            };
          };
          zig = {
            command = "${pkgs.zls}/bin/zls";
            extensionToLanguage = {
              ".zig" = "zig";
            };
          };
          elixir = {
            command = "${pkgs.beam28Packages.elixir-ls}/bin/elixir-ls";
            extensionToLanguage = {
              ".ex" = "elixir";
              ".exs" = "elixir";
            };
          };
          yaml = {
            command = "${pkgs.yaml-language-server}/bin/yaml-language-server";
            args = [ "--stdio" ];
            extensionToLanguage = {
              ".yaml" = "yaml";
              ".yml" = "yaml";
            };
          };
          toml = {
            command = "${pkgs.taplo}/bin/taplo";
            args = [
              "lsp"
              "stdio"
            ];
            extensionToLanguage = {
              ".toml" = "toml";
            };
          };
        };

        mcpServers = {
          playwright = {
            command = "npx";
            args = [
              "@playwright/mcp@latest"
              "--browser"
              "chromium"
            ];
            type = "stdio";
          };
        };
      };
    };
}
