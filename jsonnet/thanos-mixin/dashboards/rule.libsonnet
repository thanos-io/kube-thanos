local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'rule.json': g.dashboard(
      'rule'
    ).addRow(
      g.row('Thanos Rule')
    ),
  },
}
