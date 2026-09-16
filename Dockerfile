# syntax=docker/dockerfile:1
# IRIS Atrium - IRIS Community + Angular SPA
ARG IRIS_IMAGE=intersystemsdc/iris-community:latest

# ---- Stage 1: build the Angular SPA ----
FROM node:lts-alpine AS frontend
WORKDIR /build
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build -- --output-path=/build/dist --base-href=/csp/iris-atrium/

# ---- Stage 2: IRIS Community runtime ----
FROM ${IRIS_IMAGE}
ARG IRIS_IMAGE

WORKDIR /opt/mgmt

ENV IRIS_USERNAME=SuperUser
ENV MP_MAX_CORES=19

# Operator helpers: core-cap wrapper + entrypoint override.
# Invoked through `bash` (the base image runs non-root, so no chmod needed).
COPY scripts/limit-cores.sh scripts/iris-entrypoint.sh /usr/local/bin/

# Static client built by the previous stage
# Static client built by the previous stage (Angular "application" builder
# emits into dist/browser; serve files from the web-app root).
COPY --from=frontend /build/dist/browser /opt/mgmt/csp
COPY iris.script /tmp/iris.script
COPY module.xml /tmp/module.xml
COPY src /opt/mgmt/src
COPY tests /opt/mgmt/tests
COPY web /opt/mgmt/web

# Install at build time. The boot runs under the core cap so the Community
# Edition license check is never exceeded on high-core build hosts. A failed
# bootstrap (no MP_INSTALL_OK in the session log) fails the build.
RUN bash -lc 'iris start IRIS && iris session IRIS -U %SYS < /tmp/iris.script | tee /tmp/mp-install.log && iris stop IRIS quietly && grep -q "MP_INSTALL_OK" /tmp/mp-install.log'

ENTRYPOINT ["/bin/bash", "/usr/local/bin/iris-entrypoint.sh"]

EXPOSE 52773 1972