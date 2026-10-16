module Api
  class InsightsController < BaseController
    include MonthParam

    class FutureMonth < StandardError; end

    rescue_from FutureMonth do
      render_error :bad_request, "as_of can't be in the future.", status: :bad_request
    end
    def show
      group_by = params[:group_by].presence
      if group_by && !SalaryStatsQuery::GROUP_COLUMNS.key?(group_by)
        return render_error :bad_request, "group_by must be country or department.", status: :bad_request
      end

      as_of = as_of_date
      query = SalaryStatsQuery.new(**filters, group_by: group_by, as_of: as_of)
      render json: { as_of: as_of, summary: query.summary, groups: group_by ? query.groups : [] }
    end

    def trends
      render json: { as_of: as_of_date, months: SalaryTrendsQuery.new(**filters, as_of_month: as_of_month).months }
    end

    private
      def filters
        params.permit(:country_id, :department, :job_title).to_h.symbolize_keys
      end

      def as_of_month
        month = params[:as_of].present? ? month_param(params[:as_of]) : Date.current.prev_month.beginning_of_month
        raise FutureMonth if month > Date.current.beginning_of_month

        month
      end

      def as_of_date
        [ as_of_month.end_of_month, Date.current ].min
      end
  end
end
