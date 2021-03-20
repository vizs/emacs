;; -*- lexical-binding: t; -*-

;; * Basic configuration
;; ** Set path to shell
(setq explicit-shell-file-name (or (getenv "SHELL") "/bin/sh"))

;; ** Disable colours in shell-mode
(setf ansi-color-for-comint-mode 'filter)
(setq-default shell-font-lock-keywords nil
              comint-buffer-maximum-size 2000)

;; ** Add doas prompt to password regexp
(when (< emacs-major-version 28)
  (setq comint-password-prompt-regexp
        (format "%s\\|%s"
                comint-password-prompt-regexp
                "doas (.*) password: ")))

;; ** Track $PWD more effectively
;; from http://0x0.st/Hroa
;; (defun shell-sync-dir-with-prompt (string)
;;   "Set prompt to `|Pr0mPT|${PWD}|...'"
;;   (if (string-match "|Pr0mPT|\\([^|]*\\)|" string)
;;       (let ((cwd (match-string 1 string)))
;;         (setq default-directory
;;               (if (string-equal "/" (substring cwd -1))
;;                   cwd
;;                 (setq cwd (concat cwd "/"))))
;;         (replace-match "" t t string 0))
;;     string))

;; ** Initialise
(defun vz/shell-mode-init ()
  (shell-dirtrack-mode nil)
  (add-hook 'comint-output-filter-function
            #'comint-truncate-buffer)
  (add-hook 'comint-output-filter-function
            #'comint-watch-for-password-prompt)
  (setq-local
   ;; comint-prompt-read-only t
   inhibit-field-text-motion t
   comint-process-echoes t)
  (setq Man-notify-method 'quiet))

(add-hook 'shell-mode-hook #'vz/shell-mode-init)

;; * Helper functions
;; ** Are we inside a shell?
(defun vz/inside-shell? (&optional buffer)
  "Is the current ``active'' process a shell?"
  (let ((child  (process-running-child-p (get-buffer-process
                                          (or buffer (current-buffer))))))
    (or (null child)
        (s-equals? (asoc-get (process-attributes child) 'comm)
                   (f-base explicit-shell-file-name)))))

;; ** Ivy action for running commands from shell history
(defun vz/shell-history--ivy-action (command)
  (comint-delete-input)
  (comint-send-string (get-buffer-process (current-buffer))
                      (concat command "\n"))
  (comint-add-to-input-history command)
  (vz/shell-history--write command))

;; * Shell history tracking
;; ** Variables
(defvar vz/shell-history-cache-file (~ ".cache/shell_history.el")
  "Path to file to save elisp data about shell history")

;; ** Functions
(defun vz/shell-history--get ()
  "Get shell history hashtable."
  (if (not (f-exists? vz/shell-history-cache-file))
      (make-hash-table :test #'equal :size 10000)
    (read-from-whole-string (f-read vz/shell-history-cache-file
                                    'utf-8))))

(defun vz/shell-history--write (entry &optional directory)
  "Prepend ENTRY to DIRECTORY key's value."
  (let ((entry (s-trim (substring-no-properties entry)))
        (directory (or directory default-directory))
        (ht (vz/shell-history--get))
        ;; From straight.el
        (print-level nil)
        (print-length nil))
    (unless (s-blank? entry)
      (puthash directory
               (cons entry (gethash directory ht))
               ht)
      (f-write (prin1-to-string ht) 'utf-8 vz/shell-history-cache-file))))

(defun vz/shell-history--sort (dir)
  "Sort shell history according to DIR."
  (let* ((ht (vz/shell-history--get))
         (his (gethash dir ht)))
    (dolist (d (hash-table-keys ht))
      (unless (equal d dir)
        (setq his (append his (gethash d ht)))))
    his))

(defun vz/shell-insert-from-hist ()
  (interactive)
  (when-let ((proc (get-buffer-process (current-buffer)))
             (_ (vz/inside-shell?)))
    (ivy-read
     "> " (vz/shell-history--sort default-directory)
     :preselect (comint-get-old-input-default)
     :sort nil
     :action #'vz/shell-history--ivy-action)))

(add-hook 'comint-input-filter-functions
          (defun vz/shell-history--input-hook (string)
            "Add string to shell history."
            (when (and (derived-mode-p 'shell-mode)
                       (vz/inside-shell?))
              (vz/shell-history--write string))
            t))

(defun vz/shell-shell-history ()
  "Returns current shell's history as a list"
  (split-string (f-read
                 (if (s-equals? (f-filename explicit-shell-file-name) "mksh")
                     (progn
                       (call-process "mksh" nil nil nil "-ic" "fc -r -l -n 1 >/tmp/shhist")
                       "/tmp/shhist")
                   (~ ".cache/bash_history")))
                "\n" nil "\t"))

;; * History from shell
(defun vz/shell-insert-from-shell-hist ()
  "Search for command in shell history and run it"
  (interactive)
  (when-let ((proc (get-buffer-process (current-buffer)))
             (_ (vz/inside-shell?)))
    (ivy-read
     "> " (vz/shell-shell-history)
     :preselect (comint-get-old-input-default)
     :sort nil
     :action #'vz/shell-history--ivy-action)))

;; * Jump to directory alias
(defun vz/shell-get-dir-alias ()
  (seq-map #'(lambda (x) (cadr (s-split "=" x)))
        (butlast
         (s-split "\n"
                  (f-read
                   (if (s-equals? (f-filename explicit-shell-file-name) "mksh")
                       (progn
                         (call-process "mksh" nil nil nil "-ic" "alias -d >/tmp/diralias")
                         "/tmp/diralias")
                       (~ "lib/directory-aliases")))))))

;; TODO: Figure out how to do this without setting directory to ""
(defun vz/shell-jump-to-dir ()
  "Jump to directory alias. Calling `ivy-call' launches
`read-directory-name', jumps to selected directory otherwise."
  (interactive)
  (when-let ((input (comint-get-old-input-default))
             (directory "")
             (_ (vz/inside-shell?)))
    (ivy-read
     "> " (vz/shell-get-dir-alias)
     :caller 'vz/shell-jump-to-dir
     :action #'(lambda (x)
                 (if (eq this-command #'ivy-call)
                     (ivy-exit-with-action
                      #'(lambda (_) (setq directory (read-directory-name "> " x))))
                   (setq directory x))))
    (vz/shell-history--ivy-action (concat "cd " (shell-quote-argument directory)))
    (comint-send-string (get-buffer-process (current-buffer))
                        input)))

;; * Popup a shell in `default-directory'
;; ** Variables
(defvar vz/popup-shells nil
  "List of all shell buffers opened by vz/popup-shell")

;; ** Functions
(defun vz/popup-shell--add (buffer &optional cwd)
  "Add BUFFER to vz/popup-shells and add a process sentinel.
If CWD is non-nil, then cd to CWD."
  (add-to-list 'vz/popup-shells buffer)
  (set-process-sentinel
   (get-buffer-process buffer)
   #'(lambda (p)
       (unless (process-live-p p)
        (let ((buf (process-buffer p)))
         (setq vz/popup-shells (remove buf vz/popup-shells))
         (kill-buffer buf)))))
  (when cwd
    (with-current-buffer buffer
      (comint-send-string (get-buffer-process buffer)
                          (format "cd %s\n" (shell-quote-argument cwd))))))

(defun vz/popup-shell--switch (buffer cwd &optional dont-cd?)
  "Switch to CWD in BUFFER"
  (switch-to-buffer-other-window buffer)
  (unless dont-cd?
    (let ((input (comint-get-old-input-default))
          (process (get-buffer-process buffer)))
      (comint-delete-input)
      (comint-send-string process (format "cd %s\n" (shell-quote-argument cwd)))
      (unless (s-matches? input (rx (= 1 (or "$" "#" "%" "μ"))))
        (comint-send-string process input)))))

(defun vz/popup-shell ()
  "If the frame is a terminal frame, then open the associated
shell buffer otherwise try to find ``free'' buffers that have the
CWD as `default-directory' and switch to it. If nothing is found,
create a new buffer."
  (interactive)
  (if (seq-contains-p vz/term-minor-mode-frames (selected-frame))
      (switch-to-buffer-other-window (frame-parameter (selected-frame) 'term-buffer))
    (let ((cwd (condition-case nil
                   (f-dirname (buffer-file-name))
                 (error (f-full default-directory)))))
      (if (null vz/popup-shells)
          (vz/popup-shell--add (shell) cwd)
        (let* ((free-buffers (seq-filter #'(lambda (buf) (and (vz/inside-shell? buf)
                                                          (null (get-buffer-window buf t))))
                              vz/popup-shells))
               (cwd-buffers (seq-filter #'(lambda (buf) (with-current-buffer buf
                                                         (f-equal? default-directory cwd)))
                             free-buffers)))
          (cond
           (cwd-buffers
            (vz/popup-shell--switch (car cwd-buffers) cwd t))
           ((and (null cwd-buffers) free-buffers)
            (vz/popup-shell--switch (car free-buffers) cwd))
           (t
            (vz/popup-shell--add (shell (vz/uniqify "*shell")) cwd))))))))

;; * Jump to prompt
(defvar-local vz/shell--prompt-alist nil
  "An alist of prompt string and its position in buffer.")

(defun vz/shell-clear-buffer ()
  "Just like `comint-clear-buffer' except it also sets
`vz/shell--prompt-alist' to nil."
  (interactive)
  (comint-clear-buffer)
  (setq-local vz/shell--prompt-alist nil))

(add-hook 'comint-input-filter-functions
          (defun vz/shell--prompt-add-hook (prompt)
            (when (and (derived-mode-p 'shell-mode)
                       (vz/inside-shell?))
              (setq-local vz/shell--prompt-alist
                          (cons `(,(s-trim-right prompt) . ,(1- (point))) vz/shell--prompt-alist)))
            t))

(defun vz/shell-jump-to-prompt ()
  "Jump to prompt by selecting it in ivy."
  (interactive)
  (ivy-read "> " vz/shell--prompt-alist
            :sort nil
            :action #'(lambda (p)
                        (goto-char (cdr p))
                        (vz/beacon-highlight))))

;; * Emacs frame as terminal
;; ** Variables
(define-minor-mode vz/term-minor-mode
  "Minor mode for binding C-d in *term* buffers")

(defvar vz/term-minor-mode-frame nil
  "Frame variable that *term-asdf* buffer uses")

(make-variable-buffer-local 'vz/term-minor-mode-frame)

(defvar vz/term-minor-mode-frames nil
  "Frames used by *term-asdf* buffers")

;; ** Functions
(defun vz/term-minor-mode-sentinel (process output)
  "Process sentinel to auto kill associated buffer and frame in term-mode"
  (unless (process-live-p process)
    (let* ((b (process-buffer process))
           (f (asoc-get (buffer-local-variables b)
                        'vz/term-minor-mode-frame))
           (kill-buffer-query-functions nil))
      (kill-buffer b)
      (when (frame-live-p f)
        (delete-frame f)))))

(defun vz/kill-dead-term ()
  "Remove all dead *term* buffers"
  (interactive)
  (let ((kill-buffer-query-functions nil))
    (seq-each
        (seq-filter
         #'(lambda (x) (with-current-buffer x
                        (and (s-prefix? "*term-" (buffer-name x))
                         (or (not (frame-live-p vz/term-minor-mode-frame))
                          (not (get-buffer-process x))))))
         (buffer-list))
      #'kill-buffer)))

(defun vz/term-minor-mode-set-title (string)
  "Set frame title when `vz/term-minor-mode' is active"
  (when (bound-and-true-p vz/term-minor-mode)
    (set-frame-parameter vz/term-minor-mode 'title
                         (format "term: %s" (s-trim-right string)))))

;; (add-hook 'comint-input-filter-functions #'vz/term-minor-mode-set-title)

;; `term-buffer' is set to the name of the shell buffer when the frame is created.
;; `term-buffer' is a frame parameter.

(defun vz/term-minor-mode-on-delete-frame (frame)
  "If FRAME is a member of `vz/term-minor-mode-frames', then kill the
term buffer associated with it"
  (when (and (member frame vz/term-minor-mode-frames)
             ;(vz/inside-shell? (frame-parameter frame 'term-buffer))
             )
    (setq vz/term-minor-mode-frames (remove frame vz/term-minor-mode-frames))
    (let ((kill-buffer-query-functions nil))
      (kill-buffer (frame-parameter frame 'term-buffer)))))

(add-hook 'delete-frame-functions #'vz/term-minor-mode-on-delete-frame)

;; * Keybindings
(defun vz/shell-send-keysequence-to-process (key)
  "Send keysequence to current running process"
  (interactive "sPress keysequence:")
  (comint-send-string (get-buffer-process (current-buffer)) key))

(defun vz/shell-quote-region-or-till-eol ()
  "Shell quote the region or from point to EOL."
  (interactive)
  (insert
   (shell-quote-argument
    (if (region-active-p)
        (delete-and-extract-region (region-beginning) (region-end))
      (delete-and-extract-region (point) (line-end-position))))))

(vz/bind
 :prefix "C-c"
 "p" #'vz/popup-shell
 :map shell-mode-map
 "j" #'vz/shell-jump-to-dir
 "?" #'vz/shell-insert-from-shell-hist
 "/" #'vz/shell-insert-from-hist
 "J" #'vz/shell-jump-to-prompt
 "k" #'vz/shell-send-keysequence-to-process
 "C-k" #'vz/shell-quote-region-or-till-eol
 [remap comint-clear-buffer] #'vz/shell-clear-buffer)

;; Local Variables:
;; eval: (outline-minor-mode)
;; outline-regexp: ";; [*]+"
;; End:
