import _ from 'lodash'
import { Fragment } from 'react'
import { Flex } from 'reflexbox'
import { action, observable, runInAction } from 'mobx'
import { inject, observer, PropTypes as MobxPropTypes } from 'mobx-react'
import { animateScroll as scroll } from 'react-scroll'
import { Helmet } from 'react-helmet'
import { ThemeProvider } from 'styled-components'

import ClickWrapper from '~/ui/layout/ClickWrapper'
import ChannelManager from '~/utils/ChannelManager'
import CardCoverEditor from '~/ui/grid/CardCoverEditor'
import CollectionCollaborationService from '~/utils/CollectionCollaborationService'
import CollectionGrid from '~/ui/grid/CollectionGrid'
import CollectionFilter, {
  CollectionPillHolder,
} from '~/ui/filtering/CollectionFilter'
import CollectionList from '~/ui/grid/CollectionList'
import CollectionViewToggle from '~/ui/grid/CollectionViewToggle'
import FoamcoreGrid from '~/ui/grid/FoamcoreGrid'
import FloatingActionButton from '~/ui/global/FloatingActionButton'
import Loader from '~/ui/layout/Loader'
import GlobalPageComponentsContainer from '~/ui/grid/GlobalPageComponentsContainer'
import PageContainer from '~/ui/layout/PageContainer'
import PageHeader from '~/ui/pages/shared/PageHeader'
import PageSeparator from '~/ui/global/PageSeparator'
import PlusIcon from '~/ui/icons/PlusIcon'
import SubmissionBoxSettingsModal from '~/ui/submission_box/SubmissionBoxSettingsModal'
import EditorPill from '~/ui/items/EditorPill'
import SearchCollection from '~/ui/grid/SearchCollection'
import TestDesigner from '~/ui/test_collections/TestDesigner'
import v, { COLLECTION_CHANNEL_NAME } from '~/utils/variables'
import ArchivedBanner from '~/ui/layout/ArchivedBanner'
import OverdueBanner from '~/ui/layout/OverdueBanner'
import CreateOrgPage from '~/ui/pages/CreateOrgPage'
import SuggestedTagsBanner from '~/ui/global/SuggestedTagsBanner'
import HelperBanner4WFC from '~/ui/global/HelperBanner4WFC'

@inject('apiStore', 'uiStore', 'routingStore', 'undoStore')
@observer
class CollectionPage extends React.Component {
  @observable
  currentEditor = {}

  updatePoller = null
  editorTimeout = null

  constructor(props) {
    super(props)
    this.reloadData = _.throttle(this._reloadData, 3000)
    this.setEditor = _.throttle(this._setEditor, 4000)
  }

  @action
  componentDidMount() {
    const { collection, apiStore, routingStore } = this.props
    if (!apiStore.currentUser && !collection.anyone_can_view) {
      // in this case, if you're not logged in but you had access (joinable but not public)
      // we do require you to login
      // NOTE: the user will see a brief flash of the collection name before redirect
      routingStore.routeToLogin({ redirect: collection.frontendUrl })
    }
    this.setViewingRecordAndRestoreScrollPosition()
    this.initialLoad()
    this.subscribeToChannel(collection.id)
  }

  @action
  componentDidUpdate(prevProps) {
    const { collection, uiStore, routingStore } = this.props
    const {
      collection: { id: previousId },
    } = prevProps
    const { id: currentId } = collection
    if (currentId !== previousId) {
      runInAction(() => {
        // unsubscribe from previous collection; subscribe to new one
        ChannelManager.unsubscribeAllFromChannel(COLLECTION_CHANNEL_NAME)
        this.subscribeToChannel(currentId)
        // when navigating between collections, close BCT
        uiStore.closeBlankContentTool()
        this.setViewingRecordAndRestoreScrollPosition()
        this.initialLoad()
        routingStore.updateScrollState(previousId, window.pageYOffset)
      })
    }
  }

  componentWillUnmount() {
    const { routingStore, collection } = this.props
    ChannelManager.unsubscribeAllFromChannel(COLLECTION_CHANNEL_NAME)
    routingStore.updateScrollState(collection.id, window.pageYOffset)
  }

  get collection() {
    // TODO: replace all references to this.collection with this.props.collection
    return this.props.collection
  }

  initialLoad() {
    const { collection, uiStore } = this.props
    if (collection.isBoard) {
      // skip straight to this, because FoamcoreGrid will load the initial cards
      this.onAPILoad()
      return
    }
    uiStore.update('isLoading', true)
    // other collections e.g. TestCollection load as usual
    this.loadCollectionCards()
  }

  setViewingRecordAndRestoreScrollPosition() {
    const { collection, uiStore } = this.props
    // setViewingRecord has to happen first bc we use it in openBlankContentTool
    // this will also determine if there is a background image for this collection and set it
    uiStore.setViewingRecord(collection)
    this.restoreWindowScrollPosition()
  }

  @action
  loadCollectionCards = async ({
    page,
    per_page,
    rows,
    cols,
    reloading = false,
  } = {}) => {
    const { collection, uiStore, undoStore } = this.props
    // if the collection is still awaiting updates, there are no cards to load
    if (collection.awaiting_updates) {
      this.pollForUpdates()
      return []
    }

    let params = { page, per_page }
    if (collection.isBoard) {
      params = { rows }
      // ensure that boards with filters are in list view
      if (collection.activeFilters.length > 0) {
        collection.setViewMode('list')
      }
    }
    if (undoStore.actionAfterRoute) {
      // clear this out before we fetch, so that any undo/redo actions don't flash a previous state of the cards
      collection.clearCollectionCards()
    }
    if (reloading) {
      // make sure to get refetch the latest collection info as well
      await collection.refetch()
    }
    const cards = await collection.API_fetchCards(params)
    if (collection.id !== this.props.collection.id) {
      // this may have changed during the course of the request if we navigated
      return []
    }
    if (reloading) {
      return cards
    }
    if (uiStore.isLoading) {
      // non board collections e.g. TestDesigner don't load until the initial cards have loaded
      uiStore.update('isLoading', false)
    }
    // this only needs to run on the initial load not when we reload/refetch cards
    this.onAPILoad()
    return cards
  }

  loadSubmissionsCollectionCards = async ({
    page,
    per_page,
    rows,
    cols,
  } = {}) => {
    const { submissions_collection } = this.props.collection
    await submissions_collection.API_fetchCards({
      page,
      per_page,
      rows,
      cols,
    })
    if (submissions_collection.isSubmissionsCollectionInsideChallenge) {
      // fetch card reviewer statuses for the new page of cards
      submissions_collection.API_fetchCardReviewerStatuses()
    }
  }

  @action
  async onAPILoad() {
    const {
      collection,
      apiStore,
      uiStore,
      routingStore,
      undoStore,
    } = this.props

    apiStore.checkCurrentOrg({ id: collection.organization_id })

    if (collection.isSubmissionsCollection) {
      // NOTE: SubmissionsCollections are not meant to be viewable, so we route
      // back to the SubmissionBox instead
      routingStore.routeTo('collections', collection.submission_box_id)
      return
    }
    if (uiStore.actionAfterRoute) {
      uiStore.performActionAfterRoute()
    }
    if (undoStore.actionAfterRoute) {
      undoStore.performActionAfterRoute()
    }
    if (collection.joinable_group_id) {
      apiStore.checkJoinableGroup(collection.joinable_group_id)
    }
    if (collection.isNormalCollection) {
      await this.checkSubmissionBox()
    } else {
      apiStore.clearUnpersistedThreads()
    }
    apiStore.setupCommentThreadAndMenusForPage(collection)
    if (collection.processing_status) {
      const message = `${collection.processing_status}...`
      uiStore.popupSnackbar({ message })
    }
    if (collection.viewMode === 'list') {
      collection.API_fetchCardRoles()
    }
    if (collection.isChallengeOrInsideChallenge) {
      this.initializeChallenges()
    }
    uiStore.update('dragTargets', [])
    uiStore.update('preselectUserTag', false)
  }

  restoreWindowScrollPosition() {
    const { collection, uiStore, routingStore } = this.props
    const { previousViewingRecord } = uiStore
    const linkedBreadCrumbTrail = previousViewingRecord
      ? uiStore.linkedBreadcrumbTrailForRecord(previousViewingRecord)
      : []
    let isComingFromViewingRecordBreadcrumb = _.find(linkedBreadCrumbTrail, {
      id: collection.id,
    })
    if (
      collection.isUserCollection &&
      previousViewingRecord &&
      previousViewingRecord.in_my_collection
    ) {
      // we went from a record in my collection -> My Collection
      isComingFromViewingRecordBreadcrumb = true
    }
    const {
      toPathScrollY,
      history,
      location,
      previousPageBeforeSearch,
    } = routingStore
    const { action } = history
    const originalScrollY = toPathScrollY(collection.id)
    const returningFromSearch = previousPageBeforeSearch === location.pathname
    routingStore.previousPageBeforeSearch = null // reset previous page back to original state
    // on browser back button click, breadcrumb, or cancel search, scroll to original position
    const shouldScrollToOriginalPosition =
      action === 'POP' ||
      isComingFromViewingRecordBreadcrumb ||
      returningFromSearch

    if (shouldScrollToOriginalPosition) {
      scroll.scrollTo(originalScrollY, { duration: 200 })
    } else {
      scroll.scrollToTop({ duration: 0 })
    }
  }

  pollForUpdates() {
    const { collection, apiStore, uiStore } = this.props
    if (uiStore.dialogConfig.open !== 'loading') {
      let prompt =
        'Please wait while we build your account. This should take from 15 to 30 seconds.'
      if (collection.isTestCollectionOrResults) {
        prompt =
          'Please wait while we generate your feedback results collection. This should take 5 to 10 seconds.'
      }
      uiStore.loadingDialog({
        prompt,
        iconName: 'Celebrate',
      })
    }

    this.updatePoller = setInterval(async () => {
      if (collection.awaiting_updates) {
        const res = await apiStore.fetch('collections', collection.id, true)
        if (!res.data.awaiting_updates) {
          this.loadCollectionCards()
        }
      } else {
        clearInterval(this.updatePoller)
        uiStore.closeDialog()
      }
    }, 2000)
  }

  async checkSubmissionBox() {
    const { collection, uiStore } = this.props
    if (collection.isSubmissionBox && collection.submissions_collection_id) {
      this.setLoadingSubmissions(true)
      // NOTE: if other collections get sortable features we may move this logic
      uiStore.update('collectionCardSortOrder', 'updated_at')
      await collection.fetchSubmissionsCollection({ order: 'updated_at' })
      this.setLoadingSubmissions(false)
      // Also subscribe to updates for the submission boxes
      this.subscribeToChannel(collection.submissions_collection_id)
    }
    return true
  }

  async initializeChallenges() {
    const { collection } = this.props
    await collection.initializeParentChallengeForCollection()
    if (
      collection.isSubmissionInChallenge ||
      collection.isSubmissionBoxInsideChallenge
    ) {
      if (collection.submissions_collection) {
        collection.submissions_collection.API_fetchCardReviewerStatuses()
      }
    }
  }

  subscribeToChannel(id) {
    ChannelManager.subscribe(COLLECTION_CHANNEL_NAME, id, {
      channelReceivedData: this.receivedChannelData,
    })
  }

  @action
  _setEditor = editor => {
    this.currentEditor = editor
    if (this.editorTimeout) clearTimeout(this.editorTimeout)
    // this.unmounted comes from PageWithApi
    if (this.unmounted || _.isEmpty(editor)) return
    this.editorTimeout = setTimeout(() => this._setEditor({}), 4000)
  }

  handleAllClick = ev => {
    const { uiStore } = this.props
    ev.preventDefault()
    uiStore.closeCardMenu()
  }

  receivedChannelData = async data => {
    const { apiStore } = this.props
    let { collection } = this.props
    let { loadCollectionCards } = this
    const { collaborators, current_editor } = data
    // catch if receivedData happens after reload
    if (!collection) return

    if (
      collection.submissions_collection &&
      data.record_id === collection.submissions_collection.id
    ) {
      loadCollectionCards = this.loadSubmissionsCollectionCards
      collection = collection.submissions_collection
    }
    if (collection.id !== data.record_id) {
      return
    }

    if (_.get(data, 'current_editor.id') === apiStore.currentUserId) {
      // don't reload your own updates
      return
    }

    // set collaborators on this collection
    if (_.isArray(collaborators)) {
      collection.setCollaborators(collaborators)
    }

    const updateData = data.data
    if (
      updateData &&
      !updateData.coordinates &&
      !updateData.text_item &&
      !updateData.cards_selected
    ) {
      // don't show editor pill for small updates: cursor, text, selected cards
      this.setEditor(current_editor)
    }
    if (!updateData || updateData.reload_cards) {
      this.reloadData()
      return
    }
    const service = new CollectionCollaborationService({
      collection,
      loadCollectionCards,
    })
    service.handleReceivedData(updateData, current_editor)
  }

  async _reloadData() {
    const { collection } = this.props
    if (collection.isBoard) {
      this.loadCollectionCards({
        reloading: true,
        rows: [0, collection.loadedRows],
      })
    } else {
      const per_page =
        collection.collection_cards.length || collection.recordsPerPage
      this.loadCollectionCards({ reloading: true, per_page })
    }
    if (this.collection.submissions_collection) {
      this.setLoadingSubmissions(true)
      await this.collection.submissions_collection.API_fetchCards()
      this.setLoadingSubmissions(false)
    }
  }

  @action
  setLoadingSubmissions = val => {
    const { uiStore } = this.props

    if (!this.collection) return
    const { submissions_collection } = this.collection
    if (submissions_collection && submissions_collection.cardIds.length) {
      // if submissions_collection is preloaded with some cards, no need to show loader
      uiStore.update('loadingSubmissions', false)
      return
    }
    uiStore.update('loadingSubmissions', val)
  }

  onAddSubmission = ev => {
    ev.preventDefault()
    const { apiStore } = this.props
    const { id } = this.collection.submissions_collection
    const submissionSettings = {
      type: this.collection.submission_box_type,
      template: this.collection.submission_template,
    }
    apiStore.createSubmission(id, submissionSettings)
  }

  trackCollectionUpdated = () => {
    const { uiStore } = this.props
    uiStore.trackEvent('update', this.collection)
  }

  get submissionsPageSeparator() {
    const { collection } = this.props
    const { submissions_collection } = collection
    if (!submissions_collection) return ''
    return (
      <PageSeparator
        title={
          <h3>
            {submissions_collection.collection_cards.length}{' '}
            {submissions_collection.collection_cards.length === 1
              ? 'Submission'
              : 'Submissions'}
          </h3>
        }
      />
    )
  }

  get renderEditorPill() {
    const { currentEditor } = this
    const { currentUserId } = this.props.apiStore
    const { collaborators } = this.props.collection
    let hidden = ''
    // don't let logged-out users see who's editing, but they can still receive realtime updates
    if (!currentUserId) return

    const collaborator = _.find(collaborators, c => c.id === currentEditor.id)
    if (collaborator && collaborator.color) {
      runInAction(() => {
        currentEditor.color = collaborator.color
      })
    }
    if (_.isEmpty(currentEditor) || currentEditor.id === currentUserId) {
      // toggle hidden on/off to allow EditorPill CSS to fade in/out
      hidden = 'hidden'
    }
    return (
      <EditorPill className={`editor-pill ${hidden}`} editor={currentEditor} />
    )
  }

  renderSubmissionsCollection() {
    const { collection, uiStore, apiStore } = this.props
    const { blankContentToolState, gridSettings, loadingSubmissions } = uiStore
    const {
      submissions_collection,
      submission_box_type,
      submission_template,
      submissions_enabled,
    } = collection

    if (!apiStore.currentUser && !collection.anyone_can_view) {
      return
    }

    if (!submissions_collection || loadingSubmissions) {
      return this.loader()
    }

    const genericCollectionProps = {
      collection: submissions_collection,
      loadCollectionCards: this.loadSubmissionsCollectionCards,
      trackCollectionUpdated: this.trackCollectionUpdated,
      canEditCollection: false,
      // Pass in cardProperties so grid will re-render when they change
      cardProperties: submissions_collection.cardProperties,
      // Pass in BCT state so grid will re-render when open/closed
      blankContentToolState,
      // to trigger a re-render
      movingCardIds: [],
    }

    let renderedSubmissions
    if (submissions_collection.viewMode === 'list') {
      renderedSubmissions = (
        <CollectionList
          collection={submissions_collection}
          loadCollectionCards={this.loadSubmissionsCollectionCards}
        />
      )
    } else if (submissions_collection.isBoard) {
      // TODO: remove this switch between Foamcore and Normal Grid, only needed for now;
      // same note as in SearchCollection
      renderedSubmissions = (
        <FoamcoreGrid
          {...genericCollectionProps}
          submissionSettings={{
            type: submission_box_type,
            template: submission_template,
            enabled: submissions_enabled,
          }}
        />
      )
    } else {
      renderedSubmissions = (
        <CollectionGrid
          {...gridSettings}
          {...genericCollectionProps}
          submissionSettings={{
            type: submission_box_type,
            template: submission_template,
            enabled: submissions_enabled,
          }}
          sorting
        />
      )
    }

    return (
      <div style={{ position: 'relative' }}>
        {this.submissionsPageSeparator}
        <Flex ml="auto" justify="flex-end">
          <CollectionPillHolder id="collectionFilterPortal" />
          <div style={{ display: 'inline-block', marginTop: '4px' }}>
            <CollectionViewToggle collection={submissions_collection} />
          </div>
          <CollectionFilter
            collection={submissions_collection}
            canEdit={collection.can_edit_content}
            hasPreselectedTags={uiStore.preselectUserTag}
            sortable
          />
        </Flex>
        {renderedSubmissions}
        {submissions_enabled && submissions_collection.viewMode !== 'list' && (
          <FloatingActionButton
            toolTip={`Create New Submission`}
            onClick={this.onAddSubmission}
            icon={<PlusIcon />}
          />
        )}
      </div>
    )
  }

  renderSearchCollection() {
    return (
      <SearchCollection
        collection={this.props.collection}
        trackCollectionUpdated={this.trackCollectionUpdated}
      />
    )
  }

  renderTestDesigner() {
    return <TestDesigner collection={this.props.collection} />
  }

  loader = () => (
    <div style={{ marginTop: v.headerHeight }}>
      <Loader />
    </div>
  )

  transparentLoader = () => (
    <div
      style={{
        zIndex: v.zIndex.clickWrapper,
        marginTop: v.headerHeight + 40,
        position: 'fixed',
        top: 0,
        left: 'calc(50% - 50px)',
      }}
    >
      <Loader />
    </div>
  )

  render() {
    const { collection, uiStore, apiStore } = this.props
    const { currentUser } = apiStore

    if (!collection) {
      return this.loader()
    }

    // NOTE: if we have first loaded the slimmer SerializableSimpleCollection via the CommentThread
    // then some fields like `can_edit` will be undefined.
    // So we check if the full Collection has loaded via the `can_edit` attr
    // Also, checking meta.snapshot seems to load more consistently than just collection.can_edit
    const isLoading =
      collection.meta.snapshot.can_edit === undefined ||
      collection.awaiting_updates ||
      uiStore.isLoading
    const { isTransparentLoading } = uiStore

    const {
      blankContentToolState,
      submissionBoxSettingsOpen,
      gridSettings,
    } = uiStore

    // props shared by Foamcore + Normal
    const genericCollectionProps = {
      collection,
      loadCollectionCards: this.loadCollectionCards,
      trackCollectionUpdated: this.trackCollectionUpdated,
      canEditCollection: collection.can_edit_content,
      // Pass in cardProperties so grid will re-render when they change
      cardProperties: collection.cardProperties,
      // Pass in BCT state so grid will re-render when open/closed
      blankContentToolState,
      // to trigger a re-render
      movingCardIds: [...uiStore.movingCardIds],
      isMovingCards: uiStore.isMovingCards,
    }

    // submissions_collection will only exist for submission boxes
    const {
      isSubmissionBox,
      isTestCollection,
      parent_collection_card,
    } = collection
    const userRequiresOrg =
      !apiStore.currentUserOrganization && collection.common_viewable

    let inner
    if (collection.isSearchCollection) {
      // do this first because SearchCollection + list viewMode is slightly different
      inner = this.renderSearchCollection()
    } else if (collection.viewMode === 'list') {
      inner = (
        <CollectionList
          collection={collection}
          loadCollectionCards={this.loadCollectionCards}
        />
      )
    } else if (collection.isBoard) {
      inner = <FoamcoreGrid {...genericCollectionProps} />
    } else if (isTestCollection) {
      inner = this.renderTestDesigner()
    } else {
      // NOTE: deprecated now with 4WFC? do we ever land here?
      inner = (
        <CollectionGrid
          {...genericCollectionProps}
          // pull in cols, gridW, gridH, gutter
          {...gridSettings}
          // don't add the extra row for submission box
          shouldAddEmptyRow={!isSubmissionBox}
        />
      )
    }

    return (
      <ThemeProvider theme={collection.styledTheme}>
        <Fragment>
          <Helmet title={collection.pageTitle} />
          {!isLoading && collection.showSubmissionTopicSuggestions && (
            <SuggestedTagsBanner
              collection={collection}
              suggestions={_.get(collection, 'parentChallenge.topic_list', [])}
            />
          )}
          {!isLoading && (
            <Fragment>
              <ArchivedBanner />
              <OverdueBanner />
            </Fragment>
          )}

          {currentUser && currentUser.show_helper && (
            <HelperBanner4WFC currentUser={currentUser} />
          )}

          <PageHeader record={collection} template={collection.template} />
          {userRequiresOrg && (
            // for new user's trying to add a common resource, they'll see the Create Org modal
            // pop up over the CollectionGrid
            <CreateOrgPage commonViewableResource={collection} />
          )}
          {!isLoading && (
            <Fragment>
              <PageContainer
                fullWidth={
                  collection.isBoard &&
                  !collection.isFourWideBoard &&
                  collection.viewMode !== 'list'
                }
              >
                {this.renderEditorPill}
                {inner}
                {(collection.requiresSubmissionBoxSettings ||
                  submissionBoxSettingsOpen) && (
                  <SubmissionBoxSettingsModal collection={collection} />
                )}
                {/* Listen to this pastingCards value which comes from pressing CTRL+V */}
                <GlobalPageComponentsContainer
                  pastingCards={uiStore.pastingCards}
                />
                {isSubmissionBox &&
                  collection.submission_box_type &&
                  this.renderSubmissionsCollection()}
                {(uiStore.dragging || uiStore.cardMenuOpenAndPositioned) && (
                  <ClickWrapper
                    clickHandlers={[this.handleAllClick]}
                    onContextMenu={this.handleAllClick}
                  />
                )}
              </PageContainer>
            </Fragment>
          )}
          {isLoading && this.loader()}
          {!isLoading && isTransparentLoading && this.transparentLoader()}
          {collection.can_edit_content &&
            collection.canSetACover &&
            parent_collection_card && (
              <CardCoverEditor
                card={parent_collection_card}
                isEditingCardCover={
                  uiStore.editingCardCover === parent_collection_card.id
                }
                pageMenu
              />
            )}
        </Fragment>
      </ThemeProvider>
    )
  }
}

CollectionPage.propTypes = {
  collection: MobxPropTypes.objectOrObservableObject.isRequired,
}
CollectionPage.wrappedComponent.propTypes = {
  apiStore: MobxPropTypes.objectOrObservableObject.isRequired,
  uiStore: MobxPropTypes.objectOrObservableObject.isRequired,
  routingStore: MobxPropTypes.objectOrObservableObject.isRequired,
  undoStore: MobxPropTypes.objectOrObservableObject.isRequired,
}

export default CollectionPage
