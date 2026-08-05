{ ... }:

{
  programs.zsh.enable = true;
  programs.zsh.interactiveShellInit = ''
    eval "$(direnv hook zsh)"
  '';
}
