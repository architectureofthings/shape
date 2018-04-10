import { PropTypes as MobxPropTypes } from 'mobx-react'
import _ from 'lodash'
import ReactQuill from 'react-quill'
import styled from 'styled-components'

import v from '~/utils/variables'
import TextItemToolbar from '~/ui/items/TextItemToolbar'

const StyledContainer = styled.div`
  padding: 2rem 0.5rem;
`

const remapHeaderToH3 = (node, delta) => {
  delta.map((op) => (op.attributes.header = 3))
  return delta
}

export const overrideHeadersFromClipboard = (editor) => {
  // change all non-H3 header attributes to H3, e.g. when copy/pasting
  editor.clipboard.addMatcher('H1', remapHeaderToH3)
  editor.clipboard.addMatcher('H2', remapHeaderToH3)
  editor.clipboard.addMatcher('H4', remapHeaderToH3)
  editor.clipboard.addMatcher('H5', remapHeaderToH3)
  editor.clipboard.addMatcher('H6', remapHeaderToH3)
}

class TextItem extends React.Component {
  constructor(props) {
    super(props)
    this.onTextChange = _.debounce(this._onTextChange, 1000)
    this.cable = ActionCable.createConsumer('ws://localhost:3000/cable')
    this.channel = null
  }

  componentDidMount() {
    if (!this.quillEditor) return
    if (this.canEdit) {
      const { editor } = this.quillEditor
      overrideHeadersFromClipboard(editor)
    }
    this.subscribeToItemEditingChannel()
  }

  subscribeToItemEditingChannel = () => {
    const { item } = this.props
    this.channel = this.cable.subscriptions.create(
      { channel: 'ItemEditingChannel', id: item.id },
      {
        connected: this.connected,
        disconnected: this.disconnected,
        received: this.received,
        rejected: this.rejected,
      }
    )
  }

  received = (data) => {
    console.log('Channel received: ', data)
  }

  connected = () => {
    console.log('Channel connected')
  }

  disconnected = () => {
   console.log('Channel disconnected.')
  }

  rejected = () => {
   console.log('I was rejected! :(')
  }

  onBlur = () => {
    const { item } = this.props
    console.log('stop editing')
    this.channel.perform('start_editing', { id: item.id })
  }

  onFocus = () => {
    const { item } = this.props
    console.log('start editing')
    this.channel.perform('stop_editing', { id: item.id })
  }

  get canEdit() {
    return this.props.item.can_edit
  }

  _onTextChange = (content, delta, source, editor) => {
    const { item } = this.props
    const textData = editor.getContents()
    item.content = content
    item.text_data = textData
    item.save()
  }

  render() {
    const { item } = this.props

    // we have to convert the item to a normal JS object for Quill to be happy
    const textData = item.toJS().text_data
    let quillProps = {}
    if (this.canEdit) {
      quillProps = {
        ...v.quillDefaults,
        ref: c => { this.quillEditor = c },
        theme: 'snow',
        onChange: this.onTextChange,
        onFocus: this.onFocus,
        onBlur: this.onBlur,
        modules: {
          toolbar: '#quill-toolbar',
        },
      }
    } else {
      // for users who only have read access to this TextItem
      quillProps = {
        readOnly: true,
        theme: null,
      }
    }

    return (
      <StyledContainer>
        { this.canEdit && <TextItemToolbar /> }
        <ReactQuill
          {...quillProps}
          value={textData}
        />
      </StyledContainer>
    )
  }
}

TextItem.propTypes = {
  item: MobxPropTypes.objectOrObservableObject.isRequired,
}

export default TextItem
