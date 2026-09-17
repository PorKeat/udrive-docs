{{/*
Expand the name of the chart.
*/}}
{{- define "udrive.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "udrive.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "udrive.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "udrive.labels" -}}
helm.sh/chart: {{ include "udrive.chart" . }}
{{ include "udrive.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "udrive.selectorLabels" -}}
app.kubernetes.io/name: {{ include "udrive.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get the secret name for admin password
*/}}
{{- define "udrive.secretName" -}}
{{- if .Values.udrive.admin.existingSecret }}
{{- .Values.udrive.admin.existingSecret }}
{{- else }}
{{- include "udrive.fullname" . }}
{{- end }}
{{- end }}

{{/*
Get the secret name for S3 credentials
*/}}
{{- define "udrive.s3SecretName" -}}
{{- if .Values.storage.s3.existingSecret }}
{{- .Values.storage.s3.existingSecret }}
{{- else }}
{{- printf "%s-s3" (include "udrive.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "udrive.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "udrive.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
