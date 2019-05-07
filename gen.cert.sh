#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo
    echo 'Issue a wildcard SSL certificate with Fishdrowned ROOT CA'
    echo
    echo 'Usage: ./gen.cert.sh [-s /C=US/ST=Texas/L=Dallas/O=Palfans] <domain> [<domain2>] [<domain3>] [<domain4>] ...'
    echo '    <domain>          The domain name of your site, like "example.dev",'
    echo '                      you will get a certificate for *.example.dev'
    echo '                      Multiple domains are acceptable'
    exit
fi

SAN=""
SUBJ=""
DOMAIN=""
while [ $# != 0 ]; do
    if [ "$1" == "-s" ]; then
        SUBJ=$2
        shift 2
    fi

    if [ "${DOMAIN}" == "" ]; then
        DOMAIN=$1
    fi

    SAN+="DNS:*.$1,DNS:$1,"
    shift
done
SAN=${SAN:0:${#SAN}-1}

# Move to root directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Generate root certificate if not exists
if [ ! -f "out/root.crt" ]; then
    bash gen.root.sh
fi

# Create domain directory
BASE_DIR="out/${DOMAIN}"
TIME=$(date +%Y%m%d-%H%M)
DIR="${BASE_DIR}/${TIME}"
mkdir -p ${DIR}

# Create CSR
MSYS_NO_PATHCONV=1 openssl req -new -out "${DIR}/${DOMAIN}.csr.pem" \
-key out/cert.key.pem \
-reqexts SAN \
-config <(cat ca.cnf <(printf "[SAN]\nsubjectAltName=${SAN}")) \
-subj "${SUBJ}/OU=${DOMAIN}/CN=*.${DOMAIN}"

# Issue certificate
# openssl ca -batch -config ./ca.cnf -notext -in "${DIR}/$1.csr.pem" -out "${DIR}/$1.cert.pem"
openssl ca -config ./ca.cnf -batch -notext \
-in "${DIR}/${DOMAIN}.csr.pem" \
-out "${DIR}/${DOMAIN}.crt" \
-cert ./out/root.crt \
-keyfile ./out/root.key.pem

# Chain certificate with CA
cat "${DIR}/${DOMAIN}.crt" ./out/root.crt >"${DIR}/${DOMAIN}.bundle.crt"
ln -snf "./${TIME}/${DOMAIN}.bundle.crt" "${BASE_DIR}/${DOMAIN}.bundle.crt"
ln -snf "./${TIME}/${DOMAIN}.crt" "${BASE_DIR}/${DOMAIN}.crt"
ln -snf "../cert.key.pem" "${BASE_DIR}/${DOMAIN}.key.pem"
ln -snf "../root.crt" "${BASE_DIR}/root.crt"

# Output certificates
echo
echo "Certificates are located in:"

LS=$([[ $(ls --help | grep '\-\-color') ]] && echo "ls --color" || echo "ls -G")

${LS} -la $(pwd)/${BASE_DIR}/*.*
