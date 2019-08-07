local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;
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
          g.queryPanel(
            'sum(rate(grpc_server_handled_total{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"}[$interval])) by (grpc_code)' % $._config,
            '{{grpc_code}}',
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Error Rate') +
          g.queryPanel(
            |||
              sum(
                rate(grpc_server_handled_total{namespace="$namespace",grpc_code!="OK",%(thanosReceiveSelector)s,grpc_type="unary"}[$interval])
                /
                rate(grpc_server_started_total{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"}[$interval])
              ) by (grpc_code, grpc_method)
            ||| % $._config,
            '{{grpc_code}} {{grpc_method}}'
          )
        )
        .addPanel(
          g.panel('Duration Percentile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(grpc_server_handling_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"}[$interval])) by (handler, le))' % $._config,
              |||
                sum(rate(grpc_server_handling_seconds_sum{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"}[$interval]))
                /
                sum(rate(grpc_server_handling_seconds_count{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"}[$interval]))
              ||| % $._config,
              'histogram_quantile(0.50, sum(rate(grpc_server_handling_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="unary"}[$interval])) by (handler, le))' % $._config,
            ],
            [
              '99 {{grpc_method}}',
              'mean {{grpc_method}}',
              '50 {{grpc_method}}',
            ]
          )
        )
      )
      .addRow(
        g.row('gRPC (Stream)')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            'sum(rate(grpc_server_handled_total{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"}[$interval])) by (grpc_code)' % $._config,
            '{{grpc_code}}',
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Error Rate') +
          g.queryPanel(
            |||
              sum(
                rate(grpc_server_handled_total{namespace="$namespace",grpc_code!="OK",%(thanosReceiveSelector)s,grpc_type="server_stream"}[$interval])
                /
                rate(grpc_server_started_total{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"}[$interval])
              ) by (grpc_code, grpc_method)
            ||| % $._config,
            '{{grpc_code}} {{grpc_method}}'
          )
        )
        // Unknown|ResourceExhausted|Internal|Unavailable
        .addPanel(
          g.panel('Duration Percentile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(grpc_server_handling_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"}[$interval])) by (handler, le))' % $._config,
              |||
                sum(rate(grpc_server_handling_seconds_sum{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"}[$interval]))
                /
                sum(rate(grpc_server_handling_seconds_count{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"}[$interval]))
              ||| % $._config,
              'histogram_quantile(0.50, sum(rate(grpc_server_handling_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s,grpc_type="server_stream"}[$interval])) by (handler, le))' % $._config,
            ],
            [
              '99 {{grpc_method}}',
              'mean {{grpc_method}}',
              '50 {{grpc_method}}',
            ]
          )
        )
      )
      .addRow(
        g.row('Incoming Request')
        .addPanel(
          g.panel('Rate') +
          g.queryPanel(
            |||
              sum(
                label_replace(
                  rate(thanos_http_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]),
                  "status_code", "${1}xx", "code", "([0-9]).."
                  )
              ) by (status_code)
            ||| % $._config,
            '{{status_code}}'
          ) +
          g.stack +
          {
            aliasColors: {
              '1xx': '#EAB839',
              '2xx': '#7EB26D',
              '3xx': '#6ED0E0',
              '4xx': '#EF843C',
              '5xx': '#E24D42',
              success: '#7EB26D',
              'error': '#E24D42',
            },
          },
        )
        .addPanel(
          g.panel('Error Rate') +
          g.queryPanel(
            |||
              sum(rate(thanos_http_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,code!~"2.."}[$interval])) by (handler)
              /
              sum(rate(thanos_http_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])) by (handler)
            ||| % $._config,
            '{{handler}}'
          ) +
          {
            yaxes: g.yaxes({ format: 'percentunit', max: 1 }),
            aliasColors: {
              'error': '#E24D42',
            },
          },
        )
        .addPanel(
          g.panel('Duration Percentile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_http_request_duration_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])) by (handler, le))' % $._config,
              |||
                sum(rate(thanos_http_request_duration_seconds_sum{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
                /
                sum(rate(thanos_http_request_duration_seconds_count{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
              ||| % $._config,
              'histogram_quantile(0.50, sum(rate(thanos_http_request_duration_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])) by (handler, le))' % $._config,
            ],
            [
              '99 {{handler}}',
              'mean {{handler}}',
              '50 {{handler}}',
            ]
          )
        )
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
            yaxes: g.yaxes('percentunit'),
            aliasColors: {
              success: '#7EB26D',
              'error': '#E24D42',
            },
          }
        )
        .addPanel(
          g.panel('Error Rate') +
          g.queryPanel(
            |||
              sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,result="error"}[$interval]))
              /
              sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
            ||| % $._config,
            'error'
          ) +
          {
            yaxes: g.yaxes('percentunit'),
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
        g.row('Hashring Refresh')
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
            yaxes: g.yaxes('percentunit'),
            aliasColors: {
              success: '#7EB26D',
              'error': '#E24D42',
            },
          }
        )
        .addPanel(
          g.panel('Error Rate') +
          g.queryPanel(
            |||
              sum(rate(thanos_receive_hashrings_file_errors_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
              /
              sum(rate(thanos_receive_hashrings_file_refreshes_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
            ||| % $._config,
            'error'
          ) +
          {
            yaxes: g.yaxes('percentunit'),
            aliasColors: {
              success: '#7EB26D',
              'error': '#E24D42',
            },
          }
        )
      )
      .addRow(
        g.row('Hashring Config')
        .addPanel(
          g.panel('Latest Config') +
          g.statPanel(
            'thanos_receive_config_hash{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            'none'
          )
        )
        .addPanel(
          g.panel('Last Updated At') +
          g.statPanel(
            'thanos_receive_config_last_reload_success_timestamp_seconds{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            'none'
          )
        )
        .addPanel(
          g.panel('Latest Config Reload') +
          g.statPanel(
            'thanos_receive_config_last_reload_successful{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            'none'
          )
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
        )
        + { collapse: true }
      ) +
      {
        templating+: {
          list+: [
            template.new(
              'pod',
              '$datasource',
              'label_values(kube_pod_info{namespace="$namespace",%(thanosReceiveSelector)s}, pod)' % $._config,
              label='pod',
              refresh=1,
              sort=2,
              current='all',
              allValues='.*',
              includeAll=true
            ),
          ],
        },
      } +
      { tags: $._config.grafanaThanos.dashboardTags },
  },
}
