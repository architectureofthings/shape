import _ from 'lodash'
import { Fragment } from 'react'
import PropTypes from 'prop-types'
import styled from 'styled-components'
import { observable, runInAction } from 'mobx'
import { inject, observer, PropTypes as MobxPropTypes } from 'mobx-react'
import { Collapse } from '@material-ui/core'
import v from '~/utils/variables'

import { ShowMoreButton } from '~/ui/global/styled/forms'
import { Heading3, DisplayText } from '~/ui/global/styled/typography'
import { Row, RowItemLeft } from '~/ui/global/styled/layout'
import SearchButton from '~/ui/global/SearchButton'
import DropdownIcon from '~/ui/icons/DropdownIcon'
import RolesAdd from '~/ui/roles/RolesAdd'
import RoleSelect from '~/ui/roles/RoleSelect'
import { uiStore } from '~/stores'

// TODO rewrite this
function sortUserOrGroup(a, b) {
  return a.entity.name.localeCompare(b.entity.name)
}

const ScrollArea = styled.div`
  flex: 1 1 auto;
  min-height: 100px;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
`

const FooterArea = styled.div`
  flex: 0 0 auto;
  padding-top: 24px;
  padding-bottom: ${props => (props.menuOpen ? 100 : 30)}px;
`

const StyledHeaderRow = styled(Row)`
  flex-wrap: wrap;
  justify-content: space-between;
  margin-left: 0;

  @media only screen and (max-width: ${v.responsive.smallBreakpoint}px) {
    width: 100%;
  }
`
const StyledRow = styled(Row)`
  cursor: pointer;
  margin-left: 0;
`
const StyledCollapseToggle = styled.button`
  .icon {
    width: 24px;
    transform: translateY(4px);
  }
`
const StyledExpandToggle = styled.button`
  .icon {
    width: 24px;
    transform: translateY(2px) rotate(-90deg);
  }
`

@inject('apiStore', 'routingStore')
@observer
class RolesMenu extends React.Component {
  state = {
    searchText: '',
    groups: [],
    pendingPanelOpen: false,
    activePanelOpen: true,
    page: {
      pending: 1,
      active: 1,
    },
  }

  @observable
  loadingMore = false

  constructor(props) {
    super(props)
    this.debouncedInit = _.debounce(this.initializeRolesAndGroups, 300)
  }

  componentDidMount() {
    this.initializeRolesAndGroups({ reset: true, page: 1 })
  }

  async initializeRolesAndGroups({
    reset = false,
    page = 1,
    skipSearch = false,
    status = 'both',
  } = {}) {
    const { apiStore, record } = this.props
    const { searchText } = this.state

    if (!skipSearch) {
      runInAction(() => {
        this.loadingMore = true
      })
      if (status === 'both' || status === 'active') {
        await apiStore.searchRoles(record, { reset, page, query: searchText })
      }
      if (status === 'both' || status === 'pending') {
        await apiStore.searchRoles(record, {
          status: 'pending',
          page,
          query: searchText,
        })
      }
      runInAction(() => {
        this.loadingMore = false
      })
    }

    const roleEntities = []
    const counts = {
      // the total counts are stored on each role, just need to grab one
      pending: record.roles[0].pendingCount,
      active: record.roles[0].activeCount,
    }
    record.roles.forEach(role => {
      role.users.forEach(user => {
        roleEntities.push(Object.assign({}, { role, entity: user }))
      })
      // TODO remove when implemented
      if (!role.groups) return
      role.groups.forEach(group => {
        roleEntities.push(Object.assign({}, { role, entity: group }))
      })
    })
    const sortedRoleEntities = roleEntities.sort(sortUserOrGroup)

    const groups = this.setupEntityGroups(sortedRoleEntities, counts)

    this.setState(prevState => ({
      groups,
      page: {
        pending:
          status === 'pending' || status === 'both'
            ? page
            : prevState.page.pending,
        active:
          status === 'active' || status === 'both'
            ? page
            : prevState.page.active,
      },
    }))
  }

  setupEntityGroups = (entities, counts) => [
    {
      panelTitle: 'Pending Invitations',
      status: 'pending',
      count: counts.pending,
      entities: entities.filter(
        role =>
          role.entity.internalType === 'users' &&
          role.entity.status === 'pending'
      ),
    },
    {
      panelTitle: 'Active Users',
      status: 'active',
      count: counts.active,
      entities: entities.filter(
        role =>
          role.entity.internalType !== 'users' ||
          role.entity.status !== 'pending'
      ),
    },
  ]

  togglePanel = panel => {
    this.updatePanel(panel, !this.isOpenPanel(panel))
  }

  updatePanel = (panel, isOpen) => {
    this.setState({ [`${panel.status}PanelOpen`]: isOpen })
  }

  isOpenPanel = panel => this.state[`${panel.status}PanelOpen`]

  updateSearchText = searchText => {
    this.setState({ searchText }, () => {
      this.debouncedInit({ reset: true, page: 1 })
    })
  }

  handleSearchChange = value => {
    this.updateSearchText(value)
  }

  clearSearch = () => this.updateSearchText('')

  deleteRoles = (role, entity, opts = {}) => {
    const { ownerId, ownerType } = this.props
    role.API_delete(entity, ownerId, ownerType, opts).then(res => {
      // We should do a page reload to get the correct user's new org
      if (opts.organizationChange) {
        this.props.routingStore.routeTo('homepage')
        window.location.reload()
      }
      if (!opts.isSwitching) {
        this.initializeRolesAndGroups({ skipSearch: true })
      }
      return {}
    })
  }

  createRoles = (entities, roleName, opts = {}) => {
    const { apiStore, ownerId, ownerType } = this.props
    const userIds = entities
      .filter(entity => entity.internalType === 'users')
      .map(user => user.id)
    const groupIds = entities
      .filter(entity => entity.internalType === 'groups')
      .map(group => group.id)
    const data = {
      role: { name: roleName },
      group_ids: groupIds,
      user_ids: userIds,
      is_switching: opts.isSwitching,
    }
    return apiStore
      .request(`${ownerType}/${ownerId}/roles`, 'POST', data)
      .then(res => {
        this.initializeRolesAndGroups({ reset: true, page: 1 })
      })
      .catch(err => {
        uiStore.alert(err.error[0])
      })
  }

  nextPage = status => () => {
    const page = this.state.page[status]
    this.initializeRolesAndGroups({
      status,
      page: page + 1,
    })
  }

  onCreateUsers = emails => {
    const { apiStore } = this.props
    return apiStore
      .request(`users/create_from_emails`, 'POST', { emails })
      .catch(err => {
        uiStore.alert(err.error[0])
      })
  }

  notCurrentUser(entity) {
    // TODO: needs to check group roles too
    if (entity.internalType === 'groups') return true
    const { apiStore } = this.props
    const { currentUser } = apiStore
    return currentUser.id !== entity.id
  }

  render() {
    const {
      record,
      addCallout,
      canEdit,
      ownerType,
      title,
      fixedRole,
      submissionBox,
    } = this.props

    const { groups } = this.state

    const roleTypes =
      ownerType === 'groups' ? ['member', 'admin'] : ['editor', 'viewer']

    // ability to restrict the selection to only one role type
    // e.g. "admin" is the only selection for Org Admins group
    const addRoleTypes = fixedRole ? [fixedRole] : roleTypes

    return (
      <Fragment>
        <ScrollArea>
          <StyledHeaderRow align="flex-end">
            <Heading3>{title}</Heading3>
            <SearchButton
              value={this.state.searchText}
              onChange={this.handleSearchChange}
              onClear={this.clearSearch}
            />
          </StyledHeaderRow>

          {groups.map(group => {
            const { panelTitle, entities, count, status } = group
            if (entities.length === 0) return null

            return (
              <div key={panelTitle}>
                <StyledRow
                  align="center"
                  onClick={() => this.togglePanel(group)}
                >
                  <DisplayText>
                    {panelTitle} ({count})
                  </DisplayText>
                  <RowItemLeft style={{ marginLeft: '0px' }}>
                    {this.isOpenPanel(group) ? (
                      <StyledCollapseToggle aria-label="Collapse">
                        <DropdownIcon />
                      </StyledCollapseToggle>
                    ) : (
                      <StyledExpandToggle aria-label="Expand">
                        <DropdownIcon />
                      </StyledExpandToggle>
                    )}
                  </RowItemLeft>
                </StyledRow>
                <Collapse
                  in={this.isOpenPanel(group)}
                  timeout="auto"
                  unmountOnExit
                >
                  {entities.map(
                    combined =>
                      // NOTE: content_editor is a "hidden" role for now
                      combined.role.name !== 'content_editor' && (
                        <RoleSelect
                          enabled={
                            canEdit &&
                            this.notCurrentUser(combined.entity, combined.role)
                          }
                          key={`${combined.entity.id}_${
                            combined.entity.internalType
                          }_r${combined.role.id}`}
                          record={record}
                          role={combined.role}
                          roleTypes={roleTypes}
                          roleLabels={
                            submissionBox ? { viewer: 'participant' } : {}
                          }
                          entity={combined.entity}
                          onDelete={this.deleteRoles}
                          onCreate={this.createRoles}
                        />
                      )
                  )}
                  {entities.length < count && (
                    <ShowMoreButton
                      disabled={this.loadingMore}
                      onClick={this.nextPage(status)}
                    >
                      {this.loadingMore ? 'Loading...' : 'Show more...'}
                    </ShowMoreButton>
                  )}
                </Collapse>
              </div>
            )
          })}
        </ScrollArea>
        {canEdit && (
          <FooterArea menuOpen={uiStore.autocompleteValues > 0}>
            <Heading3>{addCallout}</Heading3>
            <RolesAdd
              roleTypes={addRoleTypes}
              roleLabels={submissionBox ? { viewer: 'participant' } : {}}
              onCreateRoles={this.createRoles}
              onCreateUsers={this.onCreateUsers}
              ownerType={ownerType}
            />
          </FooterArea>
        )}
      </Fragment>
    )
  }
}

RolesMenu.propTypes = {
  record: MobxPropTypes.objectOrObservableObject.isRequired,
  canEdit: PropTypes.bool,
  ownerId: PropTypes.string.isRequired,
  ownerType: PropTypes.string.isRequired,
  fixedRole: PropTypes.string,
  title: PropTypes.string,
  addCallout: PropTypes.string,
  submissionBox: PropTypes.bool,
}
RolesMenu.wrappedComponent.propTypes = {
  apiStore: MobxPropTypes.objectOrObservableObject.isRequired,
  routingStore: MobxPropTypes.objectOrObservableObject.isRequired,
}
RolesMenu.defaultProps = {
  canEdit: false,
  fixedRole: null,
  title: 'Shared with',
  addCallout: 'Add groups or people:',
  submissionBox: false,
}

export default RolesMenu
