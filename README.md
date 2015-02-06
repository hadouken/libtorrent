# Overview

This repository contains the build script to download, build and publish
Rasterbar-libtorrent for Hadouken on Windows.

Rasterbar-libtorrent is built with MSVC-12 (Visual Studio 2013).

## Building

```
CMD> powershell -ExecutionPolicy RemoteSigned -File build.ps1
```

This will download and compile Rasterbar-libtorrent in both debug and release
versions for Win32.

The output (including a NuGet package) is put in the `bin` folder.
