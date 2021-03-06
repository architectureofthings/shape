import PropTypes from 'prop-types'
import { trackErrorSpecify } from '~/utils/trackError'
import v from '~/utils/variables'

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props)
    this.state = { error: null }
  }

  componentDidCatch(error, errorInfo) {
    this.setState({ error })
    // if (process.env.NODE_ENV === 'development') {
    // eslint-disable-next-line no-console
    console.error(error)
    // }
    const source = errorInfo.componentStack.split('\n')[1]
    trackErrorSpecify(
      source,
      error.message,
      error.name,
      error.stack.split('\n')
    )
  }

  render() {
    if (this.state.error) {
      return (
        <div
          style={{
            maxWidth: v.maxWidth,
            margin: '0 auto',
            marginTop: v.headerHeight,
            textAlign: 'center',
          }}
        >
          <h3>{"We're sorry — something's gone wrong."}</h3>
        </div>
      )
    }
    return this.props.children
  }
}
ErrorBoundary.propTypes = {
  children: PropTypes.node.isRequired,
}

export default ErrorBoundary
