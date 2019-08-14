local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'compact.json':
      g.dashboard($._config.grafanaThanos.dashboardCompactTitle)
      .addTemplate('namespace', 'kube_pod_info', 'namespace')
      .addRow(
        g.row('Compaction')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval]))' % $._config,
            'compaction'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'prometheus_tsdb_compactions_failed_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('prometheus_tsdb_compaction_duration_seconds', 'namespace=~"$namespace",%(thanosCompactSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Downsample')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_downsample_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (group)' % $._config,
            'compaction'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_downsample_failed_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'thanos_compact_downsample_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
          )
        )
      )
      .addRow(
        g.row('Garbage Collection')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_garbage_collection_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval]))' % $._config,
            'compaction'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_garbage_collection_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'thanos_compact_garbage_collection_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_compact_garbage_collection_duration_seconds', 'namespace=~"$namespace",%(thanosCompactSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Group Compaction')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_group_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (group)' % $._config,
            'compaction'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_group_compactions_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'thanos_compact_group_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
          )
        )
      )
      .addRow(
        g.row('Sync Meta')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_sync_meta_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval]))' % $._config,
            'compaction'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_sync_meta_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'thanos_compact_sync_meta_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_compact_sync_meta_duration_seconds', 'namespace=~"$namespace",%(thanosCompactSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Object Store Operations')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_objstore_bucket_operations_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (operation)' % $._config,
            '{{operation}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_objstore_bucket_operation_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
            'thanos_objstore_bucket_operations_total{namespace=~"$namespace",%(thanosCompactSelector)s}' % $._config,
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', 'namespace=~"$namespace",%(thanosCompactSelector)s' % $._config)
        )
      )
      .addRow(
        g.resourceUtilizationRow('%(thanosCompactSelector)s' % $._config)
      ) +
      g.podTemplate('namespace="$namespace",created_by_name=~"%(thanosCompact)s.*"' % $._config),
  },
}
