# coding: utf-8
class Gw::Admin::Piece::ReminderController < ApplicationController
  include System::Controller::Scaffold
  include RumiHelper
  layout 'base'
  
  # 新着情報欄表示action
  def index
    # 並び順
    sort_key = params[:sort_key] == "title" ? "title" : "datetime"
    order = params[:order] == "asc" ? "asc" : "desc"

    # 新着情報
    @reminders = {}
    # 固定ヘッダーアイコン
    header_menus = Gw::EditLinkPiece.extract_location_header.map { |header_menu| header_menu.opened_children.to_a }
    header_menus.flatten!

    # メール
    mail_remind = Rumi::WebmailApi.remind(Site.user.code, Site.user.password, sort_key, order)
    mail_menu = (header_menus.select { |header_menu| mail_feature_url?(header_menu.link_options[:url]) }).first
    if mail_remind.present? && mail_menu.present?
      # 小見出しと付加するリンク
      mail_remind.store(:title, mail_menu.name)
      mail_remind.store(:url, mail_menu.link_options[:url])
      @reminders.store(:mail, mail_remind)
    end

    # 回覧板
    circular_remind = Gwcircular::Control.remind(Site.user.id, sort_key, order)
    circular_menu = (header_menus.select { |header_menu| circular_feature_url?(header_menu.link_options[:url]) }).first
    if circular_remind.present? && circular_menu.present?
      circular_remind.store(:title, circular_menu.name)
      circular_remind.store(:url, circular_menu.link_options[:url])
      @reminders.store(:circular, circular_remind)
    end

    # 掲示板
    bbs_remind = Gwbbs::Control.remind(Site.user.id, sort_key, order)
    bbs_menu = (header_menus.select { |header_menu| bbs_feature_url?(header_menu.link_options[:url]) }).first
    if bbs_remind.present? && bbs_menu.present?
      bbs_remind.store(:title, bbs_menu.name)
      bbs_remind.store(:url, bbs_menu.link_options[:url])
      @reminders.store(:bbs, bbs_remind)
    end

    # スケジュール・施設予約
    schedule_remind = Gw::Schedule.remind(Site.user.id, sort_key, order)
    schedule_menu = (header_menus.select { |header_menu| schedule_feature_url?(header_menu.link_options[:url]) }).first
    schedule_prop_menu = (header_menus.select { |header_menu| schedule_prop_feature_url?(header_menu.link_options[:url]) }).first
    if schedule_remind.present? && (schedule_menu.present? || schedule_prop_menu.present?)
      schedule_title = []
      schedule_url = []
      if schedule_menu.present?
        schedule_title << schedule_menu.name
        schedule_url << schedule_menu.link_options[:url]
      end
      if schedule_menu.present? && schedule_prop_menu.present?
        schedule_title << I18n.t("rumi.reminder.delimiter")
        schedule_url << nil
      end
      if schedule_prop_menu.present?
        schedule_title << schedule_prop_menu.name
        schedule_url << schedule_prop_menu.link_options[:url]
      end

      schedule_remind.store(:title, schedule_title)
      schedule_remind.store(:url, schedule_url)
      @reminders.store(:schedule, schedule_remind)
    end

    # ファイル管理
    doclibrary_remind = Doclibrary::Control.remind(Site.user.id, sort_key, order)
    doclibrary_menu = (header_menus.select { |header_menu| doclibrary_feature_url?(header_menu.link_options[:url]) }).first
    if doclibrary_remind.present? && doclibrary_menu.present?
      doclibrary_remind.store(:title, doclibrary_menu.name)
      doclibrary_remind.store(:url, doclibrary_menu.link_options[:url])
      @reminders.store(:doclibrary, doclibrary_remind)
    end

    @all_seen_category = ["schedule","schedule_prop","bbs","circular"]
  end

  # === 一括既読メソッド
  #  本メソッドは、チェックが入った新着情報を一括既読にするメソッド
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  * なし
  def all_seen_remind

    # 回覧板
    if params[:checkd_reminders_circular] and params[:checkd_reminders_circular].size > 0
      update_time = Time.now
      params[:checkd_reminders_circular].each do |key, value|
        reminder = Gw::Reminder.where(id: key).first
        if reminder.present?
          reminder.seen
          doc_item = Gwcircular::Doc.where(title_id: reminder.title_id, id: reminder.item_id, doc_type: '0').first
          # 新着情報を既読に変更
          doc_item.seen_remind(params[:uid]) unless doc_item.blank?
          # 対象回覧板記事の更新
          doc_item_child = Gwcircular::Doc.where(title_id: reminder.title_id, parent_id: reminder.item_id, target_user_code: params[:ucode], state: 'unread').first
          if doc_item_child.present?
            doc_item_child.state = 'already'
            doc_item_child.latest_updated_at = update_time
            doc_item_child.published_at = update_time
            doc_item_child._commission_count = true
            doc_item_child.editdate = update_time.strftime("%Y-%m-%d %H:%M")
            doc_item_child.editor_id = params[:ucode]
            doc_item_child.editor = params[:uname]
            doc_item_child.editordivision_id = params[:gcode]
            doc_item_child.editordivision = params[:gname]
            doc_item_child.save
          end
        end
      end
    end

    # 掲示板
    if params[:checkd_reminders_bbs] and params[:checkd_reminders_bbs].size > 0
      update_time = Time.now
      params[:checkd_reminders_bbs].each do |key, value|
        reminder = Gw::Reminder.where(id: key).first
        if reminder.present?
          # 関連するreminderも既読にする
          reminder_items = Gw::Reminder.where(user_id: reminder.user_id, title_id: reminder.title_id, item_id: reminder.item_id, category: "bbs")
          reminder_items.each do |reminder_item|
            # 既読にする
            reminder_item.seen
          end
        end
      end
    end

    # スケジュール・施設予約
    if params[:checkd_reminders_schedule] and params[:checkd_reminders_schedule].size > 0
      params[:checkd_reminders_schedule].each do |key, value|
        reminder = Gw::Reminder.where(id: key).first
        if reminder.present?
          reminder.seen
          if reminder.sub_category == "schedule_repeat"
            repeat_item = Gw::ScheduleRepeat.where(id: reminder.item_id).first
            item = repeat_item.schedules.first
          else
            item = Gw::Schedule.where(id: reminder.item_id).first
          end
          item.seen_remind(params[:uid]) unless item.blank?
        end
      end
    end

    redirect_to '/'
  end

end
