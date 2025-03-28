ARG GRAFANA_VERSION=11.6.0
FROM grafana/grafana-oss:${GRAFANA_VERSION}

RUN grafana-cli --pluginsDir "${GF_PATHS_PLUGINS}" plugins install grafana-timestream-datasource
COPY provisioning/datasources/* /etc/grafana/provisioning/datasources/
COPY provisioning/dashboards/* /etc/grafana/provisioning/dashboards/
COPY dashboards /var/lib/grafana/dashboards