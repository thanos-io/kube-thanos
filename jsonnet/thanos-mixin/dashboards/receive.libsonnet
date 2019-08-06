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
        g.row('Query')
        .addPanel(
          g.panel('Request Duration Quantile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(thanos_http_request_duration_seconds_bucket{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])) by (namespace, handler, le))' % $._config,
            '{{namespace}} {{handler}}'
          )
        )
        .addPanel(
          g.panel('Forward Request Failure Rate') +
          g.queryPanel(
            |||
              sum(
                rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s,result="error"}[$interval])
              /
                rate(thanos_receive_forward_requests_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])
              )
            ||| % $._config,
            ''
          )
        )
      ).addRow(
        g.row('Hashring')
        .addPanel(
          g.panel('Nodes per Hashring') +
          g.queryPanel(
            'thanos_receive_hashring_nodes{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            ''
          )
        )
        .addPanel(
          g.panel('Tenants per Hashring') +
          g.queryPanel(
            'thanos_receive_hashring_tenants{namespace="$namespace",%(thanosReceiveSelector)s}' % $._config,
            ''
          )
        )
        .addPanel(
          g.panel('Hashring File Refresh Failure Rate') +
          g.queryPanel(
            |||
              sum(
                rate(thanos_receive_hashrings_file_errors_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])
              /
                rate(thanos_receive_hashrings_file_refreshes_total{namespace="$namespace",%(thanosReceiveSelector)s}[$interval])
              )
            ||| % $._config,
            ''
          )
        )
      )
      + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
