import PropTypes from 'prop-types'
import { PropTypes as MobxPropTypes } from 'mobx-react'
import styled from 'styled-components'

import GridCardHotspot from '~/ui/grid/GridCardHotspot'
import TextItemCover from '~/ui/grid/covers/TextItemCover'
import ImageItemCover from '~/ui/grid/covers/ImageItemCover'
import VideoItemCover from '~/ui/grid/covers/VideoItemCover'
import CollectionCover from '~/ui/grid/covers/CollectionCover'

import CollectionIcon from '~/ui/icons/CollectionIcon'
import LinkedCollectionIcon from '~/ui/icons/LinkedCollectionIcon'
import LinkIcon from '~/ui/icons/LinkIcon'
import CardMenu from '~/ui/grid/CardMenu'
import v, { ITEM_TYPES } from '~/utils/variables'

export const StyledGridCard = styled.div`
  z-index: 1;
  position: relative;
  height: 100%;
  width: 100%;
  background: white;
  padding: 0;
  cursor: ${props => (props.dragging ? 'grabbing' : 'pointer')};
  box-shadow: ${props => (props.dragging ? '1px 1px 5px 2px rgba(0, 0, 0, 0.25)' : '')};
  opacity: ${props => (props.dragging ? '0.95' : '1')};
`
StyledGridCard.displayName = 'StyledGridCard'

export const StyledBottomLeftIcon = styled.div`
  position: absolute;
  left: -0.25rem; /* Because the icon has internal padding */
  bottom: -0.4rem;
  color: ${v.colors.gray};
  width: 34px;
  height: 34px;
`
StyledBottomLeftIcon.displayName = 'StyledBottomLeftIcon'

const StyledGridCardInner = styled.div`
  position: relative;
  height: 100%;
  overflow: hidden;
  z-index: 1;
`
StyledGridCardInner.displayName = 'StyledGridCardInner'

export const StyledTopRightActions = styled.div`
  position: absolute;
  top: 0.35rem;
  right: 0.25rem;
  z-index: ${v.zIndex.gridCard};
  .card-menu {
    margin-top: 0.25rem;
    display: inline-block;
    vertical-align: top;
    z-index: ${v.zIndex.gridCard};
    color: ${v.colors.gray};
  }
`
StyledTopRightActions.displayName = 'StyledTopRightActions'

const StyledSelectionCircle = styled.div`
  display: inline-block;
  vertical-align: top;
  width: 14px;
  height: 14px;
  border-radius: 14px;
  border: 1px solid ${v.colors.gray};
  margin: 5px;
  &.selected {
    border-color: ${v.colors.blackLava};
    background-color: ${v.colors.blackLava};
  }
`
StyledSelectionCircle.displayName = 'StyledSelectionCircle'

class GridCard extends React.Component {
  state = {
    selected: false,
  }

  get isItem() {
    return this.props.cardType === 'items'
  }
  get isCollection() {
    return this.props.cardType === 'collections'
  }

  get inner() {
    const { card, record, height } = this.props
    if (this.isItem) {
      switch (record.type) {
      case ITEM_TYPES.TEXT:
        return <TextItemCover item={record} height={height} />
      case ITEM_TYPES.IMAGE:
        return <ImageItemCover item={record} />
      case ITEM_TYPES.VIDEO:
        return <VideoItemCover item={record} dragging={this.props.dragging} />
      default:
        return (
          <div>
            [{card.order}] &nbsp;
            {record.content}
          </div>
        )
      }
    } else if (this.isCollection) {
      return <CollectionCover collection={record} />
    }
    return <div />
  }

  get icon() {
    const { card, cardType } = this.props
    let icon
    if (cardType === 'collections') {
      if (card.reference) {
        icon = <LinkedCollectionIcon />
      } else {
        icon = <CollectionIcon />
      }
    } else if (card.reference) {
      icon = <LinkIcon />
    }

    if (!icon) return ''

    return (
      <StyledBottomLeftIcon lassName="show-on-hover">
        {icon}
      </StyledBottomLeftIcon>
    )
  }

  toggleSelected = () => {
    this.setState({
      selected: !this.state.selected
    })
  }

  shareCard = () => {
    console.log('Share card')
  }

  duplicateCard = () => {
    console.log('Duplicate card')
  }

  linkCard = () => {
    console.log('Link card')
  }

  organizeCard = () => {
    console.log('Organize card')
  }

  archiveCard = () => {
    console.log('Archive card')
  }

  handleClick = (e) => {
    if (this.props.dragging) return
    this.props.handleClick(e)
  }

  render() {
    return (
      <StyledGridCard dragging={this.props.dragging}>
        <GridCardHotspot card={this.props.card} dragging={this.props.dragging} />
        <StyledTopRightActions className="show-on-hover">
          <StyledSelectionCircle
            className={this.state.selected ? 'selected' : ''}
            onClick={this.toggleSelected}
            role="button"
          />
          <CardMenu
            className="card-menu"
            cardId={this.props.card.id}
            menuOpen={this.props.menuOpen}
            handleShare={this.shareCard}
            handleDuplicate={this.duplicateCard}
            handleLink={this.linkCard}
            handleOrganize={this.organizeCard}
            handleArchive={this.archiveCard}
          />
        </StyledTopRightActions>
        {this.icon}
        {/* onClick placed here so it's separate from hotspot click */}
        <StyledGridCardInner onClick={this.handleClick}>
          {this.inner}
        </StyledGridCardInner>
      </StyledGridCard>
    )
  }
}

GridCard.propTypes = {
  card: MobxPropTypes.objectOrObservableObject.isRequired,
  cardType: PropTypes.string.isRequired,
  height: PropTypes.number.isRequired,
  record: MobxPropTypes.objectOrObservableObject.isRequired,
  dragging: PropTypes.bool.isRequired,
  handleClick: PropTypes.func.isRequired,
  menuOpen: PropTypes.bool.isRequired,
}

export default GridCard
