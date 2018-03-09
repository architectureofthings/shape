import PropTypes from 'prop-types'
import { action, observable } from 'mobx'
import { inject, observer, PropTypes as MobxPropTypes } from 'mobx-react'
import Dialog, {
  DialogContent,
  DialogTitle,
} from 'material-ui/Dialog'
import { withStyles } from 'material-ui/styles'
import OrganizationEdit from '~/ui/layout/OrganizationEdit'

const materialStyles = {
  paper: {
    width: 624,
  }
}

@inject('uiStore')
@observer
class OrganizationMenu extends React.Component {
  @observable editOrganizationOpen = null;

  handleClose = (ev) => {
    const { uiStore } = this.props
    uiStore.closeOrganizationMenu()
  }

  @action
  handleOrganizationClick = () => {
    if (!this.editOrganization) {
      this.editOrganizationOpen = true
    }
  }

  @action
  onSave = () => {
      this.editOrganizationOpen = false
  }

  render() {
    const { classes, organization, uiStore } = this.props
    return (
      <Dialog
        open={uiStore.organizationMenuOpen}
        classes={classes}
        onClose={this.handleClose}
        aria-labelledby="form-dialog-title"
        BackdropProps={{ invisible: true }}
      >
        <DialogTitle id="form-dialog-title">People & Groups</DialogTitle>
        <DialogContent>
          <h3>
            Your Organization
          </h3>
          <button onClick={this.handleOrganizationClick}>
            <strong>{ organization.name }</strong>
          </button>
          { !!this.editOrganizationOpen &&
            <OrganizationEdit
              onSave={this.onSave }
              organization={organization}
            />
          }
        </DialogContent>
      </Dialog>
    )
  }
}

OrganizationMenu.propTypes = {
  organization: MobxPropTypes.objectOrObservableObject.isRequired,
  classes: PropTypes.shape({
    paper: PropTypes.string,
  }).isRequired,
}
OrganizationMenu.wrappedComponent.propTypes = {
  uiStore: MobxPropTypes.objectOrObservableObject.isRequired,
}

export default withStyles(materialStyles)(OrganizationMenu)
