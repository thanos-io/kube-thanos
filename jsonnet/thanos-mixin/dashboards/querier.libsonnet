local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;
local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'querier.json':
      g.dashboard(
        '%(dashboardNamePrefix)sQuerier' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('Errors')
        .addPanel(
          g.panel('GRPC Error rate') +
          g.queryPanel(
            |||
              sum(
                rate(grpc_server_handled_total{namespace="$namespace",grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable", %(thanosQuerierSelector)s}[$interval])
                /
                rate(grpc_server_started_total{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
              ) by (grpc_code, grpc_method, pod)
            ||| % $._config,
            '{{grpc_code}} {{grpc_method}} {{pod}}'
          )
        )
        .addPanel(
          g.panel('DNS Failure Rate') +
          g.queryPanel(
            |||
              sum(
                rate(thanos_querier_store_apis_dns_failures_total{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
              /
                rate(thanos_querier_store_apis_dns_lookups_total{namespace="$namespace",%(thanosQuerierSelector)s}[$interval])
              ) by (namespace)
            ||| % $._config,
            '{{ namespace }}'
          )
        )
      )
      .addRow(
        g.row('Latency')
        .addPanel(
          g.panel('Response Time 99th Percentile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(grpc_client_handling_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (grpc_method, kubernetes_pod_name, le))' % $._config,
            '99 {{grpc_method}} {{pod}}'
          )
        )
        .addPanel(
          g.panel('Query 99th Percentile') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum(rate(thanos_query_api_instant_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))' % $._config,
              'histogram_quantile(0.99, sum(rate(thanos_query_api_range_query_duration_seconds_bucket{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, le))' % $._config,

            ],
            [
              '99 {{grpc_method}} {{pod}}',
              'range_query {{pod}}',
            ]
          )
        )
        .addPanel(
          g.panel('Prometheus Query 99th Quantile') +
          g.queryPanel(
            'prometheus_engine_query_duration_seconds{namespace="$namespace",%(thanosPrometheusSelector)s,kubernetes_pod_name=~"$pod",quantile="0.99"}' % $._config,
            '{{pod}} {{slice}}'
          )
        )
      )
      .addRow(
        g.row('Operations')
        .addPanel(
          g.panel('Request RPS') +
          g.queryPanel(
            'sum(rate(grpc_client_handled_total{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[$interval])) by (kubernetes_pod_name, grpc_code, grpc_method)' % $._config,
            '{{grpc_code}} {{grpc_method}} {{pod}}'
          )
        )
        .addPanel(
          g.panel('Prometheus Queries/s') +
          g.queryPanel(
            'prometheus_engine_queries{namespace="$namespace",%(thanosPrometheusSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
            '{{pod}}'
          )
        )
      )
      .addRow(
        g.row('Store Status')
        .addPanel(
          g.panel('Connected Stores') +
          g.statPanel(
            'sum(thanos_store_nodes_grpc_connections{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"})' % $._config,
            'none'
          )
        )
        .addPanel(
          g.panel('Gossip Info') +
          g.tablePanel(
            ['min(thanos_store_node_info{namespace="$namespace",%(thanosQuerierSelector)s}) by (external_labels)' % $._config],
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
      )
      .addRow(
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              'go_memstats_alloc_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'rate(go_memstats_alloc_bytes_total{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'rate(go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}[30s])' % $._config,
              'go_memstats_stack_inuse_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
              'go_memstats_heap_inuse_bytes{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
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
            'go_goroutines{namespace="$namespace",%(thanosQuerierSelector)s}' % $._config,
            '{{pod}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosQuerierSelector)s,kubernetes_pod_name=~"$pod"}' % $._config,
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
              'label_values(kube_pod_info{namespace="$namespace"}, pod)',
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
