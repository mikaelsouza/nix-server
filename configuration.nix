{
  config,
  pkgs,
  pkgs-unstable,
  ...
}:

let
  # Repo the auto-update timer pulls from and pushes the refreshed lock to.
  repository = "git@github.com:mikaelsouza/nix-server.git";
  branch = "main";
  # Repo-scoped GitHub deploy key with write access, root-only, never committed.
  deployKeyFile = "/etc/nix-server/deploy-key";
in
{
  imports = [ ./hardware-configuration.nix ];

  # --- Nix -----------------------------------------------------------------

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Comin builds a new closure on every push to main; nothing else reclaims it.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # --- Boot and hardware ---------------------------------------------------

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # /boot is a 1G vfat partition and comin adds a generation per push.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Override Dell's ACPI FADT `no ASPM` flag so the CPU reaches package C8/C10.
  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersupersave"
  ];
  powerManagement.powertop.enable = true;

  # --- Networking ----------------------------------------------------------

  networking.hostName = "silmeria";
  networking.networkmanager.enable = true;

  # DNS is static, not from DHCP. The router reboots daily and flaps enp1s0;
  # NetworkManager re-registers its resolvconf record ~10s after the link
  # returns, so tailscaled recomputed upstreams from an empty list and
  # SERVFAILed every query until restarted. The DHCP lease also advertises an
  # off-subnet resolver (192.168.1.1) that stalls ~5s per lookup. `dns = "none"`
  # keeps NetworkManager off resolv.conf; `nameservers` registers a static
  # record from a unit that does not depend on link state.
  networking.networkmanager.dns = "none";
  networking.nameservers = [
    "192.168.0.1"
    "1.1.1.1"
    "1.0.0.1"
  ];

  # --- Locale --------------------------------------------------------------

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Console keymap (this host is headless; there is no X11 server to configure)
  console.keyMap = "us";

  # --- Users and shell -----------------------------------------------------

  users.users.mikaels = {
    isNormalUser = true;
    description = "Mikael Souza";
    # Must match programs.zsh below, or direnv's zsh hook never runs.
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    # Declared here so a rebuild onto fresh hardware is still reachable.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMC624R5uwRjD8KVkbHZKolaXSRX8E6kzbJD3U+WUyXJ mikaelsouza@hrist.local"
    ];
  };

  programs.zsh.enable = true;
  programs.zsh.interactiveShellInit = ''
    eval "$(direnv hook zsh)"
  '';

  # --- Packages ------------------------------------------------------------

  # `system.path` sets `ignoreCollisions = true`, so on a file collision the
  # earlier entry wins. Order is load-bearing; leave it alone.
  environment.systemPackages = [
    pkgs.vim
    pkgs.powertop
    pkgs.python3
    pkgs-unstable.antigravity-cli
    pkgs-unstable.claude-code
    pkgs.git
    pkgs.neovim
    pkgs.nixd
    pkgs.direnv
    pkgs.uv
  ];

  # --- SSH -----------------------------------------------------------------

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  # --- Tailscale -----------------------------------------------------------

  # `authKeyFile` stays unset: an auth key is single-use enrollment state and
  # tailscaled persists its own login, so pointing it at a missing path makes
  # `tailscaled-autoconnect` fail the next time the node logs in.
  #
  # `tailscale0` is deliberately NOT in `firewall.trustedInterfaces`: tailnet
  # peers are firewalled like anyone else and each service opens its own port.
  services.tailscale.enable = true;

  # --- Minecraft -----------------------------------------------------------

  services.minecraft-server = {
    enable = true;
    eula = true;
    declarative = true; # required for serverProperties to take effect
    openFirewall = false; # 25565 is opened on tailscale0 only, below
    package = pkgs.papermc;
    jvmOpts = "-Xms10G -Xmx10G -XX:+UseG1GC";
    # LOCKED (README): offline-mode with no whitelist is deliberate. 25565 is
    # reachable only over Tailscale, so tailnet membership is the access control.
    serverProperties.online-mode = false;
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 25565 ];

  # --- GitOps deployment ---------------------------------------------------

  # Comin polls this repository and switches the system on every push to `main`.
  # A broken evaluation fails safe: the previous generation keeps running.
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/mikaelsouza/nix-server.git";
        branches.main.name = "main";
        branches.testing.name = ""; # skip the nonexistent testing branch
        # Host-local, root-only, never committed. The repository is private.
        auth.access_token_path = "/etc/comin/access_token";
      }
    ];
  };

  # Comin deploys the committed lock, so bumping `flake.lock` in git is the only
  # way new nixpkgs reaches this host. `system.autoUpgrade` would fight comin for
  # the system profile and rebuild the same pins anyway.
  systemd.services.nix-server-auto-update = {
    description = "Refresh flake.lock and push it for Comin to deploy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [
      pkgs.git
      pkgs.openssh
      config.nix.package
    ];

    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "nix-server-auto-update";
      WorkingDirectory = "/var/lib/nix-server-auto-update";
      Environment = [ "HOME=/var/lib/nix-server-auto-update" ];
      # oneshot defaults to 90s; building a system closure takes longer.
      TimeoutStartSec = "6h";
    };

    script = ''
      mkdir -p "$HOME/.ssh"
      export GIT_SSH_COMMAND="ssh -i ${deployKeyFile} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
      export GIT_AUTHOR_NAME="silmeria auto-update"
      export GIT_AUTHOR_EMAIL="auto-update@silmeria.local"
      export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
      export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

      if [ ! -d repo/.git ]; then
        git clone --branch ${branch} ${repository} repo
      fi
      cd repo

      # Discard anything left by a failed run and match the remote.
      git remote set-url origin ${repository}
      git fetch --prune origin ${branch}
      git checkout ${branch}
      git reset --hard origin/${branch}

      nix flake update --commit-lock-file

      if git diff --quiet origin/${branch} HEAD; then
        echo "flake.lock already current; nothing to push"
        exit 0
      fi

      # Comin fails safe on a broken build, but catch it here first.
      nix build --no-link .#nixosConfigurations.${config.networking.hostName}.config.system.build.toplevel

      git push origin ${branch}
      echo "pushed refreshed flake.lock; Comin will deploy it on its next poll"
    '';
  };

  systemd.timers.nix-server-auto-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "45min";
    };
  };

  # Stateful data release version (do not change unless you read the manual).
  system.stateVersion = "25.11";
}
