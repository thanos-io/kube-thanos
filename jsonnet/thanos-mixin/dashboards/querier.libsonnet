local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'querier.json':
      g.dashboard($._config.grafanaThanos.dashboardQuerierTitle)
      .addRow(
        g.row('Instant Query API')
        .addPanel(
          g.panel('Rate') +
          g.httpQpsPanel('http_requests_total', 'namespace="$namespace",job="$job",handler="query"')
        )
        .addPanel(
          g.panel('Errors') +
          g.httpErrPanel('http_requests_total', 'namespace="$namespace",job="$job",handler="query"')
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('http_request_duration_seconds', 'namespace="$namespace",job="$job",handler="query"')
        )
      )
      .addRow(
        g.row('Range Query API')
        .addPanel(
          g.panel('Rate') +
          g.httpQpsPanel('http_requests_total', 'namespace="$namespace",job="$job",handler="query_range"')
        )
        .addPanel(
          g.panel('Errors') +
          g.httpErrPanel('http_requests_total', 'namespace="$namespace",job="$job",handler="query_range"')
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('http_request_duration_seconds', 'namespace="$namespace",job="$job",handler="query_range"')
        )
      )
      .addRow(
        g.row('Query Detailed')
        .addPanel(
          g.panel('Rate') +
          g.httpQpsPanelDetailed('http_requests_total', 'namespace="$namespace",job="$job"')
        )
        .addPanel(
          g.panel('Errors') +
          g.httpErrDetailsPanel('http_requests_total', 'namespace="$namespace",job="$job"')
        )
        .addPanel(
          g.panel('Duration') +
          g.httpLatencyDetailsPanel('http_request_duration_seconds', 'namespace="$namespace",job="$job"')
        ) +
        g.collapse
      )
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('client', 'namespace="$namespace",job="$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('client', 'namespace="$namespace",job="$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('client', 'namespace="$namespace",job="$job",grpc_type="unary"')
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('client', 'namespace="$namespace",job="$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('client', 'namespace="$namespace",job="$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('client', 'namespace="$namespace",job="$job",grpc_type="unary"')
        ) +
        g.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('client', 'namespace="$namespace",job="$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('client', 'namespace="$namespace",job="$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('client', 'namespace="$namespace",job="$job",grpc_type="server_stream"')
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('client', 'namespace="$namespace",job="$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('client', 'namespace="$namespace",job="$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('client', 'namespace="$namespace",job="$job",grpc_type="server_stream"')
        ) +
        g.collapse
      )
      .addRow(
        g.row('DNS')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_querier_store_apis_dns_lookups_total{namespace="$namespace",job="$job"}[$interval])) by (job)',
            'lookups {{job}}'
          )
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_querier_store_apis_dns_failures_total{namespace="$namespace",job="$job"}',
            'thanos_querier_store_apis_dns_lookups_total{namespace="$namespace",job="$job"}',
          )
        )
      )
      .addRow(
        g.resourceUtilizationRow()
      ) +
      g.template('namespace', 'kube_pod_info') +
      g.template('job', 'up', 'namespace="$namespace",%(thanosQuerierSelector)s' % $._config, true) +
      g.template('pod', 'kube_pod_info', 'namespace="$namespace",created_by_name=~"%(thanosQuerierJobPrefix)s.*"' % $._config, true, '.*'),
  },
}
