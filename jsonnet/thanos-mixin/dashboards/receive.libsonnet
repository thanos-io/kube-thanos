local g = import 'grafana-builder/grafana.libsonnet';
{
  grafanaDashboards+:: {
    'receive.json': g.dashboard(
      'receive'
    ).addRow(
      g.row('Thanos Receive')
    ),
  },
}
