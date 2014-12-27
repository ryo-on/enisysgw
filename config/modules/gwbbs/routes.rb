EnisysGw::Application.routes.draw do
  mod = "gwbbs"
  scp = "admin"

  match "gwbbs",                                      :to => "gwbbs/admin/menus#index"
  match "gwbbs/docs/:parent_id/edit_file_memo/:id",   :to => "gwbbs/admin/docs#edit_file_memo"
  match "gwbbs/itemdeletes/:mode/target_record",      :to => "gwbbs/admin/itemdeletes#target_record"
  match "gwbbs/itemdeletes/:mode/create_date_record", :to => "gwbbs/admin/itemdeletes#create_date_record"
  match "gwbbs/csv_exports/:id",                      :to => "gwbbs/admin/csv_exports#index"
  match "gwbbs/csv_exports/:id/export_csv",           :to => "gwbbs/admin/csv_exports#export_csv"
  match 'gwbbs/forward_select'       => 'gwbbs/admin/menus#forward_select'
  match 'gwbbs/docs/:id/gwcircular_forward' => 'gwbbs/admin/docs#gwcircular_forward'
  match 'gwbbs/docs/:id/mail_forward' => 'gwbbs/admin/docs#mail_forward'

  #scope "_#{scp}" do
    namespace mod do
      scope :module => scp do
        resources "theme_settings",
          :controller => "theme_settings",
          :path => "theme_settings"
        resources "menus",
          :controller => "menus",
          :path => "menus"
        resources "itemdeletes",
          :controller => "itemdeletes",
          :path => "itemdeletes" do
            member do
              get :target_record, :create_date_record
            end
          end
        resources "builders",
          :controller => "builders",
          :path => "builders"
        resources "synthesetup",
          :controller => "synthesetup",
          :path => "synthesetup" do
            collection do
              get :date_edit
            end
          end
        resources "makers",
          :controller => "makers",
          :path => "makers"
        resources "categories",
          :controller => "categories",
          :path => "categories"
        resources "docs",
          :controller => "docs",
          :path => "docs" do
            member do
              get :recognize_update, :publish_update, :clone
              post :forward
            end
            collection do
              get :destroy_void_documents, :close
              post :all_seen_remind, :forward
            end
          end
        resources "comments",
          :controller => "comments",
          :path => "comments"
        resources "banners",
          :controller => "piece/banners",
          :path => "piece/banners"
        resources "menus",
          :controller => "piece/menus",
          :path => "piece/menus"
      end
    end
  #end


end
