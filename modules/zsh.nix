{
  homeModule =
    { ... }:
    {
      programs.zsh = {
        enable = true;
        autocd = false;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        oh-my-zsh = {
          enable = true;
          plugins = [
            "docker"
            "git"
            "golang"
            "gradle"
            "kubectl"
            "npm"
            "rust"
            "ssh"
            "systemd"
          ];
        };

        shellAliases = {
          edit = "sudo -e";
        };

        history = {
          size = 10000;
          ignoreAllDups = true;
          ignorePatterns = [
            "rm *"
            "pkill *"
            "cp *"
          ];
        };
      };
    };
}
