{{- define "context-service.name" -}}
context-service
{{- end -}}

{{- define "context-service.fullname" -}}
{{ include "context-service.name" . }}
{{- end -}}
