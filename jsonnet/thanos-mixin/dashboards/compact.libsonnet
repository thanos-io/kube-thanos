local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'compact.json': g.dashboard(
      '%(dashboardNamePrefix)sCompact' % $._config.grafanaThanos,
    ).addRow(
      g.row('Thanos Compact')
    ) + { tags: $._config.grafanaThanos.dashboardTags },
  },
}
