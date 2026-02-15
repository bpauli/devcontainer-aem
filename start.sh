#!/bin/bash
mkdir -p /home/aemuser/cq/author/crx-quickstart/logs
exec java -Xmx1536m -XX:MaxMetaspaceSize=256m -Djava.awt.headless=true \
  -jar /home/aemuser/cq/author/aem-sdk-quickstart.jar \
  -r author -p 4502 -nobrowser -nofork
