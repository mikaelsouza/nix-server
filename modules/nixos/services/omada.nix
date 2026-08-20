{
  config,
  lib,
  ...
}:

let
  cfg = config.my.services.omada;
in
{
  options.my.services.omada = {
    enable = lib.mkEnableOption "TP-Link Omada Software Controller as a Podman container";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open the Omada controller ports on all interfaces. Required so Omada
        devices on the LAN can adopt and be managed. Tailnet access works
        regardless via `networking.firewall.trustedInterfaces`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /home/mikaels/omada 0755 mikaels users -"
      "d /home/mikaels/omada/data 0755 mikaels users -"
      "d /home/mikaels/omada/logs 0755 mikaels users -"
    ];

    # Requires `virtualisation.podman.enable = true` (enabled by the
    # `my.services.virtualization` module). nixpkgs ships no Omada package, so
    # the controller runs from the community mbentley/omada-controller image.
    virtualisation.oci-containers = {
      backend = "podman";
      containers.omada = {
        image = "mbentley/omada-controller:6.2";
        autoStart = true;
        # Host networking is preferred by the image for reliable device adoption.
        environment = {
          TZ = "America/Sao_Paulo";
        };
        volumes = [
          "/home/mikaels/omada/data:/opt/tplink/EAPController/data"
          "/home/mikaels/omada/logs:/opt/tplink/EAPController/logs"
        ];
        extraOptions = [
          "--network=host"
          "--stop-timeout=60"
          "--ulimit=nofile=4096:8192"
          "--cpus=2"
          "--memory=4g"
          "--memory-swap=5g"
        ];
      };
    };

    # 8088/8043: management UI (HTTP/HTTPS), 8843/8844: captive portal,
    # 27001-27002: adoption + manager, 29811-29817: device management,
    # 27001/29810/19810 UDP: discovery/broadcast
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        8088
        8043
        8843
        8844
        27001
        27002
        29811
        29812
        29813
        29814
        29815
        29816
        29817
      ];
      allowedUDPPorts = [
        27001
        29810
        19810
      ];
    };
  };
}
