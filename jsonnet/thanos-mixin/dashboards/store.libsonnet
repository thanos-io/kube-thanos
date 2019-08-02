local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'store.json': g.dashboard(
      '%(dashboardNamePrefix)sStore' % $._config.grafanaThanos,
    ).addRow(
      g.row('Thanos Store')
    ) + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
