package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `fabBtnCss` (`lib/utils/css.dart`) and `createFabFunc`
 * (`lib/utils/js.dart`). FB hosts.
 */
class FabButtonRule : InjectionRule {
    override val id: String = "fabBtn"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    override fun jsFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return JS
    }

    private companion object {
        const val CSS =
            ".my_fab_btn { position: fixed; z-index: 6; bottom: 10px; right: 10px; background-color: #3B5998; width: 60px; height: 60px; border-radius: 100%; background: #3B5998; border: none; outline: none; color: #FFF; font-size: 23px; box-shadow: 0 3px 6px rgba(0, 0, 0, 0.16), 0 3px 6px rgba(0, 0, 0, 0.23); transition: .3s; -webkit-tap-highlight-color: rgba(0, 0, 0, 0); }"

        val JS = """
javascript:function createFab() {
		var button = document.createElement('button');
		button.type = 'button';
  		button.innerHTML = '▲';
  		button.className = 'my_fab_btn';

  		button.onclick = function() {
    		window.scrollTo(0,0);
  		};

  		var container = document.getElementById('root');
  		container.appendChild(button);
		}
		createFab();""".trimStart()
    }
}
