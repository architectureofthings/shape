class Item
  class DataItem < Item
    store_accessor :data_settings,
                   :d_measure,
                   :d_filters,
                   :d_timeframe

    validates :report_type, presence: true
    validate :collections_and_items_validations, if: :report_type_collections_and_items?
    validate :network_app_metric_validations, if: :report_type_network_app_metric?
    validate :record_validations, if: :report_type_record?

    VALID_MEASURES = %w[
      participants
      viewers
      activity
      content
      collections
      items
      records
    ].freeze
    VALID_TIMEFRAMES = %w[
      ever
      month
      week
    ].freeze

    enum report_type: {
      report_type_collections_and_items: 0,
      report_type_network_app_metric: 1,
      report_type_record: 2,
    }

    def datasets
      if report_type_record?
        return [] if data_content['datasets'].blank?
        data_content['datasets'].map(&:deep_symbolize_keys)
      elsif report_type_network_app_metric?
        DataReport::NetworkAppMetric.new(self).call
      elsif report_type_collections_and_items?
        DataReport::CollectionsAndItems.new(self).call
      end
    end

    private

    def record_validations
      return if data_content.present?
      errors.add(:data_content, 'must be present')
    end

    def network_app_metric_validations
      return if url.present?
      errors.add(:url, 'must be present')
    end

    def collections_and_items_validations
      if !VALID_MEASURES.include?(d_measure.to_s)
        errors.add(:data_settings, "measure must be one of #{VALID_MEASURES.join(', ')}")
      end
      return if VALID_TIMEFRAMES.include?(d_timeframe.to_s)
      errors.add(:data_settings, "timeframe must be one of #{VALID_TIMEFRAMES.join(', ')}")
    end
  end
end
