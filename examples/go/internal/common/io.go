package common

import (
	"bytes"
	"io"
)

func BytesReader(b []byte) *bytes.Reader { return bytes.NewReader(b) }

func ReadAll(rc io.ReadCloser) ([]byte, error) {
	defer rc.Close()
	return io.ReadAll(rc)
}
