local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'overview.json':
      g.dashboard(
        '%(dashboardNamePrefix)sOverview' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('Overview')
        .addPanel(
          g.panel('Per component') +
          g.tablePanel([], {},)
        )
      )
      .addRow(
        g.row('Compact')
        .addPanel(
          g.sloError(
            'Compaction Error Rate',
            'prometheus_tsdb_compactions_failed_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            10,
            30
          )
        )
        .addPanel(
          g.sloLatency(
            'Compaction Latecy 99th Percentile',
            'prometheus_tsdb_compaction_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            0.99,
            0.5,
            1,
            10
          )
        )
      )
      .addRow(
        g.row('Query')
        .addPanel(
          g.sloError(
            'gRPC API Error Rate',
            'grpc_client_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable|DataLoss",grpc_type="unary",namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            'grpc_client_started_total{grpc_type="unary",namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            10,
            30
          )
        )
        .addPanel(
          g.sloLatency(
            'gRPC Latecy 99th Percentile',
            'grpc_client_handling_seconds_bucket{grpc_type="unary",namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            0.99,
            0.5,
            1,
            10
          )
        )
        .addPanel(
          g.sloLatency(
            'Instant Query Latecy 99th Percentile',
            'thanos_query_api_instant_query_duration_seconds_bucket{namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            0.99,
            0.5,
            1,
            10
          )
        )
        .addPanel(
          g.sloLatency(
            'Range Query Latecy 99th Percentile',
            'thanos_query_api_range_query_duration_seconds_bucket{namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            0.99,
            0.5,
            1,
            10
          )
        )
      )
      .addRow(
        g.row('Receive')
        .addPanel(
          g.sloError('', '', '')
        )
        .addPanel(
          g.sloLatency('', '', 0, 0, 0, 0)
        )
      )
      .addRow(
        g.row('Rule')
        .addPanel(
          g.sloError('', '', '')
        )
        .addPanel(
          g.sloLatency('', '', 0, 0, 0, 0)
        )
      )
      .addRow(
        g.row('Sidecar')
        .addPanel(
          g.sloError('', '', '')
        )
        .addPanel(
          g.sloLatency('', '', 0, 0, 0, 0)
        )
      )
      .addRow(
        g.row('Store')
        .addPanel(
          g.sloError('', '', '')
        )
        .addPanel(
          g.sloLatency('', '', 0, 0, 0, 0)
        )
      ),
  },
}
