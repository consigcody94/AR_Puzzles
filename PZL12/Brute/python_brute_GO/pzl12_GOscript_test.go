package main

import (
	"encoding/base64"
	"reflect"
	"testing"
)

func TestParseMessage(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		wantSalt    []byte
		wantCipher  []byte
		wantErr     bool
		errMessage  string
	}{
		{
			name:       "valid salted message",
			input:      base64.StdEncoding.EncodeToString(append([]byte("Salted__12345678"), []byte("ciphertext")...)),
			wantSalt:   []byte("12345678"),
			wantCipher: []byte("ciphertext"),
			wantErr:    false,
		},
		{
			name:       "invalid base64",
			input:      "!!!",
			wantErr:    true,
			errMessage: "base64 invalid",
		},
		{
			name:       "too short message",
			input:      base64.StdEncoding.EncodeToString([]byte("Salted__1234567")),
			wantErr:    true,
			errMessage: "Invalid data",
		},
		{
			name:       "missing Salted__ prefix",
			input:      base64.StdEncoding.EncodeToString([]byte("NotSaltd12345678ciphertext")),
			wantErr:    true,
			errMessage: "Invalid data",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotSalt, gotCipher, err := parseMessage(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("parseMessage() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if tt.wantErr && err.Error() != tt.errMessage {
				t.Errorf("parseMessage() error message = %v, want %v", err.Error(), tt.errMessage)
			}
			if !tt.wantErr {
				if !reflect.DeepEqual(gotSalt, tt.wantSalt) {
					t.Errorf("parseMessage() gotSalt = %v, want %v", gotSalt, tt.wantSalt)
				}
				if !reflect.DeepEqual(gotCipher, tt.wantCipher) {
					t.Errorf("parseMessage() gotCipher = %v, want %v", gotCipher, tt.wantCipher)
				}
			}
		})
	}
}

func TestB64toBinary(t *testing.T) {
	// Reset globals
	pz_salt = nil
	pz_cipherBytes = nil
	pz_cipherBytesLen = 0

	// This calls b64toBinary which uses the global 'msg' constant
	// We should verify it populates the globals correctly.

	// We expect b64toBinary not to panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("b64toBinary() panicked: %v", r)
		}
	}()

	b64toBinary()

	if len(pz_salt) != 8 {
		t.Errorf("pz_salt length = %v, want 8", len(pz_salt))
	}
	if len(pz_cipherBytes) == 0 {
		t.Errorf("pz_cipherBytes is empty")
	}
	if pz_cipherBytesLen != len(pz_cipherBytes) {
		t.Errorf("pz_cipherBytesLen = %v, want %v", pz_cipherBytesLen, len(pz_cipherBytes))
	}
}
