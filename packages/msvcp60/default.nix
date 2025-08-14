{
  pkgs,
  nix-overlayfs,
}:
nix-overlayfs.lib.mkWinePackage {
  pname = "msvcp";
  version = "6.0";
  src = pkgs.fetchurl {
    url = "https://web.archive.org/web/20120627225622/http://download.microsoft.com/download/vc60pro/update/1/w9xnt4/en-us/vc6redistsetup_enu.exe";
    hash = "sha256-z50N2WjnjV5oWm6mq1jsQ4rArCQxaxTScbAs88ztZ9k=";
  };
  silentFlags = "/qn";
  packageName = "msvcp60";
}
