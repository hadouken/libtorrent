# This script will download and build Rasterbar-libtorrent in both debug and
# release configurations.

$PACKAGES_DIRECTORY = Join-Path $PSScriptRoot "packages"
$OUTPUT_DIRECTORY   = Join-Path $PSScriptRoot "bin"
$VERSION            = "0.0.0"

$BOOST_PACKAGE_DIRECTORY   = Join-Path $PACKAGES_DIRECTORY "hadouken.boost.0.1.5"
$OPENSSL_PACKAGE_DIRECTORY = Join-Path $PACKAGES_DIRECTORY "hadouken.openssl.0.1.3"

if (Test-Path Env:\APPVEYOR_BUILD_VERSION) {
    $VERSION = $env:APPVEYOR_BUILD_VERSION
}

# 7zip configuration section
$7ZIP_VERSION      = "9.20"
$7ZIP_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "7zip-$7ZIP_VERSION"
$7ZIP_TOOL         = Join-Path $7ZIP_DIRECTORY "7za.exe"
$7ZIP_PACKAGE_FILE = "7za$($7ZIP_VERSION.replace('.', '')).zip"
$7ZIP_DOWNLOAD_URL = "http://downloads.sourceforge.net/project/sevenzip/7-Zip/$7ZIP_VERSION/$7ZIP_PACKAGE_FILE"

# Libtorrent configuration section
$LIBTORRENT_VERSION      = "1.0.3"
$LIBTORRENT_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "libtorrent-rasterbar-$LIBTORRENT_VERSION"
$LIBTORRENT_PACKAGE_FILE = "libtorrent-rasterbar-$LIBTORRENT_VERSION.tar.gz"
$LIBTORRENT_DOWNLOAD_URL = "http://downloads.sourceforge.net/project/libtorrent/libtorrent/$LIBTORRENT_PACKAGE_FILE"

# Nuget configuration section
$NUGET_FILE         = "nuget.exe"
$NUGET_TOOL         = Join-Path $PACKAGES_DIRECTORY $NUGET_FILE
$NUGET_DOWNLOAD_URL = "https://nuget.org/$NUGET_FILE"

function Download-File {
    param (
        [string]$url,
        [string]$target
    )

    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile($url, $target)
}

function Extract-File {
    param (
        [string]$file,
        [string]$target
    )

    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $target)
}

function Load-DevelopmentTools {
    # Set environment variables for Visual Studio Command Prompt
    
    pushd "c:\Program Files (x86)\Microsoft Visual Studio 12.0\VC"
    
    cmd /c "vcvarsall.bat&set" |
    foreach {
        if ($_ -match "=") {
            $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
        }
    }
    
    popd
}

# Get our dev tools
Load-DevelopmentTools

# Create packages directory if it does not exist
if (!(Test-Path $PACKAGES_DIRECTORY)) {
    New-Item -ItemType Directory -Path $PACKAGES_DIRECTORY | Out-Null
}

# Download 7zip
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $7ZIP_PACKAGE_FILE))) {
    Write-Host "Downloading $7ZIP_PACKAGE_FILE"
    Download-File $7ZIP_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $7ZIP_PACKAGE_FILE)
}

# Download Libtorrent
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $LIBTORRENT_PACKAGE_FILE))) {
    Write-Host "Downloading $LIBTORRENT_PACKAGE_FILE"
    Download-File $LIBTORRENT_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $LIBTORRENT_PACKAGE_FILE)
}

# Download Nuget
if (!(Test-Path $NUGET_TOOL)) {
    Write-Host "Downloading $NUGET_FILE"
    Download-File $NUGET_DOWNLOAD_URL $NUGET_TOOL
}

# Unpack 7zip
if (!(Test-Path $7ZIP_DIRECTORY)) {
    Write-Host "Unpacking $7ZIP_PACKAGE_FILE"
    Extract-File (Join-Path $PACKAGES_DIRECTORY $7ZIP_PACKAGE_FILE) $7ZIP_DIRECTORY
}

# Unpack Libtorrent
if (!(Test-Path $LIBTORRENT_DIRECTORY)) {
    Write-Host "Unpacking $LIBTORRENT_PACKAGE_FILE"
    $tmp = Join-Path $PACKAGES_DIRECTORY $LIBTORRENT_PACKAGE_FILE

    & "$7ZIP_TOOL" x $tmp -o"$PACKAGES_DIRECTORY"
    & "$7ZIP_TOOL" x $tmp.replace('.gz', '') -o"$PACKAGES_DIRECTORY"
}

# Install support packages Boost and OpenSSL
& "$NUGET_TOOL" install hadouken.boost -Version 0.1.5 -OutputDirectory "$PACKAGES_DIRECTORY"
& "$NUGET_TOOL" install hadouken.openssl -Version 0.1.3 -OutputDirectory "$PACKAGES_DIRECTORY"

function Compile-Libtorrent {
    param (
        [string]$platform,
        [string]$configuration
    )

    pushd $LIBTORRENT_DIRECTORY

    $b2 = Join-Path $BOOST_PACKAGE_DIRECTORY "tools/b2.exe"

    $boost_include = Join-Path $BOOST_PACKAGE_DIRECTORY "include"
    $boost_lib = Join-Path $BOOST_PACKAGE_DIRECTORY "$platform/$configuration/lib"

    $openssl_include = Join-Path $OPENSSL_PACKAGE_DIRECTORY "$platform/$configuration/include"
    $openssl_lib = Join-Path $OPENSSL_PACKAGE_DIRECTORY "$platform/$configuration/lib"

    Start-Process "$b2" -ArgumentList "toolset=msvc-12.0 include=""$boost_include"" include=""$openssl_include"" library-path=""$boost_lib"" library-path=""$openssl_lib"" variant=$configuration boost=system boost-link=shared dht=on i2p=on encryption=openssl link=shared runtime-link=shared deprecated-functions=off" -Wait -NoNewWindow

    popd
}

function Output-Libtorrent {
    param (
        [string]$platform,
        [string]$configuration
    )

    pushd $LIBTORRENT_DIRECTORY

    $t = Join-Path $OUTPUT_DIRECTORY "$platform\$configuration"

    # Copy output files
    xcopy /y bin\msvc-12.0\$configuration\boost-link-shared\deprecated-functions-off\encryption-openssl\threading-multi\*.lib "$t\lib\*"
    xcopy /y bin\msvc-12.0\$configuration\boost-link-shared\deprecated-functions-off\encryption-openssl\threading-multi\*.dll "$t\bin\*"
    xcopy /y include\* "$t\include\*" /E

    popd
}

Compile-Libtorrent "win32" "debug"
Output-Libtorrent  "win32" "debug"

Compile-Libtorrent "win32" "release"
Output-Libtorrent  "win32" "release"

# Package with NuGet

copy hadouken.libtorrent.nuspec $OUTPUT_DIRECTORY

pushd $OUTPUT_DIRECTORY
Start-Process "$NUGET_TOOL" -ArgumentList "pack hadouken.libtorrent.nuspec -Properties version=$VERSION" -Wait -NoNewWindow
popd