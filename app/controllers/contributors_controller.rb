# frozen_string_literal: true

# Controller for the Contributors page
class ContributorsController < ApplicationController
  include OrgSelectable
  helper PaginableHelper

  before_action :fetch_plan
  before_action :ensure_org_param, only: %i[create update]
  before_action :fetch_contributor, only: %i[edit update destroy]
  after_action :verify_authorized

  # GET /plans/:plan_id/contributors
  def index
    authorize @plan
    @contributors = @plan.contributors
  end

  # GET /plans/:plan_id/contributors/new
  def new
    authorize @plan
    default_org = (@plan.org.presence || current_user.org)
    @contributor = Contributor.new(plan: @plan, org: default_org)
  end

  # GET /plans/:plan_id/contributors/:id/edit
  def edit
    authorize @plan
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  # POST /plans/:plan_id/contributors
  def create
    authorize @plan, :edit?

    args = translate_roles(hash: contributor_params)
    if args.blank?
      @contributor = Contributor.new(args)
      @contributor.errors.add(:affiliation, 'invalid')
      flash.now[:alert] = failure_message(@contributor, _('add'))
      render :new
    else
      args = process_orcid_for_create(hash: args)
      args[:plan_id] = @plan.id

      @contributor = Contributor.new(args)
      stash_orcid

      if @contributor.save
        # Now that the model has been ssaved, go ahead and save the identifiers
        save_orcid

        redirect_to plan_contributors_path(@plan),
                    notice: success_message(@contributor, _('added'))
      else
        flash.now[:alert] = failure_message(@contributor, _('add'))
        render :new
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # PUT /plans/:plan_id/contributors/:id
  def update
    authorize @plan
    args = translate_roles(hash: contributor_params)
    args = process_orcid_for_update(hash: args)

    if @contributor.update(args)
      redirect_to edit_plan_contributor_path(@plan, @contributor),
                  notice: success_message(@contributor, _('saved'))
    else
      flash.now[:alert] = failure_message(@contributor, _('save'))
      render :edit
    end
  end

  # DELETE /plans/:plan_id/contributors/:id
  def destroy
    authorize @plan
    if @contributor.destroy
      msg = success_message(@contributor, _('removed'))
      redirect_to plan_contributors_path(@plan), notice: msg
    else
      flash.now[:alert] = failure_message(@contributor, _('remove'))
      render :edit
    end
  end

  private

  def contributor_params
    base_params = %i[name email phone org_id org_name org_crosswalk]
    role_params = Contributor.new.all_roles

    params.require(:contributor).permit(
      base_params,
      role_params,
      identifiers_attributes: %i[id identifier_scheme_id value attrs],
      org_attributes: %i[abbreviation contact_email contact_name is_other
                         managed name org_type target_url links]
    )
  end

  # Translate the check boxes values of "1" and "0" to true/false
  def translate_roles(hash:)
    roles = Contributor.new.all_roles
    roles.each { |role| hash[role.to_sym] = hash[role.to_sym] == '1' }
    hash
  end

  # Convert the results of the Org Autocomplete into an Org or Org.id
  def ensure_org_param
    # Convert the selected/specified Org name into attributes
    op = autocomplete_to_controller_params
    params[:contributor][:org_id] = op[:org_id] if op[:org_id].present?
    params[:contributor][:org_attributes] = op[:org_attributes] if op[:org_id].blank?
  end

  # When creating, just remove the ORCID if it was left blank
  def process_orcid_for_create(hash:)
    return hash if hash[:identifiers_attributes].blank?

    id_hash = hash[:identifiers_attributes][:'0']
    return hash if id_hash[:value].present?

    hash.delete(:identifiers_attributes)
    hash
  end

  # When updating, destroy the ORCID if it was blanked out on form
  def process_orcid_for_update(hash:)
    return hash if hash[:identifiers_attributes].blank?

    id_hash = hash[:identifiers_attributes][:'0']
    return hash if id_hash[:value].present?

    existing = @contributor.identifier_for_scheme(scheme: 'orcid')
    existing.destroy if existing.present?
    hash.delete(:identifiers_attributes)
    hash
  end

  # =============
  # = Callbacks =
  # =============
  def fetch_plan
    @plan = Plan.find_by(id: params[:plan_id])
    return true if @plan.present?

    redirect_to root_path, alert: _('plan not found')
  end

  def fetch_contributor
    @contributor = Contributor.find_by(id: params[:id])
    return true if @contributor.present? &&
                   @plan.contributors.include?(@contributor)

    redirect_to plan_contributors_path, alert: _('contributor not found')
  end

  # The following 2 methods address an issue with using Rails normal
  # accepts_nested_attributes_for on polymorphic relationships.
  #
  # Currently, when creating the underlying model, the `.valid?` method is
  # called prior to the `save`. This causes all `identifiers` to report that
  # the `identifiable_id` is nil. Because Rails forces the `belong_to` relation
  # to be present.
  #
  # To get around it we stash the identifiers during the creation step
  # and then save them after the model has been created
  #
  # Supposedly this is fixed in Rails 5+ by designating `optional: true`
  # on the `belong_to` side of the relationship
  def stash_orcid
    return false unless @contributor.identifiers.any?

    @cached_orcid = @contributor.identifiers.first
    @contributor.identifiers = []
  end

  def save_orcid
    return true if @cached_orcid.blank?

    @cached_orcid.identifiable = @contributor
    @cached_orcid.save
    @contributor.reload
  end
end
