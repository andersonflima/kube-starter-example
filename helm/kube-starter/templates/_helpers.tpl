{{- define "kube-starter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kube-starter.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "kube-starter.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
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
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: kube-starter
{{- end -}}

{{- define "kube-starter.selectorLabels" -}}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
