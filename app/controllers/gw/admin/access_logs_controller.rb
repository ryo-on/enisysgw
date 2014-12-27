# encoding: utf-8
class Gw::Admin::AccessLogsController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold
  include Gwboard::Model::DbnameAlias
  include Gwmonitor::Model::Database
  layout "admin/template/admin"

  require 'csv'

  def initialize_scaffold

  end

  def role_gwcircular(title_id = '_menu')

    @is_sysadm = true if Gw.is_other_admin?('gwcircular')
    @is_bbsadm = true if @is_sysadm

    unless @is_bbsadm
      item = Gwcircular::Adm.new
      item.and :user_id, 0
      item.and :group_code, Site.user_group.code
      item.and :title_id, title_id unless title_id == '_menu'
      items = item.find(:all)
      @is_bbsadm = true unless items.blank?

      unless @is_bbsadm
        item = Gwcircular::Adm.new
        item.and :user_code, Site.user.code
        item.and :group_code, Site.user_group.code
        item.and :title_id, title_id unless title_id == '_menu'
        items = item.find(:all)
        @is_bbsadm = true unless items.blank?
      end
    end

    @is_admin = true if @is_sysadm
    @is_admin = true if @is_bbsadm
  end

  def init_params
    Page.title = "アクセス解析"

    params[:limit] = nz(params[:limit],30)

    @admin_role = Gw.is_admin_admin?

    @editor_role  = Gw.is_editor?

    @role_tabs  = Gw.is_other_editor?('edit_tab')

    @role_users = Gw.is_other_editor?('system_users')


    @is_readable = nil
    params[:system]='gwbbs'
    admin_flags
    @role_bbs    =    @is_readable

    @is_readable = nil
    params[:system]='doclibrary'
    admin_flags
    @role_doclibrary    = @is_readable

    @is_sysadm = nil
    @is_bbsadm = nil
    role_gwcircular('_menu')
    @role_gwcircular_sysadmin       = @is_sysadm
    @role_gwcircular_bbsadmin       = @is_bbsadm
    @role_gwcircular  = @role_gwcircular_sysadmin || @role_gwcircular_bbsadmin

    @is_sysadm = nil
    system_admin_flags
    @role_gwmonitor       = @is_sysadm

    @is_gw_config_settings_roles  = Gw.is_admin_or_editor?
    @u_role = @is_gw_config_settings_roles


    @portal_editor = @role_tabs

    @role_board = @role_bbs  ||  @role_doclibrary  ||  @role_gwcircular  ||  @role_gwmonitor
    @role_board2 = @role_bbs ||  @role_doclibrary

    @base_editor   = @role_users

    if @admin_role==true
      params[:c1]  = nz(params[:c1],1)
      params[:c2]  = nz(params[:c2],1)
    else
      if @u_role==true
        params[:c1]  = nz(params[:c1],1)
        if @portal_editor == true
          params[:c2]  = nz(params[:c2],1)
        elsif @role_board2 == true
          params[:c2]  = nz(params[:c2],6)
        elsif @base_editor == true
          params[:c2]  = nz(params[:c2],5)
        else
          params[:c2]  = nz(params[:c2],1)
        end
      end
    end
    @css = %w(/layout/admin/style.css)

    return http_error(403) unless @admin_role
  end

  def index
    init_params
    
    now = DateTime.now
    if params[:item].blank?
      start_min = (now.min / 5) * 5
      @start_date = DateTime.new(now.year, now.month, now.day, now.hour, start_min)
      @end_date = @start_date + 5.minutes
      @s_date = @start_date.strftime("%Y-%m-%-d %-H:%-M")
      @e_date = @end_date.strftime("%Y-%m-%-d %-H:%-M")
    else
      #絞込開始日時
      s_year = params[:item]['st_at(1i)'].to_i
      s_month = params[:item]['st_at(2i)'].to_i
      s_day = params[:item]['st_at(3i)'].to_i
      s_hour = params[:item]['st_at(4i)'].to_i
      s_min = params[:item]['st_at(5i)'].to_i

      #絞込終了日時
      e_year = params[:item]['ed_at(1i)'].to_i
      e_month = params[:item]['ed_at(2i)'].to_i
      e_day = params[:item]['ed_at(3i)'].to_i
      e_hour = params[:item]['ed_at(4i)'].to_i
      e_min = params[:item]['ed_at(5i)'].to_i

      @case = '0'
      if params[:item]['st_at(4i)'] =~ /^[0-9]+$/
        @case += '1'
      end
      if params[:item]['st_at(5i)'] =~ /^[0-9]+$/
        @case += '2'
      end
      if params[:item]['ed_at(4i)'] =~ /^[0-9]+$/
        @case += '3'
      end
      if params[:item]['ed_at(5i)'] =~ /^[0-9]+$/
        @case += '4'
      end

      #絞込日に文字が入っている場合の考慮
      if s_year == 0 || s_month == 0 || s_day == 0 || e_year == 0 || e_month == 0 || e_day == 0 || @case != '01234'
        start_min = (now.min / 5) * 5
        @start_date = DateTime.new(now.year, now.month, now.day, now.hour, start_min)
        @end_date = @start_date + 5.minutes
        @s_date = @start_date.strftime("%Y-%m-%-d %-H:%-M")
        @e_date = @end_date.strftime("%Y-%m-%-d %-H:%-M")
      else
        @start_date = DateTime.new(s_year, s_month, s_day, s_hour, s_min,0)
        @s_date = @start_date.strftime("%Y-%m-%-d %-H:%-M")
        @end_date = DateTime.new(e_year, e_month, e_day, e_hour, e_min,0)
        @e_date = @end_date.strftime("%Y-%m-%-d %-H:%-M")
      end
    end

    #絞込日時範囲内のログ取得
    @logs = System::AccessLog.extract_date(@start_date, @end_date)

    #固定ヘッダーの情報取得
    categories = Gw::EditLinkPiece.extract_location_header

    # ログデータ取得
    categories_data = @logs.group(:feature_name).count

    @categories =[]  #グラフ表示用機能名
    @data = []  #グラフデータ

    #固定ヘッダーに存在する機能名のログ集計
    categories.each do |categories|
      categories.opened_children.each_with_index do |level3_item, idx3|
        next if level3_item.published != 'opened' || level3_item.state != 'enabled'
        category = level3_item.name
        @categories << category
        @data << categories_data.delete(category)
      end
    end

    #ログイン情報の集計
    @categories << "ログイン"
    @data << categories_data.delete("ログイン")

    #ログアウト情報の集計
    @categories << "ログアウト"
    @data << categories_data.delete("ログアウト")

    #固定ヘッダーに存在しない機能名のログ集計
    categories_data.each do |category, data|
      @categories << category
      @data << data
    end

    @data_cnt = @logs.length

    #機能別の最大値取得
    max = @data.compact.max || 0

    @column_graph = LazyHighCharts::HighChart.new("graph") do |f|
      f.chart(:type => "column")
      f.title(:text => "#{@start_date.strftime("%Y年%m月%d日%H時%M分")} から #{@end_date.strftime("%Y年%m月%d日%H時%M分")}")
      f.xAxis(:categories => @categories)
#機能別の最大値が5件未満であれば縦軸最大値を固定する
      if max < 5
        f.yAxis(:max => "5",
                :allowDecimals => "false",
                :title => {
                  :align => "middle",
                  :text => "　"
                })
      end
      f.series(:name => "機能別 アクセス量",
               :data => @data,
               :dataLabels => {
                 :enabled => true,
                 :style => {:fontWeight => 'bold'},
                 :formatter => "function() { return this.y; }".js_code
               })
    end

    @logs = @logs.paginate(:page=>params[:page],:per_page => 50)
  end

  def export
    s_date = params[:s_date].to_time
    e_date = params[:e_date].to_time
    data_cnt = params[:data_cnt]

    start_date = s_date.strftime("%Y-%m-%d %H:%M:%S")
    end_date = e_date.strftime("%Y-%m-%d %H:%M:%S")

    logs = System::AccessLog.extract_csv_date(start_date, end_date,data_cnt)
    csv = CSV.generate do |csv|
      csv << ['アクセス日時', 'IPアドレス', 'ユーザID', 'ユーザ名', '機能名']
      logs.each do |log|
        row = []
        row << log.created_at.strftime("%Y-%m-%d %X")
        row << log.ipaddress
        row << log.user_code
        row << log.user_name
        row << log.feature_name
        csv << row
      end
    end
    csv = NKF.nkf('-Ws -Lw', csv)
    send_data(csv, :type => 'text/csv; charset=Shift_JIS',
              :filename => "access_logs_#{s_date.strftime("%Y%m%d-%H%M%S")}_#{e_date.strftime("%Y%m%d-%H%M%S")}.csv")
  end

  def show
    redirect_to('action' => 'index')
  end

  def create
    redirect_to('action' => 'index')
  end
end
