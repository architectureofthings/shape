# ruby version of CollectionGridCalculator.js
module CollectionGrid
  class Calculator
    def self.group_by_consecutive(array, value)
      groups = []
      buffer = []
      array.count.times do |i|
        cur_item = array[i]
        if cur_item == value
          buffer.push(i)
        elsif buffer.count.positive?
          groups.push(buffer)
          buffer = []
        end
      end
      groups.push(buffer) if buffer.count.positive?
      groups
    end

    def self.top_left_card(cards)
      cards = cards.reject { |card| card.row.nil? || card.col.nil? }
      min_row, min_col = cards.pluck(:row, :col).min
      cards.find { |c| c.row == min_row && c.col == min_col }
    end

    # this will add row/col value to any set of cards, as if they were a 4-col layout
    def self.calculate_rows_cols(cards, num_columns: 4, prefilled: 0)
      row = 0
      matrix = []
      cols = num_columns
      # // create an empty row
      matrix.push(Array.new(cols))
      if prefilled.positive?
        matrix[0].fill('filled', 0, prefilled)
      end

      cards.each do |card|
        # object_id for unpersisted cards
        card_id = card.id || card.object_id
        filled = false
        until filled
          width = card.width
          height = card.height

          # // go through the row and see if there is an empty gap that fits cardWidth
          gaps = group_by_consecutive(matrix[row], nil)
          max_gap = gaps.find { |g| g.count >= width }
          max_gap_length = max_gap ? max_gap.count : 0

          if max_gap && max_gap_length
            filled = true

            col = max_gap.first
            card.col = col
            card.row = row
            # // fill rows and columns
            matrix[row].fill(card_id, col, width)

            (height - 1).times do |h|
              row_idx = row + h + 1
              matrix.push(Array.new(cols)) if matrix[row_idx].blank?
              matrix[row_idx].fill(card_id, col, width)
            end

            if matrix[row].last == card_id
              row += 1
              matrix.push(Array.new(cols)) if matrix[row].blank?
            end
          else
            row += 1
            matrix.push(Array.new(cols)) if matrix[row].blank?
          end
        end
      end
      cards
    end

    def self.card_max_row(card)
      return 0 if card.row.blank? || card.height.blank?

      card.row + card.height - 1
    end

    def self.card_max_col(card)
      return 0 if card.col.blank? || card.width.blank?

      card.col + card.width - 1
    end

    def self.board_matrix(
      collection:,
      drag_positions: {},
      moving_cards: [],
      for_section: false,
      debug: false
    )
      return [] if collection.collection_cards.none? && drag_positions.empty?

      moving_section_card = for_section || moving_cards.all?(&:section?)

      # omit moving cards from our matrix
      cards = collection.collection_cards.visible.where.not(id: moving_cards.pluck(:id)).order(created_at: :desc)
      if drag_positions.present?
        cards += drag_positions.values
      end

      # reject erroneous cards
      cards = cards.reject { |card| card.row.nil? || card.col.nil? }
      max_row = cards.map { |card| card_max_row(card) }.max || 0
      matrix = Array.new(max_row + 1) { Array.new(collection.num_columns) }

      cards.each do |card|
        rows = (card.row..card_max_row(card))
        cols = (card.col..card_max_col(card))

        if moving_section_card && card.section?
          rows = (card.row + 1..card_max_row(card) - 1)
          cols = (card.col + 1..card_max_col(card) - 1)
        end

        rows.each_with_index do |row, r_idx|
          cols.each_with_index do |col, c_idx|
            if !moving_section_card && card.section?
              mid_row = r_idx.positive? && r_idx < rows.count - 1
              mid_col = c_idx.positive? && c_idx < cols.count - 1
              if r_idx.zero? || r_idx == rows.count - 1 || (mid_row && !mid_col)
                matrix[row][col] = card
              end
            else
              matrix[row][col] = card
            end
          end
        end
      end

      if debug
        pp '-' * 10
        output = matrix.map do |row|
          row.map { |c| c.nil? ? '' : c.id }
        end
        pp output
      end

      matrix
    end

    def self.determine_drag_map(
      master_card:,
      moving_cards:
    )
      drag_map = moving_cards.map do |card|
        row = card.row
        col = card.col
        master_col = master_card.col
        master_row = master_card.row
        Mashie.new(
          card: card,
          col: col - master_col,
          row: row - master_row,
        )
      end
      drag_map
    end

    def self.exact_open_spot?(
      card:,
      collection:
    )
      open_spot_matrix = calculate_open_spot_matrix(
        collection: collection,
        # ignore the card we're trying to place
        moving_cards: [card],
      )
      open_spot = find_closest_open_spot(
        card,
        open_spot_matrix,
      )
      open_spot && open_spot.row == card.row && open_spot.col == card.col
    end

    def self.moving_cards_ordered_row_col(moving_cards)
      # ensure row, col sorting so we find the best fit in order
      moving_cards.sort do |a, b|
        [a.row, a.col] <=> [b.row, b.col]
      end
    end

    def self.place_cards_on_board(
      row: nil,
      col: nil,
      collection:,
      from_collection:,
      moving_cards:
    )
      return false unless collection.num_columns.present?

      master_card = nil
      moving_cards_without_position = moving_cards.any? { |cc| cc.row.nil? || cc.col.nil? }
      if !from_collection.board_collection? || moving_cards_without_position
        # important to do this first to assign row/col onto the cards
        moving_cards = calculate_rows_cols(moving_cards)
      else
        master_card = top_left_card(moving_cards)
      end

      moving_cards = moving_cards_ordered_row_col(moving_cards)
      # e.g. for non-board collection we use the first based on the above sorting
      master_card ||= moving_cards.first
      if row.nil? || col.nil?
        placement = calculate_best_placement(
          collection: collection,
          moving_cards: moving_cards,
          master_card: master_card,
        )
        # alter the master_position based on calculation
        row = placement.row
        col = placement.col

        unless placement.fit_entire_width
          # re-flow all the cards into a uniform sequential grid
          # and do this before determine_drag_map
          calculate_rows_cols(moving_cards, num_columns: collection.num_columns, prefilled: col)
        end
      end

      drag_map = determine_drag_map(
        master_card: master_card,
        moving_cards: moving_cards,
      )
      master_position = Mashie.new(
        row: row,
        col: col,
      )

      # NOTE: we pull the inner-section cards out and move those separately
      card_ids_in_sections = moving_cards.map do |card|
        next unless card.section?

        card.cards_in_section(moving_cards: moving_cards).map { |cc| cc.id || cc.object_id }
      end.compact.flatten

      drag_positions = {}
      drag_map.each_with_index do |mapped, i|
        card = mapped.card
        # object_id for unpersisted cards
        card_id = card.id || card.object_id
        # these get moved with their section (see section_cards loop down below)
        next if card_ids_in_sections.include?(card_id)

        position = Mashie.new(
          # id is mostly just helpful for debugging output
          id: "drag-#{i}",
          # ensure row/col are > 0
          row: [mapped.row + master_position.row, 0].max,
          col: [mapped.col + master_position.col, 0].max,
          width: card.width,
          height: card.height,
        )

        open_spot_matrix = calculate_open_spot_matrix(
          collection: collection,
          moving_cards: moving_cards,
          drag_positions: drag_positions,
          for_section: card.section?,
        )

        open_spot = find_closest_open_spot(
          position,
          open_spot_matrix,
          num_columns: collection.num_columns,
        )
        # not really sure how it couldn't find a spot since it should always find an empty row at the bottom...
        next unless open_spot.present?

        position.row = open_spot.row
        position.col = open_spot.col

        # drag_positions tracks what we have "placed" so far
        drag_positions[card_id] = position

        row_diff = position.row - card.row
        col_diff = position.col - card.col
        if card.section?
          # now we deal with these since they weren't technically part of moving_cards
          card.cards_in_section(moving_cards: moving_cards).each do |section_card|
            section_card.parent = collection
            section_card.row += row_diff
            section_card.col += col_diff
          end
        end
        # now actually move the card (to be persisted in wrapping services)
        # have to do this *after* checking section logic
        card.row = position.row
        card.col = position.col
        card.parent = collection
      end

      moving_cards
    end

    # This method takes whatever cards you're moving, and tries to place
    # them at the end of the target board.
    # If the width of the moving cards can fit on the board, then find the
    # first open spot (after the last card) that can fit them.
    def self.calculate_best_placement(collection:, moving_cards:, master_card:)
      placement = Mashie.new(
        fit_entire_width: false,
      )

      col_widths = moving_cards.pluck(:col, :width)
      min_col = col_widths.min[0]
      max_col = col_widths.max[0] + col_widths.max[1]
      # get the width span of the cards we're moving
      span = max_col - min_col

      # reject erroneous cards
      last_card = collection
                  .collection_cards
                  .ordered
                  .visible
                  .reject { |card| card.row.nil? || card.col.nil? }
                  .last

      unless last_card&.col.present?
        # placeholder so that calculations can still continue
        last_card = Mashie.new(row: 0, col: 0, width: 0)
      end

      last_row_open_width = collection.num_columns - (last_card.col + last_card.width)

      if last_card.col < 6 && last_row_open_width >= span || (last_row_open_width.positive? && span > collection.num_columns)
        placement.row = last_card.row
        placement.col = last_card.col + last_card.width
      else
        placement.row = last_card.row + 1
        placement.col = 0
        last_row_open_width = collection.num_columns
        if last_row_open_width >= span
          placement.col = master_card.col - min_col
        end
      end

      if last_row_open_width >= span
        placement.fit_entire_width = true
      end
      placement
    end

    def self.find_closest_open_spot(position, open_spot_matrix, num_columns: 16)
      row = position.row
      col = position.col
      width = position.width
      height = position.height

      possibilities = []
      exact_fit = false

      if open_spot_matrix[row].blank?
        # if this entire row is empty we know it fits
        return Mashie.new(
          row: row,
          col: col,
        )
      end

      open_spot_matrix.each_with_index do |row_vals, row_idx|
        # only find a valid open spot if it's within 20 rows of where we're looking
        # (the 20 is just an arbitrary amount)
        next unless row_idx >= row && row_idx <= row + 20

        row_vals.each_with_index do |open_spots, col_idx|
          can_fit = false
          if open_spots >= width
            if height > 1
              (height - 1).times do |i|
                next_row = open_spot_matrix[row_idx + i + 1]
                # if next row is blank then that row doesn't exist yet (empty)
                if next_row.blank?
                  can_fit = true
                elsif next_row[col_idx] && next_row[col_idx] >= width
                  can_fit = true
                end
              end
            else
              can_fit = true
            end
          end

          if can_fit
            row_diff = row_idx - row
            col_diff = col_idx - col
            if col_diff.negative?
              col_diff *= 1.01
            else
              col_diff *= 0.99
            end
            distance = Math.sqrt(row_diff * row_diff + col_diff * col_diff)

            if row_diff.positive?
              # reflow treats everything flowing "off to the right" so closest means "next in snake order"
              distance = ((row_idx * num_columns + col_idx) - (row * num_columns + col)).abs
            end

            exact_fit = distance.zero?
            possibilities.push(
              Mashie.new(
                row: row_idx,
                col: col_idx,
                distance: distance,
              ),
            )
          end
          if exact_fit || possibilities.size > 32
            break
          end
        end
        if exact_fit || possibilities.size > 32
          break
        end
      end
      possibilities = possibilities.sort_by { |p| p[:distance] }
      closest = possibilities.first
      closest || false
    end

    def self.calculate_open_spot_matrix(
      collection:,
      moving_cards: [],
      drag_positions: {},
      for_section: false
    )
      card_matrix = board_matrix(
        collection: collection,
        drag_positions: drag_positions,
        moving_cards: moving_cards,
        for_section: for_section,
      )
      open_spot_matrix = [[]]

      # always add some empty rows
      4.times do
        card_matrix.push(Array.new(collection.num_columns))
      end
      card_matrix.each_with_index do |row, row_idx|
        open = 0
        open_spot_matrix[row_idx] = Array.new(collection.num_columns)
        reversed = row.reverse

        reversed.each_with_index do |card, col_idx|
          if card.present?
            open = 0
          else
            open += 1
          end
          open_spot_matrix[row_idx][collection.max_col_limit - col_idx] = open
        end
      end
      open_spot_matrix
    end

    def self.columns_sticking_out_of(card, above_card)
      return [] if above_card.nil?

      max_card_col = card.col + card.width - 1
      card_inhabited_cols = *(card.col..max_card_col)

      max_above_card_col = above_card.col + above_card.width - 1
      above_card_inhabited_cols = *(above_card.col..max_above_card_col)

      card_inhabited_cols - above_card_inhabited_cols
    end

    def self.find_uninterrupted_cards_in_col(start_row, current_col, card_matrix)
      uninterrupted_cards = []
      current_row = start_row
      while card_matrix.size - 1 >= current_row
        spot = card_matrix[current_row][current_col]
        # if there is a card at the spot it should be one of the cards
        if spot.present?
          uninterrupted_cards << spot
          # Check for wide cards sticking off to the right or left
          if spot.width > 1
            card_above = card_matrix[current_row - 1][current_col]
            add_columns = columns_sticking_out_of(spot, card_above)
            if add_columns.size.positive?
              add_columns.each do |added_column|
                uninterrupted_cards += find_uninterrupted_cards_in_col(
                  current_row + 1,
                  added_column,
                  card_matrix,
                )
              end
            end
          end
        else
          # This is a blank row break out of while loop
          break
        end
        current_row += 1
      end
      uninterrupted_cards
    end

    def self.uninterrupted_cards_below(
      selected_card:,
      collection:
    )
      card_matrix = board_matrix(
        collection: collection,
      )

      min_col = selected_card.col
      max_col = selected_card.col + selected_card.width - 1
      selected_card_cols = *(min_col..max_col)

      uninterrupted_cards = [selected_card]

      start_row = selected_card.row + 1
      selected_card_cols.each do |current_col|
        uninterrupted_cards += find_uninterrupted_cards_in_col(
          start_row,
          current_col,
          card_matrix,
        )
      end

      uninterrupted_cards.flatten.uniq
    end

    def self.overlapping_cards(collection:)
      card_matrix = board_matrix(
        collection: collection,
      )

      return if card_matrix.empty?

      total_rows = card_matrix.length - 1
      total_cols = card_matrix[0].length - 1

      overlapping_cards = []

      # capture overlapping cards by adjacency (cards placed within the card row)
      (0..total_rows).each do |grid_row|
        (0..total_cols - 1).each do |grid_col|
          # for each row, compare adjacent cards
          card = card_matrix[grid_row][grid_col]
          next_card = card_matrix[grid_row][grid_col + 1]

          next unless card.present? && next_card.present? && card.id != next_card.id

          # if the current card's length exceed's the next card's col, it's overlapping
          if (card_max_col(card) + 1) > next_card.col
            # select more recently created card
            if card.created_at > next_card.created_at
              overlapping_cards.push(card)
            else
              overlapping_cards.push(next_card)
            end
          end
        end
      end

      # combine with cards that have the same row and col
      overlapping_cards.concat(collection.collection_cards.visible - card_matrix.flatten.compact.uniq)
    end
  end
end
