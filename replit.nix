{ pkgs }: {
  deps = [
    pkgs.pkg-config
    pkgs.zlib
    pkgs.openssl
    pkgs.hiredis
    pkgs.postgresql
    pkgs.bashInteractive
    pkgs.nodePackages.bash-language-server
    pkgs.man
  ];
}