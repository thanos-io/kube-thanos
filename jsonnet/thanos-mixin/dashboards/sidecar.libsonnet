local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'sidecar.json':
      g.dashboard($._config.grafanaThanos.dashboardSidecarTitle)
      .addTemplate('namespace', 'kube_pod_info', 'namespace')
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="unary"' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('client', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('client', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('client', 'namespace="$namespace",%(thanosSidecarSelector)s,grpc_type="server_stream"' % $._config)
        ) +
        g.collapse
      )
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
          g.qpsErrTotalPanel(
            'thanos_objstore_bucket_operation_failures_total{namespace="$namespace",%(thanosSidecarSelector)s}' % $._config,
            'thanos_objstore_bucket_operations_total{namespace="$namespace",%(thanosSidecarSelector)s}' % $._config,
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', 'namespace="$namespace",%(thanosSidecarSelector)s' % $._config,)
        )
      )
      .addRow(
        g.resourceUtilizationRow('%(thanosSidecarSelector)s' % $._config)
      ) +
      g.podTemplate('namespace="$namespace",created_by_name=~"%(thanosSidecar)s.*"' % $._config),
  },
}
