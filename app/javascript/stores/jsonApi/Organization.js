import { apiUrl } from '~/utils/url'
import { ReferenceType } from 'datx'
import _ from 'lodash'

import BaseRecord from './BaseRecord'
import Item from './Item'

class Organization extends BaseRecord {
  static type = 'organizations'
  static endpoint = apiUrl('organizations')

  API_createTermsTextItem() {
    return this.apiStore.request(
      `organizations/${this.id}/add_terms_text`,
      'PATCH'
    )
  }

  API_removeTermsTextItem() {
    return this.apiStore.request(
      `organizations/${this.id}/remove_terms_text`,
      'PATCH'
    )
  }

  API_bumpTermsVersion() {
    return this.apiStore.request(
      `organizations/${this.id}/bump_terms_version`,
      'PATCH'
    )
  }

  async API_searchTagsAndUsers(tag) {
    return this.apiStore.request(
      `organizations/${this.id}/search_users_and_tags?query=${tag}`,
      'GET'
    )
  }

  async API_getOrganizationUserTag(handle) {
    // FIXME: should return user for handle
    await Promise.resolve(null)
  }

  // NOTE: Initializes tag suggestions for react tags
  async searchTagsAndUsers(handle) {
    const organizationTags = await this.API_searchTagsAndUsers(handle)
    const { data } = organizationTags

    const allTagsAndUsers = []
    if (data) {
      _.each(data, (tagOrUser, index) => {
        const { internalType } = tagOrUser

        let name = ''
        let user = null
        let label = ''
        if (internalType === 'users') {
          label = tagOrUser.handle
          user = tagOrUser.toJSON() // how do we not use .toJSON() here
          name = `${tagOrUser.first_name} ${tagOrUser.last_name} ${tagOrUser.handle}`
        } else if (internalType === 'tags') {
          label = name = tagOrUser.name.trim()
        }
        // NOTE: label is used for adding/removing tags, name is used for displaying react tag suggestions
        allTagsAndUsers.push({ id: index, name, label, user, internalType })
      })
    }

    return allTagsAndUsers
  }

  attributesForAPI = [
    'in_app_billing',
    'name',
    'handle',
    'domain_whitelist',
    'filestack_file_attributes',
    'deactivated',
  ]
}

Organization.type = 'organizations'

Organization.refDefaults = {
  terms_text_item: {
    model: Item,
    type: ReferenceType.TO_ONE,
    defaultValue: null,
  },
}

export default Organization
