import PropTypes from 'prop-types'
import styled from 'styled-components'
import MuiDialog from 'material-ui/Dialog'

import v from '~/utils/variables'
import ICONS from '~/ui/icons/dialogIcons'

const { CloseIcon } = ICONS

const StyledDialog = styled(MuiDialog)`
  .modal__paper {
    background-color: ${v.colors.cloudy};
    border-radius: 6px;
    color: white;
    opacity: 0.95;
    width: 100%;
    &-sm {
      max-width: 425px;
    }
  }
`
const ModalCloseButton = styled.button`
  cursor: pointer;
  display: block;
  right: 14px;
  position: absolute;
  top: 12px;
  width: 12px;
`
ModalCloseButton.displayName = 'ModalCloseButton'

const CenteredPaddedContent = styled.div`
  padding: 20px;
  padding-bottom: 25px;
  text-align: center;
`

const IconHolder = styled.span`
  width: 84px;
  margin-bottom: 20px;
  display: inline-block;
`

const PromptText = styled.span`
  & p {
    font-weight: ${v.weights.book};
    font-size: 1.25rem;
    font-family: ${v.fonts.sans};
    margin-bottom: 40px;
    padding: 0;
  }
`

class Dialog extends React.PureComponent {
  handleClose = async (ev) => {
    ev.preventDefault()
    this.props.onClose()
  }

  get icon() {
    const { iconName } = this.props
    const icon = ICONS[`${iconName}Icon`]
    return icon ? React.createElement(icon) : ''
  }

  render() {
    const { children, open, maxWidth } = this.props
    return (
      <StyledDialog
        open={open}
        classes={{ paper: 'modal__paper', paperWidthSm: 'modal__paper-sm' }}
        onClose={this.handleClose}
        onBackdropClick={this.handleClose}
        aria-labelledby="Confirmation"
        BackdropProps={{ invisible: true }}
        maxWidth={maxWidth}
      >
        <ModalCloseButton onClick={this.handleClose}>
          <CloseIcon />
        </ModalCloseButton>
        <CenteredPaddedContent>
          <IconHolder>
            { this.icon }
          </IconHolder>
          <PromptText>
            { children }
          </PromptText>
        </CenteredPaddedContent>
      </StyledDialog>
    )
  }
}

Dialog.propTypes = {
  iconName: PropTypes.oneOf([
    'Alert',
    'Archive',
    'Back',
    'Close',
    'Leave',
    'Link',
    'Ok',
  ]),
  children: PropTypes.node.isRequired,
  open: PropTypes.bool.isRequired,
  onClose: PropTypes.func.isRequired,
  maxWidth: PropTypes.string,
}
Dialog.defaultProps = {
  iconName: 'Alert',
  maxWidth: 'xs', // 'xs' == 360px
}
// all propTypes except required `children` node, to be used by Information/ConfirmationModal
const { children, ...childPropTypes } = Dialog.propTypes
Dialog.childPropTypes = childPropTypes

export default Dialog
