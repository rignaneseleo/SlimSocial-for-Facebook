package it.rignanese.leo.slim.webview

/**
 * Test double for [PermissionGate] used until Phase 6 supplies the real one.
 *
 * Pass a map of (perm → decision); any unmapped perm defaults to [GateDecision.Deny].
 */
class FakePermissionGate(
    private val decisions: Map<WebPermission, GateDecision> = emptyMap(),
    private val default: GateDecision = GateDecision.Deny,
) : PermissionGate {
    override fun decide(perm: WebPermission): GateDecision = decisions[perm] ?: default

    companion object {
        fun grantAll(): FakePermissionGate = FakePermissionGate(default = GateDecision.Grant)
        fun denyAll(): FakePermissionGate = FakePermissionGate(default = GateDecision.Deny)
    }
}
