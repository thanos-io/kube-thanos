{
  thanos+:: {
    querier+: {
      serviceMonitor+: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata+: {
          name: $.thanos.querier.name,
          namespace: $.thanos.querier.namespace,
        },
        spec: {
          selector: {
            matchLabels: $.thanos.querier.service.metadata.labels,
          },
          endpoints: [
            { port: 'http' },
          ],
        },
      },
    },
    store+: {
      serviceMonitor+: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata+: {
          name: $.thanos.store.name,
          namespace: $.thanos.store.namespace,
        },
        spec: {
          selector: {
            matchLabels: $.thanos.store.service.metadata.labels,
          },
          endpoints: [
            { port: 'http' },
          ],
        },
      },
    },
    receive+: {
      serviceMonitor+: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata+: {
          name: $.thanos.receive.name,
          namespace: $.thanos.receive.namespace,
        },
        spec: {
          selector: {
            matchLabels: $.thanos.receive.service.metadata.labels,
          },
          endpoints: [
            { port: 'http' },
          ],
        },
      },
    },
    compactor+: {
      serviceMonitor+: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata+: {
          name: $.thanos.compactor.name,
          namespace: $.thanos.compactor.namespace,
        },
        spec: {
          selector: {
            matchLabels: $.thanos.compactor.service.metadata.labels,
          },
          endpoints: [
            { port: 'http' },
          ],
        },
      },
    },
    rule+: {
      serviceMonitor+: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata+: {
          name: $.thanos.rule.name,
          namespace: $.thanos.rule.namespace,
        },
        spec: {
          selector: {
            matchLabels: $.thanos.rule.service.metadata.labels,
          },
          endpoints: [
            { port: 'http' },
          ],
        },
      },
    },
  },
}
