;; sane defaults
;; im a dirty vim user
(use-package evil
  :ensure t
  :config
  (setq evil-want-integration t
        evil-want-keybinding nil)
  (evil-mode t)
  (setq-default evil-normal-state-cursor '(hbar . 3)
                evil-insert-state-cursor '(hbar . 3)
                evil-visual-state-cursor '(hbar . 3)
                evil-operator-state-cursor '(hbar . 3)))

(use-package general
  :after evil
  :ensure t
  :init
  (setq general-override-states '(insert emacs hybrid normal
                                visual motion operator replace)))

;; reload config when a new frame is launched
(add-hook 'after-make-frame-functions (lambda (arg) (vz:reload-config)))

;; who even needs these?
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq-default cursor-in-non-selected-windows nil)

;; initial buffer
(defun vz:new-empty-buffer ()
  (interactive)
  (let (($buf (generate-new-buffer "new")))
    (switch-to-buffer $buf)
    (funcall initial-major-mode)
    (setq buffer-offer-save t)
    $buf))

;; default backup system is so retarded. sorry
(setq backup-by-copying t
      backup-directory-alist '(("." . "~/var/cache/emacs-bkups"))
      delete-old-versions t
      keep-new-versions 5
      keep-old-versions 2
      version-control t)
