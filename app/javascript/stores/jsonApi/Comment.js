import _ from 'lodash'
import { observable, action, runInAction } from 'mobx'

import trackError from '~/utils/trackError'
import { apiUrl } from '~/utils/url'

import BaseRecord from './BaseRecord'
import { apiStore, uiStore } from '~/stores'

class Comment extends BaseRecord {
  static type = 'comments'
  static endpoint = apiUrl('comments')

  attributesForAPI = ['parent_id', 'message']

  @observable
  unread = false
  @observable
  replies = []

  constructor(...args) {
    super(...args)
    runInAction(() => {
      this.replies.replace(this.children)
    })
  }

  @action
  markAsUnread() {
    this.unread = true
  }

  @action
  markAsRead() {
    this.unread = false
  }

  get wasEdited() {
    return this.updated_at > this.created_at
  }

  @action
  importReply(reply) {
    let sortedReplies = _.union(this.replies, [reply])
    sortedReplies = _.sortBy(sortedReplies, ['created_at'])
    this.replies.replace(sortedReplies)
  }

  API_destroy = async () => {
    try {
      await this.destroy()
      const thread = apiStore.find('comment_threads', this.comment_thread_id)
      runInAction(() => {
        _.remove(thread.comments, comment => comment.id === this.id)
      })
    } catch (e) {
      console.error(e)
      uiStore.defaultAlertError()
    }
  }

  API_updateWithoutSync = rawData => {
    this.message = rawData.message
    this.draftjs_data = rawData.draftjs_data

    const data = this.toJsonApi()
    // Turn off syncing when saving the comment to not reload the page
    data.cancel_sync = true
    return apiStore
      .request(`comments/${this.id}`, 'PATCH', {
        data,
      })
      .catch(err => {
        trackError(err, { name: 'comment:update' })
      })
  }
}

Comment.defaults = {
  draftjs_data: {},
}

export default Comment
