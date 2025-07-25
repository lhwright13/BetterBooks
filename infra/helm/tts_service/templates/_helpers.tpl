{{- define "tts-service.name" -}}
tts-service
{{- end -}}

{{- define "tts-service.fullname" -}}
{{ include "tts-service.name" . }}
{{- end -}}
