{{/*
Create normal envvars
*/}}
{{- define "fjord.normalEnvVars" -}}
{{- range $key, $val := .Values.envvar }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
{{- end }}

{{/*
Create secret envvars
*/}}
{{- define "fjord.secretEnvVars"}}
{{- range $key, $val := .Values.secrets }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.secretsRepo | default "fjord" | quote}}
      key: {{ $key }}
{{- end }}
{{- end }}
