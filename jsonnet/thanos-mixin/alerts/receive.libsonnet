{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'thanos-receive.rules',
        rules: [
          {
            alert: 'ThanosReceiveHttpRequestLatencyHigh',
            annotations: {
              message: 'Thanos Receive has a 99th percentile latency of {{ $value }} seconds for HTTP requests.',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_http_request_duration_seconds{%(thanosReceiveSelector)s}) by (le)
              ) > 1
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosReceiveHighForwardRequestFailures',
            annotations: {
              message: 'Thanos Receive has {{ $value }} of failing forward requests.',
            },
            expr: |||
              sum(
                rate(thanos_receive_forward_requests_total{result="error", %(thanosReceiveSelector)s}[5m])
              /
                rate(thanos_receive_forward_requests_total{%(thanosReceiveSelector)s}[5m])
              ) > 0.05
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosReceiveHighHashringFileRefreshFailures',
            annotations: {
              message: 'Thanos Receive has {{ $value }} of failing hashring file refreshes.',
            },
            expr: |||
              sum(
                rate(thanos_receive_hashrings_file_errors_total{%(thanosReceiveSelector)s}[5m])
              /
                rate(thanos_receive_hashrings_file_refreshes_total{%(thanosReceiveSelector)s}[5m])
              ) >= 0
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}
