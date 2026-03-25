{{/*
Expand the name of the chart.
*/}}
{{- define "payment.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the namespace used by chart resources.
*/}}
{{- define "payment.namespace" -}}
{{- default .Release.Namespace .Values.namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the primary app label used by existing manifests.
*/}}
{{- define "payment.appName" -}}
{{- default (include "payment.name" .) .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "payment.fullname" -}}
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
{{- define "payment.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "payment.labels" -}}
helm.sh/chart: {{ include "payment.chart" . }}
{{ include "payment.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "payment.selectorLabels" -}}
app: {{ include "payment.appName" . }}
{{- end }}

{{/*
Create the name of the Deployment to use.
*/}}
{{- define "payment.deploymentName" -}}
{{- default (include "payment.fullname" .) .Values.deployment.name }}
{{- end }}

{{/*
Create the name of the Service to use.
*/}}
{{- define "payment.serviceName" -}}
{{- default (include "payment.fullname" .) .Values.service.name }}
{{- end }}

{{/*
Create the name of the HPA to use.
*/}}
{{- define "payment.hpaName" -}}
{{- default (include "payment.fullname" .) .Values.autoscaling.name }}
{{- end }}

{{/*
Create the name of the container to use.
*/}}
{{- define "payment.containerName" -}}
{{- default (include "payment.appName" .) .Values.container.name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "payment.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "payment.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
