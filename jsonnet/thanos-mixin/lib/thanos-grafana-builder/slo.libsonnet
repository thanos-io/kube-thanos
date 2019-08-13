{
  sloLatency(title, selector, quantile, warning, critical)::
    $.panel(title) +
    $.queryPanel(
      'histogram_quantile(%.2f, sum(rate(%s[$interval])) by (le))' % [quantile, selector],
      'P' + quantile * 100
    ) +
    {
      yaxes: $.yaxes('s'),
      thresholds+: [
        {
          value: warning,
          colorMode: 'warning',
          op: 'gt',
          fill: true,
          line: true,
          yaxis: 'left',
        },
        {
          value: critical,
          colorMode: 'critical',
          op: 'gt',
          fill: true,
          line: true,
          yaxis: 'left',
        },
      ],
    },
}
