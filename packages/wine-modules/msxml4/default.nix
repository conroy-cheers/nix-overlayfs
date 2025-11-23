{
  fetchurl,
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinePackage {
  inherit wine;
  pname = "msxml";
  version = "4.0";
  src = fetchurl {
    url = "https://web.archive.org/web/20210506101448/http://download.microsoft.com/download/A/2/D/A2D8587D-0027-4217-9DAD-38AFDB0A177E/msxml.msi";
    hash = "sha256-R8KuZ5w3gV2pJnyB/Dd33pAK0lUcEcGcKECTizRtcLs=";
  };
  unshareInstall =
    { wineExe }:
    ''
      ${wineExe} msiexec /i $src /q
      wineserver --wait
    '';
  packageName = "msxml4";
}
