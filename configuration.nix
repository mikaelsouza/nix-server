{
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/auto-update.nix
    ./modules/comin.nix
    ./modules/minecraft.nix
  ];

  # --- Nix -----------------------------------------------------------------

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Collect garbage and deduplicate the store: comin builds a new system
  # closure on every push to main, and nothing else ever reclaims it.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # --- Boot and hardware ---------------------------------------------------

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Bound the ESP: comin builds a generation per push, and /boot is a 1G vfat partition.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Hardware power management & PCIe ASPM
  # Force PCIe ASPM to override Dell BIOS FADT ACPI restrictions, allowing package C8/C10
  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersupersave"
  ];

  # Enable powertop auto-tuning on startup for runtime PM across PCI/USB/SATA devices
  powerManagement.powertop.enable = true;

  # --- Networking ----------------------------------------------------------

  networking.hostName = "silmeria";
  networking.networkmanager.enable = true;

  # DNS is pinned statically rather than taken from DHCP, for two reasons:
  #
  #   1. The LAN router reboots daily around 06:00 and flaps enp1s0 for ~60s.
  #      tailscaled recomputes its upstream resolvers on a link change, reading
  #      them from resolvconf, but NetworkManager re-registers its DHCP-derived
  #      record ~10s *after* the link returns. tailscaled therefore read an
  #      empty list, pinned `Routes:{.:[]}`, and answered every query with
  #      SERVFAIL until restarted. Routes stayed up, so the host remained
  #      reachable over SSH/Tailscale while all outbound lookups failed.
  #   2. That DHCP lease also advertises 192.168.1.1, which is off-subnet and
  #      unroutable here, so each lookup stalled ~5s before falling back.
  #
  # `dns = "none"` keeps NetworkManager off resolv.conf, and networking.nameservers
  # registers a static resolvconf record (`resolvconf -m 1 -a static`) from a
  # oneshot unit that does not depend on link state. tailscaled then always reads
  # a non-empty upstream list, flap or not. The gateway stays first so LAN names
  # still resolve; the public resolvers cover the router's reboot window.
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
    # Match the shell that programs.zsh configures below, otherwise the direnv
    # hook in programs.zsh.interactiveShellInit never runs.
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

  # `system.path` is a buildEnv with `ignoreCollisions = true`: when two
  # packages ship the same file, the earlier entry silently wins. This order is
  # the one the pre-flattening module layout produced, so it is kept as-is.
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

  # `authKeyFile` is deliberately left unset. An auth key is single-use
  # enrollment state and tailscaled persists its own login afterwards, so
  # pointing the option at a path that does not exist makes
  # `tailscaled-autoconnect.service` fail the next time the node has to log in.
  # Set it only while enrolling this node, then clear it again.
  #
  # The tailnet is NOT blanket-trusted: `tailscale0` is deliberately absent
  # from `networking.firewall.trustedInterfaces`, so the firewall applies to
  # tailnet peers like any other network. Each service opens only the port it
  # needs on `tailscale0` (see `modules/minecraft.nix` for 25565/tcp); SSH is
  # already covered by the global `allowedTCPPorts = [ 22 ]` above. Tailscale's
  # own UDP underlay (port 41641) rides the physical interface, not
  # `tailscale0`, so it is unaffected by these rules.
  services.tailscale.enable = true;

  # Stateful data release version (do not change unless read the manual)
  system.stateVersion = "25.11";
}
