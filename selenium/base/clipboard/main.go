package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", clipboardHandler)
	log.Fatal(http.ListenAndServe(":9090", nil))
}
