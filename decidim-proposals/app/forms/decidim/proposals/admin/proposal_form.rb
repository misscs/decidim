# frozen_string_literal: true

module Decidim
  module Proposals
    module Admin
      # A form object to be used when admin users want to create a proposal.
      class ProposalForm < Decidim::Form
        include Decidim::ApplicationHelper
        mimic :proposal

        attribute :title, String
        attribute :body, String
        attribute :address, String
        attribute :latitude, Float
        attribute :longitude, Float
        attribute :category_id, Integer
        attribute :scope_id, Integer
        attribute :attachment, AttachmentForm
        attribute :position, Integer
        attribute :created_in_meeting, Boolean
        attribute :meeting_id, Integer

        validates :title, :body, presence: true, etiquette: true
        validates :title, length: { maximum: 150 }
        validates :address, geocoding: true, if: -> { current_component.settings.geocoding_enabled? }
        validates :category, presence: true, if: ->(form) { form.category_id.present? }
        validates :scope, presence: true, if: ->(form) { form.scope_id.present? }
        validates :meeting_as_author, presence: true, if: ->(form) { form.created_in_meeting? }

        validate :scope_belongs_to_participatory_space_scope

        validate :notify_missing_attachment_if_errored

        delegate :categories, to: :current_component

        def map_model(model)
          return unless model.categorization

          self.category_id = model.categorization.decidim_category_id
          self.scope_id = model.decidim_scope_id
        end

        alias component current_component

        # Finds the Category from the category_id.
        #
        # Returns a Decidim::Category
        def category
          @category ||= categories.find_by(id: category_id)
        end

        # Finds the Scope from the given decidim_scope_id, uses participatory space scope if missing.
        #
        # Returns a Decidim::Scope
        def scope
          @scope ||= @scope_id ? current_participatory_space.scopes.find_by(id: @scope_id) : current_participatory_space.scope
        end

        # Scope identifier
        #
        # Returns the scope identifier related to the proposal
        def scope_id
          @scope_id || scope&.id
        end

        # Finds the Meetings of the current participatory space
        def meetings
          @meetings ||= Decidim.find_resource_manifest(:meetings).try(:resource_scope, current_component)
                               &.order(title: :asc)
        end

        # Return the meeting as author
        def meeting_as_author
          @meeting_as_author ||= meetings.find_by(id: meeting_id)
        end

        def author
          return current_organization unless created_in_meeting?
          meeting_as_author
        end

        private

        def scope_belongs_to_participatory_space_scope
          errors.add(:scope_id, :invalid) if current_participatory_space.out_of_scope?(scope)
        end

        # This method will add an error to the `attachment` field only if there's
        # any error in any other field. This is needed because when the form has
        # an error, the attachment is lost, so we need a way to inform the user of
        # this problem.
        def notify_missing_attachment_if_errored
          errors.add(:attachment, :needs_to_be_reattached) if errors.any? && attachment.present?
        end
      end
    end
  end
end
