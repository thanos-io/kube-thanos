{
  _config+:: {
    thanosQuerier: 'thanos-querier',
    thanosStore: 'thanos-store',
    thanosReceive: 'thanos-receive',
    thanosRule: 'thanos-rule',
    thanosCompact: 'thanos-compact',
    thanosSidecar: 'thanos-sidecar',
    thanosPrometheus: 'prometheus-thanos',

    thanosQuerierSelector: 'job="%s"' % self.thanosQuerier,
    thanosStoreSelector: 'job="%s"' % self.thanosStore,
    thanosReceiveSelector: 'job="%s"' % self.thanosReceive,
    thanosRuleSelector: 'job="%s"' % self.thanosRule,
    thanosCompactSelector: 'job="%s"' % self.thanosCompact,
    thanosSidecarSelector: 'job="%s"' % self.thanosSidecar,
    thanosPrometheusSelector: 'job="%s"' % self.thanosPrometheus,

    clusterLabel: 'cluster',
    showMultiCluster: false,

    // Config for the Grafana dashboards in the thanos-mixin
    grafanaThanos: {
      dashboardNamePrefix: 'Thanos / ',
      dashboardTags: ['thanos-mixin'],

      dashboardOverviewTitle: '%(dashboardNamePrefix)sOverview' % $._config.grafanaThanos,
      dashboardCompactTitle: '%(dashboardNamePrefix)sCompact' % $._config.grafanaThanos,
      dashboardQuerierTitle: '%(dashboardNamePrefix)sQuerier' % $._config.grafanaThanos,
      dashboardReceiveTitle: '%(dashboardNamePrefix)sReceive' % $._config.grafanaThanos,
      dashboardRuleTitle: '%(dashboardNamePrefix)sRule' % $._config.grafanaThanos,
      dashboardSidecarTitle: '%(dashboardNamePrefix)sSidecar' % $._config.grafanaThanos,
      dashboardStoreTitle: '%(dashboardNamePrefix)sStore' % $._config.grafanaThanos,
    },
  },
}
