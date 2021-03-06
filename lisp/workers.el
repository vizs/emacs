;; -*- lexical-binding: t; -*-

;; * Functions
(defun pass (passwd)
  "Get password using `pass'"
  (interactive (list
                (completing-read
                 "Account: " (s-split "\n" (shell-command-to-string "pass ls")))))
  (let ((pass (s-replace-regexp "\n$" "" (shell-command-to-string
                                          (format "pass get %s" passwd))))
        (select-enable-clipboard t))
    (when (called-interactively-p 'interactive)
      (kill-new pass))
    pass))

(defun vz/reload-config ()
  "Reload init.el."
  (interactive)
  (load user-init-file nil 'nomessage)
  (redraw-display)
  (force-mode-line-update t))

(defun vz/disable-bold-italic ()
  "Disable bold and italic for everything except bold and italic face."
  (seq-each #'(lambda (x) (set-face-attribute x nil :weight 'normal))
            (face-list))
  ;; :slant 'normal
  ;; :underline nil))
  (set-face-attribute 'bold   nil :weight 'bold)
  (set-face-attribute 'italic nil :slant 'italic :underline nil))

(defun vz/windows-in-direction (direction &optional windows)
  "Get all WINDOWS in DIRECTION relative to selected window."
  (let ((win (window-in-direction direction
                                  (or (car windows) (selected-window)))))
    (if win
        (vz/windows-in-direction direction (cons win windows))
      windows)))

(defun vz/uniqify (string)
  "Uniqify STRING by adding random characters at the end.
If STRING starts with a *, add * at the end of the resultant string."
  (concat (make-temp-name (concat string "-"))
          (when (s-starts-with? "*" string) "*")))

(defmacro vz/bind (&rest args)
  "This sort of works like `general' and `bind-keys'.
The arguments to function is given like in `general' and :map <>
behaviour is similar to that of in `bind-keys'."
  (let ((map 'global-map)
        (prefix ""))
    `(progn
       ,@(seq-map
          #'(lambda (x)
            (seq-let (key fun) x
             (pcase key
              (:map    (setq map fun)    '())
              (:prefix (setq prefix fun) '())
              (_ (list 'define-key
                  map
                  (if (stringp key) `(kbd ,(concat prefix " " key)) key)
                  fun)))))
          (seq-partition args 2)))))

(defun vz/kill-current-buffer-or-prompt (arg)
  (interactive "P")
  (if arg
      (call-interactively #'kill-buffer)
    (kill-current-buffer)))

(vz/bind
 [remap kill-buffer] #'vz/kill-current-buffer-or-prompt)

;; Functions used to communicate with emacsclient.
;; It's in a separate file because it depends on dynamic scoping
(load-file (expand-file-name "lisp/hive/scripting.el" user-emacs-directory))

;; * Builtin stuff that doesn't depend on anything else
;; ** Fringe
(use-package fringe
  :straight ( :type built-in)
  :config
  ;; Remove the ugly left and right curly arrow for continued lines
  (setf (cdr (assoc 'continuation fringe-indicator-alist)) '(nil nil))
  (setf (cdr (assoc 'truncation   fringe-indicator-alist)) '(nil nil))
  (fringe-mode '(8 . 0)))

;; ** Highlighting parenthesis
(use-package show-paren
  :defer t
  :hook (prog-mode . show-paren-mode)
  :straight ( :type built-in)
  :custom
  (show-paren-delay 0)
  (show-paren-when-point-inside-paren t))

;; ** Spell check
;; Enabled on major-mode basis
(use-package flyspell
  :straight (:type built-in)
  :hook (org-mode . flyspell-mode)
  :defer t
  :init
  (setq flyspell-persistent-highlight t
        flyspell-issue-message-flag nil)
  ;;  flyspell-mark-duplication-flag nil)
  (setq ispell-program-name "hunspell"))

;; ** On the fly syntax checker
(use-package flymake
  :straight (:type built-in)
  :defer t
  :hook (sh-mode . flymake-mode)
  :config
  (define-fringe-bitmap 'vz/fringe-left-arrow
    [#b01100000
     #b00110000
     #b00011000
     #b00110000
     #b01100000]
    nil nil 'center)
  (setq
    flymake-error-bitmap   '(vz/fringe-left-arrow error)
    flymake-warning-bitmap '(vz/fringe-left-arrow warning)
    flymake-note-bitmap    '(vz/fringe-left-arrow compilation-info)))

;; ** Occur menu styling
;; I don't like the underline face at the top...
(add-hook 'occur-mode-hook
          (defun vz/style-occur-menu ()
            (face-remap-add-relative 'underline :underline nil)))

;; ** grep menu styling
;; I don't like the underline face lol
(add-hook 'grep-mode-hook
          (defun vz/style-grep-menu ()
            (seq-each (lambda (x) (face-remap-add-relative x :underline nil))
                      '(compilation-info compilation-line-number underline))))

;; ** Help menu binds
;; Why do I have to answer yes when I revert?

;; God I love Emacs 28
(when (< emacs-major-version 28)
  (vz/bind
   :map help-mode-map
   [remap revert-buffer] #'(lambda ()
                             (interactive)
                             (revert-buffer nil t))))

;; ** Recentf

;; I end up looking at the definitions of functions and variables
;; quite often and it gets quite annoying when they end up in the
;; recentf list.

(use-package recentf
  :defer t
  :straight ( :type built-in)
  :custom
  (recentf-exclude
   (list (rx bol
             (eval (expand-file-name "straight/"
                                     user-emacs-directory))
             (or "repo/" "build/")
             (1+ print)
             "/"
             (1+ print)
             (or ".el" ".el.gz")
             eol)
         (rx bol
             "/nix/store/"
             (1+ alnum) ;; Hash
             "-emacs"
             (1+ (any ?. ?- alnum))
             "/share/emacs/"
             (eval emacs-version)
             "/lisp/"
             (1+ print)
             (or ".el" ".el.gz")
             eol)))
  (recentf-max-saved-items 50)
  (recentf-max-menu-items 50))

;; ** Dired
(use-package dired
  :straight ( :type built-in)
  :defer t
  :custom
  ;; Human readable size
  (dired-listing-switches "-alh"))

;; * Modeline
(with-eval-after-load user-init-file
  (load-file (expand-file-name "lisp/hive/modeline.el"
                               user-emacs-directory)))

;; * Shell
(use-package comint
  :defer t
  :straight (:type built-in)
  :functions (vz/comint-send-input)
  :bind
  ( :map comint-mode-map
    ("<S-return>" . comint-accumulate)
    ("<return>"   . vz/comint-send-input)
    ("RET" . vz/comint-send-input))
  :config
  (defun vz/comint-send-input ()
    "Send region if present, otherwise current line to current buffer's process"
    (interactive)
    (if (use-region-p)
        (let ((cmd (buffer-substring-no-properties (region-beginning)
                                                   (region-end))))
          (comint-send-string (get-buffer-process (current-buffer))
                              (concat cmd "\n"))
          (comint-add-to-input-history cmd)
          (deactivate-mark))
      (let ((after (comint-after-pmark-p)))
        (save-excursion (comint-send-input))
        (when after
          (comint-next-prompt 1))))))

(vz/use-package shell nil
  :demand t
  :straight (:type built-in))

;; * External packages
;; ** Whitespace
(use-package ws-butler
  :config (ws-butler-global-mode))

;; ** Highlight keywords and jump between them
(use-package hl-todo
  :defer t
  :hook (prog-mode . hl-todo-mode)
  :bind
  ( :map prog-mode-map
    ("C-c tn" . hl-todo-next)
    ("C-c tp" . hl-todo-previous))
  :config
  (setq hl-todo-highlight-punctuation ":"))

;; ** Center buffer
(use-package olivetti
  :defer t
  :bind ("C-c C" . olivetti-mode)
  :custom
  (olivetti-body-width 80)
  (olivetti-enable-visual-line-mode nil))

;; ** Folding text
(if (< emacs-major-version 28)
    (use-package bicycle
      :after outline
      :defer t
      :bind ( :map outline-minor-mode-map
              ([C-tab] . bicycle-cycle)
              ("<backtab>" . bicycle-cycle-global)))
  (custom-set-variables
   '(outline-minor-mode-cycle t)))

;; ** Edit a part of a buffer in separate window
;; (use-package edit-indirect
;;   :defer t)

;; ** TODO: Execute actions based on text
;; Actually hyperbole might be better since it has implicit buttons.
;; Desperately needs a rewrite
;; (vz/use-package wand "plumb"
;;   :straight (:type git :host github
;;                    :repo "cmpitg/wand"
;;                    :fork (:repo "vizs/wand")))

;; * Org-mode
;; You don't need any explanation
(vz/use-package org nil
  :demand t
  :straight ( :type git
                    :host github :repo "emacsmirror/org")
  :bind
  (("C-c oc" . org-capture)
   ("C-c oa" . org-agenda)
   ("C-c oj" . counsel-org-goto-all))
  :init
  (straight-use-package 'auctex)
  (straight-use-package 'cdlatex))

;; * Communication
;; IRC and Discord using ircdiscord
(vz/use-package circe "irc"
  :defer t
  :functions (vz/circe-jump-irc vz/circe-jump-discord)
  :init
  (defun pass-irc (serv)
    #'(lambda (_) (pass (format "irc/%s" serv))))
  (defun pass-discord (serv)
    #'(lambda (_) (unless (or vz/ircdiscord-process
                          (process-live-p vz/ircdiscord-process))
                  (setq-default vz/ircdiscord-process
                   (start-process "ircdiscord" nil "ircdiscord")))
        (format "%s:%d" (pass "misc/discord") serv))))

;; * scroll-other-window
;; This lets you use a custom function to scroll instead of just window_scroll in C
;; See: https://github.com/politza/pdf-tools/issues/55
(with-eval-after-load 'org-noter
  (when (load-file (expand-file-name "lisp/hive/scroll-other-window.el"
                                     user-emacs-directory))
    (add-hook 'org-noter-notes-mode-hook
              #'sow-mode)))

;; * Programming Languages
(use-package company
  :demand t
  :functions (company-complete-common-or-cycle
              vz/company-previous-candidate
              vz/company-next-candidate)
  :bind
  ( :map company-active-map
    ("C-n" . vz/company-next-candidate)
    ("C-p" . vz/company-previous-candidate))
  :config
  (defun vz/company-previous-candidate ()
    (interactive)
    (company-complete-common-or-cycle -1))
  (defun vz/company-next-candidate ()
    (interactive)
    (company-complete-common-or-cycle 1))
  (add-to-list 'company-backends #'company-capf)
  (global-company-mode)
  :custom
  (company-require-match nil)
  (company-idle-delay nil)
  (company-tooltip-limit 10)
  (company-show-numbers 'left)
  (company-global-modes '(not special-mode shell-mode org-mode))
  (company-minimum-prefix-length 2)
  (completion-in-region-function
   (lambda (start end collection predicate)
     (if company-mode
         (company-complete-common)
       (ivy-completion-in-region start end collection predicate)))))

;; ** Shellcheck
(use-package flymake-shellcheck
  :after flymake
  :defer t
  :commands flymake-shellcheck-load
  :hook (sh-mode . flymake-shellcheck-load))

;; ** Python
(use-package python
  :defer t
  :straight (:type built-in)
  ;:bind
  ;("C-c df" . python-describe-at-point)
  :custom
  (python-shell-interpreter "python3")
  (python-shell-interpreter-args "-i"))

;; ** Scheme
;; Depends on chicken
(use-package scheme
  :defer t
  :straight (:type built-in)
  ;; :hook (scheme-mode . aggressive-indent-mode)
  :config
  (setq scheme-program-name "csi"))

;; ** Emacs Lisp
;; Has a separate file
(vz/use-package elisp-mode "elisp"
  :straight (:type built-in)
  :functions (vz/emacs-lisp-indent-function))

;; ** Go
(use-package go-mode
  :defer t
  :hook
  (before-save . gofmt-before-save)
  :config
  ;; Cleaned up flymake-go
  (defun vz/flymake-go ()
    (list "go" (list "fmt"
                     (flymake-proc-init-create-temp-buffer-copy
                      'flymake-proc-create-temp-inplace)))))
  ;;(add-hook 'go-mode-hook
  ;;          (defun vz/go-mode-init ()
  ;;            (flymake-mode)
  ;;            (add-to-list 'flymake-proc-allowed-file-name-masks
  ;;                         '("\\.go\\'" vz/flymake-go)))
  ;;          nil t))

;; ** Lua
(use-package lua-mode
  :defer t)

;; ** Racket
(use-package racket-mode
  :defer t
  :hook (racket-mode . racket-xp-mode)
  :config
  (add-to-list 'font-lock-maximum-decoration '(racket-mode . nil))

  (add-hook 'racket-xp-mode-hook
            (defun vz/racket-xp-mode-init ()
              ;; (remove-hook 'pre-display-functions
              ;;              #'racket-xp-pre-redisplay t)
              (setq-local eldoc-documentation-function #'racket-xp-eldoc-function)))

  ;; For that sweet ivy-prescient sorting
  (defun vz/racket--symbol-at-point-or-prompt (force-prompt-p prompt &optional completions)
    (let* ((s (ivy-read prompt completions
                        :preselect (thing-at-point 'symbol)
                        :sort t)))
      (if (s-blank? (racket--trim (substring-no-properties s)))
          nil
        s)))
  (advice-add 'racket--symbol-at-point-or-prompt
              :override #'vz/racket--symbol-at-point-or-prompt)

  (defun vz/racket-eros-eval-last-sexp ()
    "Eval the previous sexp asynchronously and create an eros overlay"
    (interactive)
    (unless (racket--repl-live-p)
      (user-error "No REPL session available."))
    (racket--cmd/async
     (racket--repl-session-id)
     `(eval ,(buffer-substring-no-properties (racket--repl-last-sexp-start) (point)))
     (let ((point (point)))
       #'(lambda (result) (message "%s" result)
           (eros--make-result-overlay result
            :where point
            :duration eros-eval-result-duration)))))
  (vz/bind
   :map racket-mode-map
   [remap racket-send-last-sexp] #'vz/racket-eros-eval-last-sexp)

  (defvar vz/racket-mode-syntax-table-during-abbrev
    (make-syntax-table racket-mode-syntax-table))
  (modify-syntax-entry ?\\ "w" vz/racket-mode-syntax-table-during-abbrev)

  (define-abbrev-table 'racket-mode-unicode-abbrev-table
    '(("lambda"     "λ" nil 0 :system t)
      ("\\alpha"    "α" nil 0 :system t)
      ("\\Alpha"    "Α" nil 0 :system t)
      ("\\beta"     "β" nil 0 :system t)
      ("\\Beta"     "Β" nil 0 :system t)
      ("\\gamma"    "γ" nil 0 :system t)
      ("\\Gamma"    "Γ" nil 0 :system t)
      ("\\delta"    "δ" nil 0 :system t)
      ("\\Delta"    "Δ" nil 0 :system t)
      ("\\epsilon"  "ε" nil 0 :system t)
      ("\\Epsilon"  "Ε" nil 0 :system t)
      ("\\zeta"     "ζ" nil 0 :system t)
      ("\\Zeta"     "Ζ" nil 0 :system t)
      ("\\eta"      "η" nil 0 :system t)
      ("\\Eta"      "Η" nil 0 :system t)
      ("\\theta"    "θ" nil 0 :system t)
      ("\\Theta"    "Θ" nil 0 :system t)
      ("\\iota"     "ι" nil 0 :system t)
      ("\\Iota"     "Ι" nil 0 :system t)
      ("\\kappa"    "κ" nil 0 :system t)
      ("\\Kappa"    "Κ" nil 0 :system t)
      ("\\lambda"   "λ" nil 0 :system t)
      ("\\Lambda"   "Λ" nil 0 :system t)
      ("\\lamda"    "λ" nil 0 :system t)
      ("\\Lamda"    "Λ" nil 0 :system t)
      ("\\mu"       "μ" nil 0 :system t)
      ("\\Mu"       "Μ" nil 0 :system t)
      ("\\nu"       "ν" nil 0 :system t)
      ("\\Nu"       "Ν" nil 0 :system t)
      ("\\xi"       "ξ" nil 0 :system t)
      ("\\Xi"       "Ξ" nil 0 :system t)
      ("\\omicron"  "ο" nil 0 :system t)
      ("\\Omicron"  "Ο" nil 0 :system t)
      ("\\pi"       "π" nil 0 :system t)
      ("\\Pi"       "Π" nil 0 :system t)
      ("\\rho"      "ρ" nil 0 :system t)
      ("\\Rho"      "Ρ" nil 0 :system t)
      ("\\sigma"    "σ" nil 0 :system t)
      ("\\Sigma"    "Σ" nil 0 :system t)
      ("\\tau"      "τ" nil 0 :system t)
      ("\\Tau"      "Τ" nil 0 :system t)
      ("\\upsilon"  "υ" nil 0 :system t)
      ("\\Upsilon"  "Υ" nil 0 :system t)
      ("\\phi"      "φ" nil 0 :system t)
      ("\\Phi"      "Φ" nil 0 :system t)
      ("\\chi"      "χ" nil 0 :system t)
      ("\\Chi"      "Χ" nil 0 :system t)
      ("\\psi"      "ψ" nil 0 :system t)
      ("\\Psi"      "Ψ" nil 0 :system t)
      ("\\omega"    "ω" nil 0 :system t)
      ("\\Omega"    "Ω" nil 0 :system t)
      ("_0"         "₀" nil 0 :system t)
      ("_1"         "₁" nil 0 :system t)
      ("_2"         "₂" nil 0 :system t)
      ("_3"         "₃" nil 0 :system t)
      ("_4"         "₄" nil 0 :system t)
      ("_5"         "₅" nil 0 :system t)
      ("_6"         "₆" nil 0 :system t)
      ("_7"         "₇" nil 0 :system t)
      ("_8"         "₈" nil 0 :system t)
      ("_9"         "₉" nil 0 :system t)
      ("^0"         "⁰" nil 0 :system t)
      ("^1"         "¹" nil 0 :system t)
      ("^2"         "²" nil 0 :system t)
      ("^3"         "³" nil 0 :system t)
      ("^4"         "⁴" nil 0 :system t)
      ("^5"         "⁵" nil 0 :system t)
      ("^6"         "⁶" nil 0 :system t)
      ("^7"         "⁷" nil 0 :system t)
      ("^8"         "⁸" nil 0 :system t)
      ("^9"         "⁹" nil 0 :system t))
    "Abbrev table used for inserting unicode characters in
racket-mode buffers. Only has the abbreviations that I'm likely
to use.")

  (add-hook 'racket-mode-hook
            (defun vz/racket-mode-turn-on-abbrev-mode ()
              (setq-local local-abbrev-table racket-mode-unicode-abbrev-table)
              (add-function :around (local 'abbrev-expand-function)
                            (lambda (old)
                              (with-syntax-table vz/racket-mode-syntax-table-during-abbrev
                                (funcall old))))
              (abbrev-mode t))))

;; ** Nix
(use-package nix-mode
  :defer t
  :mode "\\.nix\\'")

;; TODO: Use nix-sandbox for flymake commands
;; (use-package nix-sandbox)

;; * Sorting entries
;; Save and sort entries in ivy and company
(use-package prescient
  :custom
  (prescient-history-length 150)
        ;;  prescient-filter-method '(literal regexp initialism fuzzy)
  (prescient-save-file (~ ".cache/emacs-prescient.el"))
  :config
  (prescient-persist-mode))

(use-package ivy-prescient
  :after prescient
  :custom
  (ivy-prescient-enable-sorting t)
  :config
  (ivy-prescient-mode t)
  (custom-set-variables
   '(ivy-prescient-sort-commands (append ivy-prescient-sort-commands '(vz/shell-jump-to-dir proced-filter-interactive)))))

(use-package company-prescient
  :after company
  :hook (prog-mode . company-prescient-mode))

;; * Improve(?) editing experience
(load-file (expand-file-name "lisp/hive/editing.el" user-emacs-directory))

;; * Interface
;; ** Transmission
(use-package transmission
  :demand t
  :bind ("C-c T" . transmission)
  :custom
  (transmission-time-format "%A, %d %B, %Y %k:%M")
  (transmission-units 'iec))

;; ** proced
(use-package proced
  :defer t
  :straight ( :type built-in)
  :custom
  (proced-filter 'all))

;; ** Calendar
;; The way I'm setting the holidays is probably not idiomatic IDRC. I
;; don't live in murica anw

(use-package calendar
  :defer t
  :straight ( :type built-in)
  :config
  (add-hook 'calendar-today-visible-hook #'calendar-mark-today)
  :init
  (setq holiday-hindu-holidays ;; Only fixed ones. Majority vary every year.
        '((holiday-fixed 1 15 "Makar Sankranti")
          ;; Technically Tamil only but eh
          (holiday-fixed 1 15 "Pongal")
          (holiday-fixed 1 14 "Tamil New Year")))
  :custom
  (calendar-mark-holidays-flag t)
  (calendar-islamic-all-holidays-flag t)
  (holiday-christian-holidays
   '((holiday-easter-etc -2 "Good Friday")
     (holiday-fixed 12 25 "Christmas")))
  (holiday-islamic-holidays
   '((holiday-islamic 10 1 "Eid-ul-Fitr")
     (holiday-islamic 3 12 "Eid-e-Milad-un-Nabi")))
  (holiday-general-holidays
   '((holiday-fixed 1 1 "New Year's")
     (holiday-fixed 1 26 "Republic Day")
     (holiday-fixed 1 14 "Dr. B.R. Ambedkar Jayanti")
     (holiday-fixed 8 18 "Independence Day")
     (holiday-fixed 10 2 "Gandhi Jayanthi")))
  (calendar-holidays (append holiday-hindu-holidays
                             holiday-general-holidays
                             holiday-christian-holidays
                             holiday-islamic-holidays))
  (calendar-date-style 'european)
  (calendar-month-abbrev-array calendar-month-name-array)
  (calendar-day-abbrev-array calendar-day-name-array))

;; Local Variables:
;; eval: (outline-minor-mode)
;; outline-regexp: ";; [*]+"
;; End:
