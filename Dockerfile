ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

LABEL maintainer="mail@bpauli.de"

ARG JACOCO_VERSION

ENV JACOCO_VERSION=$JACOCO_VERSION
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openjdk-21-jdk \
        maven \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN usermod -l aemuser -d /home/aemuser -m ubuntu && \
    groupmod -n aemuser ubuntu

RUN mkdir -p /home/aemuser/cq/author && chown -R aemuser:aemuser /home/aemuser/cq
WORKDIR /home/aemuser/cq

USER aemuser

RUN mvn -B org.apache.maven.plugins:maven-dependency-plugin:get -Dartifact=org.jacoco:jacoco-maven-plugin:$JACOCO_VERSION
ENV JACOCO_AGENT=/home/aemuser/.m2/repository/org/jacoco/org.jacoco.agent/$JACOCO_VERSION/org.jacoco.agent-$JACOCO_VERSION-runtime.jar

COPY --chown=aemuser:aemuser aem-sdk-quickstart.jar author/aem-sdk-quickstart.jar

COPY --chown=aemuser:aemuser start.sh .
RUN chmod +x start.sh

EXPOSE 4502

CMD ["/bin/bash", "./start.sh"]
