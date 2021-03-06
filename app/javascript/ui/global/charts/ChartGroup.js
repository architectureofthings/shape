import PropTypes from 'prop-types'
import _ from 'lodash'
import { observer, inject, PropTypes as MobxPropTypes } from 'mobx-react'
import styled from 'styled-components'
import {
  VictoryAxis,
  VictoryChart,
  VictoryGroup,
  VictoryLabel,
  VictoryVoronoiContainer,
} from 'victory'

import { DisplayText } from '~/ui/global/styled/typography'
import OrganicGrid from '~/ui/icons/OrganicGrid'
import v, { DATASET_CHART_TYPES } from '~/utils/variables'
import AreaChart from '~/ui/global/charts/AreaChart'
import BarChart from '~/ui/global/charts/BarChart'
import LineChart from '~/ui/global/charts/LineChart'
import barChartAxisProps from '~/ui/global/charts/barChartAxisProps'
import chartAxisProps from '~/ui/global/charts/chartAxisProps'
import {
  barWidthPx,
  victoryTheme,
  emojiSeriesForQuestionType,
  chartDomainForDatasetValues,
  domainXForSingleValue,
  formatValuesForVictory,
} from '~/ui/global/charts/ChartUtils'

const NotEnoughDataContainer = styled.div`
  position: relative;
  top: 50%;
  transform: translateY(-50%);
`

const ChartContainer = styled.div`
  position: absolute;
  height: ${props => props.height};
  bottom: 0;
  left: 0;
  right: 0;
`

// Adds duplicate values (if only 1 value), and dates if primary dataset has them
const formatSecondaryDatasetValues = (
  values = [],
  primaryDatasetValues = []
) => {
  if (values.length > 1) return values

  // Get values from primary dataset
  const addStartDate = primaryDatasetValues[0].date
  const addEndDate = primaryDatasetValues[primaryDatasetValues.length - 1].date
  return formatValuesForVictory({
    values,
    addStartDate,
    addEndDate,
  })
}

@inject('routingStore')
@observer
class ChartGroup extends React.Component {
  get primaryDataset() {
    const { primaryDataset } = this.props.dataItem
    return primaryDataset
  }

  get primaryDatasetValues() {
    if (!this.primaryDataset || !this.primaryDataset.dataWithDates) return []
    return this.primaryDataset.dataWithDates
  }

  get secondaryDatasetsWithData() {
    const { secondaryDatasets } = this.props.dataItem
    return secondaryDatasets().filter(
      dataset => dataset.dataWithDates.length > 0
    )
  }

  get primaryDatasetBarChart() {
    return (
      this.primaryDataset &&
      this.primaryDataset.chart_type === DATASET_CHART_TYPES.BAR
    )
  }

  get hasPercentileComparison() {
    return (
      this.secondaryDatasetsWithData[0] &&
      this.secondaryDatasetsWithData[0].chart_type === 'line'
    )
  }

  get chartDomain() {
    const allValues = [...this.primaryDatasetValues]
    this.secondaryDatasetsWithData.forEach(dataset => {
      if (dataset.data[0].date) {
        // Format data in the same way it will show up in other secondary charts
        allValues.push(
          ...formatSecondaryDatasetValues(
            dataset.dataWithDates,
            this.primaryDatasetValues
          )
        )
      }
    })
    const domain = chartDomainForDatasetValues({
      values: allValues,
      maxYDomain: this.primaryDataset.max_domain,
    })
    // If there's one single value, and the secondary datasets are only
    // the percentitles (with no dates), then spread the domain out.
    const uniqDates = _.uniqWith(_.map(allValues, 'date'), _.isEqual)
    if (allValues.length === 1 || uniqDates.length === 1) {
      domain.x = domainXForSingleValue(allValues[0].date)
    }
    return domain
  }

  get isSmallChartStyle() {
    const { width, height } = this.props
    return width <= 1 && height <= 1
  }

  routeToSearch = searchText => {
    const { routingStore } = this.props
    routingStore.routeTo('search', searchText)
  }

  get totalBarsPerGroup() {
    return this.secondaryDatasetsWithData.length + 1
  }

  get emojiScale() {
    const { question_type } = this.primaryDataset
    if (!question_type) return []
    return emojiSeriesForQuestionType(question_type)
  }

  get totalColumns() {
    return this.primaryDataset.data.length
  }

  get totalGroupings() {
    return this.renderedDatasets.length
  }

  get tierAxis() {
    const { tiers } = this.primaryDataset
    if (!tiers.length) return
    const renderedColor = _.get(tiers[0], 'style.fill') || 'black'
    return (
      <VictoryAxis
        dependentAxis
        orientation="left"
        tickValues={tiers.map(t => t.value)}
        tickFormat={tiers.map(t => t.name)}
        offsetX={40}
        style={{
          axis: {
            stroke: 'transparent',
          },
          grid: {
            stroke: renderedColor,
            strokeWidth: 0.8,
            strokeDasharray: [1, 1],
          },
          ticks: { padding: 10 },
        }}
        tickLabelComponent={
          <VictoryLabel
            textAnchor="start"
            verticalAnchor="end"
            dy={-5}
            style={{ fill: renderedColor, fontSize: '20px' }}
          />
        }
      />
    )
  }

  areElementsOverlapping(a, b) {
    const ar = a.x + a.w
    const br = b.x + b.w
    return !(ar < b.x || a.x > br)
  }

  areLabelsOverlapping(labelA, labelB) {
    if (labelA.overlapping || labelB.overlapping) {
      // don't mark labels as overlapping if they have already been removed
      return false
    }

    return this.areElementsOverlapping(
      { ...labelA, w: this.calculateLabelWidth(labelA) },
      { ...labelB, w: this.calculateLabelWidth(labelB) }
    )
  }

  calculateLabelWidth(label) {
    const modifier = this.isSmallChartStyle ? 12 : 8
    if (!label.text) return 0
    return label.text.length * modifier
  }

  extractLabelsFromVictoryProps(victoryProps) {
    return _.compact(
      Object.entries(victoryProps).map(([key, val]) => {
        if (_.isNumber(parseInt(key))) {
          return val.tickLabels
        }
      })
    )
  }

  findOverlappingLabels(renderedLabels) {
    let sortedLabels = _.orderBy(renderedLabels, ['x'], ['desc'])
    if (sortedLabels.length > 2) {
      // Take out earliest label if more than two data points
      sortedLabels = sortedLabels.slice(0, sortedLabels.length - 1)
    }
    const latest = _.first(sortedLabels)

    const overlappingLabels = []
    if (sortedLabels.length === 1) return []
    sortedLabels.forEach((label, i) => {
      let overlapping = false
      for (let j = i + 1; j < sortedLabels.length; j++) {
        const nextLabel = sortedLabels[j]
        let { x } = label
        if (label === latest) {
          x = latest.x - this.calculateLabelWidth(latest) / 2
        }
        overlapping = this.areLabelsOverlapping({ ...label, x }, nextLabel)

        if (overlapping) {
          overlappingLabels.push(nextLabel)
          nextLabel.overlapping = true
          // remove label text from overlapping label to only show the tick mark
          nextLabel.text = ''
        }
      }
    })
    return _.uniq(overlappingLabels)
  }

  get axisRawDateValues() {
    const datasetsWithData = [
      this.primaryDataset,
      ...this.secondaryDatasetsWithData,
    ]
    return _.compact(
      _.map(_.flatten(_.map(datasetsWithData, 'dataWithDates')), 'date')
    )
  }

  get axisFilteredDateValues() {
    const victoryProps = VictoryAxis.getBaseProps(this.axisProps)
    const renderedLabels = this.extractLabelsFromVictoryProps(victoryProps)
    // this will go through and remove the text label from the overlapping ones
    // it will also (somehow?) adjust the right-most one to be aligned
    this.findOverlappingLabels(renderedLabels)

    return renderedLabels
  }

  get axisProps() {
    if (this.primaryDatasetBarChart) {
      return barChartAxisProps({
        dataset: this.primaryDataset,
        totalColumns: this.totalColumns,
        totalGroupings: this.totalGroupings,
      })
    } else {
      const { timeframe } = this.primaryDataset
      const dates = this.axisRawDateValues
      const axisProps = chartAxisProps({
        datasetValues: this.primaryDatasetValues,
        secondaryValues: this.secondaryDatasetsWithData,
        datasetTimeframe: timeframe,
        domain: this.chartDomain,
        isSmallChartStyle: this.isSmallChartStyle,
        dateValues: this.isSmallChartStyle ? dates.sort() : null,
      })

      return axisProps
    }
  }

  get chartAxis() {
    const { axisProps } = this
    if (this.isSmallChartStyle) {
      const filteredLabels = _.sortBy(this.axisFilteredDateValues, 'x')
      if (filteredLabels.length > 2) {
        // cut off the earliest label
        const first = _.first(filteredLabels)
        first.text = ''
      }
      axisProps.tickValues = filteredLabels.map(l => l.datum)
      axisProps.tickFormat = filteredLabels.map(l => l.text)
    }
    return <VictoryAxis {...axisProps} />
  }

  // Oddly es-lint complains when this is a get function
  renderNotEnoughData = () => (
    <NotEnoughDataContainer>
      <DisplayText className="noDataMessage">Not enough data yet</DisplayText>
    </NotEnoughDataContainer>
  )

  renderDataset = (dataset, index, total, colorOrder) => {
    const { simpleDateTooltip, width, height } = this.props
    const order = index
    let modifiedChartType = dataset.chart_type
    // Secondary datasets to primary area type datasets should use line charts
    // instead of default area charts.
    if (
      dataset !== this.primaryDataset &&
      this.primaryDataset.chart_type === 'area'
    ) {
      if (dataset.hasDates) {
        modifiedChartType = 'area'
      } else {
        modifiedChartType = 'line'
      }
      // Creative Difference chart comparisons should just be lines.
      if (order > 0 && this.isSmallChartStyle) {
        modifiedChartType = 'line'
      }
    }
    const dashWidth = index * 2
    switch (modifiedChartType) {
      case DATASET_CHART_TYPES.AREA:
        return AreaChart({
          dataset,
          simpleDateTooltip,
          order,
          colorOrder,
          cardArea: width * height,
          domain: this.chartDomain,
        })
      case DATASET_CHART_TYPES.LINE:
        return LineChart({
          dataset,
          simpleDateTooltip,
          order,
          cardArea: width * height,
          dashWidth,
          domain: this.chartDomain,
          isSmallChartStyle: this.isSmallChartStyle,
        })
      case DATASET_CHART_TYPES.BAR:
        return BarChart({
          dataset,
          cardArea: width * height,
          barsInGroup: total,
          routeToSearch: this.routeToSearch,
        })
      default:
        return AreaChart({
          dataset,
          order,
          simpleDateTooltip,
          cardArea: width * height,
          domain: this.chartDomain,
        })
    }
  }

  get renderedDatasets() {
    let datasetIndex = 0
    let colorOrder = 0
    const datasets = [
      this.renderDataset(
        this.primaryDataset,
        datasetIndex,
        this.totalBarsPerGroup,
        colorOrder
      ),
    ]
    if (!this.secondaryDatasetsWithData) return datasets
    this.secondaryDatasetsWithData.forEach(dataset => {
      if (dataset.hasDates) colorOrder += 1
      datasets.push(
        this.renderDataset(
          dataset,
          (datasetIndex += 1),
          this.totalBarsPerGroup,
          colorOrder
        )
      )
    })
    return datasets
  }

  get renderVictoryChart() {
    if (this.primaryDatasetBarChart) {
      const barWidth = barWidthPx(this.totalColumns, this.totalGroupings)
      return (
        <VictoryChart
          theme={victoryTheme}
          domainPadding={{ y: 70 }}
          padding={{
            top: 0,
            left: barWidth * (Math.max(this.totalGroupings, 2) - 1),
            right: barWidth * (Math.max(this.totalGroupings, 2) - 1),
            bottom: 30,
          }}
        >
          <VictoryGroup offset={barWidth}>
            {this.renderedDatasets.map(dataset => dataset)}
          </VictoryGroup>
          {this.chartAxis}
          {this.tierAxis}
        </VictoryChart>
      )
    }

    return (
      <VictoryChart
        theme={victoryTheme}
        padding={{
          top: 0,
          left: 0,
          right: 0,
          bottom: this.isSmallChartStyle ? 18 : 8,
        }}
        containerComponent={
          <VictoryVoronoiContainer portalZIndex={v.zIndex.gridCard} />
        }
        scale={{ x: 'time' }}
        domain={this.chartDomain}
      >
        {this.renderedDatasets.map(dataset => dataset)}
        {this.chartAxis}
        {this.tierAxis}
      </VictoryChart>
    )
  }

  render() {
    if (this.primaryDatasetValues.length === 0) {
      return this.renderNotEnoughData()
    }
    return (
      <ChartContainer
        height={this.primaryDatasetBarChart ? '100%' : '92%'}
        data-cy="ChartContainer"
      >
        <OrganicGrid />
        {this.renderVictoryChart}
      </ChartContainer>
    )
  }
}

ChartGroup.propTypes = {
  dataItem: MobxPropTypes.objectOrObservableObject.isRequired,
  simpleDateTooltip: PropTypes.bool,
  width: PropTypes.number,
  height: PropTypes.number,
}

ChartGroup.defaultProps = {
  simpleDateTooltip: false,
  width: 1,
  height: 1,
}

ChartGroup.wrappedComponent.propTypes = {
  routingStore: MobxPropTypes.objectOrObservableObject.isRequired,
}

ChartGroup.displayName = 'ChartGroup'

export default ChartGroup
