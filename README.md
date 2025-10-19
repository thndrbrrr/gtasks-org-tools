# gtasks-org-tools.el

`gtasks-org-tools.el` helps you capture Google Tasks in Org and publish selected (tagged) Org entries back to Google Tasks.

**Note:** This package intentionally avoids two-way synchronization. Edits in Org do not update Google Tasks, and changes inside Google Tasks do not alter existing Org headlines.

The idea is to treat your Google tasklists (e.g. "My Tasks") as temporary inboxes for collecting items on the go. Import them into something like `inbox.org`, then process them in Org. When exporting Org entries with certain tags consider those Google tasklists like disposable snapshots.

[gtasks.el](https://github.com/thndrbrrr/gtasks) provides the Google Tasks API bindings used by this package.

## Installation

Add the repository to your `load-path` and require the library:

```elisp
(add-to-list 'load-path "/path/to/gtasks-org-tools")
(require 'gtasks-org-tools)
```

If you use `use-package`, you can load it lazily:

```elisp
(use-package gtasks-org-tools
  :load-path "/path/to/gtasks-org-tools")
```

## Usage

### Import tasks

Import from a Google tasklist and append to an Org file:

``` elisp
(gtasks-org-tools-pull (gtasks-tasklist-id-by-title "My Tasks")
			           (concat my/org-directory "/inbox.org")
			           'complete)
```

`gtasks-org-tools-pull` accepts an optional third argument that determines how the source Google tasks are treated after they are written to the Org file:

* Omit the argument to leave the remote tasks untouched.
* `'complete` to mark the imported Google tasks as completed.
* `'delete` to remove the imported Google tasks.

`gtasks-org-tools-after-append-hook` is invoked after entries have been appended and saved.

### Export tagged Org entries

You can provide a list of tags to export. `org-sync-tools` will create Google tasklists of the same name if they don't exist. During export, entries whose deadlines or timestamps fall before today are filtered out so that overdue items stay in Org:

```elisp
(gtasks-org-tools-push-tags '("@ERRAND" "@NYC" "Shopping"))
```

### Configuration in `init.el`

An end-to-end setup for defining helper commands in your `init.el` for import and export could look like this:

``` elisp
(add-to-list 'load-path "/path/to/gtasks")
(require 'gtasks)

(setq gtasks-client-id
      "some-client-id.apps.googleusercontent.com")

(setq gtasks-client-secret
      (lambda ()
		  (auth-source-pick-first-password :host "google-api-creds")))

;; Run once to get the refresh token.
;; (gtasks-authorize)

(add-to-list 'load-path "/path/to/gtasks-org-tools")
(require 'gtasks-org-tools)

;; Run once to get a tasklist's ID (so you don't have to look it up every time).
;; (gtasks-tasklist-id-by-title "My Tasks")

(defun my/import-gtasks-to-inbox ()
  "Import tasks from Google's 'My Tasks' list and append them to inbox.org.
Mark all imported entries as completed."
  (interactive)
  (gtasks-org-tools-pull "sOmElOnGtAsKlIsTId"  ;; My Tasks
	                     (concat my/org-directory "/inbox.org")
			             'complete))

(defun my/export-tags-to-gtasks ()
  "Export tagged Org entries to Google Tasks."
  (interactive)
  (gtasks-org-tools-push-tags '("@ERRAND" "@NYC" "Shopping")))
```

## Customization

All package options live under `M-x customize-group RET gtasks-org-tools RET`. You can also set them in your init file before requiring `gtasks-org-tools.el`:

* **`gtasks-org-tools-default-todo`** – Todo keyword applied to imported tasks that are still open.
* **`gtasks-org-tools-done-todo`** – Todo keyword used for imported tasks that are already completed.
* **`gtasks-org-tools-after-append-hook`** – Hook invoked after entries are appended and saved.

## License

Distributed under the terms of the GNU General Public License Version 3.  See `LICENSE` for details.
