{ ... }:

{
  # GitOps configuration deployment via Comin
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/mikaelsouza/nix-server.git";
        branches.main.name = "main";
      }
    ];
  };

  # OpenSSH daemon settings
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };

  # Firewall configuration
  networking.firewall.allowedTCPPorts = [
    22
    2222
  ];
}
