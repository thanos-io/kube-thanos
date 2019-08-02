local g = import 'grafana-builder/grafana.libsonnet';
{
  grafanaDashboards+:: {
    'receive.json': g.dashboard(
      '%(dashboardNamePrefix)sReceive' % $._config.grafanaThanos,
    ).addRow(
      g.row('Thanos Receive')
    ) + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
