ActsAsTaggableOn.remove_unused_tags = false
ActsAsTaggableOn.strict_case_match = false
ActsAsTaggableOn.force_lowercase = false
# ActsAsTaggableOn.force_parameterize = true

# Adds an after_save callback for the Tagging class to add our custom
# `organization_id` to the Tag
module CustomTaggingMethods
  extend ActiveSupport::Concern

  included do
    after_save do
      if taggable.respond_to?(:organization_id)
        organization_id = taggable.organization_id

        unless tag.organization_ids.include?(organization_id)
          tag.organization_ids << organization_id
          tag.save
        end
      end
    end
  end
end

# Adds support for application relationship on tag
module CustomTagMethods
  extend ActiveSupport::Concern

  included do
    belongs_to :application, optional: true
  end
end

ActsAsTaggableOn::Tagging.send(:include, CustomTaggingMethods)
ActsAsTaggableOn::Tag.send(:include, CustomTagMethods)
