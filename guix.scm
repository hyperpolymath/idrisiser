;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) {{CURRENT_YEAR}} {{AUTHOR}} ({{OWNER}}) <{{AUTHOR_EMAIL}}>
;;
;; Guix package definition for {{PROJECT_NAME}}
;;
;; Usage:
;;   guix shell -D -f guix.scm    # Enter development shell
;;   guix build -f guix.scm       # Build package
;;
;; TODO: Replace {{PROJECT_NAME}} and customize inputs for your language/stack.
;; See: https://guix.gnu.org/manual/en/html_node/Defining-Packages.html

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system gnu)
             (guix licenses)
             (gnu packages base))

(package
  (name "{{PROJECT_NAME}}")
  (version "0.1.0")
  (source (local-file "." "source"
                       #:recursive? #t
                       #:select? (lambda (file stat)
                                   (not (string-contains file ".git")))))
  (build-system gnu-build-system)
  (arguments
   '(#:phases
     (modify-phases %standard-phases
       ;; TODO: Customize build phases for your project
       ;; Examples for common stacks:
       ;;
       ;; Rust:
       ;;   (replace 'build (lambda _ (invoke "cargo" "build" "--release")))
       ;;   (replace 'check (lambda _ (invoke "cargo" "test")))
       ;;
       ;; Elixir:
       ;;   (replace 'build (lambda _ (invoke "mix" "compile")))
       ;;   (replace 'check (lambda _ (invoke "mix" "test")))
       ;;
       ;; Zig:
       ;;   (replace 'build (lambda _ (invoke "zig" "build")))
       ;;   (replace 'check (lambda _ (invoke "zig" "build" "test")))
       (delete 'configure)
       (delete 'build)
       (delete 'check)
       (replace 'install
         (lambda* (#:key outputs #:allow-other-keys)
           (let ((out (assoc-ref outputs "out")))
             (mkdir-p (string-append out "/share/doc"))
             (copy-file "README.adoc"
                        (string-append out "/share/doc/README.adoc"))))))))
  (native-inputs
   (list
    ;; TODO: Add build-time dependencies
    ;; Examples:
    ;;   rust (gnu packages rust)
    ;;   elixir (gnu packages elixir)
    ;;   zig (gnu packages zig)
    ))
  (inputs
   (list
    ;; TODO: Add runtime dependencies
    ))
  (home-page "https://github.com/{{OWNER}}/{{PROJECT_NAME}}")
  (synopsis "{{PROJECT_PURPOSE}}")
  (description "RSR-compliant project. See README.adoc for details.")
  (license (list
            ;; PMPL-1.0-or-later extends MPL-2.0
            mpl2.0)))
