{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'thanos-receive.rules',
        rules: [
          {
            alert: 'ThanosReceiveHttpRequestLatencyHigh',
            annotations: {
              message: 'Thanos Receive {{$labels.job}} has a 99th percentile latency of {{ $value }} seconds for HTTP requests.',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(thanos_http_request_duration_seconds_bucket{%(thanosReceiveSelector)s}) by (job, le)
              ) > 10
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'high',
            },
          },
          {
            alert: 'ThanosReceiveHighForwardRequestFailures',
            annotations: {
              message: 'Thanos Receive {{$labels.job}} is failing to forward {{ $value | humanize }}% of requests.',
            },
            expr: |||
              sum(
                rate(thanos_receive_forward_requests_total{result="error", %(thanosReceiveSelector)s}[5m])
              /
                rate(thanos_receive_forward_requests_total{%(thanosReceiveSelector)s}[5m])
              ) by (job) * 100 > 5
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'high',
            },
          },
          {
            alert: 'ThanosReceiveHighHashringFileRefreshFailures',
            annotations: {
              message: 'Thanos Receive {{$labels.job}} is failing to refresh hashring file, {{ $value | humanize }} of attempts failed.',
            },
            expr: |||
              sum(
                rate(thanos_receive_hashrings_file_errors_total{%(thanosReceiveSelector)s}[5m])
              /
                rate(thanos_receive_hashrings_file_refreshes_total{%(thanosReceiveSelector)s}[5m])
              ) by (job) > 0
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'medium',
            },
          },
          {
            alert: 'ThanosReceiveConfigReloadFailure',
            annotations: {
              message: 'Thanos Receive {{$labels.job}} has not been able to reload hashring configurations.',
            },
            expr: 'avg(thanos_receive_config_last_reload_successful{%(thanosReceiveSelector)s}) by (job) != 1' % $._config,
            'for': '5m',
            labels: {
              severity: 'medium',
            },
          },
        ],
      },
    ],
  },
}
