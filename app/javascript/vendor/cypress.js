import { apiStore, uiStore, undoStore } from '~/stores'
import captureGlobalKeypress from '~/utils/captureGlobalKeypress'

const cypress = navigator && navigator.userAgent === 'cypress'
if (cypress) {
  // expose on the window so that cypress has access
  window.apiStore = apiStore
  window.uiStore = uiStore
  window.undoStore = undoStore
  window.captureGlobalKeypress = captureGlobalKeypress
}
