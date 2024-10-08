#!/bin/bash

set -e

# Set environment variables
PACKAGESDIR="$PWD/packages"
DOWNLOADDIR="$PWD/downloads"
OUTPUTDIR="$PWD/output"
RUNTIME_VERSION="8.0.1-servicing.23580.1"
SDK_VERSION="8.0.101-servicing.23580.21"
ASPNETCORE_VERSION="8.0.1-servicing.23580.8"
ROOTFS_DIR="/"

# Install prerequisites
# sudo dpkg --add-architecture riscv64
# sudo sed -i -E 's|^deb ([^ ]+) (.*)$|deb [arch=amd64] \1 \2\ndeb [arch=riscv64] http://ports.ubuntu.com/ubuntu-ports/ \2|' /etc/apt/sources.list
# sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    ca-certificates \
    python3-minimal \
    python3-libxml2 \
    git \
    wget \
    curl \
    cmake \
    locales \
    build-essential \
    zlib1g-dev:riscv64 \
    libkrb5-dev:riscv64 \
    libssl-dev:riscv64 \
    libicu-dev:riscv64 \
    liblttng-ust-dev:riscv64 \
    zlib1g-dev \
    liblttng-ust-dev

sudo locale-gen en_US.UTF-8

# Clone repositories
git clone --depth 1 -b v8.0.1 https://github.com/dotnet/runtime
git clone --depth 1 -b v8.0.1 https://github.com/dotnet/aspnetcore --recurse-submodules
git clone --depth 1 -b v8.0.101 https://github.com/dotnet/sdk
git clone --depth 1 -b v8.0.101 https://github.com/dotnet/installer

# Update Node.js
sudo apt-get update
sudo apt-get autoremove -y nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt-get install -y nodejs

# Build runtime
mkdir -p ${PACKAGESDIR} ${DOWNLOADDIR} ${OUTPUTDIR}

cd runtime
git apply ../runtime.patch
./build.sh --ci -c Release --cross --arch riscv64 --gcc
cp artifacts/packages/Release/Shipping/Microsoft.NETCore.App.Host.linux-riscv64.*.nupkg ${PACKAGESDIR}
cp artifacts/packages/Release/Shipping/Microsoft.NETCore.App.Runtime.linux-riscv64.*.nupkg ${PACKAGESDIR}
mkdir -p ${DOWNLOADDIR}/Runtime/${RUNTIME_VERSION}
cp artifacts/packages/Release/Shipping/dotnet-runtime-*-linux-riscv64.tar.gz ${DOWNLOADDIR}/Runtime/${RUNTIME_VERSION}
cp artifacts/packages/Release/Shipping/dotnet-runtime-*-linux-riscv64.tar.gz ${OUTPUTDIR}
cp artifacts/packages/Release/Shipping/Microsoft.NETCore.App.Host.linux-riscv64.*.nupkg ${OUTPUTDIR}
cp artifacts/packages/Release/Shipping/Microsoft.NETCore.App.Runtime.linux-riscv64.*.nupkg ${OUTPUTDIR}
cp artifacts/packages/Release/Shipping/runtime.linux-riscv64.Microsoft.NETCore.DotNetHost.*.nupkg ${OUTPUTDIR}
cp artifacts/packages/Release/Shipping/runtime.linux-riscv64.Microsoft.NETCore.DotNetHostPolicy.*.nupkg ${OUTPUTDIR}
cp artifacts/packages/Release/Shipping/runtime.linux-riscv64.Microsoft.NETCore.DotNetHostResolver.*.nupkg ${OUTPUTDIR}
cp artifacts/packages/Release/NonShipping/runtime.linux-riscv64.Microsoft.NETCore.ILAsm.*.nupkg ${OUTPUTDIR}
cp artifacts/packages/Release/NonShipping/runtime.linux-riscv64.Microsoft.NETCore.ILDAsm.*.nupkg ${OUTPUTDIR}
cd .. && rm -r runtime

# Build SDK
cd sdk
./build.sh --pack --ci -c Release /p:Architecture=riscv64
mkdir -p ${DOWNLOADDIR}/Sdk/${SDK_VERSION}
cp artifacts/packages/Release/NonShipping/dotnet-toolset-internal-*.zip ${DOWNLOADDIR}/Sdk/${SDK_VERSION}/dotnet-toolset-internal-${SDK_VERSION}.zip
cp artifacts/packages/Release/Shipping/Microsoft.DotNet.Common.*.nupkg ${PACKAGESDIR}
cd .. && rm -r sdk

# Build aspnetcore
cd aspnetcore
sed -i "s|ppc64le|riscv64|" src/Framework/App.Runtime/src/Microsoft.AspNetCore.App.Runtime.csproj
sed -i "s|\$(BaseIntermediateOutputPath)\$(DotNetRuntimeArchiveFileName)|${DOWNLOADDIR}/Runtime/${RUNTIME_VERSION}/dotnet-runtime-8.0.1-linux-riscv64.tar.gz|" src/Framework/App.Runtime/src/Microsoft.AspNetCore.App.Runtime.csproj
./eng/build.sh --pack --ci -c Release -arch riscv64 /p:DotNetAssetRootUrl=file://${DOWNLOADDIR}/

cp artifacts/packages/Release/Shipping/Microsoft.AspNetCore.App.Runtime.linux-riscv64.*.nupkg ${PACKAGESDIR}
mkdir -p ${DOWNLOADDIR}/aspnetcore/Runtime/${ASPNETCORE_VERSION}
cp artifacts/installers/Release/aspnetcore-runtime-*-linux-riscv64.tar.gz ${DOWNLOADDIR}/aspnetcore/Runtime/${ASPNETCORE_VERSION}
cp artifacts/installers/Release/aspnetcore_base_runtime.version ${DOWNLOADDIR}/aspnetcore/Runtime/${ASPNETCORE_VERSION}
cp artifacts/packages/Release/Shipping/Microsoft.AspNetCore.App.Runtime.linux-riscv64.*.nupkg ${OUTPUTDIR}
cp artifacts/packages/Release/Shipping/Microsoft.DotNet.Web.*.nupkg ${PACKAGESDIR}
cd .. && rm -r aspnetcore

# Build installer
cd installer
sed -i "s|linux-arm64|linux-riscv64|" src/redist/targets/GenerateBundledVersions.targets
sed -i "s|linux-arm64|linux-riscv64|" src/SourceBuild/content/eng/bootstrap/buildBootstrapPreviouslySB.csproj
sed -i s'|ppc64le|riscv64|' Directory.Build.props
sed -i s'|ppc64le|riscv64|' src/SourceBuild/content/Directory.Build.props
sed -i s'|ppc64le|riscv64|' src/redist/targets/Crossgen.targets
sed -i s"|<clear />|<clear />\n<add key='local' value='${PACKAGESDIR}' />|" NuGet.config
./build.sh --ci -c Release -a riscv64 /p:HostRid=linux-x64 /p:PublicBaseURL=file://${DOWNLOADDIR}/
cp artifacts/packages/Release/Shipping/dotnet-sdk-*-linux-riscv64.tar.gz ${OUTPUTDIR}
cp artifacts/packages/Release/Shipping/dotnet-sdk-*-linux-riscv64.tar.gz.sha512 ${OUTPUTDIR}

echo "Build completed. Output files are in ${OUTPUTDIR}"