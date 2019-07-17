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
                grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable", %(thanosStoreSelector)s}[5m]
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
                thanos_objstore_bucket_operation_failures_total{%(thanosStoreSelector)s}[5m]
              ) > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosStoreSeriesGateLatencyHigh',
            annotations: {
              message: '',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_bucket_store_series_gate_duration_seconds{%(thanosStoreSelector)s}) by (le)
              ) > 1
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosStoreObjstoreOperationLatencyHigh',
            annotations: {
              message: '',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_objstore_bucket_operation_duration_seconds{%(thanosQuerierSelector)s}) by (le)
              ) > 1
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}
