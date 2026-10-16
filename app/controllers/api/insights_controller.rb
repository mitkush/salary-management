module Api
  class InsightsController < BaseController
    def show
      group_by = params[:group_by].presence
      if group_by && !SalaryStatsQuery::GROUP_COLUMNS.key?(group_by)
        return render_error :bad_request, "group_by must be country or department.", status: :bad_request
      end

      query = SalaryStatsQuery.new(**params.permit(:country_id, :department, :job_title, :group_by).to_h.symbolize_keys)
      render json: { summary: query.summary, groups: group_by ? query.groups : [] }
    end
  end
end
