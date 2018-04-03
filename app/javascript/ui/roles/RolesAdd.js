import _ from 'lodash'
import PropTypes from 'prop-types'
import { observable, action } from 'mobx'
import { observer, PropTypes as MobxPropTypes } from 'mobx-react'
import styled from 'styled-components'
import {
  FormButton,
  FormActionsContainer,
  Select,
} from '~/ui/global/styled/forms'
import {
  Row,
  RowItemRight,
} from '~/ui/global/styled/layout'
import AutoComplete from '~/ui/global/AutoComplete'
import PillList from '~/ui/global/PillList'
import { MenuItem } from 'material-ui/Menu'

const RightAligner = styled.span`
  margin-right: 30px;
  min-width: 97px;
`
RightAligner.displayName = 'StyledRightAligner'

@observer
class RolesAdd extends React.Component {
  @observable selectedUsers = []
  @observable selectedRole = ''

  constructor(props) {
    super(props)
    const [first] = this.props.roleTypes
    this.selectedRole = first
  }

  @action
  onUserSelected = (data) => {
    let user = data
    if (!data.id) {
      user = Object.assign({}, { name: data.custom, email: data.custom })
    }
    if (!this.selectedUsers.find((selected) => selected.email === user.email)) {
      this.selectedUsers.push(user)
    }
  }

  @action
  onUserDelete = (user) => {
    this.selectedUsers.remove(user)
  }

  onUserSearch = (searchTerm) =>
    this.props.onSearch(searchTerm).then((res) =>
      res.data.map((user) =>
        ({ value: user.email, label: user.name, data: user })))

  handleSave = async (ev) => {
    const emails = this.selectedUsers
      .filter((selected) => !selected.id)
      .map((selected) => selected.email)

    const fullUsers = this.selectedUsers
      .filter((selected) => !!selected.id)

    let created = { data: [] }
    if (emails.length) {
      created = await this.props.onCreateUsers(emails)
    }
    const roles = await this.props.onCreateRoles(
      [...created.data, ...fullUsers], this.selectedRole
    )
    this.reset()
    return roles
  }

  @action
  handleRoleSelect = (ev) => {
    this.selectedRole = ev.target.value
  }

  @action
  reset() {
    this.selectedUsers = []
  }

  mapItems() {
    const { searchableItems } = this.props
    return searchableItems.map(item => {
      let value
      if (item.type === 'users') {
        value = item.email
      } else if (item.type === 'groups') {
        value = item.handle
      } else {
        throw new Error('Can only search users and groups')
      }
      return { value, label: item.name, data: item }
    })
  }

  render() {
    const { roleTypes } = this.props
    return (
      <div>
        { this.selectedUsers.length > 0 && (
          <PillList
            itemList={this.selectedUsers}
            onItemDelete={this.onUserDelete}
          />)
        }
        <Row>
          <AutoComplete
            options={this.mapItems()}
            onInputChange={this.onUserSearch}
            onOptionSelect={this.onUserSelected}
          />
          <RightAligner>
            <RowItemRight>
              <Select
                classes={{ root: 'select', selectMenu: 'selectMenu' }}
                displayEmpty
                disableUnderline
                name="role"
                onChange={this.handleRoleSelect}
                value={this.selectedRole}
              >
                { roleTypes.map(roleType =>
                  (<MenuItem key={roleType} value={roleType}>
                    {_.startCase(roleType)}
                  </MenuItem>))
                }
              </Select>
            </RowItemRight>
          </RightAligner>
        </Row>
        <FormActionsContainer>
          <FormButton
            onClick={this.handleSave}
            disabled={this.selectedUsers.length === 0}
          >
            Add
          </FormButton>
        </FormActionsContainer>
      </div>
    )
  }
}

RolesAdd.propTypes = {
  searchableItems: MobxPropTypes.arrayOrObservableArray.isRequired,
  roleTypes: PropTypes.arrayOf(PropTypes.string).isRequired,
  onCreateRoles: PropTypes.func.isRequired,
  onCreateUsers: PropTypes.func.isRequired,
  onSearch: PropTypes.func,
}
RolesAdd.defaultProps = {
  onSearch: () => {}
}

export default RolesAdd
