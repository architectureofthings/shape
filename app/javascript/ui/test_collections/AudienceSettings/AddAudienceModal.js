import PropTypes from 'prop-types'
import styled from 'styled-components'
import { inject, observer, PropTypes as MobxPropTypes } from 'mobx-react'
import { filter, flatten, includes, remove } from 'lodash'
import { Flex } from 'reflexbox'
import { Grid } from '@material-ui/core'

import Audience from '~/stores/jsonApi/Audience'
import Button from '~shared/components/atoms/Button'
import EditPencilIcon from '~/ui/icons/EditPencilIcon'
import HorizontalDivider from '~shared/components/atoms/HorizontalDivider'
import Modal from '~/ui/global/modals/Modal'
import PlusIcon from '~/ui/icons/PlusIcon'
import TrashIcon from '~/ui/icons/TrashIcon'
import v from '~/utils/variables'
import { criteria, criteriaOptions } from './AudienceCriteria'
import {
  Checkbox,
  CheckboxSelectOption,
  FormButton,
  FieldContainer,
  Label,
  Select,
  SelectOption,
  TextButton,
  TextField,
} from '~/ui/global/styled/forms'
import { FloatRight } from '~/ui/global/styled/layout'

const ROOT_MENU = 'root'

const StyledPlusIcon = styled.span`
  height: 15px;
  margin-right: 8px;
  width: 15px;
`

const EditButton = styled.button`
  height: 22px;
  width: 22px;
`
EditButton.displayName = 'EditButton'

const DeleteButton = styled.button`
  height: 22px;
  width: 27px;
`
DeleteButton.displayName = 'DeleteButton'

const SelectedOption = styled.span`
  background: ${v.colors.commonLightest};
  font-family: ${v.fonts.sans};
  margin-bottom: 8px;
  margin-right: 8px;
  padding: 8px 12px;
`
SelectedOption.displayName = 'SelectedOption'

@inject('apiStore')
@observer
class AddAudienceModal extends React.Component {
  state = {
    name: '',
    valid: false,
    selectedCriteria: [],
    openMenus: {},
    selectedCriteriaOptions: [],
  }

  criteriaTriggers = {}

  closeModal = () => {
    this.closeCriteriaMenu()
    this.props.close()
  }

  openMenu = menu => {
    const { openMenus } = this.state
    openMenus[menu] = true

    this.setState({ openMenus })
  }

  updateMenuPosition = (menu, ref) => {
    const criteriaTrigger = this.criteriaTriggers[menu]
    if (!criteriaTrigger || !ref) return

    const triggerPosition = criteriaTrigger.getBoundingClientRect()
    const { top, left, height } = triggerPosition
    const menuTop = top + height

    const baseStyle = 'position: fixed; z-index: 1400;'
    ref.style = `${baseStyle} top: ${menuTop}px; left: ${left}px;`
  }

  closeMenu = menu => {
    const { openMenus } = this.state
    openMenus[menu] = false

    this.setState({ openMenus })
  }

  handleNameChange = ev => {
    this.setState({ name: ev.target.value })
    this.validateForm()
  }

  handleSave = async () => {
    const { apiStore } = this.props
    const { name, selectedCriteriaOptions } = this.state
    const tag_list = selectedCriteriaOptions.join(', ')

    const audience = new Audience({ name, tag_list }, apiStore)
    await audience.API_create()

    this.reset()
  }

  reset = () => {
    this.props.close()
    this.setState({ name: '', valid: false })
  }

  addCriteria = e => {
    const criteria = e.target.value[0]
    if (!criteria) return

    const { selectedCriteria } = this.state
    selectedCriteria.push(criteria)
    this.setState({ selectedCriteria })

    this.closeMenu(ROOT_MENU)
    this.openMenu(criteria)
  }

  removeCriteria(criteria) {
    const { selectedCriteria, selectedCriteriaOptions } = this.state

    remove(selectedCriteria, c => c === criteria)

    const { options } = criteriaOptions[criteria]
    remove(selectedCriteriaOptions, o => includes(options, o))

    this.setState({ selectedCriteria, selectedCriteriaOptions })
  }

  selectCriteraOption = e => {
    const { selectedCriteriaOptions } = this.state

    e.target.value.forEach(value => {
      if (includes(selectedCriteriaOptions, value)) {
        remove(selectedCriteriaOptions, o => o === value)
      } else {
        selectedCriteriaOptions.push(value)
      }
    })

    this.setState({ selectedCriteriaOptions })
  }

  validateForm() {
    const valid = this.state.name.length > 0
    this.setState({ valid })
  }

  prefixCriteriaOption(criteria, option) {
    return `${criteria} ${option}`
  }

  unPrefixCriteriaOption(criteria, prefixedOption) {
    return prefixedOption.replace(`${criteria} `, '')
  }

  renderCriteriaMenu() {
    const { openMenus, selectedCriteria } = this.state

    // Since the menu is displayed in a MUI dialog, it must be
    // rendered after the add audience modal is opened.
    // Otherwise, it is replaced by the add audience modal
    const menuOpen = openMenus[ROOT_MENU]
    if (!menuOpen) return null

    const groups = Object.keys(criteria).map(group => {
      const options = criteria[group].map(option => {
        const { name } = option

        return (
          <SelectOption
            key={name}
            classes={{ root: 'selectOption' }}
            disabled={includes(selectedCriteria, name)}
            value={name}
          >
            {name}
          </SelectOption>
        )
      })

      const groupOption = (
        <SelectOption
          key={group}
          classes={{ root: 'category' }}
          disabled={true}
        >
          {group}
        </SelectOption>
      )

      options.splice(0, 0, groupOption)
      return options
    })

    return (
      <div ref={ref => this.updateMenuPosition(ROOT_MENU, ref)}>
        <Select
          open={menuOpen}
          onOpen={() => this.openMenu(ROOT_MENU)}
          onClose={() => this.closeMenu(ROOT_MENU)}
          onChange={this.addCriteria}
          MenuProps={{ style: { maxHeight: '366px' } }}
          multiple
          value={[]}
          style={{ visibility: 'hidden', width: 0, height: 0 }}
        >
          {flatten(groups)}
        </Select>
      </div>
    )
  }

  renderSelectedCriteria() {
    const { selectedCriteriaOptions } = this.state

    return this.state.selectedCriteria.map(criteria => {
      const { options } = criteriaOptions[criteria]
      const prefixedOptions = options.map(o =>
        this.prefixCriteriaOption(criteria, o)
      )
      const selectedOptions = filter(selectedCriteriaOptions, o =>
        includes(prefixedOptions, o)
      )

      return (
        <FieldContainer key={`menu_${criteria}`}>
          <FloatRight>
            <EditButton onClick={() => this.openMenu(criteria)}>
              <EditPencilIcon />
            </EditButton>
            <DeleteButton onClick={() => this.removeCriteria(criteria)}>
              <TrashIcon />
            </DeleteButton>
          </FloatRight>
          <span ref={ref => (this.criteriaTriggers[criteria] = ref)}>
            <Label>{criteria}</Label>
          </span>
          <Flex wrap>
            {selectedOptions.map(option => (
              <SelectedOption key={`selected_${option}`}>
                {this.unPrefixCriteriaOption(criteria, option)}
              </SelectedOption>
            ))}
          </Flex>
          <HorizontalDivider
            color={v.colors.commonMedium}
            style={{ borderWidth: '0 0 1px 0', marginBlockStart: 0 }}
          />
        </FieldContainer>
      )
    })
  }

  renderSelectedCriteriaMenus() {
    const { selectedCriteria, selectedCriteriaOptions, openMenus } = this.state

    return selectedCriteria.map(criteria => {
      const availableOptions = criteriaOptions[criteria].options

      const options = availableOptions.map(option => {
        const prefixedOption = this.prefixCriteriaOption(criteria, option)

        return (
          <CheckboxSelectOption
            key={prefixedOption}
            classes={{ root: 'selectOption' }}
            value={prefixedOption}
          >
            <Checkbox
              checked={includes(selectedCriteriaOptions, prefixedOption)}
            />
            {option}
          </CheckboxSelectOption>
        )
      })

      const menuOpen = openMenus[criteria]

      return (
        <div key={criteria} ref={ref => this.updateMenuPosition(criteria, ref)}>
          <Select
            open={menuOpen}
            onOpen={() => this.openMenu(criteria)}
            onClose={() => this.closeMenu(criteria)}
            onChange={this.selectCriteraOption}
            MenuProps={{ style: { maxHeight: '366px' } }}
            multiple
            value={[]}
            style={{ visibility: 'hidden', width: 0, height: 0 }}
          >
            {options}
          </Select>
        </div>
      )
    })
  }

  render() {
    const { open, close } = this.props

    return (
      <React.Fragment>
        <Modal title="Create New Audience" onClose={close} open={open} noScroll>
          <FieldContainer>
            <Label htmlFor="audienceName">Audience Name</Label>
            <TextField
              id="audienceName"
              type="text"
              value={this.state.name}
              onChange={this.handleNameChange}
              placeholder={'Enter Audience Name…'}
            />
          </FieldContainer>
          {this.renderSelectedCriteria()}
          <FieldContainer>
            <Label>Targeting Criteria</Label>
            <div ref={ref => (this.criteriaTriggers[ROOT_MENU] = ref)}>
              <Button href="#" onClick={() => this.openMenu(ROOT_MENU)}>
                <StyledPlusIcon>
                  <PlusIcon />
                </StyledPlusIcon>
                Add Audience Criteria
              </Button>
            </div>
            <HorizontalDivider
              color={v.colors.commonMedium}
              style={{ borderWidth: '0 0 1px 0' }}
            />
          </FieldContainer>
          <Grid container alignItems="center" style={{ paddingBottom: '32px' }}>
            <Grid item xs={6}>
              <Grid container justify="center">
                <TextButton onClick={this.reset} width={190}>
                  Cancel
                </TextButton>
              </Grid>
            </Grid>
            <Grid item xs={6}>
              <Grid container justify="center">
                <FormButton
                  onClick={this.handleSave}
                  width={190}
                  type="submit"
                  disabled={!this.state.valid}
                >
                  Save
                </FormButton>
              </Grid>
            </Grid>
          </Grid>
        </Modal>
        {this.renderCriteriaMenu()}
        {this.renderSelectedCriteriaMenus()}
      </React.Fragment>
    )
  }
}

AddAudienceModal.propTypes = {
  open: PropTypes.bool.isRequired,
  close: PropTypes.func.isRequired,
}
AddAudienceModal.wrappedComponent.propTypes = {
  apiStore: MobxPropTypes.objectOrObservableObject.isRequired,
}

export default AddAudienceModal
