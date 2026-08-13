// Package ark owns the Volcengine Ark inference identity used by Jarvis model
// transports. Public source snapshots must not commit API keys; provide the key
// through JARVIS_ARK_API_KEY in the local runtime environment.
package ark

import (
	"os"
	"strings"
)

const (
	BaseURL = "https://ark.cn-beijing.volces.com/api/coding/v3"

	EmbeddingModel      = "doubao-embedding-vision-251215"
	EmbeddingDimensions = 1024
)

var APIKey = strings.TrimSpace(os.Getenv("JARVIS_ARK_API_KEY"))
