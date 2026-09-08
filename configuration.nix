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
  # See HARDWARE.md.
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
  # Installs direnv, hooks it into zsh, and enables nix-direnv.
  programs.direnv.enable = true;

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

  # The nixpkgs module already hardens this unit heavily (PrivateDevices,
  # ProtectHome, RestrictSUIDSGID, an empty CapabilityBoundingSet, …) but leaves
  # the filesystem writable and privilege escalation open. The server only ever
  # writes under its dataDir, plus the private /tmp it already gets.
  systemd.services.minecraft-server.serviceConfig = {
    ProtectSystem = "strict";
    ReadWritePaths = [ config.services.minecraft-server.dataDir ];
    NoNewPrivileges = true;
  };

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
    # Bind the metrics exporter to loopback. The firewall already blocks 4243 on
    # every interface, but the wildcard bind meant any future port rule or
    # trusted interface would silently re-expose it.
    exporter.listen_address = "127.0.0.1";
  };

  # Pin github.com's host key so the auto-update unit below can require it
  # (`StrictHostKeyChecking=yes`) instead of trusting whatever answers first.
  # Value cross-checked against https://api.github.com/meta over HTTPS and a
  # live ssh-keyscan; both agree. Written to /etc/ssh/ssh_known_hosts, which the
  # system ssh_config reads as GlobalKnownHostsFile.
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

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
      export GIT_SSH_COMMAND="ssh -i ${deployKeyFile} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"
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

  # Comin activates a new generation but never reboots, so a kernel or systemd
  # update would otherwise sit unused until someone noticed. Reboot daily at
  # 06:00 local time to bound that lag.
  #
  # `Persistent` is deliberately left false: with it on, a machine that was down
  # at 06:00 would reboot again immediately on the next boot.
  systemd.services.scheduled-reboot = {
    description = "Daily reboot to pick up new kernels";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reboot";
    };
  };

  systemd.timers.scheduled-reboot = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*-*-* 06:00:00";
  };

  # Stateful data release version (do not change unless you read the manual).
  system.stateVersion = "25.11";
}
