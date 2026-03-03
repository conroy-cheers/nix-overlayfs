{
  fetchurl,
  wine,
  overlayfsLib,
}:
let
  srcX86 = fetchurl {
    url = "https://download.visualstudio.microsoft.com/download/pr/6f02464a-5e9b-486d-a506-c99a17db9a83/E7267C1BDF9237C0B4A28CF027C382B97AA909934F84F1C92D3FB9F04173B33E/VC_redist.x86.exe";
    hash = "sha256-5yZ8G9+SN8C0oozwJ8OCuXqpCZNPhPHJLT+58EFzsz4=";
  };
  srcX64 = fetchurl {
    url = "https://download.visualstudio.microsoft.com/download/pr/6f02464a-5e9b-486d-a506-c99a17db9a83/8995548DFFFCDE7C49987029C764355612BA6850EE09A7B6F0FDDC85BDC5C280/VC_redist.x64.exe";
    hash = "sha256-iZVUjf/83nxJmHApx2Q1VhK6aFDuCae28P3chb3FwoA=";
  };
in
overlayfsLib.mkWinePackage {
  inherit wine;
  pname = "vcrun";
  version = "2022";
  src = srcX86;
  packageName = "vcrun2022";
  unshareInstall =
    { wineExe }:
    ''
      install_redist() {
        local status=0

        "${wineExe}" "$1" /quiet /norestart || status=$?
        if [ "$status" -ne 0 ] && [ "$status" -ne 194 ]; then
          exit "$status"
        fi
      }

      install_redist "${srcX86}"
      ${if wine.wineArch != "win32" then ''install_redist "${srcX64}"'' else ""}
      wineserver --wait
    '';
}
