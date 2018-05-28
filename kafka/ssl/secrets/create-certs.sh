#!/bin/bash

set -o nounset \
  -o errexit \
  -o verbose \
  -o xtrace

# Generate CA key
openssl req -new -x509 -keyout root-ca-1.key -out root-ca-1.crt -days 365 -subj '/CN=ca1.test.local/OU=TEST/O=ASKJA/L=London/S=Ca/C=GB' -passin pass:javidev -passout pass:javidev

# Kafkacat
openssl genrsa -des3 -passout "pass:javidev" -out librdkafka.client.key 1024
openssl req -passin "pass:javidev" -passout "pass:javidev" -key librdkafka.client.key -new -out librdkafka.client.req -subj '/CN=librdkafka.test.local/OU=TEST/O=ASKJA/L=London/S=Ca/C=GB'
openssl x509 -req -CA root-ca-1.crt -CAkey root-ca-1.key -in librdkafka.client.req -out librdkafka-ca1-signed.pem -days 9999 -CAcreateserial -passin "pass:javidev"



for i in broker1 client
do
  echo $i
  # Create keystores
  keytool -genkey -noprompt \
    -alias $i \
    -dname "CN=$i.test.local, OU=TEST, O=ASKJA, L=London, S=Ca, C=GB" \
    -keystore kafka.$i.keystore.jks \
    -keyalg RSA \
    -storepass javidev \
    -keypass javidev

  # Create CSR, sign the key and import back into keystore
  keytool -keystore kafka.$i.keystore.jks -alias $i -certreq -file $i.csr -storepass javidev -keypass javidev

  openssl x509 -req -CA root-ca-1.crt -CAkey root-ca-1.key -in $i.csr -out $i-ca1-signed.crt -days 9999 -CAcreateserial -passin pass:javidev

  keytool -keystore kafka.$i.keystore.jks -alias CARoot -import -file root-ca-1.crt -storepass javidev -keypass javidev

  keytool -keystore kafka.$i.keystore.jks -alias $i -import -file $i-ca1-signed.crt -storepass javidev -keypass javidev

  # Create truststore and import the CA cert.
  keytool -keystore kafka.$i.truststore.jks -alias CARoot -import -file root-ca-1.crt -storepass javidev -keypass javidev

  echo "javidev" > ${i}_sslkey_creds
  echo "javidev" > ${i}_keystore_creds
  echo "javidev" > ${i}_truststore_creds
done
