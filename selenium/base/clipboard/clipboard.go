package main

import (
	"io"
	"net/http"

	"golang.design/x/clipboard"
)

func clipboardHandler(w http.ResponseWriter, r *http.Request) {

	if err := clipboard.Init(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	switch r.Method {
	case http.MethodGet:
		b := clipboard.Read(clipboard.FmtText)
		w.Write(b)
	case http.MethodPost:
		if r.ContentLength > 1048576 {
			http.Error(w, http.StatusText(http.StatusRequestEntityTooLarge), http.StatusRequestEntityTooLarge)
			return
		}
		b, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
			return
		}
		clipboard.Write(clipboard.FmtText, b)
	default:
		http.Error(w, http.StatusText(http.StatusMethodNotAllowed), http.StatusMethodNotAllowed)
		return
	}
}
