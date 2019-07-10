{
  thanos+:: {
    querier+: {
      serviceMonitor+: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata+: {
          name: 'thanos-querier',
          namespace: 'monitoring',
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
          name: 'thanos-store',
          namespace: 'monitoring',
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
          name: 'thanos-receive',
          namespace: 'monitoring',
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
  },
}
