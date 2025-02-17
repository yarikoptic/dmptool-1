# frozen_string_literal: true

# Controller for Grant typeahead
class ResearchProjectsController < ApplicationController
  def index
    render json: research_projects
  end

  def search
    @results = research_projects.select { |r| r.description.match(params[:description]) }
    render json: @results
  end

  private

  def research_projects
    return @research_projects if @research_projects.present?

    # Check the cache contents as well since the instance variable is only
    # relevant per request
    cached = Rails.cache.fetch(['research_projects', funder_type])
    return @research_projects = cached if cached.present?

    @research_projects = fetch_projects
  end

  def funder_type
    params.fetch(:type, ExternalApis::OpenAireService.default_funder)
  end

  def fetch_projects
    Rails.cache.fetch(['research_projects', funder_type], expires_in: expiry) do
      ExternalApis::OpenAireService.search(funder: funder_type)
    end
  end

  # Retrieve the Cache expiration seconds
  def expiry
    expiration = Rails.configuration.x.cache.research_projects_expiration
    (expiration.presence || 1.day)
  end
end
