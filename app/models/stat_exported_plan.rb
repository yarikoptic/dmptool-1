# frozen_string_literal: true

# == Schema Information
#
# Table name: stats
#
#  id         :integer          not null, primary key
#  count      :bigint(8)        default(0)
#  date       :date             not null
#  details    :text(65535)
#  filtered   :boolean          default(FALSE)
#  type       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  org_id     :integer
#

# Object that represents a Nbr of Plans exported usage statistic
class StatExportedPlan < Stat
  class << self
    def to_csv(exported_plans)
      Stat.to_csv(exported_plans)
    end
  end
end
