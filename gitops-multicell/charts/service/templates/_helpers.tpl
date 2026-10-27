{{- define "service.name" -}}
{{- required "name es obligatorio" .Values.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "service.image" -}}
{{- $tag := required "image.tag es obligatorio (SHA del commit)" .Values.image.tag -}}
{{- if eq $tag "latest" -}}
{{- fail "image.tag no puede ser latest: usar un tag inmutable" -}}
{{- end -}}
{{- printf "%s:%s" (required "image.repository es obligatorio" .Values.image.repository) $tag -}}
{{- end -}}

{{- define "service.labels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
platform.example.io/cell: {{ .Values.cell.name | quote }}
platform.example.io/env: {{ .Values.cell.env | quote }}
{{- end -}}

{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
{{- end -}}

{{- define "service.secretName" -}}
{{- printf "%s-secrets" (include "service.name" .) -}}
{{- end -}}
