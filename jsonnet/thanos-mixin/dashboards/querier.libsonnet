local b = import '../lib/thanos-grafana-builder/builder.libsonnet';
local g = import 'grafana-builder/grafana.libsonnet';

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
          b.grpcQpsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="unary"' % $._config)
        ) +
        b.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="client_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="client_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanel('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="client_stream"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="client_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="client_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanelDetailed('client', 'namespace="$namespace",%(thanosQuerierSelector)s,grpc_type="client_stream"' % $._config)
        ) +
        b.collapse

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
          g.queryPanel(
            |||
              sum(
                rate(thanos_querier_store_apis_dns_failures_total{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
              /
                rate(thanos_querier_store_apis_dns_lookups_total{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
              )
            ||| % $._config,
            'error'
          ) +
          { yaxes: g.yaxes({ format: 'percentunit', max: 1 }) } +
          g.stack,
        )
      )
      .addRow(
        g.row('Query API')
        .addPanel(
          g.panel('Instant Query') +
          b.latencyPanel('thanos_query_api_instant_query_duration_seconds', 'namespace="$namespace",%(thanosQuerierSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Range Query') +
          b.latencyPanel('thanos_query_api_range_query_duration_seconds', 'namespace="$namespace",%(thanosQuerierSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_query_api_instant_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))' % $._config,
              |||
                sum(
                  rate(thanos_query_api_instant_query_duration_seconds_sum{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])
                /
                  rate(thanos_query_api_instant_query_duration_seconds_count{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])
                ) by (kubernetes_pod_name)
              ||| % $._config,
              'histogram_quantile(0.50, sum(rate(thanos_query_api_instant_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))' % $._config,
            ],
            [
              'P99 {{pod}}',
              'mean {{pod}}',
              'P50 {{pod}}',
            ]
          )
        )
        .addPanel(
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_query_api_range_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))' % $._config,
              |||
                sum(
                  rate(thanos_query_api_range_query_duration_seconds_sum{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])
                /
                  rate(thanos_query_api_range_query_duration_seconds_count{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])
                ) by (kubernetes_pod_name)
              ||| % $._config,
              'histogram_quantile(0.50, sum(rate(thanos_query_api_range_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))' % $._config,
            ],
            [
              'P99 {{pod}}',
              'mean {{pod}}',
              'P50 {{pod}}',
            ]
          )
        ) +
        b.collapse
      )
      .addRow(
        g.row('Prometheus')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'prometheus_engine_queries{namespace="$namespace",%(thanosPrometheusSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.queryPanel(
            [
              'prometheus_engine_query_duration_seconds{namespace="$namespace",%(thanosPrometheusSelector)s,kubernetes_pod_name=~"$pod",quantile="0.99"}' % $._config,
              'prometheus_engine_query_duration_seconds{namespace="$namespace",%(thanosPrometheusSelector)s,kubernetes_pod_name=~"$pod",quantile="0.50"}' % $._config,
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
            'sum(thanos_store_nodes_grpc_connections{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"})' % $._config,
            'none'
          ) +
          b.sparkline
        )
        .addPanel(
          g.panel('Gossip Info') +
          g.tablePanel(
            [
              'min(thanos_store_node_info{namespace="$namespace",%(thanosQuerierSelector)s}) by (external_labels)' % $._config,
            ],
            {
              'Value #A': {
                alias: 'Peer',
                decimals: 2,
                colors: [
                  'rgba(245, 54, 54, 0.9)',
                  'rgba(237, 129, 40, 0.89)',
                  'rgba(50, 172, 45, 0.97)',
                ],
              },
              'Value #B': {
                alias: 'Replicas',
                decimals: 2,
                // type: 'hidden',
                colors: [
                  'rgba(245, 54, 54, 0.9)',
                  'rgba(237, 129, 40, 0.89)',
                  'rgba(50, 172, 45, 0.97)',
                ],
              },
            },
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
      b.podTemplate('namespace="$namespace",created_by_name=~"%(thanosQuerier)s.*"' % $._config),
  },
}
