local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;
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
              'sum(rate(prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_objstore_bucket_operations_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_garbage_collection_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_group_compactions_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_sync_meta_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
            ], [
              'compaction',
              'bucket ops',
              'gc ops',
              'group compact',
              'sync metas',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Failures/s') +
          g.queryPanel(
            [
              'sum(rate(prometheus_tsdb_compactions_failed_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_objstore_bucket_operation_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_garbage_collection_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_group_compactions_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_compact_sync_meta_failures_total{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace)' % $._config,
            ], [
              'compaction',
              'bucket ops',
              'gc ops',
              'group compact',
              'sync metas',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Time 99th Percentile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_compact_garbage_collection_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_compact_sync_meta_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_objstore_bucket_operation_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(prometheus_tsdb_compaction_duration_seconds_bucket{namespace=~"$namespace",%(thanosCompactSelector)s}[$interval])) by (namespace,le))' % $._config,
            ], [
              '99 gc',
              '99 sync meta',
              '99 bucket ops',
              '99 compact',
            ],
          )
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
      )
      + {
        templating+: {
          list+: [
            template.new(
              'pod',
              '$datasource',
              'label_values(kube_pod_info{namespace="$namespace"}, pod)',
              label='pod',
              refresh=1,
              sort=2,
              current='all',
              allValues='.*',
              includeAll=true
            ),
          ],
        },
      } + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
