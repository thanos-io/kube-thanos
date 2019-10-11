{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'thanos-receive.rules',
        rules: [
          {
            alert: 'ThanosReceiveIsNotRunning',
            annotations: {
              message: 'Thanos Receive is not running or just not scraped yet.',
            },
            expr: 'up{%(thanosReceiveSelector)s} == 0 or absent({%(thanosReceiveSelector)s})' % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'ThanosReceiveHttpRequestLatencyHigh',
            annotations: {
              message: 'Thanos Receive {{$labels.job}} has a 99th percentile latency of {{ $value }} seconds for HTTP requests.',
            },
            expr: |||
              histogram_quantile(0.99,
                sum(http_request_duration_seconds_bucket{%(thanosReceiveSelector)s, handler="receive"}) by (job, le)
              ) > 10
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'ThanosReceiveHighForwardRequestFailures',
            annotations: {
              message: 'Thanos Receive {{$labels.job}} is failing to forward {{ $value | humanize }}% of requests.',
            },
            expr: |||
              (
                sum by (job) (rate(thanos_receive_forward_requests_total{result="error", %(thanosReceiveSelector)s}[5m]))
              /
                sum by (job) (rate(thanos_receive_forward_requests_total{%(thanosReceiveSelector)s}[5m]))
              * 100 > 5
              )
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'ThanosReceiveHighHashringFileRefreshFailures',
            annotations: {
              message: 'Thanos Receive {{$labels.job}} is failing to refresh hashring file, {{ $value | humanize }} of attempts failed.',
            },
            expr: |||
              (
                sum by (job) (rate(thanos_receive_hashrings_file_errors_total{%(thanosReceiveSelector)s}[5m]))
              /
                sum by (job) (rate(thanos_receive_hashrings_file_refreshes_total{%(thanosReceiveSelector)s}[5m]))
              > 0
              )
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
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
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}
