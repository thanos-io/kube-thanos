local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'rule.json':
      g.dashboard($._config.grafanaThanos.dashboardRuleTitle)
      .addRow(
        g.row('Alert Sent')
        .addPanel(
          g.panel('Dropped Rate') +
          g.queryPanel(
            'sum(rate(thanos_alert_sender_alerts_dropped_total{namespace=~"$namespace",job=~"$job"}[$interval])) by (job, alertmanager)',
            '{{job}} {{alertmanager}}'
          )
        )
        .addPanel(
          g.panel('Sent Rate') +
          g.queryPanel(
            'sum(rate(thanos_alert_sender_alerts_sent_total{namespace=~"$namespace",job=~"$job"}[$interval])) by (job, alertmanager)',
            '{{job}} {{alertmanager}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Sent Errors') +
          g.qpsErrTotalPanel(
            'thanos_alert_sender_errors_total{namespace="$namespace",job=~"$job"}',
            'thanos_alert_sender_alerts_sent_total{namespace="$namespace",job=~"$job"}',
          )
        )
        .addPanel(
          g.panel('Sent Duration') +
          g.latencyPanel('thanos_alert_sender_latency_seconds', 'namespace=~"$namespace",job=~"$job"'),
        )
      )
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="unary"')
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",job=~"$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="unary"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",job=~"$job",grpc_type="unary"')
        ) +
        g.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        ) +
        g.collapse
      )
      .addRow(
        g.resourceUtilizationRow()
      ) +
      g.template('namespace', 'kube_pod_info') +
      g.template('job', 'up', 'namespace="$namespace",%(thanosRuleSelector)s' % $._config, true, "%(thanosRuleJobPrefix)s.*" % $._config) +
      g.template('pod', 'kube_pod_info', 'namespace="$namespace",created_by_name=~"%(thanosRuleJobPrefix)s.*"' % $._config, true,'.*'),
  },
}
