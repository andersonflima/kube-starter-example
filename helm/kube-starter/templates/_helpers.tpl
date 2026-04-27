{{- define "kube-starter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kube-starter.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "kube-starter.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kube-starter.backendFullname" -}}
{{- printf "%s-backend" (include "kube-starter.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kube-starter.frontendFullname" -}}
{{- printf "%s-frontend" (include "kube-starter.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kube-starter.labels" -}}
app.kubernetes.io/name: {{ include "kube-starter.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

