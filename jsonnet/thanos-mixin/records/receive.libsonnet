{
  prometheusRecords+:: {
    groups+: [
      {
        name: 'thanos-receive.rules',
        rules: [
          {
            record: 'thanos_receive:grpc_server_failures_per_unary:rate5m',
            expr: |||
              sum(
                rate(grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable|DataLoss", %(thanosQuerierSelector)s, grpc_type="unary"}[5m])
              /
                rate(grpc_server_started_total{%(thanosQuerierSelector)s, grpc_type="unary"}[5m])
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_receive:grpc_server_failures_per_stream:rate5m',
            expr: |||
              sum(
                rate(grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable|DataLoss", %(thanosQuerierSelector)s, grpc_type="server_stream"}[5m])
              /
                rate(grpc_server_started_total{%(thanosQuerierSelector)s, grpc_type="server_stream"}[5m])
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_receive:http_failure_per_request:rate5m',
            expr: |||
              sum(
                rate(thanos_http_requests_total{%(thanosReceiveSelector)s, code!~"2.."}[5m])
              /
                rate(thanos_http_requests_total{%(thanosReceiveSelector)s}[5m])
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_receive:http_request_duration_seconds:p99:sum',
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_http_request_duration_seconds_bucket{%(thanosReceiveSelector)s}) by (le)
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_receive:http_request_duration_seconds:p99:rate5m',
            expr: |||
              histogram_quantile(0.99,
                sum(rate(thanos_http_request_duration_seconds_bucket{%(thanosReceiveSelector)s}[5m])) by (le)
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_receive:forward_failure_per_requests:rate5m',
            expr: |||
              sum(
                rate(thanos_receive_forward_requests_total{result="error", %(thanosReceiveSelector)s}[5m])
              /
                rate(thanos_receive_forward_requests_total{%(thanosReceiveSelector)s}[5m])
              )
            ||| % $._config,
            labels: {
            },
          },
          {
            record: 'thanos_receive:hashring_file_failure_per_refresh:rate5m',
            expr: |||
              sum(
                rate(thanos_receive_hashrings_file_errors_total{%(thanosReceiveSelector)s}[5m])
              /
                rate(thanos_receive_hashrings_file_refreshes_total{%(thanosReceiveSelector)s}[5m])
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
