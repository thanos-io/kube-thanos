local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'rule.json': g.dashboard(
      '%(dashboardNamePrefix)sRule' % $._config.grafanaThanos,
    ).addRow(
      g.row('Thanos Rule')
    ) + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
