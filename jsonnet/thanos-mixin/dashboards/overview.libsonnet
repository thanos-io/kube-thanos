local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'overview.json':
      g.dashboard($._config.grafanaThanos.dashboardOverviewTitle)
      .addRow(
        g.row('Instant Query')
        .addPanel(
          g.panel('Requests Rate') +
          g.httpQpsPanel('http_requests_total', 'namespace="$namespace",%(thanosQuerierSelector)s,handler="query"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        )
        .addPanel(
          g.panel('Requests Errors') +
          g.httpErrPanel('http_requests_total', 'namespace="$namespace",%(thanosQuerierSelector)s,handler="query"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        )
        .addPanel(
          g.sloLatency(
            'Latency 99th Percentile',
            'http_request_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,handler="query"}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        ) +
        { __dashboardFilename__:: 'querier.json' },
      )
      .addRow(
        g.row('Range Query')
        .addPanel(
          g.panel('Requests Rate') +
          g.httpQpsPanel('http_requests_total', 'namespace="$namespace",%(thanosQuerierSelector)s,handler="query_range"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        )
        .addPanel(
          g.panel('Requests Errors') +
          g.httpErrPanel('http_requests_total', 'namespace="$namespace",%(thanosQuerierSelector)s,handler="query_range"' % $._config) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        )
        .addPanel(
          g.sloLatency(
            'Latency 99th Percentile',
            'http_request_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,handler="query_range"}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardQuerierTitle)
        ) +
        { __dashboardFilename__:: 'querier.json' },
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
            'grpc_server_handling_seconds_bucket{grpc_type="unary",namespace="$namespace",%(thanosStoreSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardStoreTitle)
        ) +
        { __dashboardFilename__:: 'store.json' },
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
            'grpc_server_handling_seconds_bucket{grpc_type="unary",namespace="$namespace",%(thanosSidecarSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardSidecarTitle)
        )
        +
        { __dashboardFilename__:: 'sidecar.json' },
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
            'thanos_http_request_duration_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardReceiveTitle)
        )
        +
        { __dashboardFilename__:: 'receive.json' },
      )
      .addRow(
        g.row('Rule')
        .addPanel(
          g.panel('Alert Sent Rate') +
          g.queryPanel(
            'sum(rate(thanos_alert_sender_alerts_sent_total{namespace="$namespace",%(thanosRuleSelector)s}[$interval])) by (job, alertmanager)' % $._config,
            '{{job}} {{alertmanager}}'
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
            'thanos_alert_sender_latency_seconds_bucket{namespace="$namespace",%(thanosRuleSelector)s}' % $._config,
            0.99,
            0.5,
            1
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardRuleTitle)
        ) +
        g.collapse +
        { __dashboardFilename__:: 'rule.json' },
      )
      .addRow(
        g.row('Compact')
        .addPanel(
          g.panel('Compaction Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_group_compactions_total{namespace="$namespace",%(thanosCompactSelector)s}[$interval])) by (job)' % $._config,
            'compaction {{job}}'
          ) +
          g.stack +
          g.addDashboardLink($._config.grafanaThanos.dashboardCompactTitle)
        )
        .addPanel(
          g.panel('Compaction Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_group_compactions_failures_total{namespace="$namespace",%(thanosCompactSelector)s}' % $._config,
            'thanos_compact_group_compactions_total{namespace="$namespace",%(thanosCompactSelector)s}' % $._config,
          ) +
          g.addDashboardLink($._config.grafanaThanos.dashboardCompactTitle)
        ) +
        g.collapse +
        { __dashboardFilename__:: 'compact.json' },
      ) +
      g.template('namespace', 'kube_pod_info'),
  },
} +
{
  local grafanaDashboards = super.grafanaDashboards,
  grafanaDashboards+:: {
    local existingComponents = [f for f in std.objectFields(grafanaDashboards)],

    'overview.json'+: {
      rows: std.filter(
        function(row) std.setMember(row.__dashboardFilename__, existingComponents),
        super.rows
      ),
    },
  },
}
