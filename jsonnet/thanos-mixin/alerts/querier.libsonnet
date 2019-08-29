{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'thanos-querier.rules',
        rules: [
          {
            alert: 'ThanosQuerierGrpcErrorRate',
            annotations: {
              message: 'Thanos Querier {{$labels.job}} is failing to handle {{ $value | humanize }}% of requests.',
            },
            expr: |||
              sum(
                rate(grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable", %(thanosQuerierSelector)s}[5m])
                /
                rate(grpc_server_started_total{%(thanosQuerierSelector)s}[5m])
              ) by (job) * 100 > 5
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosQuerierHighDNSFailures',
            annotations: {
              message: 'Thanos Queriers {{$labels.job}} have {{ $value }} of failing DNS queries.',
            },
            expr: |||
              sum(
                rate(thanos_querier_store_apis_dns_failures_total{%(thanosQuerierSelector)s}[5m])
              /
                rate(thanos_querier_store_apis_dns_lookups_total{%(thanosQuerierSelector)s}[5m])
              ) by (job) > 1
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosQuerierInstantLatencyHigh',
            annotations: {
              message: 'Thanos Querier {{$labels.job}} has a 99th percentile latency of {{ $value }} seconds for instant queries.',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_query_api_instant_query_duration_seconds_bucket{%(thanosQuerierSelector)s}) by (job, le)
              ) > 10
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'ThanosQuerierRangeLatencyHigh',
            annotations: {
              message: 'Thanos Querier {{$labels.job}} has a 99th percentile latency of {{ $value }} seconds for instant queries.',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_query_api_range_query_duration_seconds_bucket{%(thanosQuerierSelector)s}) by (job, le)
              ) > 10
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'critical',
            },
          },
        ],
      },
    ],
  },
}
