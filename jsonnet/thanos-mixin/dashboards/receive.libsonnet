local g = import '../lib/thanos-grafana-builder/builder.libsonnet';

{
  grafanaDashboards+:: {
    'receive.json':
      g.dashboard($._config.grafanaThanos.dashboardReceiveTitle)
      .addTemplate('namespace', 'kube_pod_info', 'namespace')
      .addRow(
        g.row('Incoming Request')
        .addPanel(
          g.panel('Rate') +
          g.httpQpsPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.httpErrPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('thanos_http_request_duration_seconds', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.httpQpsPanelDetailed('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.httpErrDetailsPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.httpLatencyDetailsPanel('thanos_http_request_duration_seconds', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.row('Forward Request')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))' % $._config,
            'all',
          )
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,result="error"}' % $._config,
            'thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
          )
        )
      )
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          g.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          g.grpcErrDetailsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          g.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        ) +
        g.collapse
      )
      .addRow(
        g.row('Last Updated')
        .addPanel(
          g.panel('Successful Upload') +
          g.tablePanel(
            ['time() - max(thanos_objstore_bucket_last_successful_upload_time{namespace="$namespace",%(thanosReceiveSelector)s}) by (bucket)' % $._config],
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
        g.row('Hashring Status')
        .addPanel(
          g.panel('Nodes per Hashring') +
          g.queryPanel(
            'avg(thanos_receive_hashring_nodes{namespace="$namespace",%(thanosReceiveSelector)s}) by (name)' % $._config,
            '{{name}}'
          )
        )
        .addPanel(
          g.panel('Tenants per Hashring') +
          g.queryPanel(
            'avg(thanos_receive_hashring_tenants{namespace="$namespace",%(thanosReceiveSelector)s}) by (name)' % $._config,
            '{{name}}'
          )
        )
      )
      .addRow(
        g.row('Hashring Config')
        .addPanel(
          g.panel('Last Updated') +
          g.statPanel(
            'time() - max(thanos_receive_config_last_reload_success_timestamp_seconds{namespace="$namespace",%(thanosReceiveSelector)s})' % $._config,
            's'
          ) +
          {
            postfix: 'ago',
            decimals: 0,
          }
        )
        .addPanel(
          g.panel('Latest Config Reload') +
          g.statPanel(
            'avg(thanos_receive_config_last_reload_successful{namespace="$namespace",%(thanosReceiveSelector)s})' % $._config,
            'none'
          ) +
          {
            thresholds: '0.5,0.7',
            colorBackground: true,
            colors: [
              '#d44a3a',
              'rgba(237, 129, 40, 0.89)',
              '#299c46',
            ],
            valueMaps: [
              {
                value: 'null',
                op: '=',
                text: 'N/A',
              },
              {
                value: '1',
                op: '=',
                text: 'OK',
              },
            ],
          },
        )
      )
      .addRow(
        g.row('Hashring Config Refresh')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(thanos_receive_hashrings_file_changes_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))' % $._config,
            'all'
          )
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'thanos_receive_hashrings_file_errors_total{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            'thanos_receive_hashrings_file_changes_total{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
          )
        )
      )
      .addRow(
        g.row('Compaction')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosReceiveSelector)s}[$interval]))' % $._config,
            'compaction'
          )
        )
        .addPanel(
          g.panel('Errors') +
          g.qpsErrTotalPanel(
            'prometheus_tsdb_compactions_failed_total{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            'prometheus_tsdb_compactions_total{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
          )
        )
        .addPanel(
          g.panel('Duration') +
          g.latencyPanel('prometheus_tsdb_compaction_duration_seconds', 'namespace=~"$namespace",%(thanosReceiveSelector)s' % $._config)
        )
      )
      .addRow(
        g.resourceUtilizationRow('%(thanosReceiveSelector)s' % $._config)
      ) +
      g.podTemplate('namespace="$namespace",created_by_name=~"%(thanosReceive)s.*"' % $._config),
  },
}
