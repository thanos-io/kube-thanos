local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'querier.json':
      g.dashboard(
        '%(dashboardNamePrefix)sQuerier' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorDetailsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="server_stream"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorDetailsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="server_stream"' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.row('DNS')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_querier_store_apis_dns_lookups_total{namespace="$namespace",%(thanosQuerierSelector)s}[$interval]))' % $._config,
            'lookups'
          )
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_querier_store_apis_dns_failures_total{namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
            'thanos_querier_store_apis_dns_lookups_total{namespace=~"$namespace",%(thanosQuerierSelector)s}' % $._config,
          )
        )
      )
      .addRow(
        g.row('Query API')
        .addPanel(
          g.panel('Instant Query') +
          g.latencyPanel('thanos_query_api_instant_query_duration_seconds', 'namespace="$namespace",%(thanosQuerierSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Range Query') +
          g.latencyPanel('thanos_query_api_range_query_duration_seconds', 'namespace="$namespace",%(thanosQuerierSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Instant Query') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_query_api_instant_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])) by (pod, le))' % $._config,
              |||
                sum(
                  rate(thanos_query_api_instant_query_duration_seconds_sum{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
                /
                  rate(thanos_query_api_instant_query_duration_seconds_count{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
                ) by (pod)
              ||| % $._config,
              'histogram_quantile(0.50, sum(rate(thanos_query_api_instant_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])) by (pod, le))' % $._config,
            ],
            [
              'P99 {{pod}}',
              'mean {{pod}}',
              'P50 {{pod}}',
            ]
          )
        )
        .addPanel(
          g.panel('Range Query') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_query_api_range_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])) by (pod, le))' % $._config,
              |||
                sum(
                  rate(thanos_query_api_range_query_duration_seconds_sum{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
                /
                  rate(thanos_query_api_range_query_duration_seconds_count{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
                ) by (pod)
              ||| % $._config,
              'histogram_quantile(0.50, sum(rate(thanos_query_api_range_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])) by (pod, le))' % $._config,
            ],
            [
              'P99 {{pod}}',
              'mean {{pod}}',
              'P50 {{pod}}',
            ]
          )
        ) +
        g.collapse
      )
      .addRow(
        g.row('Prometheus')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'prometheus_engine_queries{namespace="$namespace",%(thanosPrometheusSelector)s}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.queryPanel(
            [
              'prometheus_engine_query_duration_seconds{namespace="$namespace",%(thanosPrometheusSelector)s,quantile="0.99"}' % $._config,
              'prometheus_engine_query_duration_seconds{namespace="$namespace",%(thanosPrometheusSelector)s,quantile="0.50"}' % $._config,
            ],
            [
              'P99 {{pod}} {{slice}}',
              'P50 {{pod}} {{slice}}',
            ],
          )
        )
      )
      .addRow(
        g.row('Store')
        .addPanel(
          g.panel('Connected') +
          g.statPanel(
            'sum(thanos_store_nodes_grpc_connections{namespace="$namespace",%(thanosQuerierSelector)s})' % $._config,
            'none'
          ) +
          g.sparkline
        )
        .addPanel(
          g.panel('Node Info') +
          g.tablePanel(
            ['min(thanos_store_node_info{namespace="$namespace",%(thanosQuerierSelector)s}) by (external_labels)' % $._config],
            {},
          )
        )
      )
      .addRow(
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              'go_memstats_alloc_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'rate(go_memstats_alloc_bytes_total{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'rate(go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'go_memstats_stack_inuse_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_inuse_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
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
            'go_goroutines{namespace="$namespace",%(thanosQuerierSelector)s}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
            '{{quantile}} {{pod}}'
          )
        )
        + { collapse: true }
      ) +
      g.podTemplate('namespace="$namespace",created_by_name=~"%(thanosQuerier)s.*"' % $._config),
  },
}
