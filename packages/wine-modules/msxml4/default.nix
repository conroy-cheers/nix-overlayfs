{
  fetchurl,
  wine,
  nix-overlayfs,
}:
nix-overlayfs.lib.mkWinePackage {
  inherit wine;
  pname = "msxml";
  version = "4.0";
  src = fetchurl {
    url = "https://web.archive.org/web/20120202055700/http://download.microsoft.com/download/A/2/D/A2D8587D-0027-4217-9DAD-38AFDB0A177E/msxml.msi";
    hash = "sha256-oqJ1aa27C2padzpP6KTx5dKM3TRk/w7npiWHmcpU+bI=";
  };
  silentFlags = "/qn";
  packageName = "msxml4";
}
