class AgentRateLimit < ApplicationRecord
  belongs_to :agent

  validates :window_seconds, numericality: { only_integer: true, greater_than: 0 }
  validates :max_requests, numericality: { only_integer: true, greater_than: 0 }
end
