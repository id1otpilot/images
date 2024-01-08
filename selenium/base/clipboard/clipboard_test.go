package main

import (
	"bytes"
	"errors"
	"io"
	"math/rand"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"golang.design/x/clipboard"
)

type errReader int

func (errReader) Read(p []byte) (n int, err error) {
	return 0, errors.New("test error")
}

func randomString(length int) string {
	charset := "`" + ` !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~`
	seededRand := rand.New(rand.NewSource(time.Now().UnixNano()))
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[seededRand.Intn(len(charset))]
	}
	return string(b)
}

func TestClipboardHandler(t *testing.T) {
	type test struct {
		data       string
		httpMethod string
		statusCode int
		expected   string
	}
	tests := map[string]test{
		"method not allowed": {
			httpMethod: http.MethodPut,
			statusCode: http.StatusMethodNotAllowed,
		},
		"bad request": {
			httpMethod: http.MethodPost,
			statusCode: http.StatusBadRequest,
		},
		"payload too large": {
			httpMethod: http.MethodPost,
			statusCode: http.StatusRequestEntityTooLarge,
		},
		"get clipboard short text value": {
			data:       randomString(100),
			httpMethod: http.MethodGet,
			statusCode: http.StatusOK,
		},
		"get clipboard long text value": {
			data:       randomString(1048576),
			httpMethod: http.MethodGet,
			statusCode: http.StatusOK,
		},
		"set clipboard short text value": {
			data:       randomString(100),
			httpMethod: http.MethodPost,
			statusCode: http.StatusOK,
		},
		"set clipboard long text value": {
			data:       randomString(1048576),
			httpMethod: http.MethodPost,
			statusCode: http.StatusOK,
		},
	}

	for description, test := range tests {

		rr := httptest.NewRecorder()

		t.Run(description, func(t *testing.T) {
			switch test.httpMethod {
			case http.MethodGet:
				if test.data != "" {
					test.expected = test.data
					clipboard.Write(clipboard.FmtText, []byte(test.data))
				}

				req := httptest.NewRequest(test.httpMethod, "/", nil)
				clipboardHandler(rr, req)
				if rr.Code != test.statusCode {
					t.Errorf("handler returned wrong status code: got %v want %v",
						rr.Code, test.statusCode)
				}

				if test.expected != "" {
					buf := new(strings.Builder)
					_, err := io.Copy(buf, rr.Body)
					if err != nil {
						t.Error(err)
					}
					responseString := buf.String()
					if responseString != test.expected {
						t.Errorf("clipboard has unexpected value")
					}
				}
			case http.MethodPost:
				if test.data != "" {
					test.expected = test.data
				}

				req := httptest.NewRequest(test.httpMethod, "/", bytes.NewReader([]byte(test.data)))

				if test.statusCode == http.StatusBadRequest {
					req = httptest.NewRequest(test.httpMethod, "/", errReader(0))
				}

				if test.statusCode == http.StatusRequestEntityTooLarge {
					req = httptest.NewRequest(test.httpMethod, "/", bytes.NewReader([]byte(randomString(1050000))))
				}

				clipboardHandler(rr, req)
				if rr.Code != test.statusCode {
					t.Errorf("handler returned wrong status code: got %v want %v",
						rr.Code, test.statusCode)
				}

				if test.expected != "" {
					dataFromClipboard := string(clipboard.Read(clipboard.FmtText))
					if dataFromClipboard != test.expected {
						t.Errorf("clipboard has unexpected value")
					}
				}
			default:
				req := httptest.NewRequest(test.httpMethod, "/", nil)
				clipboardHandler(rr, req)
				if rr.Code != test.statusCode {
					t.Errorf("handler returned wrong status code: got %v want %v",
						rr.Code, test.statusCode)
				}
			}
		})
	}
}
