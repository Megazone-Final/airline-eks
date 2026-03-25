{{/*
Expand the name of the chart.
*/}}
{{- define "auth.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the namespace used by chart resources.
*/}}
{{- define "auth.namespace" -}}
{{- default .Release.Namespace .Values.namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the primary app label used by existing manifests.
*/}}
{{- define "auth.appName" -}}
{{- default (include "auth.name" .) .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "auth.fullname" -}}
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
{{- define "auth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "auth.labels" -}}
helm.sh/chart: {{ include "auth.chart" . }}
{{ include "auth.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "auth.selectorLabels" -}}
app: {{ include "auth.appName" . }}
{{- end }}

{{/*
Create the name of the Deployment to use.
*/}}
{{- define "auth.deploymentName" -}}
{{- default (include "auth.fullname" .) .Values.deployment.name }}
{{- end }}

{{/*
Create the name of the Service to use.
*/}}
{{- define "auth.serviceName" -}}
{{- default (include "auth.fullname" .) .Values.service.name }}
{{- end }}

{{/*
Create the name of the HPA to use.
*/}}
{{- define "auth.hpaName" -}}
{{- default (include "auth.fullname" .) .Values.autoscaling.name }}
{{- end }}

{{/*
Create the name of the container to use.
*/}}
{{- define "auth.containerName" -}}
{{- default (include "auth.appName" .) .Values.container.name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "auth.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "auth.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
