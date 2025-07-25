{{- define "llm-gateway.name" -}}
llm-gateway
{{- end -}}

{{- define "llm-gateway.fullname" -}}
{{ include "llm-gateway.name" . }}
{{- end -}}
