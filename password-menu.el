;;; password-menu.el --- Password Menu  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Robert Nadler <robert.nadler@gmail.com>

;; Author: Robert Nadler <robert.nadler@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: news
;; URL: https://github.com/rnadler/password-menu

;; The MIT License (MIT)

;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
;; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
;; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Commentary:

;; `password-menu' is a UI wrapper for the built-in Emacs `auth-source' library.
;; This package allows you to display auth-sources entries in the minibuffer
;; with either completing-read or transient. The password for the selected entry
;; is copied to the kill ring and system clipboard.
;;
;; See https://github.com/rnadler/password-menu for usage details.

;;; Code:

(require 'auth-source)
(require 'transient)

(defgroup password-menu ()
  "Password Menu content."
  :group 'gnus)

;;; Customizations:

(defcustom password-menu-time-before-clipboard-restore
  (if (getenv "PASSWORD_MENU_CLIP_TIME")
      (string-to-number (getenv "PASSWORD_MENU_CLIP_TIME"))
    45)
  "Number of seconds to wait before restoring the clipboard."
  :group 'password-menu
  :type 'number)

(defcustom password-menu-prompt "Get password for: "
  "Password menu prompt string."
  :group 'password-menu
  :type 'string)

(defcustom password-menu-sources-max 100
  "Maximum number of sources to find."
  :group 'password-menu
  :type 'number)

;;; Variables:

;; Kill ring expiration Credit:
;; https://github.com/zx2c4/password-store/blob/b5e965a838bb68c1227caa2cdd874ba496f10149/contrib/emacs/password-store.el#L291

(defvar password-menu-prefix-list nil
  "Cached password menu list.")

(defvar password-menu-timeout-timer nil
  "Timer for clearing clipboard.")

(defvar password-menu-kill-ring-pointer nil
  "The tail of of the kill ring ring whose car is the password.")

(defvar password-menu--create-fake-source-data nil
  "Flag to create fake data for testing long lists.")

(declare-function password-menu-prefix "password-menu")

;;; Functions:

(defun password-menu-clear ()
  "Clear secret in the kill ring."
  (interactive "i")
  (when password-menu-timeout-timer
    (cancel-timer password-menu-timeout-timer)
    (setq password-menu-timeout-timer nil))
  (when password-menu-kill-ring-pointer
    (setcar password-menu-kill-ring-pointer "")
    (kill-new "")
    (setq password-menu-kill-ring-pointer nil)
    (message "Password cleared from kill ring and system clipboard.")))

(defun password-menu--save-field-in-kill-ring (secret entry)
  "Add SECRET to kill ring for ENTRY."
  (password-menu-clear)
  (kill-new secret)
  (setq password-menu-kill-ring-pointer kill-ring-yank-pointer)
  (message "Copied password for %s to the kill ring and system clipboard. Will clear in %d seconds."
                entry password-menu-time-before-clipboard-restore)
  (setq password-menu-timeout-timer
        (run-at-time password-menu-time-before-clipboard-restore nil #'password-menu-clear)))

(defun password-menu-fetch-password (&rest params)
  "Fetch the password for the passed PARAMS."
  (let ((match (car (apply #'auth-source-search params))))
    (if match
        (let ((secret (plist-get match :secret)))
          (if (functionp secret)
              (funcall secret)
            secret))
      (error "Password not found for %S" params))))

(defun password-menu-get-password (name host)
    "Put password for user NAME and HOST on the kill ring."
    (let ((password (password-menu-fetch-password :user name :host host))
          (name-pw (concat name "@" host)))
      (if password
          (password-menu--save-field-in-kill-ring password name-pw)
        (message "Password not found for %s" name-pw))))

(defun password-menu-picker-string (num)
  "Get list picker string for NUM.
The string sequence will be 1..0,a1..a0,b1..b0,...
This will support 269 entries (1..z9) before the leading
character becomes non-alpha (270 --> '{0')."
  (let* ((div 10)
         (rem (mod num div))
         (i (/ num div)))
    (format "%s%d"
            (if (<= num div) "" (char-to-string (+ ?a (1- i))))
            rem)))

(defun password-menu--fake-source-data ()
  "Create fake source data."
  (if password-menu--create-fake-source-data
      (let ((count 50)
            (rv ()))
        (dotimes (n count)
          (let ((name (concat (char-to-string (+ ?A n)) "-name")))
            (push (list name "example.com") rv)))
        (reverse rv))
    nil))

(defun password-menu-get-sources ()
    "Get a list of all sources."
    (append
     (mapcar (lambda (e) (list
                          (plist-get e :user)
                          (plist-get e :host)))
             (auth-source-search :max password-menu-sources-max))
     (password-menu--fake-source-data)))

(defmacro password-menu--get-source-list (body)
  "Get the source list from the password sources with BODY content."
  `(mapcar
    (lambda (source)
      (let ((user (nth 0 source))
            (host (nth 1 source)))
        (,@body)))
      (password-menu-get-sources)))

(defmacro password-menu--selection-item ()
  "Get the selection USER and HOST item content."
  `(list
    (concat user "@" host)
    `(lambda () (interactive) (password-menu-get-password ,user ,host))))

(defun password-menu-get-prefix-list ()
  "Get the transient prefix list from the password sources.
Returns a vector of lists."
  (let ((picker 0))
    (apply #'vector
           (password-menu--get-source-list
            (append
             (list (password-menu-picker-string (setq picker (1+ picker))))
             (password-menu--selection-item))))))

(defun password-menu-get-completing-list ()
  "Get the completing list from the password sources."
  (password-menu--get-source-list
   (password-menu--selection-item)))

;;;###autoload
(defun password-menu-clear-password-menu ()
  "Clear the password transient menu."
  (interactive)
  (setq password-menu-prefix-list nil)
  (auth-source-forget-all-cached))

;;;###autoload
(defun password-menu-transient ()
  "Show the password transient menu."
  (interactive)
  (when (not password-menu-prefix-list)
    (progn
      (setq password-menu-prefix-list (vconcat (vector password-menu-prompt) (password-menu-get-prefix-list)))
      (eval '(transient-define-prefix password-menu-prefix () password-menu-prefix-list))))
    (password-menu-prefix))

;; Completing-read with a list Credit:
;; https://arialdomartini.github.io/emacs-surround-2

;;;###autoload
(defun password-menu-ask-password ()
  "Popup list of user@host entries to select from."
  (let ((choices (password-menu-get-completing-list)))
    (alist-get (completing-read password-menu-prompt choices)
               choices nil nil 'equal)))

;;;###autoload
(defun password-menu-completing-read (password-func)
  "Use interactive to get PASSWORD-FUNC fram the list."
  (interactive (list (password-menu-ask-password)))
  (eval password-func))

(provide 'password-menu)

;;; password-menu.el ends here
