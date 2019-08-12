{
  prometheusRecords+:: {
    groups+: [
      {
        name: 'thanos-store.rules',
        rules: [
          {
            record: 'thanos_store:grpc_server_failures_per_unary:rate5m',
            expr: |||
              sum(
                rate(grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable|DataLoss", %(thanosStoreSelector)s, grpc_type="unary"}[5m])
              /
                rate(grpc_server_started_total{%(thanosStoreSelector)s, grpc_type="unary"}[5m])
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_store:grpc_server_failures_per_stream:rate5m',
            expr: |||
              sum(
                rate(grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable|DataLoss", %(thanosStoreSelector)s, grpc_type="server_stream"}[5m])
              /
                rate(grpc_server_started_total{%(thanosStoreSelector)s, grpc_type="server_stream"}[5m])
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_store:objstore_bucket_failures_per_operation:rate5m',
            expr: |||
              sum(
                rate(thanos_objstore_bucket_operation_failures_total{%(thanosStoreSelector)s}[5m])
              /
                rate(thanos_objstore_bucket_operations_total{%(thanosStoreSelector)s}[5m])
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_store:objstore_bucket_operation_duration_seconds:p99:sum',
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_objstore_bucket_operation_duration_seconds_bucket{%(thanosStoreSelector)s}) by (le)
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_store:objstore_bucket_operation_duration_seconds:p99:rate5m',
            expr: |||
              histogram_quantile(0.99,
                sum(rate(thanos_objstore_bucket_operation_duration_seconds_bucket{%(thanosStoreSelector)s}[5m])) by (le)
              )
            ||| % $._config,
            labels: {
            },
          },
        ],
      },
    ],
  },
}
