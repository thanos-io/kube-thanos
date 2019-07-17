{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'thanos-receive.rules',
        rules: [
          {
            alert: 'ThanosReceiveHttpRequestLatencyHigh',
            annotations: {
              message: '',
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
        ],
      },
    ],
  },
}
