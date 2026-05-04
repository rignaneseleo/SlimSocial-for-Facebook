package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `darkThemeMessengerCss` from Flutter `lib/utils/css.dart`. Messenger
 * hosts only.
 */
class DarkThemeMessengerRule : InjectionRule {
    override val id: String = "dark_theme_messenger"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isMessengerHost(url)) return null
        return CSS
    }

    private companion object {
        val CSS = """
.__fb-light-mode {
    --surface-background: #000000;
    --messenger-card-background: #000000;
    --primary-text: #e5e5e5;
    --wash: #303030;
    --comment-background: rgba(38, 38, 38, 0.81);
    --secondary-button-background: rgba(38, 38, 38, 0.81);
    --primary-icon: #ffffff;
    --always-black: white;
    --divider: #181818;
    --media-inner-border: #181818;
    --disabled-icon: #65636c;
    --popover-background: #b79ab11a;
    --filter-primary-icon: invert(100%) sepia(10%) saturate(200%) saturate(200%) saturate(166%) hue-rotate(177deg) brightness(104%) contrast(91%);
    --hosted-view-selected-state: rgba(201, 201, 201, 0.11);
    --card-background: #000000;
    --fds-gray-20: #181818;
    --secondary-button-text: #dbdbdb;
    --web-wash: #000000;
}
::-webkit-scrollbar {
  width: 0;
}
::-webkit-scrollbar-thumb {
  background: #888;
  border-radius: 12px;
}
.xb756pt {
    box-shadow: 0 0 2px rgb(24, 24, 24);
}
"""
    }
}
