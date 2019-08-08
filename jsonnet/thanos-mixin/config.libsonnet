{
  _config+:: {
    thanosQuerier: 'thanos-querier',
    thanosStore: 'thanos-store',
    thanosReceive: 'thanos-receive',
    thanosRule: 'thanos-rule',
    thanosCompact: 'thanos-compact',
    thanosSidecar: 'thanos-sidecar',
    thanosPrometheus: 'thanos-prometheus',

    thanosQuerierSelector: 'job="thanos-querier"',
    thanosStoreSelector: 'job="thanos-store"',
    thanosReceiveSelector: 'job="thanos-receive"',
    thanosRuleSelector: 'job="thanos-rule"',
    thanosCompactSelector: 'job="thanos-compact"',
    thanosSidecarSelector: 'job="thanos-sidecar"',
    thanosPrometheusSelector: 'job="thanos-prometheus"',

    clusterLabel: 'cluster',
    showMultiCluster: false,

    // Config for the Grafana dashboards in the thanos-mixin
    grafanaThanos: {
      dashboardNamePrefix: 'Thanos / ',
      dashboardTags: ['thanos-mixin'],

      // For links between grafana dashboards, you need to tell us if your grafana
      // servers under some non-root path.
      linkPrefix: '',
    },
  },
}
