{
  pkgs,
  callPackage,
  fetchurl,
  llvmMingwArm64ec,
  versions,
}:
let
  release = versions.wineArm64ec;
  baseWine = callPackage "${pkgs.path}/pkgs/applications/emulators/wine/base.nix" {
    pname = "wine-arm64ec";
    inherit (release) version;
    src = fetchurl {
      inherit (release) url hash;
    };
    patches = [
      ../patches/wine-11.3-arm64ec-bylaws.patch
      ../patches/wine-arm64x-basereloc-fix.patch
      ../patches/wine-arm64ec-worklist-fallback.patch
    ];
    pkgArches = [ pkgs ];
    mingwSupport = true;
    mingwGccs = [ llvmMingwArm64ec ];
    geckos = [ ];
    monos = [ ];
    configureFlags = [
      "--enable-archs=arm64ec,aarch64,i386"
      "--disable-tests"
    ];
    platforms = [ "aarch64-linux" ];
    mainProgram = "wine";

    gettextSupport = true;
    fontconfigSupport = true;
    alsaSupport = true;
    openglSupport = true;
    vulkanSupport = true;
    tlsSupport = true;
    cupsSupport = true;
    dbusSupport = true;
    cairoSupport = true;
    cursesSupport = true;
    saneSupport = true;
    pulseaudioSupport = true;
    udevSupport = true;
    xineramaSupport = true;
    sdlSupport = true;
    usbSupport = true;
    waylandSupport = true;
    x11Support = true;
    ffmpegSupport = true;
    gtkSupport = true;
    gstreamerSupport = true;
    openclSupport = true;
    odbcSupport = true;
    netapiSupport = true;
    vaSupport = true;
    pcapSupport = true;
    v4lSupport = true;
    gphoto2Support = true;
    krb5Support = true;
    embedInstallers = true;
  };
in
baseWine.overrideAttrs (old: {
  env = (old.env or { }) // {
    NIX_CFLAGS_COMPILE = "-O0 -g3";
  };
  dontStrip = true;
})
