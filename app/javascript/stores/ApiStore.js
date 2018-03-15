import { action, observable, computed } from 'mobx'
import { Store } from 'mobx-jsonapi-store'

import Collection from './jsonApi/Collection'
import CollectionCard from './jsonApi/CollectionCard'
import FilestackFile from './jsonApi/FilestackFile'
import Item from './jsonApi/Item'
import Organization from './jsonApi/Organization'
import User from './jsonApi/User'

class ApiStore extends Store {
  @observable currentUserId = null

  @action setCurrentUserId(id) {
    this.currentUserId = id
  }

  @computed get currentUser() {
    return this.find('users', this.currentUserId)
  }
}
ApiStore.types = [Organization, User, Collection, Item, CollectionCard, FilestackFile]

export default ApiStore
