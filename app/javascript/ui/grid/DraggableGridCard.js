import React from 'react'

import Style from 'style-it'
import FlipMove from 'react-flip-move'
import Draggable from 'react-draggable'

import GridCardItem from '~/ui/grid/GridCardItem'
import GridCardCollection from '~/ui/grid/GridCardCollection'
import GridItemBlank from '~/ui/grid/GridItemBlank'

class DraggableGridCard extends React.PureComponent {
  state = {
    position: { x: 0, y: 0 },
    dragging: false,
    zIndex: 1,
  }

  handleStart = () => {
    this.setState({ dragging: true, zIndex: 1000 })
  }

  handleDrag = (e) => {
    const { position } = this.props
    const pad = {
      left: 0,
      top: 100,
    }
    const dragPosition = {
      // use position of mouseX / Y
      dragX: e.pageX - pad.left, // compensate for padding-left in container
      dragY: e.pageY - pad.top, // compensate for padding-top in container
      ...position
    }
    this.props.onDrag(this.props.card.id, dragPosition)
  }
  handleStop = () => {
    if (this.props.onDragStop) {
      this.props.onDragStop(this.props.card.id)
    }
    this.setState({ dragging: false })
    setTimeout(() => {
      // have this item remain "on top" while it animates back
      this.setState({ zIndex: 1 })
    }, 350)
  }

  render() {
    const {
      card,
      cardType,
      record,
      position
    } = this.props

    // GridItem setup
    // const itemProps = { ...this.props }
    let GridCard = () => <div />
    const placeholder = cardType === 'placeholder'
    const blank = cardType === 'blank'
    if (cardType === 'items') {
      GridCard = GridCardItem
    } else if (cardType === 'collections') {
      GridCard = GridCardCollection
    } else if (placeholder) {
      GridCard = () => <div />
    } else if (blank) {
      GridCard = GridItemBlank
    }
    //
    const {
      width,
      height,
      xPos,
      yPos
    } = position

    let transition = 'transform 0.5s, opacity 0.5s ease-out 0.2s;'
    let opacity = 1
    let rotation = '0deg'
    let { zIndex } = this.state
    const bounds = {
      left: (-50 + (xPos * -1)),
      // TODO: `1200` would come from some viewport width
      right: (1200 - (width / 2)) - xPos
    }
    if (this.state.dragging) {
      opacity = 0.9
      rotation = '5deg'
    }
    if (placeholder) {
      zIndex = 0
      transition = 'none'
      rotation = '0deg'
    }
    return (
      <FlipMove appearAnimation={placeholder ? null : 'elevator'}>
        <Draggable
          handle=".DragHandle"
          bounds={bounds}
          onStart={this.handleStart}
          onDrag={this.handleDrag}
          onStop={this.handleStop}
          position={this.state.position}
        >
          <div style={{ zIndex, position: 'relative' }}>
            <Style>
              {`
                .PositionedDiv {
                  width: ${width}px;
                  height: ${height}px;
                  transform: translate(${xPos}px, ${yPos}px) rotate(${rotation});
                  transform: translate3d(${xPos}px, ${yPos}px, 0) rotate(${rotation});
                  transition: ${transition};
                  opacity: ${opacity};
                }
              `}
              <div className={`GridCard PositionedDiv ${placeholder ? 'placeholder' : ''}`}>
                <GridCard card={card} record={record} />
              </div>
            </Style>
          </div>
        </Draggable>
      </FlipMove>
    )
  }
}

export default DraggableGridCard
