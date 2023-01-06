#!/bin/bash -e

VERSION=${VERSION:-$(curl -s https://hoopartifacts.s3.amazonaws.com/release/latest.txt)}
curl -s https://hoopartifacts.s3.amazonaws.com/release/${VERSION}/hoop_${VERSION}_Linux_$(uname -m).tar.gz \
    -o hoop-$VERSION.tar.gz
tar --extract --file hoop-$VERSION.tar.gz -C bin/ hoop && \
    rm -f hoop-$VERSION.tar.gz

chmod +x ./bin/hoop
/app/bin/hoop start agent
