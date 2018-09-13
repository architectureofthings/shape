import PropTypes from 'prop-types'
import styled from 'styled-components'

import PlusIcon from '~/ui/icons/PlusIcon'

const HotEdge = styled.div`
  height: 0;
  margin-left: 320px;
  position: relative;
  top: -20px;
  width: 100%;
  z-index: 900;
`

const HotEdgeVisuals = styled.div`
  opacity: ${props => (props.showing ? 1.0 : 0.0)};
  transition: opacity 0.20s;
  transition-timing-function: ease-in;
  visibility: ${props => (props.showing ? 'visible' : 'hidden')};
  z-index: 901;
`

const VisualBar = styled.div`
  background-color: #C0DBDE;
  height: 6px;
  left: 20px;
  position: absolute;
  top: 20px;
  width: calc(100% - 40px);
`
const RoundAddButton = styled.button`
  background-color: #C0DBDE;
  border-radius: 50%;
  color: white;
  height: 32px;
  left: calc(50% - 16px);
  position: absolute;
  top: 6px;
  width: 32px;
  z-index: 900;

  svg {
    width: 16px;
  }
`

const HotAreaButton = styled.button`
  box-sizing: border-box;
  height: 40px;
  position: absolute;
  top: -10px;
  width: 100%;
  z-index: 901;
`

class QuestionHotEdge extends React.Component {
  state = { showing: false }

  handleAdd = (ev) => {
    ev.preventDefault()
    this.props.onAdd()
  }

  handleMouseOver = (ev) => {
    this.setState({ showing: true })
  }

  handleMouseOut = (ev) => {
    this.setState({ showing: false })
  }

  render() {
    return (
      <HotEdge>
        <HotAreaButton
          onClick={this.handleAdd}
          onMouseEnter={this.handleMouseOver}
          onMouseLeave={this.handleMouseOut}
          onFocus={this.handleMouseOver}
          onBlur={this.handleMouseOut}
        />
        <HotEdgeVisuals showing={this.state.showing}>
          <VisualBar />
          <RoundAddButton onClick={this.handleAdd}>
            <PlusIcon />
          </RoundAddButton>
        </HotEdgeVisuals>
      </HotEdge>
    )
  }
}
QuestionHotEdge.propTypes = {
  onAdd: PropTypes.func.isRequired,
}

export default QuestionHotEdge
