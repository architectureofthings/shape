import _ from 'lodash'
import styled from 'styled-components'
import v from '~/utils/variables'
import PropTypes from 'prop-types'

import hexToRgba from '~/utils/hexToRgba'
import propShapes from '~/utils/propShapes'
import { inject, observer, PropTypes as MobxPropTypes } from 'mobx-react'
import GridCardDropzone from '~/ui/grid/dropzone/GridCardDropzone'
import GridCardBlank from '~/ui/grid/blankContentTool/GridCardBlank'
import GridCardEmptyHotspot from '~/ui/grid/dragLayer/GridCardEmptyHotspot'

const CircleIconHolder = styled.button`
  border: 1px solid ${v.colors.secondaryMedium};
  border-radius: 50%;
  color: ${v.colors.secondaryMedium};
  height: 32px;
  width: 32px;
`

// When you have attributes that will change a lot,
// it's a performance gain to use `styled.div.attrs`
const BlankCardContainer = styled.div.attrs(({ x, y, h, w, zoomLevel }) => ({
  style: {
    height: `${h}px`,
    left: `${x}px`,
    top: `${y}px`,
    transform: `scale(${1 / zoomLevel})`,
    width: `${w}px`,
    cursor: 'pointer',
  },
}))`
  background: ${props => {
    if (props.interactionType === 'unrendered') {
      return v.colors.commonLightest
    } else if (props.interactionType === 'drag-overflow') {
      const color = props.blocked ? v.colors.alert : v.colors.primaryLight
      return `linear-gradient(
        to bottom,
        ${hexToRgba(color)} 0%,
        ${hexToRgba(color)} 25%,
        ${hexToRgba(color, 0)} 100%)`
    } else if (props.blocked) {
      return v.colors.alert
    } else if (_.includes(['drag', 'resize'], props.interactionType)) {
      return v.colors.primaryLight
    }
    return 'none'
  }};
  position: absolute;
  transform-origin: left top;
  opacity: ${props => {
    if (props.interactionType === 'unrendered') return 0.75
    if (_.includes(props.interactionType, 'drag')) return 0.5
    return 1
  }};
  z-index: ${props =>
    _.includes(props.interactionType, 'drag') ? v.zIndex.cardHovering : 1};

  /* FIXME: is this the same CircleIconHolder under GridCardEmptyHotspot? */

  ${CircleIconHolder} {
    display: none;
    height: 32px;
    width: 32px;
  }

  ${CircleIconHolder} + ${CircleIconHolder} {
    margin-top: 8px;
  }

  ${props =>
    props.interactionType !== 'unrendered' &&
    `&:hover {
    background-color: ${v.colors.primaryLight} !important;

    .plus-icon {
      display: block;
    }

    ${CircleIconHolder} {
      display: block;
    }
  }
  `} .plus-icon {
    display: none;
  }
`

@inject('uiStore')
@observer
class PositionedBlankCard extends React.Component {
  constructor(props) {
    super(props)
  }

  render() {
    const {
      collection,
      row,
      col,
      position,
      uiStore,
      blocked,
      interactionType,
    } = this.props
    const { blankContentToolIsOpen, droppingFiles } = uiStore

    const { xPos, yPos, height, width } = position

    const defaultProps = {
      row,
      col,
      x: xPos,
      y: yPos,
      h: height,
      w: width,
      zoomLevel: uiStore.relativeZoomLevel,
    }

    if (droppingFiles) {
      return (
        <BlankCardContainer {...defaultProps}>
          <GridCardDropzone collection={collection} row={row} col={col} />
        </BlankCardContainer>
      )
    } else if (blankContentToolIsOpen && interactionType === 'bct') {
      // FIXME: should render new hot cell since bct will be deprecated
      const blankContentTool = {
        id: 'blank',
        num: 0,
        cardType: 'blank',
        blankType: 'bct',
        col,
        row,
        width,
        height,
      }
      return (
        <BlankCardContainer {...defaultProps}>
          <GridCardBlank
            card={blankContentTool}
            cardType={'blank'}
            position={position}
            record={null}
            parent={collection}
          />
        </BlankCardContainer>
      )
    }

    const {
      emptyRow,
      handleBlankCardClick,
      handleInsertRowClick,
      handleRemoveRowClick,
    } = this.props
    const draggingOrResizing = _.includes(['drag', 'resize'], interactionType)

    return (
      <BlankCardContainer
        {...defaultProps}
        blocked={blocked}
        interactionType={interactionType}
        onClick={
          !draggingOrResizing
            ? () => {
                handleBlankCardClick({ row, col })
              }
            : null
        }
      >
        <GridCardEmptyHotspot
          interactionType={interactionType}
          emptyRow={emptyRow}
          isFourWideBoard={collection.isFourWideBoard}
          handleInsertRowClick={handleInsertRowClick}
          handleRemoveRowClick={handleRemoveRowClick}
        />
      </BlankCardContainer>
    )
  }
}

PositionedBlankCard.wrappedComponent.propTypes = {
  uiStore: MobxPropTypes.objectOrObservableObject.isRequired,
}

PositionedBlankCard.propTypes = {
  collection: MobxPropTypes.objectOrObservableObject.isRequired,
  row: PropTypes.number.isRequired,
  col: PropTypes.number.isRequired,
  position: PropTypes.shape(propShapes.position).isRequired,
  interactionType: PropTypes.oneOf(['hover', 'drag', 'unrendered', 'resize'])
    .isRequired,
  handleBlankCardClick: PropTypes.func,
  handleRemoveRowClick: PropTypes.func,
  handleInsertRowClick: PropTypes.func,
  blocked: PropTypes.bool,
  emptyRow: PropTypes.bool,
  replacingId: PropTypes.String,
}

PositionedBlankCard.defaultProps = {
  handleBlankCardClick: null,
  handleRemoveRowClick: null,
  handleInsertRowClick: null,
  blocked: false,
  emptyRow: false,
  replacingId: null,
}

PositionedBlankCard.displayName = 'PositionedBlankCard'

export default PositionedBlankCard