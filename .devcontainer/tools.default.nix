{ pkgs, ... }:

{
  home = {
    stateVersion = "24.05";
    packages = [ pkgs.gnumake ] ++ import ../dependencies.nix { inherit pkgs; };

    sessionVariables = {
      EDITOR = "code --wait";
    };
  };

  programs = {
    home-manager.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    bash.enable = true;

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "history"
        ];
        theme = "robbyrussell";
      };

      initContent = ''
        source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        source "${pkgs.nix-zsh-completions}/share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh"
        source "${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use/you-should-use.plugin.zsh"
        source "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh"
        source "${pkgs.zsh-forgit}/share/zsh/zsh-forgit/forgit.plugin.zsh"
        source "${pkgs.zsh-fzf-history-search}/share/zsh-fzf-history-search/zsh-fzf-history-search.plugin.zsh"

        zstyle ':completion:*:descriptions' format '%d'
        zstyle ':fzf-tab:*' group-colors '''
      '';
    };
  };
}
