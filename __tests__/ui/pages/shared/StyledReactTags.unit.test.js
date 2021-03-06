import { tagColor } from '~/ui/pages/shared/StyledReactTags'
import v from '~/utils/variables'

describe('tagColor', () => {
  it('returns default color if none given', () => {
    expect(tagColor('Cats')).toEqual(v.colors.commonMediumTint)
    expect(tagColor()).toEqual(v.colors.commonMediumTint)
  })

  it('returns color if default given', () => {
    expect(tagColor('Cats', 'white')).toEqual('white')
  })

  it('returns color if it matches a Creative Quality or subquality', () => {
    expect(tagColor('purpose', 'white')).toEqual('#9874AB')
    expect(tagColor('Purpose', 'white')).toEqual('#9874AB')
    expect(tagColor('Process Clarity', 'white')).toEqual('#83CCB1')
    expect(tagColor('process clarity', 'white')).toEqual('#83CCB1')
  })
})
