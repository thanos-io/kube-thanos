{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'thanos-store.rules',
        rules: [
          {
            alert: 'ThanosStoreGrpcErrorRate',
            annotations: {
              message: 'Thanos Store is returning Internal/Unavailable errors.',
            },
            expr: |||
              rate(
                grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable", %(thanosStoreSelector)}[5m]
              ) > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosStoreBucketOperationsFailed',
            annotations: {
              message: 'Thanos Store is failing to do bucket operations.',
            },
            expr: |||
              rate(
                thanos_objstore_bucket_operation_failures_total{%(thanosStoreSelector)}[5m]
              ) > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}