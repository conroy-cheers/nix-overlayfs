# nix-overlayfs

*Composable, reproducible overlay-based packaging for Wine applications*

## Usage

An example package definition is located in `apps/notepad-plus-plus`:

```
nix run .#notepad-plus-plus
```

The flake also exposes the packaged app itself, so you can build it directly:

```
nix build .#notepad-plus-plus
```

The top-level flake surface is intentionally narrow:

- `packages.<system>` contains only buildable derivations
- `apps.<system>` contains only schema-valid flat app entries

The richer internal package set is exposed through:

```text
legacyPackages.<system>.nix-overlayfs
```

That internal package set contains:

- `packages`: the flat default derivation set mirrored into the flake `packages` output
- `apps`: the flat default app set mirrored into the flake `apps` output
- `moduleScopes`: runtime/module scopes such as `nativeModules` and `x64FexModules`
- `packageVariants`: namespaced derivation variants such as `x64Fex.notepad-plus-plus`
- `appVariants`: namespaced app variants with the same runtime split

If you consume this repository as an overlay, the same package set is available
as:

```text
pkgs.nix-overlayfs
```

Each of these modules can be used as an install-time (see `lib.mkWindowsPackage`)
or runtime (see `lib.composeWindowsLayers`) dependency for other modules or applications;
each module serves a purpose similar to each of [Winetricks](https://github.com/Winetricks/winetricks)' verbs.
This module-based approach provides an advantage over the traditional Winetricks + prefix-per-application,
in that each module is a self-contained overlayfs and can thus be shared between multiple application
prefixes, saving on build/install time and disk space.

`runtime.mkSession` exposes `commands.wine`, `commands.wineserver`,
`commands.wineboot`, and `commands.winecfg` as the stable execution surface.
`commands.wine64` is optional; on `wow64` runtimes it aliases the main `wine`
launcher instead of a separate `bin/wine64` path.

## Migrating from `composeWineLayers`

The old `composeWineLayers` entrypoint has been replaced by
`composeWindowsLayers`.

The functional role is the same: compose a runnable overlay package from a base
layer, additional overlay layers, and a target executable path.

The main API change is that callers no longer pass a `wine` package directly.
They now pass a `runtime` taken from the selected module scope.

Old shape:

```nix
overlayfsLib.composeWineLayers {
  wine = wineModules.wine;
  packageName = "my-app";
  baseLayer = wineModules.base-env;
  overlayDependencies = [ wineModules.dxvk ];
  executableName = "my-app";
  executablePath = "${wineModules.wine.programFilesPath}/My App/app.exe";
}
```

New shape:

```nix
overlayfsLib.composeWindowsLayers {
  runtime = someModules.runtime;
  packageName = "my-app";
  baseLayer = someModules.base-env;
  overlayDependencies = [ someModules.dxvk ];
  executableName = "my-app";
  executablePath = "${someModules.runtime.programFilesPath}/My App/app.exe";
}
```

In practice, the migration is:

- `composeWineLayers` -> `composeWindowsLayers`
- `wine = ...` -> `runtime = ...`
- `wine.programFilesPath` -> `runtime.programFilesPath`
- choose the backend by choosing the module scope, not by swapping a Wine package manually

For example, on `aarch64-linux` you can point `runtime` at:

- `legacyPackages.aarch64-linux.nix-overlayfs.moduleScopes.nativeModules.runtime`
- `legacyPackages.aarch64-linux.nix-overlayfs.moduleScopes.x64FexModules.runtime`

## `aarch64-linux` runtime options

On `aarch64-linux`, this repository exposes two separate 64-bit Windows
runtime strategies.

### 1. `x64FexModules`

This is the native-host Wine path:

- Wine itself is built as native `aarch64-linux`.
- The Wine build is configured with `--enable-archs=arm64ec,aarch64,i386 --disable-tests`.
- The FEX WoA DLLs are bundled into `lib/wine/aarch64-windows/`.
- The base prefix sets `HKLM\Software\Microsoft\Wow64\amd64=libarm64ecfex.dll`
  so x64 Windows binaries can be dispatched through the FEX WoA layer.

The runtime shape is:

```text
app -> wine (native aarch64-linux) -> Windows ARM64EC/FEX WoA bridge -> host
```

This keeps Wine itself native on the host and avoids the separate Linux guest
userspace layer used by the older guest-FEX implementation.

The current implementation is intended for 64-bit Windows applications. 32-bit
WoW support is not enabled by default in this path, even though the FEX WoA DLL
package also includes `libwow64fex.dll`.

### 2. `nativeModules`

This is the native Windows ARM64 path:

- Wine itself is built as native `aarch64-linux`.
- The packaged app uses the upstream Windows ARM64 build when one is available.
- No FEX WoA bridge is involved.

The runtime shape is:

```text
app -> wine (native aarch64-linux) -> Windows ARM64 binary -> host
```

### Which scope to use

Use `nativeModules` when:

- you want the host-native Wine path for the current system
- on `x86_64-linux`, your target is a standard Windows x64 application
- on `aarch64-linux`, your target has a native Windows ARM64 build

Use `x64FexModules` on `aarch64-linux` when:

- you want the native-host ARM64EC + FEX path
- your target application is the Windows x64 build
- you want the repo's default `aarch64-linux` path for mainstream Windows apps

### Selecting a runtime in your own package

The flake keeps bare top-level names for the preferred default on each host.
Explicit runtime variants live under `legacyPackages.<system>.nix-overlayfs`.

On `aarch64-linux`:

```text
nix run .#notepad-plus-plus

nix build .#notepad-plus-plus
nix build .#legacyPackages.aarch64-linux.nix-overlayfs.packageVariants.x64Fex.notepad-plus-plus
nix run .#legacyPackages.aarch64-linux.nix-overlayfs.appVariants.x64Fex.notepad-plus-plus

nix build .#legacyPackages.aarch64-linux.nix-overlayfs.packageVariants.native.notepad-plus-plus
nix run .#legacyPackages.aarch64-linux.nix-overlayfs.appVariants.native.notepad-plus-plus
```

`notepad-plus-plus` is the per-app preferred default on `aarch64-linux`.
Today it resolves to the Windows x64 package on the ARM64EC + FEX path.

`legacyPackages.aarch64-linux.nix-overlayfs.packageVariants.x64Fex.notepad-plus-plus` is the explicit Windows x64 variant on the
ARM64EC + FEX path.

`legacyPackages.aarch64-linux.nix-overlayfs.packageVariants.native.notepad-plus-plus` uses the upstream ARM64 portable zip with the native
ARM64 Wine path, which is useful for validating native Windows ARM64 execution
separately from x64-on-ARM64EC.

On `x86_64-linux`:

```text
nix run .#notepad-plus-plus

nix build .#notepad-plus-plus
nix build .#legacyPackages.x86_64-linux.nix-overlayfs.packageVariants.native.notepad-plus-plus
```

There is no `x64Fex` variant namespace on `x86_64-linux`.

For a minimal x64 Windows repro on `aarch64-linux`, the flake also exposes:

```text
nix run .#hello-x64

nix build .#hello-x64
nix build .#legacyPackages.aarch64-linux.nix-overlayfs.packageVariants.x64Fex.hello-x64
```

`hello-x64` is a locally built x64 Windows console executable packaged through
the same runtime wrapper. It is intended specifically for isolating the
ARM64EC/FEX x64 execution path from application complexity.

To opt into a specific runtime in your own package definition, use that scope's
`runtime` explicitly:

```nix
overlayfsLib.mkWinpkgsPackage {
  runtime = pkgs.nix-overlayfs.moduleScopes.x64FexModules.runtime;
  packageName = "Notepad++/Notepad++";
  executableName = "notepad++";
  executablePath = "${pkgs.nix-overlayfs.moduleScopes.x64FexModules.runtime.programFilesPath}/Notepad++/notepad++.exe";
}
```

The `apps` listing layer decides which runtime to use for the bare package/app
name on each host. The explicit variant trees are available from
`pkgs.nix-overlayfs.packageVariants` and `pkgs.nix-overlayfs.appVariants` when
consuming the overlay, or via `legacyPackages.<system>.nix-overlayfs` from the
flake.

### Related package outputs on `aarch64-linux`

For the native ARM64EC path, the package set exposes:

- `llvmMingwArm64ec`: the llvm-mingw toolchain bundle used for ARM64EC/ARM64 PE builds
- `fexWineDlls`: the built FEX WoA DLL package
- `nativeArm64ecWine`: the native-host ARM64EC-enabled Wine build
- `nativeArm64ecWineWithFex`: that Wine build with the FEX WoA DLLs merged in

These are useful if you want to inspect or override the native path directly
without going through `x64FexModules` or `nativeModules`.

### Current status

On `aarch64-linux`, the `x64Fex` namespace is the default backend for apps that
ship a Windows x64 build.

The minimal x64 Windows repro `hello-x64` now runs successfully through the
native ARM64EC + FEX path on this repository's 16K-page Asahi test machine.
The two main bring-up issues were:

- Wine misparsing the ARM64X dynamic relocation tail in `.reloc` as classic
  base relocations, which produced `Unknown/unsupported relocation 507c`
- ARM64EC work-list setup failing when the shared section mapping was attempted
  strictly with `MEM_TOP_DOWN`

Those are currently fixed by the local Wine patches in
[packages/patches/wine-arm64x-basereloc-fix.patch](/home/conroy/src/nix-overlayfs/packages/patches/wine-arm64x-basereloc-fix.patch)
and
[packages/patches/wine-arm64ec-worklist-fallback.patch](/home/conroy/src/nix-overlayfs/packages/patches/wine-arm64ec-worklist-fallback.patch).

Where an application does not support unattended installation, its installer can be automated
by providing an AutoHotKey script (see `lib.mkWindowsPackage`).

With this toolbox of fully reproducible Wine environments, application dependencies,
and unattended installation helpers, it should be possible to package and distribute any Windows application
for Linux without needing to distribute the installers themselves.

## Acknowledgements

Many thanks to [nix-overlayfs concept by xstepa73](https://github.com/xstepa73/nix-overlayfs),
upon which this is based.
