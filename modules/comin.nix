{ ... }:

{
  # GitOps: comin polls this repository and switches the system on every push
  # to `main`. A broken evaluation fails safe — the previous generation keeps
  # running — but `main` is still live production. See README (GitOps).
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/mikaelsouza/nix-server.git";
        branches.main.name = "main";
        # Empty name makes comin skip the (nonexistent) testing branch
        branches.testing.name = "";
        # Host-local, root-only, never committed. The repository is private.
        auth.access_token_path = "/etc/comin/access_token";
      }
    ];
  };
}
