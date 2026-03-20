;; SPDX-License-Identifier: PMPL-1.0-or-later
;;
;; Panicbot directive — controls panic-attack static analysis behaviour.
;;
;; By default, only safe static analysis commands are allowed (assail,
;; adjudicate, diagnostics). Dynamic attack modes that execute the target
;; binary are denied — opt-in per repo if needed.
;;
;; See: https://github.com/hyperpolymath/gitbot-fleet/tree/main/bots/panicbot

(bot-directive
  (bot "panicbot")
  (scope "static-analysis")

  ;; Safe static analysis commands (no code execution)
  (allow ("assail" "adjudicate" "diagnostics"))

  ;; Dynamic attack modes — DENIED by default (execute target binary,
  ;; may cause side effects, resource exhaustion, or data corruption).
  ;; Opt-in per repo by moving items from deny to allow.
  (deny ("attack" "assault" "ambush" "amuck" "abduct" "axial"))

  (config
    ;; Report all severity levels. Set to "medium", "high", or "critical"
    ;; to filter out low-severity noise in mature repos.
    (min-severity "low")

    ;; Maximum wall-clock time for a single panic-attack invocation.
    ;; Increase for large codebases; decrease for CI time budgets.
    (timeout-seconds 300))

  (notes "Static analysis only by default. Dynamic attacks require explicit opt-in.")
  (notes "Unfixable findings are written to .panicbot/PANICBOT-FINDINGS.a2ml")
  (notes "Fixable findings are routed to Hypatia for automated remediation"))
