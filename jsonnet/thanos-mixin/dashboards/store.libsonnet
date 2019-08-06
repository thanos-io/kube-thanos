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
            '{{grpc_code}} {{grpc_method}} {{namespace}}'
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
            '{{grpc_code}} {{grpc_method}} {{namespace}}'
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
          g.panel('Response Time 99th Quantile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(grpc_server_handling_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (grpc_method, le, namespace))' % $._config,
            '{{grpc_method}} {{namespace}}'
          )
        )
        .addPanel(
          g.panel('Response Size 99th Quantile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(thanos_bucket_store_sent_chunk_size_bytes_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (le, namespace))' % $._config,
            '{{namespace}}'
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
              'bucket {{operation}} {{namespace}}',
              'block drops {{namespace}}',
              'block loads {{namespace}}',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Failures/s') +
          g.queryPanel(
            [
              'sum(rate(thanos_objstore_bucket_operation_failures_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (operation,namespace)' % $._config,
              'sum(rate(thanos_bucket_store_block_drop_failures_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace)' % $._config,
              'sum(rate(thanos_bucket_store_block_load_failures_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace)' % $._config,
            ], [
              'bucket {{operation}} {{namespace}}',
              'block drops {{namespace}}',
              'block loads {{namespace}}',
            ],
          )
        )
        .addPanel(
          g.panel('Operation Time 99th Quantile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_objstore_bucket_operation_duration_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,le, operation))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_bucket_store_series_get_all_duration_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,le))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_bucket_store_series_merge_duration_seconds_bucket{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,le))' % $._config,
            ], [
              '99 bucket {{operation}} {{namespace}}',
              '99 get all {{namespace}}',
              '99 merge {{namespace}}',
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
              'sum(rate(thanos_store_index_cache_items_added_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,item_type)' % $._config,
              'sum(rate(thanos_store_index_cache_items_evicted_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,item_type)' % $._config,
              'sum(rate(thanos_store_index_cache_requests_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,item_type)' % $._config,
              'sum(rate(thanos_store_index_cache_hits_total{namespace="$namespace",%(thanosStoreSelector)s}[$interval])) by (namespace,item_type)' % $._config,
            ], [
              'added {{item_type}} {{namespace}}',
              'evicted {{item_type}} {{namespace}}',
              'requests {{item_type}} {{namespace}}',
              'hits {{item_type}} {{namespace}}',
            ],
          )
        )
        .addPanel(
          g.panel('Series Gate Time 99th Quantile') +
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
          g.panel('Pod Operation Time 99th Quantile') +
          g.queryPanel(
            [
              'thanos_bucket_store_series_blocks_queried{namespace="$namespace",%(thanosStoreSelector)s,quantile="0.99"}' % $._config,
              'thanos_bucket_store_series_data_fetched{namespace="$namespace",%(thanosStoreSelector)s,quantile="0.99"}' % $._config,
              'thanos_bucket_store_series_result_series{namespace="$namespace",%(thanosStoreSelector)s,quantile="0.99"}' % $._config,
            ], [
              'blocks queried {{kubernetes_pod_name}} {{namespace}}',
              'data fetched {{kubernetes_pod_name}} {{namespace}}',
              'result series {{kubernetes_pod_name}} {{namespace}}',
            ],
          )
        )
      )
      .addRow(
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosStoreSelector)s}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('Goroutines') +
          g.queryPanel(
            'go_goroutines{namespace="$namespace",%(thanosStoreSelector)s}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosStoreSelector)s, quantile="1"}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
      )
      + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
