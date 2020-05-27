(dolist  (f #'(menu-bar-mode tool-bar-mode scroll-bar-mode blink-cursor-mode))
  (funcall f -1))

(setq-default
 display-line-numbers-type 'relative
 display-line-numbers-width 0
 display-line-current-absolute t)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'view-mode-hook #'(lambda () (display-line-numbers-mode 0)))

(add-to-list 'default-frame-alist '(font . "Verily Serif Mono:pixelsize=12"))

(setq-default left-fringe-width 2)

;; Emacs 27 feature
(when (= emacs-major-version 27)
  (setq-default display-fill-column-indicator-column 80
    display-fill-column-indicator-char "|")
  (add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)
  (add-hook 'view-mode-hook #'(lambda ()
                                (display-fill-column-indicator-mode 0))))

;; Disable all bold and italic fonts
(dolist (f (face-list))
  (set-face-attribute f nil
  :weight 'normal :slant 'normal :underline nil))

(setq-ns show-paren
 delay 0
 when-point-inside-paren t)
(show-paren-mode t)

;; Modeline
(dolist (m '(display-time-mode display-battery-mode))
  (funcall m t))

(defun vz/mode-line-file-state ()
  (if (buffer-file-name)
      (cond
       (buffer-read-only    " [!]")
       ((buffer-modified-p) " [+]")
       (:else               ""))
  ""))
  
(defun vz/mode-line-evil-state ()
  (cond
   ((eq evil-state 'visual) "    VISUAL » ")
   ((eq evil-state 'insert) "    INSERT » ")
   (:else                   "    ")))

;; From https://0x0.st/oYX8
(defun vz/mode-line-fill (face except)
  (propertize " "
        'display `((space :align-to (- (+ right right-fringe right-margin)
                                       ,except)))
        'face face))

(setq-default
 battery-update-interval 240
 mode-line-format `((:eval (vz/mode-line-evil-state))
                    "%b"
                    (:eval (vz/mode-line-file-state))
                    (:eval (vz/mode-line-fill 'mode-line 19))
                    "« "
                    (:eval (format-time-string "[%H:%M] "))
                    "["
                    (:eval (battery-format "%b%p"
                                           (funcall battery-status-function)))
                    "%%]"))

;; How to be sane when you're working with multiple windows
(use-package beacon
  :config
  (beacon-mode 1)
  (setq-ns beacon-blink-when
    window-scrolls t
    point-moves-horizontally nil
    point-moves-vertically nil))

(custom-set-faces
 '(italic         ((t :slant italic)))
 '(bold           ((t :weight bold)))
 '(variable-pitch ((t :family "Charter" :height 100)))
 '(fixed-pitch    ((t :family "Verily Serif Mono" :height 90)))
 '(org-quote      ((t :inherit italic)))
 '(fixed-pitch-serif ((t :inherit fixed-pitch))))

;; Change faces
(load-file (vz/conf-path "theme.el"))
