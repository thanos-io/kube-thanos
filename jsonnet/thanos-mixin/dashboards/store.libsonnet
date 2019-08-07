local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;
local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'store.json':
      g.dashboard(
        '%(dashboardNamePrefix)sStore' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('Query')
        .addPanel(
          g.panel('Query RPS') +
          g.queryPanel(
            'sum(rate(grpc_server_handled_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (grpc_code, grpc_method, namespace)' % $._config,
            '{{grpc_code}} {{grpc_method}}'
          )
        )
        .addPanel(
          g.panel('Query Error Rate') +
          g.queryPanel(
            |||
              sum(
                rate(grpc_server_handled_total{namespace="$namespace",grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable",%(thanosStoreSelector)s}[$interval])
                /
                rate(grpc_server_started_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])
              ) by (grpc_code, grpc_method, namespace)
            ||| % $._config,
            '{{grpc_code}} {{grpc_method}}'
          )
        )
        .addPanel(
          g.panel('Bucket Operations Error Rate') +
          g.queryPanel(
            |||
              sum(
                rate(thanos_objstore_bucket_operation_failures_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])
              /
                rate(thanos_objstore_bucket_operations_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])
              )
            ||| % $._config,
            ''
          )
        )
      )
      .addRow(
        g.row('Response')
        .addPanel(
          g.panel('Response Time 99th Percentile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(grpc_server_handling_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (grpc_method, le, namespace))' % $._config,
            '{{grpc_method}}'
          )
        )
        .addPanel(
          g.panel('Response Size 99th Percentile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(thanos_bucket_store_sent_chunk_size_bytes_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (le, namespace))' % $._config,
            ''
          )
        )
      )
      .addRow(
        g.row('Operations')
        .addPanel(
          g.panel('Operations/s') +
          g.queryPanel(
            [
              'sum(rate(thanos_objstore_bucket_operations_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace, operation)' % $._config,
              'sum(rate(thanos_bucket_store_block_drops_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_bucket_store_block_loads_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace)' % $._config,
            ], [
              'bucket {{operation}}',
              'block drops',
              'block loads',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Failures/s') +
          g.queryPanel(
            [
              'sum(rate(thanos_objstore_bucket_operation_failures_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (operation, namespace)' % $._config,
              'sum(rate(thanos_bucket_store_block_drop_failures_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_bucket_store_block_load_failures_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace)' % $._config,
            ], [
              'bucket {{operation}}',
              'block drops',
              'block loads',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Time 99th Percentile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_objstore_bucket_operation_duration_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,le,operation))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_bucket_store_series_get_all_duration_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_bucket_store_series_merge_duration_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,le))' % $._config,
            ], [
              '99 bucket {{operation}}',
              '99 get all',
              '99 merge',
            ],
          )
        )
      )
      .addRow(
        g.row('Operations')
        .addPanel(
          g.panel('Cache Ops/s') +
          g.queryPanel(
            [
              'sum(rate(thanos_store_index_cache_items_added_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace, item_type)' % $._config,
              'sum(rate(thanos_store_index_cache_items_evicted_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace, item_type)' % $._config,
              'sum(rate(thanos_store_index_cache_requests_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace, item_type)' % $._config,
              'sum(rate(thanos_store_index_cache_hits_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace, item_type)' % $._config,
            ], [
              'added {{item_type}}',
              'evicted {{item_type}}',
              'requests {{item_type}}',
              'hits {{item_type}}',
            ],
          )
        )
        .addPanel(
          g.panel('Series Gate Time 99th Percentile') +
          g.queryPanel(
            |||
              histogram_quantile(0.99,
                sum(thanos_bucket_store_series_gate_duration_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}) by (le)
              )
            ||| % $._config,
            ''
          )
        )
        .addPanel(
          g.panel('Pod Operation Time 99th Percentile') +
          g.queryPanel(
            [
              'thanos_bucket_store_series_blocks_queried{namespace="$namespace",%(thanosStoreSelector)s,quantile="0.99"}' % $._config,
              'thanos_bucket_store_series_data_fetched{namespace="$namespace",%(thanosStoreSelector)s,quantile="0.99"}' % $._config,
              'thanos_bucket_store_series_result_series{namespace="$namespace",%(thanosStoreSelector)s,quantile="0.99"}' % $._config,
            ], [
              'blocks queried {{kubernetes_pod_name}}',
              'data fetched {{kubernetes_pod_name}}',
              'result series {{kubernetes_pod_name}}',
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
              'go_memstats_alloc_bytes{namespace="$namespace",%(thanosStoreSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosStoreSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'rate(go_memstats_alloc_bytes_total{namespace="$namespace",%(thanosStoreSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'rate(go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosStoreSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'go_memstats_stack_inuse_bytes{namespace="$namespace",%(thanosStoreSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_inuse_bytes{namespace="$namespace",%(thanosStoreSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
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
            'go_goroutines{namespace="$namespace",%(thanosStoreSelector)s}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosStoreSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
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
      }
      + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
