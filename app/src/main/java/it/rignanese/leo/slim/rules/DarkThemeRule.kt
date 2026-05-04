package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `darkThemeCss` (key `dark_theme`) from Flutter `lib/utils/css.dart`
 * lines 218-511. The Flutter source built this string by concatenating two
 * adjacent triple-quoted raw strings; both halves are preserved verbatim.
 * FB hosts.
 */
class DarkThemeRule : InjectionRule {
    override val id: String = "dark_theme"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        val CSS = """
/* ===========================
Credits: Bean Verified Bean Terified
https://userstyles.org/styles/160729/violet-nebula
============================*/
body,
body ._li {
	background:black !important
}

._53jh {
    background: transparent;
}

.loggedout_menubar_container {
    background: none !important;
}

.fbIndex #globalContainer #dropmenu_container,
.fbIndex #globalContainer #content,
.fbIndex #globalContainer #pageFooter {
    display: none !important
}


.fbIndex .loggedout_menubar_container {
    position: fixed !important;
    width: 0px !important;
    height: 0px !important;
    min-width: 0px !important;
    bottom: 70% !important;
    left: 1% !important;
    margin-bottom: -290px !important;
    margin-left: -15px !important;
    z-index: -1000 !important;
}


.loggedout_menubar {
    background: rgba(0, 0, 0, .6) !important;
    padding: 0 0px 0px 0px;
    -webkit-border-radius: 0px;
    border-radius: 0px;
    -webkit-box-shadow: rgba(0, 0, 0, .4);
    box-shadow: rgba(0, 0, 0, .4);
    border: 1px solid #333 !important;
}

.fbIndex .loggedout_menubar {
    width: auto !important
}

.fbIndex .loggedout_menubar_container .lfloat,
.fbIndex .loggedout_menubar_container .rfloat {
    float: none !important
}

.fbIndex .loggedout_menubar_container .lfloat img,
.fbIndex .loggedout_menubar_container .rfloat #login_form table {
    display: block !important;
    margin: 0 auto !important
}

.menu_login_container {
    margin-top: 1.2em !important;
}

td .inputtext {
    background: rgba(0, 0, 0, 0.4) !important;
    border-radius: 0px !important;
}

* {
    border-color: transparent !important;
    font-family: Arial !important;
    color: #FFFFFF !important;
    background-color: transparent !important;
}

a:hover {
    text-decoration: none;
    font-weight: bold;
}

#BuddylistPagelet {
    display: none !important;
}

/*left panel */
._3m75 .sideNavItem ._5afe::after {
    background-color: rgba(0, 0, 0, 0.8);
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}

._3m75 .sideNavItem ._5afe:active {
    background-color: rgba(0, 0, 0, 0.8);
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}

/*group sidebar*/
._2yau::after {
    background-color: rgba(0, 0, 0, 0.8) !important;
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}

._2yau:active {
    background-color: rgba(0, 0, 0, 0.8);
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}


/*leave box */
._1yv {
    background-color: rgba(0, 0, 0, 0.8) !important;
}

/*global notification */
._50d1 {
    background-color: rgba(0, 0, 0, 0.8) !important;
}


/*#contentCol,#left_column,#right_column{
	background-color: rgba(0,0,0,0.6) !important;
	border: none !important;
}*/
._4-u2 {
    background-color: rgba(0, 0, 0, 0.5) !important;
}

.u_yqurkg_f8,
._26z1 {
    display: none;
}

.__tw,
._54ng,
._5tlx,
.fbNubFlyoutOuter {
    background-color: rgba(0, 0, 0, 0.8) !important;
}

/*Chat box */
.fbNubFlyoutTitlebar {
    background-color: rgba(0, 0, 0, 0.8) !important;
    border-radius: 0px !important;
}

._2nlt,
._3olsv,
._2nlst {
    background: rgba(255, 255, 255, 0.8) !important;
}

/*header */
#pagelet_bluebar {
    background-color: rgba(0, 0, 0, 0.4) !important;
}

/*search icon */
._585- ._42ft {
    display: none;
}

/*unread notification*/
.jewelItemNew {
    background-color: rgba(255, 255, 255, 0.2) !important;
}

/*tool tip chat like time etc*/
.uiTooltipX {
    background-color: rgba(0, 0, 0, 0.8) !important;
}

._59s7 {
    background-color: rgba(0, 0, 0, 0.8) !important;
}


/*messenger*/
._1enh {
    border-right: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

._4_j5 {
    border-left: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

._5742 {
    border-bottom: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

._36ic {
    border-bottom: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

#u_jsonp_6_7,
.stickyHeaderWrap,
.uiMenuInner {
    background-color: rgba(0, 0, 0, 0.5) !important;
}

/*friend request*/
._n3 {
    background-color: rgba(0, 0, 0, 0.9) !important;
}

/*personal profil*/
._6_7 {
    background-color: rgba(0, 0, 0, 0.6) !important;
}

._513x {
    display: none !important;
}

/*pointer*/

/*messenger read notification*/
._9ah {
    background-color: rgba(255, 255, 255, 0.7) !important;
}

/*delivered*/
._3zzf {
    border: 1px solid rgba(255, 255, 255, 0.7) !important;
    color: blue !important
}

/*sent*/

/*profile*/
._53ij {
    background-color: rgba(0, 0, 0, 0.8) !important;
}
""" + """
/*badge*/
span._59tg {
    background-color: #3141ac !important;
}

#header {
background-color: #080618 !important;
}
"""
    }
}
