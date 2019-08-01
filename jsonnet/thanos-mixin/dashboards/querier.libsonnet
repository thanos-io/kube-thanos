local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'querier.json':
      g.dashboard(
        'querier'
      )
      .addRow(
        g.row('Thanos Query')
        .addPanel(
          g.panel('Request RPS') +
          g.queryPanel(
            'sum(rate(grpc_client_handled_total{$labelselector="$labelvalue",kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, grpc_code, grpc_method)',
            '{{grpc_code}} {{grpc_method}} {{kubernetes_pod_name}}'
          )
        )
      ),
  },
}
