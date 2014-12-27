class System::RoleGroup < ActiveRecord::Base
  include System::Model::Base

  belongs_to :group, foreign_key: :group_id, class_name: "System::Group"

  attr_accessible :group_code, :group_id, :group_name, :role_code, :system_role_id
end
