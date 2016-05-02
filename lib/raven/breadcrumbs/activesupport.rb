module Raven
  module ActiveSupportBreadcrumbs
    class << self
        def add(name, _started, _finished, _unique_id, data)
          Raven.breadcrumbs.record do |crumb|
            crumb.data = data
            crumb.category = name
            # TODO(dcramer): coerce started into unix timestamp or UTC iso
            # crumb.timestamp = started
          end
        end

        def inject
          ActiveSupport::Notifications.subscribe(/.*/) do |name, started, finished, unique_id, data|
            add(name, started, finished, unique_id, data)
          end
        end
    end
  end
end
