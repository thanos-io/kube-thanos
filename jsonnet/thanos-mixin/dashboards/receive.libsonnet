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
        g.row('Request')
        .addPanel(
          g.panel('Forward Request Failure Rate') +
          g.queryPanel(
            |||
              sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,result="error"}[$interval]))
              /
              sum(rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
            ||| % $._config,
            'failure rate'
          ) +
          { yaxes: g.yaxes('percentunit') }
        )
        .addPanel(
          g.panel('Request Duration 99th Percentile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(thanos_http_request_duration_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])) by (handler, le))' % $._config,
            '{{handler}}'
          )
        )
      )
      .addRow(
        g.row('Hashring')
        .addPanel(
          g.panel('Hashring File Refresh Failure Rate') +
          g.queryPanel(
            |||
              sum(rate(thanos_receive_hashrings_file_errors_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
              /
              sum(rate(thanos_receive_hashrings_file_refreshes_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval]))
            ||| % $._config,
            'failure rate'
          ) +
          { yaxes: g.yaxes('percentunit') }
        )
      )
      .addRow(
        g.row('Hashring')
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
        g.row('Config')
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
      )
      + {
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
      }
      + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
