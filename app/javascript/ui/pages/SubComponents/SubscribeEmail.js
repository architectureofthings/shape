import styled from 'styled-components'
import { Flex, Box } from 'reflexbox'
import v from '~/utils/variables'

const SubscribeInput = styled.input`
  width: 180px;
  font-weight: ${v.weights.book};
  font-family: ${v.fonts.sans};
  font-size: 1rem;
  margin: 1em;
  padding: 12px 12px;
  cursor: pointer;
  letter-spacing: 1.5px;
  border-radius: 2px;
  border: 2px solid white;
  margin-right: -7.6px;

  @media only screen and (min-width: ${v.responsive.smallBreakpoint}px) {
    width: 320.3px;
    margin-right: -4px;
  }
`

const SubscribeButton = styled.button`
  align: left;
  font-weight: ${v.weights.medium};
  font-family: ${v.fonts.sans};
  font-size: 14px;
  color: white;
  margin: 1em;
  padding: 12px 12px;
  cursor: pointer;
  letter-spacing: 0.5px;
  border-radius: 4px;
  border: 2px solid white;
  text-transform: uppercase;

  &:hover {
    color: ${v.colors.blackLava};
  }
`

class SubscribeEmail extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      emailText: '',
    }
  }

  render() {
    return (
      <div id="mc_embed_signup">
        <form
          action="https://ideocreativedifference.us11.list-manage.com/subscribe/post"
          method="POST"
          id="mc-embedded-subscribe-form"
          name="mc-embedded-subscribe-form"
          target="_blank"
          noValidate
        >
              <input type="hidden" name="u" value="2f039cb306f0565682c88c494" />
              <input type="hidden" name="id" value="b141f584d3" />
              <SubscribeInput
                id="mce-EMAIL"
                name="EMAIL"
                type="email"
                placeholder="Email"
                value={this.state.emailText}
                onChange={(e) => { this.setState({ emailText: e.target.value }) }}
                autoCapitalize="off"
                autoCorrect="off"
              />
              <SubscribeButton
                id="mc-embedded-subscribe"
                type="submit"
              >
                Subscribe
              </SubscribeButton>
            <div style={{ position: 'absolute', left: '-5000px' }} aria-hidden="true" aria-label="Please leave the following three fields empty">
              <label htmlFor="b_name">
                Name:
                <input type="text" name="b_name" tabIndex="-1" value="" placeholder="Freddie" id="b_name" />
              </label>

              <label htmlFor="b_email">
                Email:
                <input type="email" name="b_email" tabIndex="-1" value="" placeholder="youremail@gmail.com" id="b_email" />
              </label>

              <label htmlFor="b_comment">
                Comment:
                <textarea name="b_comment" tabIndex="-1" placeholder="Please comment" id="b_comment" />
              </label>
            </div>
        </form>
      </div>
    )
  }
}

export default SubscribeEmail
