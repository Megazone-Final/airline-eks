{{/*
Expand the name of the chart.
*/}}
{{- define "flight.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the namespace used by chart resources.
*/}}
{{- define "flight.namespace" -}}
{{- default .Release.Namespace .Values.namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the primary app label used by existing manifests.
*/}}
{{- define "flight.appName" -}}
{{- default (include "flight.name" .) .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "flight.fullname" -}}
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
{{- define "flight.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flight.labels" -}}
helm.sh/chart: {{ include "flight.chart" . }}
{{ include "flight.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flight.selectorLabels" -}}
app: {{ include "flight.appName" . }}
{{- end }}

{{/*
Create the name of the Deployment to use.
*/}}
{{- define "flight.deploymentName" -}}
{{- default (include "flight.fullname" .) .Values.deployment.name }}
{{- end }}

{{/*
Create the name of the Service to use.
*/}}
{{- define "flight.serviceName" -}}
{{- default (include "flight.fullname" .) .Values.service.name }}
{{- end }}

{{/*
Create the name of the HPA to use.
*/}}
{{- define "flight.hpaName" -}}
{{- default (include "flight.fullname" .) .Values.autoscaling.name }}
{{- end }}

{{/*
Create the name of the container to use.
*/}}
{{- define "flight.containerName" -}}
{{- default (include "flight.appName" .) .Values.container.name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flight.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flight.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
