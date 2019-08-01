local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'querier.json':
      g.dashboard(
        'querier'
      )
      .addTemplate('thanos', 'thanos', 'thanos')
      .addRow(
        g.row('Thanos Query')
        .addPanel(
          g.panel('Request RPS') +
          g.queryPanel(
            'sum(rate(grpc_client_handled_total{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, grpc_code, grpc_method)',
            '{{grpc_code}} {{grpc_method}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('Response Time Quantile [$interval]') +
          g.queryPanel(
            'histogram_quantile(0.9999, sum(rate(grpc_client_handling_seconds_bucket{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}[$interval])) by (grpc_method,kubernetes_pod_name, le))',
            '99.99 {{grpc_method}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('Thanos Query 99.99 Quantile [$interval]') +
          g.queryPanel(
            [
              'histogram_quantile(0.9999, sum(rate(thanos_query_api_instant_query_duration_seconds_bucket{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))',
              'histogram_quantile(0.9999, sum(rate(thanos_query_api_range_query_duration_seconds_bucket{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))',

            ],
            [
              '99.99 {{grpc_method}} {{kubernetes_pod_name}}',
              'range_query {{kubernetes_pod_name}}',
            ]
          )
        )
        .addPanel(
          g.panel('Prometheus Query 99 Quantile') +
          g.queryPanel(
            'prometheus_engine_query_duration_seconds{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod",quantile="0.99"}',
            '{{kubernetes_pod_name}} {{slice}}'
          )
        )
        .addPanel(
          g.panel('Prometheus Queries/s') +
          g.queryPanel(
            'prometheus_engine_queries{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}',
            '{{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('Gossip Info') +
          g.tablePanel(
            ['min(thanos_store_node_info{$labelselector="$labelvalue"}) by (external_labels)'],
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
                type: 'hidden',
                colors: [
                  'rgba(245, 54, 54, 0.9)',
                  'rgba(237, 129, 40, 0.89)',
                  'rgba(50, 172, 45, 0.97)',
                ],
              },
            },
          )
        )
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            'go_memstats_heap_alloc_bytes{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}',
            '{{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('Goroutines') +
          g.queryPanel(
            'go_goroutines{$labelselector="$labelvalue"}',
            '{{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}',
            '{{quantile}} {{kubernetes_pod_name}}'
          )
        )
      ),
  },
}
