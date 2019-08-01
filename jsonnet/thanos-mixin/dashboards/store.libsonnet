local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'store.json': g.dashboard(
      'store'
    ).addRow(
      g.row('Thanos Store')
    ),
  },
}
