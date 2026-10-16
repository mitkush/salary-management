class FrontendController < ApplicationController
  def show
    render file: Rails.configuration.x.frontend_index_path, layout: false
  end
end
