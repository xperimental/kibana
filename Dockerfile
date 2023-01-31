#@follow_tag(registry.redhat.io/ubi8:latest)
FROM registry.redhat.io/ubi8:8.7-1054 AS nodejs10

ENV NODEJS_VERSION=10

RUN yum -y module enable nodejs:$NODEJS_VERSION && \
    INSTALL_PKGS="nodejs npm nodejs-nodemon nss_wrapper git" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    ln -s /usr/libexec/platform-python /usr/bin/python3 && \
    yum remove -y $INSTALL_PKGS && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all --enablerepo='*'

FROM nodejs10 AS builder

WORKDIR /build/

COPY hack/yarn-1.22.19.js /usr/local/bin/yarn

COPY . .

RUN yarn kbn bootstrap --oss

RUN node scripts/build --oss --skip-os-packages --skip-archives --release

FROM nodejs10

ENV HOME=/opt/app-root/src

ENV NPM_RUN=start \
    NAME=nodejs \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH

USER 0

WORKDIR ${HOME}

ENV BUILD_VERSION=6.8.1
ENV OS_GIT_MAJOR=6
ENV OS_GIT_MINOR=8
ENV OS_GIT_PATCH=1
ENV SOURCE_GIT_COMMIT=${CI_KIBANA_UPSTREAM_COMMIT:-}
ENV SOURCE_GIT_URL=${CI_KIBANA_UPSTREAM_URL:-}

EXPOSE 5601

ENV ELASTICSEARCH_URL=https://elasticsearch.openshift-logging.svc.cluster.local:9200 \
    KIBANA_CONF_DIR=${HOME}/config \
    KIBANA_VERSION=6.8.1 \
    NODE_ENV=production \
    RELEASE_STREAM=prod \
    container=oci \
    NODE_ENV=production \
    NODE_PATH=/usr/bin

ARG LOCAL_REPO

COPY --from=builder /build/build/oss/kibana-6.8.1-linux-x86_64/ ${HOME}/
COPY --from=builder /build/hack/opendistro_security_kibana_plugin-0.10.0.4/ ${HOME}/plugins/opendistro_security_kibana_plugin-0.10.0.4/

RUN chmod -R og+w ${HOME}/

COPY --from=builder /build/hack/probe/ /usr/share/kibana/probe/
COPY --from=builder /build/hack/kibana.yml ${KIBANA_CONF_DIR}/
COPY --from=builder /build/hack/run.sh ${HOME}/
COPY --from=builder /build/hack/utils ${HOME}/
COPY --from=builder /build/hack/module_list.sh ${HOME}/

RUN node src/cli --optimize

CMD ["./run.sh"]

LABEL \
        License="Apache-2.0" \
        io.k8s.description="Kibana container for querying Elasticsearch for aggregated logs" \
        io.k8s.display-name="Kibana" \
        io.openshift.tags="logging,elk,kibana" \
        maintainer="AOS Logging <team-logging@redhat.com>" \
        vendor="Red Hat" \
        name="openshift-logging/kibana6-rhel8" \
        com.redhat.component="logging-kibana6-container" \
        io.openshift.maintainer.product="OpenShift Container Platform" \
        io.openshift.build.commit.id=${CI_KIBANA_UPSTREAM_COMMIT} \
        io.openshift.build.source-location=${CI_KIBANA_UPSTREAM_URL} \
        io.openshift.build.commit.url=${CI_KIBANA_UPSTREAM_URL}/commit/${CI_KIBANA_UPSTREAM_COMMIT} \
        version=v6.8.1
