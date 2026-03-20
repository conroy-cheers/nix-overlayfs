{
  llvmMingwArm64ec = {
    version = "20250920";
    url = "https://github.com/bylaws/llvm-mingw/releases/download/20250920/llvm-mingw-20250920-ucrt-ubuntu-22.04-aarch64.tar.xz";
    hash = "sha256-vOXMdVxhNRX9ROHulSMSPYVBA6uuFHVxrbZFRQA2J00=";
  };

  wineArm64ec = {
    version = "11.3";
    url = "https://dl.winehq.org/wine/source/11.x/wine-11.3.tar.xz";
    hash = "sha256-u+QhWM/cZzKAlx4Ayb6CCwWBbI9qVouArngpwGxFXiQ=";
  };

  fexForWineDlls = {
    version = "2603^36.git.9eb639e";
    rev = "9eb639e89124b5976501029d886740b0e76c01c9";
    hash = "sha256-xE5/U/LOH97P0o30potbhN94mDqGNVN1dyLmc55Yu1M=";
  };
}
