local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'overview.json':
      g.dashboard($._config.grafanaThanos.dashboardOverviewTitle)
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('Compact')
        .addPanel(
          g.panel('Compaction Rate') +
          g.queryPanel(
            'sum(rate(prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval]))' % $._config,
            'compaction'
          ) +
          g.stack +
          g.addDashboardLink($._config.grafanaThanos.dashboardCompactTitle)
        )
        .addPanel(
          g.panel('Compaction Errors') +
          g.qpsErrTotalPanel(
            'prometheus_tsdb_compactions_failed_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardCompactTitle)
        )
        .addPanel(
          g.sloLatency(
            'Compaction Latency 99th Percentile',
            'prometheus_tsdb_compaction_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardCompactTitle)
        )
      )
      .addRow(
        g.row('Query')
        .addPanel(
          g.sloLatency(
            'Instant Query Latency 99th Percentile',
            'thanos_query_api_instant_query_duration_seconds_bucket{namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        )
        .addPanel(
          g.sloLatency(
            'Range Query Latency 99th Percentile',
            'thanos_query_api_range_query_duration_seconds_bucket{namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        )
      )
      .addRow(
        g.row('Receive')
        .addPanel(
          g.panel('Incoming Requests Rate') +
          g.httpQpsPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardReceiveTitle)
        )
        .addPanel(
          g.panel('Incoming Requests  Errors') +
          g.httpErrPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardReceiveTitle)
        )
        .addPanel(
          g.sloLatency(
            'Incoming Requests Latency 99th Percentile',
            'thanos_http_request_duration_seconds_bucket{namespace=~"$namespace",%(thanosReceiveSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardReceiveTitle)
        )
      )
      .addRow(
        g.row('Rule')
        .addPanel(
          g.panel('Alert Sent Rate') +
          g.queryPanel(
            'sum(rate(thanos_alert_sender_alerts_sent_total{namespace=~"$namespace",%(thanosRuleSelector)s}[$interval])) by (alertmanager)' % $._config,
            '{{alertmanager}}'
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardRuleTitle) +
          g.stack
        )
        .addPanel(
          g.panel('Alert Sent Errors') +
          g.qpsErrTotalPanel(
            'thanos_alert_sender_errors_total{namespace="$namespace",%(thanosRuleSelector)s}' % $._config,
            'thanos_alert_sender_alerts_sent_total{namespace="$namespace",%(thanosRuleSelector)s}' % $._config,
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardRuleTitle)
        )
        .addPanel(
          g.sloLatency(
            'Sent Error Duration',
            'thanos_alert_sender_latency_seconds_bucket{namespace=~"$namespace",%(thanosRuleSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardRuleTitle)
        )
      )
      .addRow(
        g.row('Sidecar')
        .addPanel(
          g.panel('gPRC (Unary) Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardSidecarTitle)
        )
        .addPanel(
          g.panel('gPRC (Unary) Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardSidecarTitle)
        )
        .addPanel(
          g.sloLatency(
            'gPRC (Unary) Latency 99th Percentile',
            'grpc_server_handling_seconds_bucket{grpc_type="unary",namespace=~"$namespace",%(thanosSidecarSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardSidecarTitle)
        )
      )
      .addRow(
        g.row('Store')
        .addPanel(
          g.panel('gPRC (Unary) Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosStoreSelector)s,grpc_type="unary"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardStoreTitle)
        )
        .addPanel(
          g.panel('gPRC (Unary) Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosStoreSelector)s,grpc_type="unary"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardStoreTitle)
        )
        .addPanel(
          g.sloLatency(
            'gRPC Latency 99th Percentile',
            'grpc_server_handling_seconds_bucket{grpc_type="unary",namespace=~"$namespace",%(thanosStoreSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardStoreTitle)
        )
      ),
  },
}
