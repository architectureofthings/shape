import PropTypes from 'prop-types'
import Icon from '~/ui/icons/Icon'

const LightbulbIcon = ({ size }) => (
  <Icon fill>
    {size === 'lg' && (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
        <path d="M22.213 5.225c-1.706-1.679-3.952-2.541-6.357-2.544-4.886.078-8.713 3.968-8.713 8.856a8.886 8.886 0 002.802 6.461 6.548 6.548 0 012.084 4.794c0 .884.719 1.603 1.602 1.603h4.739c.883 0 1.602-.719 1.602-1.603 0-1.791.772-3.551 2.121-4.829a8.773 8.773 0 002.766-6.427 8.797 8.797 0 00-2.646-6.311zm-7.599 8.469c-.431-.124-.597-.293-.599-.396-.003-.159.198-.341.285-.344.075 0 .303 0 .313.405v.335zm1.485 9.4h-.185v-7.943c.06-.001.123.002.185 0v7.943zm5.099-6.074c-1.605 1.522-2.527 3.626-2.527 5.772a.302.302 0 01-.301.302h-.97l-.001-8.057c.38-.072.703-.179.968-.319.786-.418.903-1.025.903-1.35 0-.866-.834-1.685-1.717-1.685-.4 0-.748.142-1.007.407-.446.461-.45 1.112-.447 1.219v.541h-.185v-.492c0-.686-.431-1.706-1.614-1.706-.829 0-1.585.782-1.585 1.642 0 .331.117.953.903 1.39.272.151.605.267.995.345v8.065h-.983c-.166 0-.301-.135-.301-.385 0-2.111-.91-4.174-2.496-5.66a7.48 7.48 0 01-2.39-5.512c0-4.171 3.265-7.49 7.434-7.556l.124-.001c1.997 0 3.875.768 5.3 2.17a7.503 7.503 0 012.256 5.386 7.487 7.487 0 01-2.359 5.484zm-3.799-3.314v-.408c0-.1.036-.257.154-.313.168 0 .417.229.417.384 0 .054-.084.133-.214.201a1.78 1.78 0 01-.357.136z" />
        <path d="M11.132 7.576a.647.647 0 00-.897.198 6.807 6.807 0 00-.806 1.789.65.65 0 001.25.357 5.5 5.5 0 01.651-1.446.65.65 0 00-.198-.898zM15.89 4.621a6.813 6.813 0 00-3.772 1.203.65.65 0 10.738 1.07 5.505 5.505 0 013.054-.973.652.652 0 00.641-.66c-.007-.357-.293-.684-.661-.64zM18.653 24.736h-5.488a.65.65 0 100 1.3h5.488a.65.65 0 100-1.3zM18.653 26.377h-5.488a.65.65 0 100 1.3h5.488a.65.65 0 100-1.3zM17.372 28.02h-2.744a.65.65 0 100 1.3h2.744a.65.65 0 100-1.3z" />
      </svg>
    )}
    {size === 'xxl' && (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 360">
        <path d="M240.4 74.5c-16.6-16.3-38.5-25.1-61.8-24.7-22.8.4-44.1 9.5-60 25.7-15.9 16.2-24.7 37.6-24.7 60.4 0 23.7 9.9 46.6 27.2 62.7 13.4 12.5 21 29.8 21 47.6v.8c0 7.9 6.5 14.4 14.4 14.4h15.2c.3.1.6.1 1 .1s.7 0 1-.1h12.8c.3.1.6.1 1 .1s.7 0 1-.1h14.8c7.9 0 14.4-6.5 14.4-14.4 0-18.1 7.8-35.9 21.4-48.7 17.2-16 27-38.7 27-62.4 0-23.2-9.1-45-25.7-61.4zM167.7 159c-2.6-.6-4.4-1.3-5.7-2-2-1.1-3.1-2.4-3.1-3.7 0-2.4 2.7-4.8 4.2-4.8 3.8 0 4.5 3.4 4.5 5.4v5.1zm24.8-5.7c0-1.1.4-3.1 1.2-4 .2-.2.5-.5 1.7-.5 2.4 0 5.5 2.9 5.5 5.2 0 1.4-1.6 2.6-2.9 3.2-1.2.6-3 1.3-5.5 1.9v-5.7-.1zm-10 98.1h-4.8v-81.2h4.8v81.2zm49.8-60.4c-15.6 14.8-24.6 35.2-24.6 56 0 2.4-2 4.4-4.4 4.4h-10.8v-82.1c4.1-.7 7.5-1.8 10.2-3.2 7.1-3.8 8.2-9.2 8.2-12.1 0-7.8-7.5-15.2-15.5-15.2-3.6 0-6.6 1.2-8.9 3.6-3.9 4.1-4 10-4 11.1v6.7h-4.8v-6.3c0-6.2-3.9-15.4-14.5-15.4-7.3 0-14.2 7.2-14.2 14.8 0 3 1.1 8.5 8.2 12.5 2.8 1.6 6.3 2.7 10.5 3.5v82.2h-11.2c-2.4 0-4.4-2-4.4-4.4v-.8c0-20.5-8.8-40.5-24.2-54.8-15.3-14.3-24-34.5-24-55.5 0-20.2 7.7-39.1 21.8-53.4 14.1-14.3 32.9-22.4 53.1-22.7h1.2c20.1 0 39 7.7 53.4 21.9 14.6 14.4 22.7 33.7 22.7 54.2 0 20.8-8.7 40.9-23.8 55z" />
        <path d="M131.2 98c-2.3-1.5-5.4-.8-6.9 1.6-3.5 5.5-6.1 11.3-7.8 17.3-.7 2.7.8 5.4 3.5 6.2.5.1.9.2 1.4.2 2.2 0 4.2-1.4 4.8-3.7 1.4-5 3.6-10 6.6-14.7 1.4-2.4.7-5.4-1.6-6.9zM178.9 69c-13.1.2-25.7 4.2-36.5 11.6-2.3 1.6-2.9 4.7-1.3 7 1 1.4 2.5 2.2 4.1 2.2 1 0 2-.3 2.8-.9 9.1-6.2 19.8-9.6 30.9-9.8 2.8 0 5-2.3 4.9-5.1.2-2.8-2.1-5-4.9-5zM206.2 267.7H152c-2.8 0-5 2.2-5 5s2.2 5 5 5h54.2c2.8 0 5-2.2 5-5s-2.2-5-5-5zM206.2 283.9H152c-2.8 0-5 2.2-5 5s2.2 5 5 5h54.2c2.8 0 5-2.2 5-5s-2.2-5-5-5zM193.6 300.2h-27.2c-2.8 0-5 2.2-5 5s2.2 5 5 5h27.2c2.8 0 5-2.2 5-5s-2.2-5-5-5z" />
      </svg>
    )}
  </Icon>
)

LightbulbIcon.propTypes = {
  size: PropTypes.string,
}

LightbulbIcon.defaultProps = {
  size: 'lg',
}

export default LightbulbIcon