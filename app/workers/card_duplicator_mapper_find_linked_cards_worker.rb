class CardDuplicatorMapperFindLinkedCardsWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'critical'

  def perform(
    batch_id,
    card_ids,
    for_user_id = nil,
    system_collection = false
  )
    for_user = User.find(for_user_id) if for_user_id.present?

    CardDuplicatorMapper::FindLinkedCards.call(
      batch_id: batch_id,
      card_ids: card_ids,
      for_user: for_user,
      system_collection: system_collection,
    )
  end
end
