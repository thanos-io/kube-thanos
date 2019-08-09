local b = import '../lib/thanos-grafana-builder/builder.libsonnet';
local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'receive.json':
      g.dashboard(
        '%(dashboardNamePrefix)sReceive' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('gRPC (Unary)')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorDetailsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"' % $._config)
        ) +
        b.collapse
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          b.grpcQpsPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.grpcErrorDetailsPanel('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.grpcLatencyPanelDetailed('server', 'namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"' % $._config)
        ) +
        b.collapse
      )
      .addRow(
        g.row('Incoming Request')
        .addPanel(
          g.panel('Rate') +
          b.qpsPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.errorsPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.latencyPanel('thanos_http_request_duration_seconds', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Detailed')
        .addPanel(
          g.panel('Rate') +
          b.qpsPanelDetailed('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Errors') +
          b.errorDetailsPanel('thanos_http_requests_total', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        )
        .addPanel(
          g.panel('Duration') +
          b.httpLatencyDetailsPanel('thanos_http_request_duration_seconds', 'namespace="$namespace",%(thanosReceiveSelector)s' % $._config)
        ) +
        b.collapse
      )
      .addRow(
        g.row('Forward Request')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            [
              'sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,result="error"}[$interval]))' % $._config,
              'sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,result="success"}[$interval]))' % $._config,
            ],
            [
              'error',
              'success',
            ]
          ) +
          g.stack +
          {
            aliasColors: {
              success: '#7EB26D',
              'error': '#E24D42',
            },
          }
        )
        .addPanel(
          g.panel('Errors') +
          g.queryPanel(
            |||
              sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,result="error"}[$interval]))
              /
              sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
            ||| % $._config,
            'error'
          ) +
          {
            aliasColors: {
              success: '#7EB26D',
              'error': '#E24D42',
            },
          }
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
            [
              'sum(rate(thanos_receive_hashrings_file_errors_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))' % $._config,
              'sum(rate(thanos_receive_hashrings_file_changes_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))' % $._config,
            ],
            [
              'error',
              'success',
            ]
          ) +
          g.stack +
          {
            aliasColors: {
              success: '#7EB26D',
              'error': '#E24D42',
            },
          }
        )
        .addPanel(
          g.panel('Errors') +
          g.queryPanel(
            |||
              sum(rate(thanos_receive_hashrings_file_errors_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
              /
              sum(rate(thanos_receive_hashrings_file_refreshes_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
            ||| % $._config,
            'error'
          ) +
          {
            aliasColors: {
              success: '#7EB26D',
              'error': '#E24D42',
            },
          }
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
          g.queryPanel(
            'sum(rate(prometheus_tsdb_compactions_failed_total{namespace=~"$namespace",%(thanosReceiveSelector)s}[$interval])) / sum(rate(prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosReceiveSelector)s}[$interval]))' % $._config,
            'error'
          ) +
          { aliasColors: { 'error': '#E24D42' } }
        )
        .addPanel(
          g.panel('Duration') +
          b.latencyPanel('prometheus_tsdb_compaction_duration_seconds', 'namespace=~"$namespace",%(thanosReceiveSelector)s' % $._config)
        )
      )
      .addRow(
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              'go_memstats_alloc_bytes{namespace="$namespace",%(thanosReceiveSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosReceiveSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'rate(go_memstats_alloc_bytes_total{namespace="$namespace",%(thanosReceiveSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'rate(go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosReceiveSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'go_memstats_stack_inuse_bytes{namespace="$namespace",%(thanosReceiveSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_inuse_bytes{namespace="$namespace",%(thanosReceiveSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
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
            'go_goroutines{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosReceiveSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
            '{{quantile}} {{pod}}'
          )
        ) +
        b.collapse
      ) +
      b.podTemplate('namespace="$namespace",created_by_name=~"%(thanosReceive)s.*"' % $._config),
  },
}
