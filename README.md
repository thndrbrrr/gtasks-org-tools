# gtasks-org-tools.el

`gtasks-org-tools.el` allows you to import Google Tasks into Org and export tagged Org entries to Google Tasks.

**Note:** This is not the same "syncing" between the two systems. Making changes in Org will not affect the corresponding Google Tasks, and completing or deleting Google Tasks will not affect Org entries.

The idea is for data to flow only one way, using Google Tasks on the road. Treat the "My Tasks" tasklist as an inbox, which you can then import and add to your `inbox.org`. Similar idea for exporting: treat the exported lists as throwaways.

[gtasks.el](https://github.com/thndrbrrr/gtasks) is used for interacting with Google Tasks API.

## Installation

Add the repository to your `load-path` and require the library:

```elisp
(add-to-list 'load-path "/path/to/gtasks-org-tools")
(require 'gtasks-org-tools)
```

If you use `use-package`, you can load it lazily:

```elisp
(use-package gtasks-org-tools
  :load-path "~/src/gtasks-org-tools")
```

## Usage

Import tasks from a Google tasklist and append to an Org file:

``` elisp
(gtasks-org-tools-pull (gtasks-tasklist-id-by-title "My Tasks")
			 (concat my/org-directory "/inbox.org")
			 'complete)
```

Export tagged Org entries to Google tasklists of the same name:

```elisp
(gtasks-org-tools-push-tags '("@ERRAND" "@NYC" "Shopping"))
```

The end-to-end setup for to setup functions for importing and exporting could look like this:

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
  (gtasks-org-tools-pull "sOmEtAsKlIsTId"  ;; My Tasks
	                     (concat my/org-directory "/inbox.org")
			             'complete))

(defun my/export-tags-to-gtasks ()
  "Export tagged org entries to Google Tasks."
  (interactive)
  (gtasks-org-tools-push-tags '("@ERRAND" "@NYC" "Shopping")))

```

## Customization

All package options live under `M-x customize-group RET gtasks-org-tools RET`.

TODO

Adjust these variables either through Customize or by setting them in your init file prior to requiring `gtasks-org-tools.el`.

## License

Distributed under the terms of the GNU General Public License Version 3.  See `LICENSE` for details.
