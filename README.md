# nix-overlayfs

*Composable, reproducible overlay-based packaging for Wine applications*

## Usage

An example package definition is located in `apps/notepad-plus-plus`:

```
nix run .#notepad-plus-plus
```

The `packages` output contains a number of scopes (e.g. `wineWin32Modules`), each containing
a wrapped Wine package and the set of modules built with that Wine environment.

Each of these modules can be used as an install-time (see `lib.mkWinePackage`)
or runtime (see `lib.composeWineLayers`) dependency for other modules or applications;
each module serves a purpose similar to each of [Winetricks](https://github.com/Winetricks/winetricks)' verbs.
This module-based approach provides an advantage over the traditional Winetricks + prefix-per-application,
in that each module is a self-contained overlayfs and can thus be shared between multiple application
prefixes, saving on build/install time and disk space.

Where an application does not support unattended installation, its installer can be automated
by providing an AutoHotKey script (see `lib.mkWinePackage`).

With this toolbox of fully reproducible Wine environments, application dependencies,
and unattended installation helpers, it should be possible to package and distribute any Windows application
for Linux without needing to distribute the installers themselves.

## Acknowledgements

Many thanks to [nix-overlayfs concept by xstepa73](https://github.com/xstepa73/nix-overlayfs),
upon which this is based.
