import { inject, observer, PropTypes as MobxPropTypes } from 'mobx-react'
// import styled from 'styled-components'

import { Heading1, Heading2 } from '~/ui/global/styled/typography'
import v from '~/utils/variables'
import Header from '~/ui/layout/Header'
import PageContainer from '~/ui/layout/PageContainer'
import TagEditor from '~/ui/pages/shared/TagEditor'

@inject('apiStore', 'routingStore')
@observer
class SettingsPage extends React.Component {
  componentDidMount() {
    // kick out if you're not an org admin (i.e. primary_group admin)
    if (!this.organization.primary_group.can_edit) {
      this.props.routingStore.routeTo('/')
    }
  }

  get organization() {
    const { apiStore } = this.props
    return apiStore.currentUserOrganization
  }

  render() {
    return (
      <div>
        <Header />
        <PageContainer marginTop={v.headerHeightCompact}>
          <Heading1 noTransform marginBottom>Settings</Heading1>
          <Heading2>Official Domains</Heading2>
          <p>
            Any new people added to {this.organization.name} without these email domains
            will be considered guests.
          </p>

          <TagEditor
            canEdit
            validate="domain"
            placeholder="Please enter domains with the following format: domain.com"
            record={this.organization}
            tagField="domain_whitelist"
            tagColor="white"
          />
        </PageContainer>
      </div>
    )
  }
}

SettingsPage.wrappedComponent.propTypes = {
  apiStore: MobxPropTypes.objectOrObservableObject.isRequired,
  routingStore: MobxPropTypes.objectOrObservableObject.isRequired,
}

export default SettingsPage
