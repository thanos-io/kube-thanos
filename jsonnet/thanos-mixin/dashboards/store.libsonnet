local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'store.json':
      g.dashboard($._config.grafanaThanos.dashboardStoreTitle)
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
          g.grpcQpsPanelDetailed('client', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('client', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('client', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        ) +
        g.collapse
      )
      .addRow(
        g.row('Bucket Operations')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_objstore_bucket_operations_total{namespace="$namespace",job=~"$job"}[$interval])) by (job, operation)',
            '{{job}} {{operation}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_objstore_bucket_operation_failures_total{namespace="$namespace",job=~"$job"}',
            'thanos_objstore_bucket_operations_total{namespace="$namespace",job=~"$job"}',
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', 'namespace="$namespace",job=~"$job"')
        )
      )
      .addRow(
        g.row('Block Operations')
        .addPanel(
          g.panel('Block Load Rate') +
          g.queryPanel(
            'sum(rate(thanos_bucket_store_block_loads_total{namespace="$namespace",job=~"$job"}[$interval]))',
            'block loads'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Block Load Errors') +
          g.qpsErrTotalPanel(
            'thanos_bucket_store_block_load_failures_total{namespace="$namespace",job=~"$job"}',
            'thanos_bucket_store_block_loads_total{namespace="$namespace",job=~"$job"}',
          )
        )
        .addPanel(
          g.panel('Block Drop Rate') +
          g.queryPanel(
            'sum(rate(thanos_bucket_store_block_drops_total{namespace="$namespace",job=~"$job"}[$interval])) by (job, operation)',
            'block drops {{job}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Block Drop Errors') +
          g.qpsErrTotalPanel(
            'thanos_bucket_store_block_drop_failures_total{namespace="$namespace",job=~"$job"}',
            'thanos_bucket_store_block_drops_total{namespace="$namespace",job=~"$job"}',
          )
        )
      )
      .addRow(
        g.row('Cache Operations')
        .addPanel(
          g.panel('Requests') +
          g.queryPanel(
            'sum(rate(thanos_store_index_cache_requests_total{namespace="$namespace",job=~"$job"}[$interval])) by (job, item_type)',
            '{{job}} {{item_type}}',
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Hits') +
          g.queryPanel(
            'sum(rate(thanos_store_index_cache_hits_total{namespace="$namespace",job=~"$job"}[$interval])) by (job, item_type)',
            '{{job}} {{item_type}}',
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Added') +
          g.queryPanel(
            'sum(rate(thanos_store_index_cache_items_added_total{namespace="$namespace",job=~"$job"}[$interval])) by (job, item_type)',
            '{{job}} {{item_type}}',
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Evicted') +
          g.queryPanel(
            'sum(rate(thanos_store_index_cache_items_evicted_total{namespace="$namespace",job=~"$job"}[$interval])) by (job, item_type)',
            '{{job}} {{item_type}}',
          ) +
          g.stack
        )
      )
      .addRow(
        g.row('Store Sent')
        .addPanel(
          g.panel('Chunk Size') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_bucket_store_sent_chunk_size_bytes_bucket{namespace="$namespace",job=~"$job"}[$interval])) by (job, le))',
              'sum(rate(thanos_bucket_store_sent_chunk_size_bytes_sum{namespace="$namespace",job=~"$job"}[$interval])) by (job) / sum(rate(thanos_bucket_store_sent_chunk_size_bytes_count{namespace="$namespace",job=~"$job"}[$interval])) by (job)',
              'histogram_quantile(0.99, sum(rate(thanos_bucket_store_sent_chunk_size_bytes_bucket{namespace="$namespace",job=~"$job"}[$interval])) by (job, le))',
            ],
            [
              'P99',
              'mean',
              'P50',
            ],
          )
        ) +
        { yaxes: g.yaxes('decbytes') },
      )
      .addRow(
        g.row('Series Operations')
        .addPanel(
          g.panel('Block queried') +
          g.queryPanel(
            [
              'thanos_bucket_store_series_blocks_queried{namespace="$namespace",job=~"$job",quantile="0.99"}',
              'sum(rate(thanos_bucket_store_series_blocks_queried_sum{namespace="$namespace",job=~"$job"}[$interval])) by (job) / sum(rate(thanos_bucket_store_series_blocks_queried_count{namespace="$namespace",job=~"$job"}[$interval])) by (job)',
              'thanos_bucket_store_series_blocks_queried{namespace="$namespace",job=~"$job",quantile="0.50"}',
            ], [
              'P99',
              'mean {{job}}',
              'P50',
            ],
          )
        )
        .addPanel(
          g.panel('Data Fetched') +
          g.queryPanel(
            [
              'thanos_bucket_store_series_data_fetched{namespace="$namespace",job=~"$job",quantile="0.99"}',
              'sum(rate(thanos_bucket_store_series_data_fetched_sum{namespace="$namespace",job=~"$job"}[$interval])) by (job) / sum(rate(thanos_bucket_store_series_data_fetched_count{namespace="$namespace",job=~"$job"}[$interval])) by (job)',
              'thanos_bucket_store_series_data_fetched{namespace="$namespace",job=~"$job",quantile="0.50"}',
            ], [
              'P99',
              'mean {{job}}',
              'P50',
            ],
          )
        )
        .addPanel(
          g.panel('Result series') +
          g.queryPanel(
            [
              'thanos_bucket_store_series_result_series{namespace="$namespace",job=~"$job",quantile="0.99"}',
              'sum(rate(thanos_bucket_store_series_result_series_sum{namespace="$namespace",job=~"$job"}[$interval])) by (job) / sum(rate(thanos_bucket_store_series_result_series_count{namespace="$namespace",job=~"$job"}[$interval])) by (job)',
              'thanos_bucket_store_series_result_series{namespace="$namespace",job=~"$job",quantile="0.50"}',
            ], [
              'P99',
              'mean {{job}}',
              'P50',
            ],
          )
        )
      )
      .addRow(
        g.row('Series Operation Durations')
        .addPanel(
          g.panel('Get All') +
          g.latencyPanel('thanos_bucket_store_series_get_all_duration_seconds', 'namespace="$namespace",job=~"$job"')
        )
        .addPanel(
          g.panel('Merge') +
          g.latencyPanel('thanos_bucket_store_series_merge_duration_seconds_bucket', 'namespace="$namespace",job=~"$job"')
        )
        .addPanel(
          g.panel('Gate') +
          g.latencyPanel('thanos_bucket_store_series_gate_duration_seconds_bucket', 'namespace="$namespace",job=~"$job"')
        )
      )
      .addRow(
        g.resourceUtilizationRow()
      ) +
      g.template('namespace', 'kube_pod_info') +
      g.template('job', 'up', 'namespace="$namespace",%(thanosStoreSelector)s' % $._config, true, '%(thanosStoreJobPrefix)s.*' % $._config) +
      g.template('pod', 'kube_pod_info', 'namespace="$namespace",created_by_name=~"%(thanosStoreJobPrefix)s.*"' % $._config, true, '.*'),
  },
}
