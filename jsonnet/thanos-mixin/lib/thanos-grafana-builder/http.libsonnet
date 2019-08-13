{
  httpQpsPanel(metricName, selector):: {
    aliasColors: {
      '1xx': '#EAB839',
      '2xx': '#7EB26D',
      '3xx': '#6ED0E0',
      '4xx': '#EF843C',
      '5xx': '#E24D42',
      success: '#7EB26D',
      'error': '#E24D42',
    },
    targets: [
      {
        expr: 'sum(label_replace(rate(%s{%s}[$interval]),"status_code", "${1}xx", "code", "([0-9])..")) by (status_code)' % [metricName, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: '{{status_code}}',
        refId: 'A',
        step: 10,
      },
    ],
  } + $.stack,

  httpQpsPanelDetailed(metricName, selector)::
    $.httpQpsPanel(metricName, selector) {
      targets: [
        {
          expr: 'sum(label_replace(rate(%s{%s}[$interval]),"status_code", "${1}xx", "code", "([0-9])..")) by (handler, status_code)' % [metricName, selector],
          format: 'time_series',
          intervalFactor: 2,
          legendFormat: '{{handler}} {{status_code}}',
          refId: 'A',
          step: 10,
        },
      ],
    },

  httpErrPanel(metricName, selector)::
    $.qpsErrTotalPanel(
      '%s{%s,code!~"2.."}' % [metricName, selector],
      '%s{%s}' % [metricName, selector],
    ),

  httpErrDetailsPanel(metricName, selector)::
    $.queryPanel(
      |||
        sum(rate(%s{%s,code!~"2.."}[$interval])) by (handler, code)
        /
        sum(rate(%s{%s}[$interval])) by (handler, code)
      ||| % [metricName, selector, metricName, selector],
      '{{handler}} {{code}}'
    ) +
    { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) } +
    $.stack,

  httpLatencyDetailsPanel(metricName, selector, multiplier='1'):: {
    nullPointMode: 'null as zero',
    targets: [
      {
        expr: 'histogram_quantile(0.99, sum(rate(%s_bucket{%s}[$interval])) by (handler, le)) * %s' % [metricName, selector, multiplier],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'P99 {{handler}}',
        refId: 'A',
        step: 10,
      },
      {
        expr: 'sum(rate(%s_sum{%s}[$interval])) * %s / sum(rate(%s_count{%s}[$interval]))' % [metricName, selector, multiplier, metricName, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'mean',
        refId: 'B',
        step: 10,
      },
      {
        expr: 'histogram_quantile(0.50, sum(rate(%s_bucket{%s}[$interval])) by (lhandler, e)) * %s' % [metricName, selector, multiplier],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'P50 {{handler}}',
        refId: 'C',
        step: 10,
      },
    ],
    yaxes: $.yaxes('ms'),
  },
}
