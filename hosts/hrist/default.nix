{ ... }:

{
  imports = [
    ../../modules/common
    ../../modules/darwin
  ];

  networking.hostName = "hrist";
  system.stateVersion = 5;
}
