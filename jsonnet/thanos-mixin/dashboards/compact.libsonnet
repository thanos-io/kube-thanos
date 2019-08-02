local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'compact.json':
      g.dashboard(
        '%(dashboardNamePrefix)sCompact' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('Operations')
        .addPanel(
          g.panel('Operations/s') +
          g.queryPanel(
            [
              'sum(rate(prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_objstore_bucket_operations_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_garbage_collection_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_group_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_sync_meta_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
            ], [
              'compaction {{namespace}}',
              'bucket ops {{namespace}}',
              'gc ops  {{namespace}}',
              'group compact  {{namespace}}',
              'sync metas  {{namespace}}',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Failures/s') +
          g.queryPanel(
            [
              'sum(rate(prometheus_tsdb_compactions_failed_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_objstore_bucket_operation_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_garbage_collection_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_group_compactions_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_sync_meta_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace)' % $._config,
            ], [
              'compaction {{namespace}}',
              'bucket ops {{namespace}}',
              'gc ops  {{namespace}}',
              'group compact  {{namespace}}',
              'sync metas  {{namespace}}',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Time Quantile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_compact_garbage_collection_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_compact_sync_meta_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_objstore_bucket_operation_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(prometheus_tsdb_compaction_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$__range])) by (namespace,le))' % $._config,
            ], [
              '99 gc {{namespace}}"',
              '99 sync meta  {{namespace}}',
              '99 bucket ops {{namespace}}',
              '99 compact {{namespace}}',
            ],
          )
        )
      )
      .addRow(
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosCompactSelector)s}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('Goroutines') +
          g.queryPanel(
            'go_goroutines{namespace="$namespace",%(thanosCompactSelector)s}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosCompactSelector)s, quantile="1"}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
      ) + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
