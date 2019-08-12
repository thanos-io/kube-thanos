local grafana = import 'grafonnet/grafana.libsonnet';
local singlestat = grafana.singlestat;
local prometheus = grafana.prometheus;

local gauge = {
  new(title, query)::
    singlestat.new(
      title,
      datasource='$datasource',
      span=3,
      format='percent',
      valueName='current',
      colors=[
        'rgba(245, 54, 54, 0.9)',
        'rgba(237, 129, 40, 0.89)',
        'rgba(50, 172, 45, 0.97)',
      ],
      thresholds='50,80',
      valueMaps=[
        {
          op: '=',
          text: 'N/A',
          value: 'null',
        },
      ],
    )
    .addTarget(
      prometheus.target(
        query
      )
    ) + {
      gauge: {
        maxValue: 100,
        minValue: 0,
        show: true,
        thresholdLabels: false,
        thresholdMarkers: true,
      },
      withTextNullValue(text):: self {
        valueMaps: [
          {
            op: '=',
            text: text,
            value: 'null',
          },
        ],
      },
      withSpanSize(size):: self {
        span: size,
      },
      withLowerBeingBetter(thresholds='80,90'):: self {
        colors: [
          'rgba(50, 172, 45, 0.97)',
          'rgba(237, 129, 40, 0.89)',
          'rgba(245, 54, 54, 0.9)',
        ],
        thresholds: thresholds,
      },

      withHigherBeingBetter(thresholds='80,90'):: self {
        thresholds: thresholds,
      },

      withMaxValue(maxValue):: self {
        gauge: {
          maxValue: maxValue,
        },
      },

      withFormet(format):: self {
        format: format,
      },
    },
};

{
  sloError(title, selectorErr, selectorTotal, warning='50', critical='80')::
    gauge.new(
      title,
      'sum(rate(%s[$interval]) / rate(%s[$interval])) * 100' % [selectorErr, selectorTotal],
    ).withLowerBeingBetter(warning + ',' + critical),

  sloLatency(title, selector, quantile, warning, critical, max)::
    gauge.new(
      title,
      'histogram_quantile(%.2f, sum(rate(%s[$interval])) by (le))' % [quantile, selector],
    )
    .withLowerBeingBetter(warning + ',' + critical)
    .withFormet('s')
    .withMaxValue(max),
}
