module DataReport
  class CollectionsAndItems < SimpleService
    delegate :measure, :timeframe, to: :@dataset

    def initialize(dataset:, end_date: nil)
      @dataset = dataset
      @record = dataset.data_source
      @data = []
      @single_value = nil
      @is_single_value = false
      @query = nil
      @group = dataset.group
      @end_date = (end_date || Date.tomorrow).to_s
    end

    def call
      if measure == 'records'
        collections_and_items_report_dataset
      else
        initialize_data
        calculate_timeframe_values
      end
      @data
    end

    def single_value
      @is_single_value = true
      if measure == 'records'
        collections_and_items_report_dataset
      else
        initialize_data
        calculate_single_value
      end
      @single_value
    end

    def actor_ids
      initialize_data
      query_actor_ids
    end

    def sql_query
      sql_table = query_table.table_name
      if @record
        earliest = @record.created_at
      else
        earliest = @query.select("min(#{sql_table}.created_at)").to_a.first.min
      end
      return unless earliest.present?

      min = earliest.clamp(start_date_limit, start_date_minimum)
      case measure
      when 'participants', 'viewers'
        count = 'count(distinct(actor_id))'
      else
        count = 'count(distinct(id))'
      end

      # Doing the BETWEEN upper limit finds all activities created BEFORE the upper limit, for example:
      # i.date of "01-01-2020" will return "between 12-01-2019 and 01-01-2020" aka "all of December 2019"
      columns = %i[id created_at]
      columns.push(:actor_id) if measure_queries_activities?
      beginning_of_timeframe = min.send("beginning_of_#{timeframe}")

      intervals = %{
        SELECT
          DISTINCT LEAST(series.date, '#{@end_date}'::DATE) date
        FROM
          GENERATE_SERIES(
            ('#{beginning_of_timeframe}'::DATE + INTERVAL '1 #{timeframe}'),
            '#{@end_date}'::DATE + INTERVAL '1 #{timeframe}',
            INTERVAL '1 #{timeframe}'
          ) AS series
      }

      %{
        WITH intervals AS (#{intervals})
          SELECT i.date, #{count}
            FROM (#{@query.select(*columns).to_sql}) inner_query
            RIGHT JOIN intervals i
            ON
              created_at BETWEEN
                i.date - INTERVAL '1 #{timeframe}'
                AND
                i.date
            GROUP BY i.date
            ORDER BY i.date
      }
    end

    private

    def single_value?
      @is_single_value
    end

    def organization_id
      @dataset.organization_id || @record&.organization_id
    end

    def initialize_data
      @query = generate_base_query
      return [] unless @query

      filter_query
      filter_query_for_group_actors if @group.present?
    end

    def collections_and_items_report_dataset
      item_data = DataReport::CollectionsAndItems.new(dataset:
        Dataset.new(
          data_source: @record,
          measure: 'items',
          timeframe: timeframe,
          organization_id: organization_id,
        ), end_date: @end_date)

      collection_data = DataReport::CollectionsAndItems.new(dataset:
        Dataset.new(
          data_source: @record,
          measure: 'collections',
          timeframe: timeframe,
          organization_id: organization_id,
        ), end_date: @end_date)

      if single_value?
        # Combine the two reports
        # Call .to_i on single_value because it may be nil (only present if timeframe is `ever`)
        @single_value = item_data.single_value.to_i + collection_data.single_value.to_i
      else
        concatenated = (item_data.call + collection_data.call)
        all_values = concatenated.group_by { |x| x[:date] }
        @data = all_values.map do |date, values|
          {
            date: date,
            value: values.map { |x| x[:value] }.sum,
          }
        end
      end
    end

    def generate_base_query
      case measure
      when 'participants'
        Activity.in_org(organization_id).where_participated
      when 'viewers', 'views'
        Activity.in_org(organization_id).where_viewed
      when 'activity'
        Activity.in_org(organization_id).where_active
      when 'content'
        Activity.in_org(organization_id).where_content
      when 'collections'
        Collection.data_collectable.active
      when 'items'
        Item.active
      end
    end

    def filter_query
      if @record.is_a?(Collection)
        collection_opts = { collection_id: @record.id }
        if measure == 'views'
          @query = @query.where(target: @record)
          return
        end

        if measure_queries_activities?
          collections = @query
                        .joins(%(join collections on
                       activities.target_id = collections.id and
                       activities.target_type = 'Collection'))
                        .where(%(collections.breadcrumb @> ':collection_id' or
                      collections.id = :collection_id),
                               collection_opts)

          items = @query
                  .joins(%(join items on
                       activities.target_id = items.id and
                       activities.target_type = 'Item'))
                  .where(%(items.breadcrumb @> ':collection_id'), collection_opts)
          @query = Activity.from(
            "(#{collections.to_sql} UNION #{items.to_sql}) AS activities",
          )
        elsif measure == 'collections'
          @query = @query.where(%(breadcrumb @> ':collection_id' or
                         id = :collection_id),
                                collection_opts)
        elsif measure == 'items'
          @query = @query.where(%(breadcrumb @> ':collection_id'),
                                collection_opts)
        end

        return @query
      end

      # if not querying activities; by default, within entire org
      if measure == 'items'
        @query = @query.joins(parent_collection_card: :parent)
                       .where('collections.organization_id = ?', organization_id)
      else
        @query = @query.where(organization_id: organization_id)
      end
    end

    def filter_query_for_group_actors
      # limit actor_id to users in the selected group
      @query = @query.join_actors_in_group(@group)
    end

    def measure_queries_activities?
      !%w[collections items records].include?(measure)
    end

    def query_table
      return Activity if measure_queries_activities?

      case measure
      when 'collections'
        Collection
      when 'items'
        Item
      else
        return
      end
    end

    def start_date_limit
      @dataset.start_date_limit || 12.months.ago
    end

    def start_date_minimum
      # the graph looks odd with only one or two data points so we ensure a minimum
      2.send(timeframe).ago
    end

    def calculate_timeframe_values
      timeframe_cache_key = "#{cache_key_base}::Time-#{timeframe}"
      query = sql_query
      return unless query.present?

      values = Rails.cache.fetch timeframe_cache_key do
        query_table.connection.execute(query)
                   .map { |val| { date: val['date'], value: val['count'] } }
      end
      @data = values
    end

    def query_actor_ids
      @query
        .select(:actor_id)
        .distinct
        .pluck(:actor_id)
    end

    def calculate_single_value
      case measure
      when 'participants', 'viewers'
        value = @query
                .select(:actor_id)
                .distinct
      when 'activity', 'content', 'collections', 'items', 'views'
        value = @query
      else
        return
      end

      @single_value = Rails.cache.fetch "#{cache_key_base}::SingleValue" do
        value.count
      end
    end

    def cache_key_base
      if @record
        identifier = "#{@record.class.base_class.name}/#{@record.id}"
      else
        identifier = "Org/#{organization_id}"
      end
      key = "Dataset::#{identifier}::#{measure}"
      if @group.present?
        key = "#{key}::Group/#{@group.id}"
      end
      "#{key}::#{Date.today}"
    end
  end
end
