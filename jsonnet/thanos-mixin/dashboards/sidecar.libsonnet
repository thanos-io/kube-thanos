local b = import '../lib/thanos-grafana-builder/builder.libsonnet';
local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'sidecar.json':
      g.dashboard(
        '%(dashboardNamePrefix)sSidecar' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('Last Updated')
        .addPanel(
          g.panel('Successful Upload') +
          g.tablePanel(
            ['time() - max(thanos_objstore_bucket_last_successful_upload_time{namespace="$namespace",%(thanosSidecarSelector)s}) by (bucket)' % $._config],
            {
              Value: {
                alias: 'Uploaded Ago',
                unit: 's',
                type: 'number',
              },
            },
          )
        )
        .addPanel(
          g.panel('Successful Hearthbeat') +
          g.tablePanel(
            ['time() - max(thanos_sidecar_last_heartbeat_success_time_seconds{namespace="$namespace",%(thanosSidecarSelector)s}) by (pod)' % $._config],
            {
              Value: {
                alias: 'Ago',
                unit: 's',
                type: 'number',
              },
            },
          )
        )
      )
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorDetailsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        ) +
        b.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanelDetailed('client', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorDetailsPanel('client', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanelDetailed('client', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        ) +
        b.collapse
      )
      .addRow(
        g.row('Bucket Operations')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_objstore_bucket_operations_total{namespace="$namespace",%(thanosSidecarSelector)s}[$interval])) by (operation)' % $._config,
            '{{operation}}'
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Errors') +
          g.queryPanel(
            |||
              sum(
                rate(thanos_objstore_bucket_operation_failures_total{namespace="$namespace",%(thanosSidecarSelector)s}[$interval])
              /
                rate(thanos_objstore_bucket_operations_total{namespace="$namespace",%(thanosSidecarSelector)s}[$interval])
              )
            ||| % $._config,
            'error'
          ) +
          { aliasColors: { 'error': '#E24D42' } } +
          { yaxes: g.yaxes({ format: 'percentunit', max: 1 }) }
        )
        .addPanel(
          g.panel('Duration') +
          b.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', 'namespace="$namespace",%(thanosSidecarSelector)s' % $._config,)
        )
      )
      .addRow(
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              'go_memstats_alloc_bytes{namespace="$namespace",%(thanosSidecarSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosSidecarSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'rate(go_memstats_alloc_bytes_total{namespace="$namespace",%(thanosSidecarSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'rate(go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosSidecarSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'go_memstats_stack_inuse_bytes{namespace="$namespace",%(thanosSidecarSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_inuse_bytes{namespace="$namespace",%(thanosSidecarSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
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
            'go_goroutines{namespace="$namespace",%(thanosSidecarSelector)s}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosSidecarSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
            '{{quantile}} {{pod}}'
          )
        )
        + { collapse: true }
      ) +
      b.podTemplate('namespace="$namespace",created_by_name=~"%(thanosSidecar)s.*"' % $._config),
  },
}
