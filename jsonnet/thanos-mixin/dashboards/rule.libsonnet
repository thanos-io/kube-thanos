local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'rule.json':
      g.dashboard($._config.grafanaThanos.dashboardRuleTitle)
      .addTemplate('namespace', 'kube_pod_info', 'namespace')
      .addRow(
        g.row('Alert Sent')
        .addPanel(
          g.panel('Dropped Rate') +
          g.queryPanel(
            'sum(rate(thanos_alert_sender_alerts_dropped_total{namespace=~"$namespace",%(thanosRuleSelector)s}[$interval])) by (alertmanager)' % $._config,
            '{{alertmanager}}'
          )
        )
        .addPanel(
          g.panel('Sent Rate') +
          g.queryPanel(
            'sum(rate(thanos_alert_sender_alerts_sent_total{namespace=~"$namespace",%(thanosRuleSelector)s}[$interval])) by (alertmanager)' % $._config,
            '{{alertmanager}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Sent Errors') +
          g.qpsErrTotalPanel(
            'thanos_alert_sender_errors_total{namespace="$namespace",%(thanosRuleSelector)s}' % $._config,
            'thanos_alert_sender_alerts_sent_total{namespace="$namespace",%(thanosRuleSelector)s}' % $._config,
          )
        )
        .addPanel(
          g.panel('Sent Duration') +
          g.latencyPanel('thanos_alert_sender_latency_seconds', 'namespace=~"$namespace",%(thanosRuleSelector)s' % $._config),
        )
      )
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="unary"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="unary"' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="server_stream"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosRuleSelector)s,grpc_type="server_stream"' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.resourceUtilizationRow('%(thanosRuleSelector)s' % $._config)
      ) +
      g.podTemplate('namespace="$namespace",created_by_name=~"%(thanosRule)s.*"' % $._config),
  },
}
