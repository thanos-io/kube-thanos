{
  _config+:: {
    thanosQuerierJobPrefix: 'thanos-querier',
    thanosStoreJobPrefix: 'thanos-store',
    thanosReceiveJobPrefix: 'thanos-receive',
    thanosRuleJobPrefix: 'thanos-rule',
    thanosCompactJobPrefix: 'thanos-compact',
    thanosSidecarJobPrefix: 'thanos-sidecar',

    thanosQuerierSelector: 'job=~"%s.*"' % self.thanosQuerierJobPrefix,
    thanosStoreSelector: 'job=~"%s.*"' % self.thanosStoreJobPrefix,
    thanosReceiveSelector: 'job=~"%s.*"' % self.thanosReceiveJobPrefix,
    thanosRuleSelector: 'job=~"%s.*"' % self.thanosRuleJobPrefix,
    thanosCompactSelector: 'job=~"%s.*"' % self.thanosCompactJobPrefix,
    thanosSidecarSelector: 'job=~"%s.*"' % self.thanosSidecarJobPrefix,

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
