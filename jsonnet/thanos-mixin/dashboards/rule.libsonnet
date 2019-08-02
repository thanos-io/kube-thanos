local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'rule.json':
      g.dashboard(
        '%(dashboardNamePrefix)sRule' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('Load')
        .addPanel(
          g.panel('RPS') +
          g.queryPanel(
            'sum(rate(grpc_server_handled_total{namespace="$namespace",%(thanosRuleSelector)s}[$__range])) by (grpc_code, grpc_method, namespace)' % $._config,
            '{{grpc_code}} {{namespace}}/{{grpc_method}}'
          )
        )
        .addPanel(
          g.panel('Query Response Time Quantile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(grpc_server_handling_seconds_bucket{namespace=~"$namespace",%(thanosRuleSelector)s}[$__range])) by (grpc_method, le, namespace))' % $._config,
            '99 {{namespace}}/{{grpc_method}}'
          )
        )
      )
      .addRow(
        g.row('Alert Sender')
        .addPanel(
          g.panel('Alert Sent Rate') +
          g.queryPanel(
            'rate(thanos_alert_sender_alerts_sent_total{namespace=~"$namespace",%(thanosRuleSelector)s}[$__range])' % $._config,
            '{{alertmanager}}'
          )
        )
        .addPanel(
          g.panel('Alert Dropped Rate') +
          g.queryPanel(
            'rate(thanos_alert_sender_alerts_dropped_total{namespace=~"$namespace",%(thanosRuleSelector)s}[$__range])' % $._config,
            '{{alertmanager}}'
          )
        )
        .addPanel(
          g.panel('Alert Sender Latency Quantile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(thanos_alert_sender_latency_seconds_bucket{namespace=~"$namespace",%(thanosRuleSelector)s}[$__range])) by (alertmanager, le, namespace))' % $._config,
            '99 {{namespace}}/{{alertmanager}}'
          )
        )
      )
      .addRow(
        g.row('Compaction')
        .addPanel(
          g.panel('Compaction Rate') +
          g.queryPanel(
            'sum(rate(prometheus_tsdb_compactions_total{namespace=~"$namespace",%(thanosRuleSelector)s}[$__range])) by (namespace)' % $._config,
            '{{ namespace }}'
          )
        )
        .addPanel(
          g.panel('Compaction Failure Rate') +
          g.queryPanel(
            'sum(rate(prometheus_tsdb_compactions_failed_total{namespace=~"$namespace",%(thanosRuleSelector)s}[$__range])) by (namespace)' % $._config,
            '{{ namespace }}'
          )
        )
        .addPanel(
          g.panel('Compaction Duration Quatile') +
          g.queryPanel(
            'histogram_quantile(0.99, sum(rate(prometheus_tsdb_compaction_duration_seconds_bucket{namespace=~"$namespace",%(thanosRuleSelector)s}[$__range])) by (namespace,le))' % $._config,
            '99 {{namespace}}'
          )
        )
      )
      .addRow(
        g.row('Resources')
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            'go_memstats_heap_alloc_bytes{namespace="$namespace",%(thanosRuleSelector)s}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('Goroutines') +
          g.queryPanel(
            'go_goroutines{namespace="$namespace",%(thanosRuleSelector)s}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
        .addPanel(
          g.panel('GC Time Quantiles') +
          g.queryPanel(
            'go_gc_duration_seconds{namespace="$namespace",%(thanosRuleSelector)s, quantile="1"}' % $._config,
            '{{namespace}} {{kubernetes_pod_name}}'
          )
        )
      ) + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
