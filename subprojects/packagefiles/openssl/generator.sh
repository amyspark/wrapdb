#!/bin/bash
set -e
set -x

cd "$(dirname "${BASH_SOURCE[0]}")"

# Node.js version should bundle OpenSSL of matching version to one specified in wrap file
node_version=v16.5.0
openssl_version="$OPENSSL_VERSION"

if [ -z "$openssl_version" ]; then
  openssl_version=$(grep 'directory = ' ../../openssl.wrap | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-z]')
fi

if [ ! -d "node" ]; then
  git clone --depth 1 --branch $node_version https://github.com/nodejs/node.git
else
  pushd node
  git checkout -f $node_version
  popd
fi

rm -rf generated-config

pushd node/deps/openssl

# Apply patch that will allow us generate `meson.build` for different targets
patch -u config/Makefile -i ../../../Makefile.patch
patch -u config/generate_gypi.pl -i ../../../generate_gypi.pl.patch
# Copy `meson.build` template file
cp ../../../meson.build.tmpl config/

# Swap bundled OpenSSL in Node.js with upstream
rm -rf openssl
git clone --depth 1 --branch "OpenSSL_$(echo $openssl_version | tr . _)" https://github.com/openssl/openssl.git

rm -rf config/archs
LANG=C make -C config

# Copy generated files back into correct place
find config/archs -name 'meson.build' | xargs -I % sh -c 'mkdir -p ../../../generated-$(dirname %); cp % ../../../generated-%'
find config/archs -name '*.h' | xargs -I % sh -c 'mkdir -p ../../../generated-$(dirname %); cp % ../../../generated-%'
find config/archs -iname '*.s' | xargs -I % sh -c 'mkdir -p ../../../generated-$(dirname %); cp % ../../../generated-%'
find config/archs -iname '*.asm' | xargs -I % sh -c 'mkdir -p ../../../generated-$(dirname %); cp % ../../../generated-%'
find config/archs -iname '*.rc' | xargs -I % sh -c 'mkdir -p ../../../generated-$(dirname %); cp % ../../../generated-%'
find config/archs -iname '*.def' | xargs -I % sh -c 'mkdir -p ../../../generated-$(dirname %); cp % ../../../generated-%'

# AIX is not supported by Meson
rm -rf ../../../generated-config/archs/aix*
# Remove build info files, we use hardcoded deterministic one instead
rm -rf ../../../generated-config/archs/*/*/crypto/buildinf.h

popd

# Comment this line out when testing, so that it avoids repeated clones
rm -rf node
