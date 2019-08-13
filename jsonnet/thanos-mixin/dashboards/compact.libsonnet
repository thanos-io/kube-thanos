local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'compact.json':
      g.dashboard($._config.grafanaThanos.dashboardCompactTitle)
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
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
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              'go_memstats_alloc_bytes{namespace="$namespace",%(thanosCompactSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosCompactSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'rate(go_memstats_alloc_bytes_total{namespace="$namespace",%(thanosCompactSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'rate(go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosCompactSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'go_memstats_stack_inuse_bytes{namespace="$namespace",%(thanosCompactSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_inuse_bytes{namespace="$namespace",%(thanosCompactSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
            ],
            [
              'alloc all {{pod}}',
              'alloc heap {{pod}}',
              'alloc rate all {{pod}}',
              'alloc rate heap {{pod}}',
              'inuse stack {{pod}}',
              'inuse heap {{pod}}',
            ]
          )
        )
        .addPanel(
          g.panel('Goroutines') +
          g.queryPanel(
            'go_goroutines{namespace="$namespace",%(thanosCompactSelector)s}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosCompactSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
            '{{quantile}} {{pod}}'
          )
        )
        + { collapse: true }
      ) +
      g.podTemplate('namespace="$namespace",created_by_name=~"%(thanosCompact)s.*"' % $._config),
  },
}
