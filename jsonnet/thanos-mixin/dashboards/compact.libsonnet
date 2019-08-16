local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'compact.json':
      g.dashboard($._config.grafanaThanos.dashboardCompactTitle)
      .addRow(
        g.row('Group Compaction')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_group_compactions_total{namespace="$namespace",job="$job"}[$interval])) by (job, group)',
            'compaction {{job}} {{group}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_group_compactions_failures_total{namespace="$namespace",job="$job"}',
            'thanos_compact_group_compactions_total{namespace="$namespace",job="$job"}',
          )
        )
      )
      .addRow(
        g.row('Downsample')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_downsample_total{namespace="$namespace",job="$job"}[$interval])) by (job, group)',
            'downsample {{job}} {{group}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_downsample_failed_total{namespace="$namespace",job="$job"}',
            'thanos_compact_downsample_total{namespace="$namespace",job="$job"}',
          )
        )
      )
      .addRow(
        g.row('Garbage Collection')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_garbage_collection_total{namespace="$namespace",job="$job"}[$interval])) by (job)',
            'garbage collection {{job}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_garbage_collection_failures_total{namespace="$namespace",job="$job"}',
            'thanos_compact_garbage_collection_total{namespace="$namespace",job="$job"}',
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_compact_garbage_collection_duration_seconds', 'namespace="$namespace",job="$job"')
        )
      )
      .addRow(
        g.row('Sync Meta')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_compact_sync_meta_total{namespace="$namespace",job="$job"}[$interval])) by (job)',
            'sync {{job}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_compact_sync_meta_failures_total{namespace="$namespace",job="$job"}',
            'thanos_compact_sync_meta_total{namespace="$namespace",job="$job"}',
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_compact_sync_meta_duration_seconds', 'namespace="$namespace",job="$job"')
        )
      )
      .addRow(
        g.row('Object Store Operations')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_objstore_bucket_operations_total{namespace="$namespace",job="$job"}[$interval])) by (job, operation)',
            '{{job}} {{operation}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_objstore_bucket_operation_failures_total{namespace="$namespace",job="$job"}',
            'thanos_objstore_bucket_operations_total{namespace="$namespace",job="$job"}',
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', 'namespace="$namespace",job="$job"')
        )
      )
      .addRow(
        g.resourceUtilizationRow()
      ) +
      g.template('namespace', 'kube_pod_info') +
      g.template('job', 'up', 'namespace="$namespace",%(thanosCompactSelector)s' % $._config, true) +
      g.template('pod', 'kube_pod_info', 'namespace="$namespace",created_by_name=~"%(thanosCompactJobPrefix)s.*"' % $._config, true, '.*'),
  },
}
