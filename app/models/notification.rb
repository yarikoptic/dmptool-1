# frozen_string_literal: true

# == Schema Information
#
# Table name: notifications
#
#  id                :integer          not null, primary key
#  body              :text(65535)
#  dismissable       :boolean
#  enabled           :boolean          default(TRUE)
#  expires_at        :date
#  level             :integer
#  notification_type :integer
#  starts_at         :date
#  title             :string(255)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

# Object that represents a global notification
class Notification < ApplicationRecord
  enum level: { info: 0, warning: 1, danger: 2 }
  enum notification_type: { global: 0 }

  # ================
  # = Associations =
  # ================

  has_and_belongs_to_many :users, dependent: :destroy,
                                  join_table: 'notification_acknowledgements'

  # ===============
  # = Validations =
  # ===============

  validates :notification_type, presence: { message: PRESENCE_MESSAGE }

  validates :title, presence: { message: PRESENCE_MESSAGE }

  validates :level, presence: { message: PRESENCE_MESSAGE }

  validates :body, presence: { message: PRESENCE_MESSAGE }

  validates :dismissable, inclusion: { in: BOOLEAN_VALUES }

  validates :enabled, inclusion: { in: BOOLEAN_VALUES }

  validates :starts_at, presence: { message: PRESENCE_MESSAGE },
                        after: { date: Date.today, on: :create }

  validates :expires_at, presence: { message: PRESENCE_MESSAGE },
                         after: { date: Date.tomorrow, on: :create }

  # ==========
  # = Scopes =
  # ==========

  scope :active, (lambda do
    where('starts_at <= :now and :now < expires_at', now: Time.zone.now).where(enabled: true)
  end)

  scope :active_per_user, (lambda do |user|
    if user.present?
      acknowledgement_ids = user.notifications.map(&:id)
      active.where.not(id: acknowledgement_ids)
    else
      active.where(dismissable: false)
    end
  end)

  # Has the Notification been acknowledged by the given user ?
  # If no user is given, currently logged in user (if any) is the default
  #
  # Returns Boolean
  def acknowledged?(user)
    dismissable? && user.present? && users.include?(user)
  end
end
