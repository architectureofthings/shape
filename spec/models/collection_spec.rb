require 'rails_helper'

describe Collection, type: :model do
  context 'validations' do
    it { should validate_presence_of(:name) }
  end
  context 'associations' do
    it { should belong_to :cloned_from }
    it { should belong_to :organization }
  end
end
