local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'compact.json': g.dashboard(
      'compact'
    ).addRow(
      g.row('Thanos Compact')
    ),
  },
}
