local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'receive.json':
      g.dashboard($._config.grafanaThanos.dashboardReceiveTitle)
      .addRow(
        g.row('Incoming Request')
        .addPanel(
          g.panel('Rate') +
          g.httpQpsPanel('thanos_http_requests_total', 'namespace="$namespace",job=~"$job"')
        )
        .addPanel(
          g.panel('Errors') +
          g.httpErrPanel('thanos_http_requests_total', 'namespace="$namespace",job=~"$job"')
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_http_request_duration_seconds', 'namespace="$namespace",job=~"$job"')
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.httpQpsPanelDetailed('thanos_http_requests_total', 'namespace="$namespace",job=~"$job"')
        )
        .addPanel(
          g.panel('Errors') +
          g.httpErrDetailsPanel('thanos_http_requests_total', 'namespace="$namespace",job=~"$job"')
        )
        .addPanel(
          g.panel('Duration') +
          g.httpLatencyDetailsPanel('thanos_http_request_duration_seconds', 'namespace="$namespace",job=~"$job"')
        ) +
        g.collapse
      )
      .addRow(
        g.row('Forward Request')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",job=~"$job"}[$interval])) by (job)',
            'all {{job}}',
          )
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_receive_forward_requests_total{namespace="$namespace",job=~"$job",result="error"}',
            'thanos_receive_forward_requests_total{namespace="$namespace",job=~"$job"}',
          )
        )
      )
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
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",job=~"$job",grpc_type="server_stream"')
        ) +
        g.collapse
      )
      .addRow(
        g.row('Last Updated')
        .addPanel(
          g.panel('Successful Upload') +
          g.tablePanel(
            ['time() - max(thanos_objstore_bucket_last_successful_upload_time{namespace="$namespace",job=~"$job"}) by (job, bucket)'],
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
        g.resourceUtilizationRow()
      ) +
      g.template('namespace', 'kube_pod_info') +
      g.template('job', 'up', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config, true, "%(thanosReceiveJobPrefix)s.*" % $._config) +
      g.template('pod', 'kube_pod_info', 'namespace="$namespace",created_by_name=~"%(thanosReceiveJobPrefix)s.*"' % $._config, true, '.*'),
  },
}
