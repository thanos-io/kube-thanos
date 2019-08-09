local b = import '../lib/thanos-grafana-builder/builder.libsonnet';
local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'overview.json':
      g.dashboard(
        '%(dashboardNamePrefix)sOverview' % $._config.grafanaThanos,
      )
      .addTemplate('cluster', 'kube_pod_info', 'cluster', hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(g.row('Compact'))
      .addRow(g.row('Query'))
      .addRow(g.row('Receive'))
      .addRow(g.row('Rule'))
      .addRow(g.row('Sidecar'))
      .addRow(g.row('Store')),
  },
}
