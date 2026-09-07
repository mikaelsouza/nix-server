{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.services.autoUpdate;
in
{
  options.my.services.autoUpdate = {
    enable = lib.mkEnableOption "daily flake.lock updates pushed to the GitOps branch";

    repository = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:mikaelsouza/nix-server.git";
      description = "SSH remote to pull from and push the refreshed lock to.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch Comin deploys from, and therefore the branch to update.";
    };

    deployKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nix-server/deploy-key";
      description = ''
        Path to a host-local SSH private key with push access to
        `repository`, read by the unit as root. Either an account key already
        on the host, or a repo-scoped GitHub deploy key with "Allow write
        access" — the latter limits the blast radius to this one repository.
        Never commit it. Without it the timer fails and the lock simply stops
        moving.
      '';
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for the update check.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Bumping flake.lock in git is the only way new nixpkgs reaches this host:
    # Comin deploys the committed lock, so `system.autoUpgrade` would both
    # fight Comin for the system profile and still rebuild the same pins.
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
        # oneshot units default to DefaultTimeoutStartSec (90s); building a
        # system closure routinely takes longer than that.
        TimeoutStartSec = "6h";
      };

      script = ''
        mkdir -p "$HOME/.ssh"
        export GIT_SSH_COMMAND="ssh -i ${cfg.deployKeyFile} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
        export GIT_AUTHOR_NAME="silmeria auto-update"
        export GIT_AUTHOR_EMAIL="auto-update@silmeria.local"
        export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
        export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

        if [ ! -d repo/.git ]; then
          git clone --branch ${cfg.branch} ${cfg.repository} repo
        fi
        cd repo

        # Discard anything left behind by a failed run and match the remote.
        git remote set-url origin ${cfg.repository}
        git fetch --prune origin ${cfg.branch}
        git checkout ${cfg.branch}
        git reset --hard origin/${cfg.branch}

        nix flake update --commit-lock-file

        if git diff --quiet origin/${cfg.branch} HEAD; then
          echo "flake.lock already current; nothing to push"
          exit 0
        fi

        # Build before pushing: Comin fails safe on a broken build, but there
        # is no reason to hand it one we could have caught here.
        nix build --no-link .#nixosConfigurations.${config.networking.hostName}.config.system.build.toplevel

        git push origin ${cfg.branch}
        echo "pushed refreshed flake.lock; Comin will deploy it on its next poll"
      '';
    };

    systemd.timers.nix-server-auto-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.dates;
        Persistent = true;
        RandomizedDelaySec = "45min";
      };
    };
  };
}
