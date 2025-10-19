;;; gtasks-org-tools.el --- Google Tasks Import and Export -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Import Google Tasks into Org and export Org entries to Google Tasks.
;;
;; Copyright (C) 2025 thndrbrrr@gmail.com
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;; Code:

(require 'org)
(require 'org-ql)
(require 'cl-lib) ;; TODO: used where? remove dependency
(require 'subr-x) ;; string-trim -- TODO: only used once ... remove dependency
(require 'gtasks)

(defgroup gtasks-org-tools nil
  "Tools for importing Google Tasks to Org and exporting Org entries."
  :group 'convenience
  :prefix "gtasks-org-tools-")

(defcustom gtasks-org-tools-default-todo "TODO"
  "Headline keyword for imported tasks that are not completed."
  :type 'string :group 'gtasks-org-tools)

(defcustom gtasks-org-tools-done-todo "DONE"
  "Headline keyword for imported completed tasks."
  :type 'string :group 'gtasks-org-tools)

(defcustom gtasks-org-tools-after-append-hook nil
  "Normal hook run *after* entries are appended and file saved.
Functions are called with: (ENTRIES TASKS TASKLIST FILE)."
  :type 'hook :group 'gtasks-org-tools)

;; TODO: add more customization options

(defun gtasks-org-tools--format-iso-date (iso)
  "Extract YYYY-MM-DD from RFC3339/ISO8601 string ISO without timezone conversion."
  (when (and iso (string-match "\\`\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" iso))
    (match-string 1 iso)))

(defun gtasks-org-tools--format-iso-to-org (iso)
  "Convert ISO (ISO8601) to \"YYYY-MM-DD Day HH:MM\"."
  (when iso
    (format-time-string "%Y-%m-%d %a %H:%M"
			(ignore-errors (date-to-time iso)))))

(defun gtasks-org-tools--task-to-org (tasklist-id task)
  "Return an Org subtree string for TASK in TASKLIST-ID.
Adds GTASKS_TASKLIST_ID and GTASKS_TASK_ID in a property drawer."
  (let* ((status (plist-get task :status))           ;; \"needsAction\" | \"completed\"
         (done-p (string= status "completed"))
         (kw (if done-p gtasks-org-tools-done-todo gtasks-org-tools-default-todo))
         (title (or (plist-get task :title) "(no title)"))
         (notes (or (plist-get task :notes) ""))
         (task-id (plist-get task :id))
         (closed (gtasks-org-tools--format-iso-to-org (plist-get task :completed)))
         (due   (gtasks-org-tools--format-iso-date (plist-get task :due)))
         (title-line (concat "* " kw " " title (if due (format " <%s>" due) ""))))
    (concat
     title-line "\n"
     (when closed (format "CLOSED: [%s]\n" closed))
     ":PROPERTIES:\n"
     (format ":GTASKS_TASKLIST_ID: %s\n" (or tasklist-id ""))
     (format ":GTASKS_TASK_ID: %s\n" (or task-id ""))
     ":END:\n"
     (unless (string-empty-p notes) (concat notes "\n")))))

(defun gtasks-org-tools--append-org-file (entries file)
  "Append Org ENTRIES to FILE.  Return t if appended."
  (when entries
    (let ((abs (expand-file-name file)))
      (with-current-buffer (find-file-noselect abs)
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert (mapconcat #'identity entries ""))
        (save-buffer)
        t))))

(defun gtasks-org-tools--rfc3339-date-midnight (date)
  "Convert DATE into an RFC3339 midnight timestamp.

Arguments:
- DATE: String formatted as \"YYYY-MM-DD\".

Returns:
- RFC3339 timestamp string or nil when DATE is invalid."
  (when (and (stringp date)
             (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'" date))
    (format "%sT00:00:00.000Z" date)))

(defun gtasks-org-tools--org-ts->yyyy-mm-dd (s)
  "Return YYYY-MM-DD from an Org timestamp string S, or nil."
  (when (and s (stringp s)
             (string-match "\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" s))
    (match-string 1 s)))

(defun gtasks-org-tools--clean-org-entry-title (s)
  "Remove date expressions like <2025-10-10 Fri> or [2025-10-10] from S and trim."
  (when s
    (string-trim
     (replace-regexp-in-string
      " \\(\\[\\|<\\)[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}[^]>]*\\(>\\|\\]\\)" "" s))))

(defun gtasks-org-tools--clean-org-entry-body (s)
  "Remove PROPERTIES drawers and dates from S (an org entry body).
Return cleaned string, nil if result is empty/whitespace."
  (let ((res
         (with-temp-buffer
           (insert s)
           ;; Remove any PROPERTIES drawer(s): from a line starting with :PROPERTIES: to the matching :END:
           (goto-char (point-min))
           (while (re-search-forward "^\\s-*:PROPERTIES:\\s-*$" nil t)
             (let ((beg (match-beginning 0)))
               (if (re-search-forward "^\\s-*:END:\\s-*$" nil t)
                   (delete-region beg (match-end 0))
                 ;; If no :END: is found, drop to end of buffer
                 (delete-region beg (point-max)))))
           ;; Drop lines consisting solely of: <...> or [...] or SCHEDULED:/DEADLINE: <...|[...]>
           (goto-char (point-min))
           (flush-lines
            "^\\s-*\\(?:\\(?:SCHEDULED:\\|DEADLINE:\\)\\s-*\\)?\\(?:<[^>\n]+>\\|\\[[^]\n]+\\]\\)\\s-*$")
           ;; Trim leading/trailing blank lines
           (goto-char (point-min))
           (while (looking-at "^[ \t]*\n") (replace-match ""))
           (goto-char (point-max))
           (while (and (> (point) (point-min))
                       (save-excursion (forward-line -1) (looking-at "^[ \t]*$")))
             (forward-line -1))
           (buffer-substring-no-properties (point-min) (point-max)))))
    (if (string-match-p "\\`[ \t\n]*\\'" res) nil res)))

(defun gtasks-org-tools--org-entry-to-plist ()
  "Convert the current Org entry to a property list.

Extracts the title, TODO state, timestamp / deadline, body,
and properties from the current Org entry and returns them as a property list.

The keys in the property list are :title, :todo, :due, :body, and :props."
  (let* ((title (gtasks-org-tools--clean-org-entry-title (org-no-properties (org-get-heading t t t t))))
         (todo  (org-no-properties (org-get-todo-state)))  ;; capture TODO keyword if any
         (deadline (org-entry-get nil "DEADLINE"))
         (active (save-excursion
                   (goto-char (org-entry-beginning-position))
                   (when (re-search-forward org-ts-regexp (org-entry-end-position) t)
                     (org-no-properties (match-string 0)))))
         (due (or (gtasks-org-tools--org-ts->yyyy-mm-dd deadline)
                  (gtasks-org-tools--org-ts->yyyy-mm-dd active)))
         (body (gtasks-org-tools--clean-org-entry-body (org-no-properties (org-get-entry))))
         ;; PROPERTIES drawer → plist (user properties only, local to this entry)
         (props-plist
          (let* ((alist (org-entry-properties nil 'standard)) ; user-defined props at this heading
                 (plist (cl-loop for (k . v) in alist
                                 if (and v (not (string-empty-p v)))
                                 append (list (intern (concat ":" (upcase k))) v))))
            (and plist plist))))
    (list :title title
          :todo todo
          :due due
          :body body
          :props props-plist)))

(defun gtasks-org-tools--org-plist-to-gtask-plist (p)
  "Convert an org entry plist P to a gtask plist for calling the API."
  (list :title (plist-get p :title)
	:notes (plist-get p :body)
	:due (gtasks-org-tools--rfc3339-date-midnight (plist-get p :due))))

(defun gtasks-org-tools--find-tagged-entries (tag)
  "Find org entries that match TAG.

Org entries are filtered such that they don't have a past due date such as
DEADLINEs or timestamps."
  (org-ql-select (org-agenda-files)
    `(and (tags ,tag)
          (not (deadline :to -1))
          (not (ts-active :to -1))
          (not (ts-inactive :to -1)))
    :action (lambda ()
	      (gtasks-org-tools--org-plist-to-gtask-plist
	       (gtasks-org-tools--org-entry-to-plist)))))

(defun gtasks-org-tools--tasklist-ensure (title)
  "Return tasklist id for TITLE, creating the list if necessary."
  (or (gtasks-tasklist-id-by-title title)
      (plist-get (gtasks-tasklist-insert `(:title ,title)) :id)))

(defun gtasks-org-tools-pull (tasklist-id file &rest post-import-action)
  "Fetch tasks for TASKLIST-ID, append to FILE, and optionally post-process them.

Runs `gtasks-org-tools-after-append-hook' before post-import-action.

POST-IMPORT-ACTION (optional) controls what to do with imported tasks:
  - nil (default):  do nothing.
  - 'complete    :  mark each imported task completed.
  - 'delete      :  delete each imported task.

Returns t if entries were successfully appended."
  (let* ((action (car post-import-action)))
    (unless (memq action '(nil complete delete))
      (user-error "Invalid post-import-action: %S (expected nil, 'complete, or 'delete)" action))
    (let ((tasklist (gtasks-tasklist-get tasklist-id)))
      (when tasklist
        (let* ((tasks   (plist-get (gtasks-task-list tasklist-id) :items))
               (entries (mapcar (lambda (tsk)
				  (gtasks-org-tools--task-to-org tasklist-id tsk))
				tasks))
               (ok      (gtasks-org-tools--append-org-file entries file))
               (abs     (expand-file-name file)))
          (when ok
            (run-hook-with-args 'gtasks-org-tools-after-append-hook entries tasks tasklist abs)
            (let ((fn (cond ((eq action 'delete)   #'gtasks-task-delete)
                            ((eq action 'complete) #'gtasks-task-complete))))
              (when fn
                (dolist (tsk tasks)
                  (ignore-errors
                    (funcall fn tasklist-id (plist-get tsk :id)))))))
          ok)))))

(defun gtasks-org-tools-push-tags (tags)
  "Exports entries matching any of the TAGS to a Google Tasklist of the same name.
If a tasklist with a matching name doesn't exist then it is created.

Returns an alist of:
  (TAG . (:tasklist-id TASKLIST-ID :created (TASK ...)))
where each TASK is a Google Task API response."
  (mapcar (lambda (tag)
	    (let ((entries (gtasks-org-tools--find-tagged-entries tag)))
	      (cons tag
		    (and entries
			 (let* ((tlid (gtasks-org-tools--tasklist-ensure tag))
				(created (mapcar (lambda (tsk)
						   (gtasks-task-insert tlid tsk))
						 entries)))
			   (list :tasklist-id tlid :created created))))))
	  tags))

(provide 'gtasks-org-tools)

;;; gtasks-org-tools.el ends here
