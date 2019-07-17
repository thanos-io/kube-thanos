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
              sum(
                rate(grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable", %(thanosStoreSelector)s}[5m])
                /
                rate(grpc_server_started_total{%(thanosStoreSelector)s}[5m])
              ) > 0.05
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosStoreSeriesGateLatencyHigh',
            annotations: {
              message: 'Thanos Store has a 99th percentile latency of {{ $value }} seconds for store series gate requests.',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_bucket_store_series_gate_duration_seconds{%(thanosStoreSelector)s}) by (le)
              ) > 2
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosStoreBucketHighOperationFailures',
            annotations: {
              message: 'Thanos Store Bucket has {{ $value }} of failing operations.',
            },
            expr: |||
              sum(
                rate(thanos_objstore_bucket_operation_failures_total{%(thanosStoreSelector)s}[5m])
              /
                rate(thanos_objstore_bucket_operations_total{%(thanosStoreSelector)s}[5m])
              ) > 0.05
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosStoreObjstoreOperationLatencyHigh',
            annotations: {
              message: 'Thanos Store Bucket has a 99th percentile latency of {{ $value }} seconds for bucket operations.',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_objstore_bucket_operation_duration_seconds{%(thanosQuerierSelector)s}) by (le)
              ) > 15
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
