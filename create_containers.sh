#!/bin/bash

#set -e

imagename=$1

echo "create all containers"
docker run --rm --privileged --network none --name aix -d ${imagename}
docker run --rm --privileged --network none --name solaris -d ${imagename}
docker run --rm --privileged --network none --name gemini -d ${imagename}
docker run --rm --privileged --network none --name gateway -d ${imagename}
docker run --rm --privileged --network none --name netb -d ${imagename}
docker run --rm --privileged --network none --name sun -d ${imagename}
docker run --rm --privileged --network none --name svr4 -d ${imagename}
docker run --rm --privileged --network none --name bsdi -d ${imagename}
docker run --rm --privileged --network none --name slip -d ${imagename}
