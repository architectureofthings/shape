import { PropTypes as MobxPropTypes } from 'mobx-react'

import CardActionHolder from '~/ui/icons/CardActionHolder'
import ContainImageIcon from '~/ui/icons/ContainImageIcon'
import v from '~/utils/variables'

class ContainImage extends React.Component {
  toggleSelected = ev => {
    ev.preventDefault()
    const { card } = this.props
    card.image_contain = !card.image_contain
    card.save()
  }

  render() {
    const { card } = this.props
    const { image_contain } = card

    return (
      <CardActionHolder
        className="show-on-hover"
        color={image_contain ? v.colors.black : v.colors.commonMedium}
        onClick={this.toggleSelected}
        tooltipText={
          !image_contain ? 'show whole image' : 'fill tile with image'
        }
      >
        <ContainImageIcon />
      </CardActionHolder>
    )
  }
}

ContainImage.propTypes = {
  card: MobxPropTypes.objectOrObservableObject.isRequired,
}

// to override the long 'injected-xxx' name
ContainImage.displayName = 'ContainImage'

export default ContainImage
