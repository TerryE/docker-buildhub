#!/bin/bash

CXT="$(dirname $(dirname "$(readlink -fm "$0")"))"
source "$CXT"/.env

TGTDIR="/tmp/$$"
mkdir -p ${TGTDIR}/{bin,output}

##+ The standard image runs docker-entry-setup.sh so we can overload this to do the custom build
# Note that the standard entry scipt returns to the calling entrypoint.sh to setup the standard
# monitoring framework and initiator.  In this the script just takes over to the build and 
# doesn't return
cat > ${TGTDIR}/bin/maxmind_builder.sh <<'END_BUILDER'
#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "--- Starting mod_maxminddb Build Process ---"

# 1. Install Build Dependencies
# Note: libmaxminddb-dev provides the headers for the C library itself
apt-get update
apt-get install -y apache2-dev build-essential libmaxminddb-dev git automake libtool
cd /tmp; git clone --recursive https://github.com/maxmind/mod_maxminddb.git
cd mod_maxminddb

# 3. Generate build files, Do the build and install in the Apache2 hierarchy
./bootstrap
./configure 
make install

echo "--- Move SO file to host ---"
cp $(apxs -q LIBEXECDIR)/mod_maxminddb.so /output/ || ( echo "ERROR: Build failed"; exit 1; )

echo "Build of mod_maxminddb completed in ${SECONDS} sec"
END_BUILDER
##- end of entry scripts
chmod +x ${TGTDIR}/bin/maxmind_builder.sh

docker run --rm --restart no -it \
  --memory="1g" --memory-swap="1g" --cpus="0.75" \
  --name maxmind_builder \
  -v "${TGTDIR}/bin:/usr/local/bin:ro" \
  -v "${TGTDIR}/output:/output:rw" \
  -e DEBIAN_FRONTEND=noninteractive \
  "debian:${DEBIAN_VERSION}-extended" \
  maxmind_builder.sh || ( echo "ERROR: Build failed"; exit 1; )

MOD_DIR="${CXT}/service/apache2/bin/.mod_lib"
mkdir -p ${MOD_DIR}
sudo mv ${TGTDIR}/output/mod_maxminddb.so ${MOD_DIR}

rm -R ${TGTDIR}

