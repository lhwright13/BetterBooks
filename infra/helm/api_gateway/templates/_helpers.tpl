{{- define "api-gateway.name" -}}
api-gateway
{{- end -}}

{{- define "api-gateway.fullname" -}}
{{ include "api-gateway.name" . }}
{{- end -}}
