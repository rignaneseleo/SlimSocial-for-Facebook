package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `adaptMessengerPageCss` from Flutter `lib/utils/css.dart`. Messenger
 * hosts only.
 */
class AdaptMessengerRule : InjectionRule {
    override val id: String = "adaptMessenger"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isMessengerHost(url)) return null
        return CSS
    }

    private companion object {
        val CSS = """
    /***** TOP BAR *****/
.x9f619.x1n2onr6.x1ja2u2z.xdt5ytf.x2lah0s.x193iq5w.xeuugli.x6s0dn4.x78zum5.xn3w4p2.xl56j7k.x1yrsyyn.xsyo7zv.x10b6aqq.x16hj40l.x187nhsf {
    display: none;
}

/* search bar */
.x9f619.x1n2onr6.x1ja2u2z.x1swvt13.x1pi30zi.xsag5q8.x1yrsyyn {
    padding-left: 2px;
    padding-right: 2px;
}

/***** LEFT BAR (groups,marketplace,etc) *****/
/* remove padding from icons on the left (groups, etc)*/
.x9f619.x1n2onr6.x1ja2u2z.x78zum5.xdt5ytf.x2lah0s.x193iq5w.xurb0ha.x1sxyh0 {
    padding: 0;
}

/* reduce the width */
.x9f619.x1n2onr6.x1ja2u2z.x78zum5.xdt5ytf.x2lah0s.x193iq5w.xeuugli.xycxndf.xkhd6sd.x4uap5.xexx8yu.x18d9i69 {
    width: 43px;
}

/***** CHAT BAR *****/
.x12nzpgo.x12nzpgo {
    width: 60px;
}

/* reduce chat bubbles */
a.x1i10hfl.x1qjc9v5.xjbqb8w.xjqpnuy.xa49m3k.xqeqjp1.x2hbi6w.x13fuv20.xu3j5b3.x1q0q8m5.x26u7qi.x972fbf.xcfux6l.x1qhh985.xm0m39n.x9f619.x1ypdohk.xdl72j9.x2lah0s.xe8uvvx.x2lwn1j.xeuugli.x1n2onr6.x16tdsg8.x1hl2dhg.xggy1nq.x1ja2u2z.x1t137rt.x1q0g3np.x87ps6o.x1lku1pv.x1a2a7pz.x1lq5wgf.xgqcy7u.x30kzoy.x9jhf4c.x1lliihq.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.x889kno.x1iji9kk.x1a8lsjc.x1sln4lm {
    padding-top: 2px;
    padding-bottom: 6px;
    padding-left: 0px;
    padding-right: 0px;
}

/* selected chat */
a.x1i10hfl.x1qjc9v5.xjqpnuy.xa49m3k.xqeqjp1.x2hbi6w.x13fuv20.xu3j5b3.x1q0q8m5.x26u7qi.x972fbf.xcfux6l.x1qhh985.xm0m39n.x9f619.x1ypdohk.xdl72j9.x2lah0s.xe8uvvx.x2lwn1j.xeuugli.x1n2onr6.x16tdsg8.x1hl2dhg.xggy1nq.x1ja2u2z.x1t137rt.x1q0g3np.x87ps6o.x1lku1pv.x1a2a7pz.x1lq5wgf.xgqcy7u.x30kzoy.x9jhf4c.x1lliihq.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.x889kno.x1iji9kk.x1a8lsjc.x1sln4lm.x1av1boa {
    padding: 7px;
}

/* hide badge downlad msg */
.x9f619.x1n2onr6.x1ja2u2z.x78zum5.x1r8uery.xs83m0k.xeuugli.x1qughib.x6s0dn4.xozqiw3.x1q0g3np.xb756pt.x1c4vz4f.xt55aet.xexx8yu.xc73u3c.x18d9i69.x5ib6vp.x1lku1pv.x12nzpgo {
    display: none;
}


/***** CHAT *****/

/* hide send gif */
.x6s0dn4.x1ey2m1c.x78zum5.xl56j7k.x10l6tqk.x1vjfegm.xat24cr.x3oybdh.x1g2r6go.x11xpdln.x5w5eug {
    display: none;
}

/* hide sticker */
.x6s0dn4.x1ey2m1c.x78zum5.xl56j7k.x10l6tqk.x1vjfegm.xat24cr.x3oybdh.x1g2r6go.x11xpdln.x5h36tt {
    display: none;
}

/* larger textbox */
.x78zum5.x1iyjqo2.x6q2ic0 {
    margin-left: 36px !important;
}

/* hide send audio */
.x1i10hfl.x1qjc9v5.xjbqb8w.xjqpnuy.xa49m3k.xqeqjp1.x2hbi6w.x13fuv20.xu3j5b3.x1q0q8m5.x26u7qi.x972fbf.xcfux6l.x1qhh985.xm0m39n.x9f619.x1ypdohk.xdl72j9.x2lah0s.xe8uvvx.xdj266r.x11i5rnm.xat24cr.x2lwn1j.xeuugli.x1n2onr6.x16tdsg8.x1hl2dhg.xggy1nq.x1ja2u2z.x1t137rt.x1o1ewxj.x3x9cwd.x1e5q0jg.x13rtm0m.x3nfvp2.x1q0g3np.x87ps6o.x1lku1pv.x1a2a7pz.x1i64zmx.x1y1aw1k.x1sxyh0.xwib8y2.xurb0ha {
    display: none;
}

/***** OTHERS *****/
.wkznzc2l {
    display: none !important;
}

.kuivcneq {
    display: none !important;
}

.bafdgad4 {
    display: none !important;
}

.aov4n071.cxmmr5t8.bi6gxh9e.hcukyx3x.jb3vyjys.hv4rvrfc.qt6c0cv9.dati1w0a {
    display: none !important;
}

.rj1gh0hx {
    max-width: -webkit-fill-available;
}

.j83agx80 {
    max-width: -webkit-fill-available;
}
"""
    }
}
