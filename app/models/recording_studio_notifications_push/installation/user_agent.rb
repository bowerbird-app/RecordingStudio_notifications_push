# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Installation
    module UserAgent
      module_function

      def user_agent_like?(value)
        value.start_with?("Mozilla/") || value.length > 48
      end

      def label(user_agent)
        agent = user_agent.to_s
        return if agent.blank?

        browser = browser_name(agent)
        os = os_name(agent)
        return unless browser && os

        Copy.t("labels.on", browser: browser, os: os)
      end

      def mobile?(user_agent: nil, platform: nil, label: nil)
        haystack = [user_agent, platform, label].map { |value| value.to_s.downcase }.join(" ")
        return true if haystack.match?(/\b(iphone|ipod|ipad|android|ios|mobile)\b/)
        return true if haystack.match?(/\bon (iphone|ipad|android)\b/)

        false
      end

      def browser_name(user_agent)
        return Copy.t("labels.browsers.edge") if user_agent.match?(%r{Edg/})
        return Copy.t("labels.browsers.chrome") if user_agent.match?(%r{Chrome/})
        return Copy.t("labels.browsers.firefox") if user_agent.match?(%r{Firefox/})
        return Copy.t("labels.browsers.safari") if user_agent.match?(%r{Safari/}) && !user_agent.match?(%r{Chrome/})

        Copy.t("labels.browsers.browser")
      end

      def os_name(user_agent)
        return Copy.t("labels.os.ipad") if user_agent.match?(/iPad/)
        return Copy.t("labels.os.iphone") if user_agent.match?(/iPhone|iPod/)
        return Copy.t("labels.os.mac") if user_agent.match?(/Mac OS X|Macintosh/)
        return Copy.t("labels.os.windows") if user_agent.match?(/Windows/)
        return Copy.t("labels.os.android") if user_agent.match?(/Android/)
        return Copy.t("labels.os.linux") if user_agent.match?(/Linux/)

        Copy.t("labels.os.device")
      end
    end
  end
end
